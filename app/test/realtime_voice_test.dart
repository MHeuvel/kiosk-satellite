import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiosk_satellite/managers/voice/assist_view.dart';
import 'package:kiosk_satellite/managers/voice/realtime/mcp_client.dart';
import 'package:kiosk_satellite/managers/voice/realtime/openai_realtime_backend.dart';
import 'package:kiosk_satellite/managers/voice/realtime/pcm_resampler.dart';
import 'package:kiosk_satellite/managers/voice/realtime/realtime_backend.dart';
import 'package:kiosk_satellite/managers/voice/realtime/realtime_player.dart';
import 'package:kiosk_satellite/managers/voice/realtime/realtime_session.dart';
import 'package:kiosk_satellite/managers/voice/realtime/realtime_tools.dart';
import 'package:kiosk_satellite/managers/voice/voice_session.dart';

Uint8List _pcm(List<int> samples) {
  final out = Uint8List(samples.length * 2);
  final view = ByteData.sublistView(out);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, samples[i], Endian.little);
  }
  return out;
}

List<int> _samples(Uint8List pcm) {
  final view = ByteData.sublistView(pcm);
  return [
    for (var i = 0; i < pcm.length ~/ 2; i++)
      view.getInt16(i * 2, Endian.little),
  ];
}

// ── the socket and the tools ──────────────────────────────────────────────

class _Socket implements RealtimeSocket {
  final incoming = StreamController<Object?>();
  final sent = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Stream<Object?> get messages => incoming.stream;

  @override
  void send(String message) =>
      sent.add((jsonDecode(message) as Map).cast<String, Object?>());

  @override
  Future<void> close() async {
    closed = true;
    await incoming.close();
  }

  @override
  String? get closeReason => null;

  void server(Map<String, Object?> event) => incoming.add(jsonEncode(event));

  List<String> get types => [for (final m in sent) '${m['type']}'];
}

class _Tools implements RealtimeToolbox {
  final calls = <(String, Map<String, Object?>)>[];
  Completer<void>? gate;

  @override
  Future<List<RealtimeToolSpec>> list() async => const [
    RealtimeToolSpec(
      name: 'intent__HassTurnOn',
      description: 'Turns on',
      parameters: {'type': 'object', 'properties': <String, Object?>{}},
    ),
    RealtimeToolSpec(
      name: LocalToolbox.endConversation,
      description: 'End',
      parameters: {'type': 'object', 'properties': <String, Object?>{}},
    ),
  ];

  @override
  Future<RealtimeToolOutput> call(
    String name,
    Map<String, Object?> args,
  ) async {
    calls.add((name, args));
    await gate?.future;
    if (name == LocalToolbox.endConversation) {
      return const RealtimeToolOutput('{}', endConversation: true);
    }
    return const RealtimeToolOutput('{"success": true}');
  }

  @override
  String originalName(String name) => name;

  @override
  void close() {}
}

// ── the session's ports ───────────────────────────────────────────────────

class _Backend implements RealtimeBackend {
  final _events = StreamController<RealtimeEvent>();
  final audio = <Uint8List>[];
  final interruptions = <(String, int)>[];
  RealtimeStart? started;
  bool closed = false;

  @override
  RealtimeCapabilities get capabilities => const RealtimeCapabilities();

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Future<void> start(RealtimeStart start) async => started = start;

  @override
  void sendAudio(Uint8List pcm) => audio.add(pcm);

  @override
  void interrupted(String itemId, int playedMs) =>
      interruptions.add((itemId, playedMs));

  @override
  Future<void> close() async {
    closed = true;
    await _events.close();
  }

  void emit(RealtimeEvent event) => _events.add(event);
}

class _Mic implements VoiceMicPort {
  void Function(Uint8List pcm, bool preRoll)? sink;
  int closes = 0;

  @override
  Future<bool> open(void Function(Uint8List pcm, bool preRoll) onChunk) async {
    sink = onChunk;
    return true;
  }

  @override
  Future<void> close() async {
    closes++;
    sink = null;
  }

  /// 80 ms at 16 kHz.
  void speak({int value = 1000, bool preRoll = false}) =>
      sink?.call(_pcm(List.filled(1280, value)), preRoll);
}

class _Player implements RealtimePlayerPort {
  final written = <Uint8List>[];

  /// Frames the fake track has played, moved by the test.
  int frames = 0;
  int flushes = 0;
  bool open = false;
  int? rate;

  @override
  Future<bool> start(int sampleRate) async {
    rate = sampleRate;
    return open = true;
  }

  @override
  void write(Uint8List pcm) => written.add(pcm);

  @override
  Future<int> flush() async {
    flushes++;
    return frames;
  }

  @override
  Future<int> played() async => frames;

  @override
  Future<void> stop() async => open = false;
}

class _Chimes implements VoicePlayerPort {
  final chimes = <String>[];
  int settled = 0;

  @override
  Future<(String, double)?> chime(String kind) async {
    chimes.add(kind);
    return ('c${chimes.length}', 0.3);
  }

  @override
  Future<String?> play(
    String url, {
    String text = '',
    bool announcement = false,
  }) async => null;

  @override
  Future<void> stop(String id) async {}

  @override
  Future<void> settle() async => settled++;
}

class _Harness {
  _Harness(this.time, {this.options = const RealtimeOptions()}) {
    session = RealtimeSession(
      backend: () => backend,
      mic: mic,
      player: player,
      chimes: chimes,
      options: () => options,
      onView: views.add,
      onLevel: (_) {},
      onCountdown: countdown.add,
      onBusy: (busy, _) => busy_.add(busy),
      onStopArmed: stopArmed.add,
      onError: (code, _) => errors.add(code),
      onIdle: () => idles++,
      now: () => DateTime(2026).add(time.elapsed),
    );
  }

  final FakeAsync time;
  RealtimeOptions options;
  late final RealtimeSession session;
  final backend = _Backend();
  final mic = _Mic();
  final player = _Player();
  final chimes = _Chimes();
  final views = <AssistView>[];
  final countdown = <double>[];
  final busy_ = <bool>[];
  final stopArmed = <bool>[];
  final errors = <String>[];
  int idles = 0;

  AssistView get view => views.last;

  /// Wakes, lets the chime pass and brings the backend up.
  void wakeAndConnect() {
    unawaited(session.wake('Hey Jarvis'));
    time.flushMicrotasks();
    time.elapse(const Duration(milliseconds: 600));
    backend.emit(const RealtimeReady());
    time.flushMicrotasks();
  }

  /// One second of the model's voice at 24 kHz.
  void answer(String item, {int seconds = 1}) {
    backend.emit(const RealtimeResponseStarted());
    backend.emit(RealtimeAudio(item, _pcm(List.filled(24000 * seconds, 3000))));
    time.flushMicrotasks();
  }
}

void main() {
  group('PcmResampler', () {
    test('16 kHz to 24 kHz makes three samples of every two', () {
      final r = PcmResampler(from: 16000, to: 24000);
      var total = 0;
      for (var i = 0; i < 10; i++) {
        total += r.convert(_pcm(List.filled(1280, 100))).length ~/ 2;
      }
      // 12800 in, 19200 out, give or take the last carried sample.
      expect(total, closeTo(19200, 2));
    });

    test('interpolates across chunk edges', () {
      final r = PcmResampler(from: 16000, to: 24000);
      final a = _samples(r.convert(_pcm([0, 300])));
      final b = _samples(r.convert(_pcm([600, 900])));
      final all = [...a, ...b];
      // A straight ramp stays a straight ramp at 200 per output sample.
      for (var i = 1; i < all.length; i++) {
        expect(all[i] - all[i - 1], 200);
      }
    });

    test('the same rate passes through', () {
      final r = PcmResampler(from: 24000, to: 24000);
      final pcm = _pcm([1, 2, 3]);
      expect(r.convert(pcm), same(pcm));
    });
  });

  group('McpClient', () {
    test(
      'initializes once, keeps the session and reads an event stream',
      () async {
        final requests = <Map<String, Object?>>[];
        final sessions = <String?>[];
        final client = MockClient.streaming((request, body) async {
          final text = await body.bytesToString();
          final json = (jsonDecode(text) as Map).cast<String, Object?>();
          requests.add(json);
          sessions.add(request.headers['Mcp-Session-Id']);
          expect(request.headers['Authorization'], 'Bearer tok');
          switch (json['method']) {
            case 'initialize':
              return http.StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'jsonrpc': '2.0',
                      'id': json['id'],
                      'result': {'protocolVersion': '2025-06-18'},
                    }),
                  ),
                ),
                200,
                headers: {
                  'content-type': 'application/json',
                  'mcp-session-id': 'sess1',
                },
              );
            case 'notifications/initialized':
              return http.StreamedResponse(const Stream.empty(), 202);
            case 'tools/list':
              final event =
                  'event: message\ndata: ${jsonEncode({
                    'jsonrpc': '2.0',
                    'id': json['id'],
                    'result': {
                      'tools': [
                        {
                          'name': 'HassTurnOn',
                          'description': 'Turns on a device',
                          'inputSchema': {'type': 'object', 'properties': {}},
                        },
                      ],
                    },
                  })}\n\n';
              return http.StreamedResponse(
                Stream.value(utf8.encode(event)),
                200,
                headers: {'content-type': 'text/event-stream'},
              );
            case 'tools/call':
              return http.StreamedResponse(
                Stream.value(
                  utf8.encode(
                    jsonEncode({
                      'jsonrpc': '2.0',
                      'id': json['id'],
                      'result': {
                        'content': [
                          {'type': 'text', 'text': 'done'},
                        ],
                      },
                    }),
                  ),
                ),
                200,
                headers: {'content-type': 'application/json'},
              );
          }
          return http.StreamedResponse(const Stream.empty(), 400);
        });
        final mcp = McpClient(
          url: Uri.parse('http://ha/api/mcp'),
          token: 'tok',
          client: client,
        );
        final tools = await mcp.listTools();
        expect(tools.single.name, 'HassTurnOn');
        final result = await mcp.callTool('HassTurnOn', {'name': 'Kitchen'});
        expect(result.text, 'done');
        expect(result.error, isFalse);
        expect(
          [for (final r in requests) r['method']],
          [
            'initialize',
            'notifications/initialized',
            'tools/list',
            'tools/call',
          ],
        );
        // The session the server gave rides every request after it.
        expect(sessions.skip(1), everyElement('sess1'));
      },
    );

    test('an HTTP error says so', () async {
      final mcp = McpClient(
        url: Uri.parse('http://ha/api/mcp'),
        client: MockClient((_) async => http.Response('nope', 401)),
      );
      await expectLater(
        mcp.listTools(),
        throwsA(isA<McpException>().having((e) => e.status, 'status', 401)),
      );
    });
  });

  group('McpToolbox', () {
    test('model names are safe and map back', () {
      expect(McpToolbox.safeName('light__HassLightSet'), 'light__HassLightSet');
      expect(McpToolbox.safeName('weird name.v2'), 'weird_name_v2');
      expect(McpToolbox.safeName('x' * 80).length, 64);
    });
  });

  group('OpenAiRealtimeBackend', () {
    late _Socket socket;
    late _Tools tools;
    late List<RealtimeEvent> events;
    Uri? url;
    Map<String, String>? headers;

    OpenAiRealtimeBackend make(RealtimeConfig config) {
      socket = _Socket();
      tools = _Tools();
      events = [];
      final backend = OpenAiRealtimeBackend(
        config: config,
        toolbox: tools,
        connector: (u, h) async {
          url = u;
          headers = h;
          return socket;
        },
      );
      backend.events.listen(events.add);
      return backend;
    }

    test('OpenAI: the model in the query and the GA session shape', () async {
      final backend = make(
        const RealtimeConfig(provider: RealtimeProvider.openai, apiKey: 'sk'),
      );
      await backend.start(const RealtimeStart(language: 'es'));
      expect(
        url.toString(),
        'wss://api.openai.com/v1/realtime?model=gpt-realtime',
      );
      expect(headers?['Authorization'], 'Bearer sk');
      final session = socket.sent.first['session'] as Map;
      expect(session['type'], 'realtime');
      final audio = session['audio'] as Map;
      expect((audio['output'] as Map)['voice'], 'marin');
      final input = audio['input'] as Map;
      expect((input['format'] as Map)['rate'], 24000);
      expect((input['turn_detection'] as Map)['interrupt_response'], true);
      expect((input['transcription'] as Map)['language'], 'es');
      expect((session['tools'] as List).length, 2);
      await backend.close();
    });

    test(
      'xAI: voice and turn detection at the top, a relay endpoint',
      () async {
        final backend = make(
          const RealtimeConfig(
            provider: RealtimeProvider.xai,
            endpoint: 'http://relay.local:8099/realtime',
            voice: 'ara',
          ),
        );
        await backend.start(const RealtimeStart());
        expect(
          url.toString(),
          'ws://relay.local:8099/realtime?model=grok-voice-latest',
        );
        // No key: the relay adds it.
        expect(headers, isEmpty);
        final session = socket.sent.first['session'] as Map;
        expect(session['voice'], 'ara');
        expect((session['turn_detection'] as Map)['type'], 'server_vad');
        expect(session.containsKey('type'), isFalse);
        await backend.close();
      },
    );

    test('audio, transcripts and the answer come through as events', () async {
      final backend = make(
        const RealtimeConfig(provider: RealtimeProvider.openai),
      );
      await backend.start(const RealtimeStart());
      socket
        ..server({'type': 'session.updated'})
        ..server({'type': 'input_audio_buffer.speech_started'})
        ..server({
          'type': 'conversation.item.input_audio_transcription.completed',
          'item_id': 'u1',
          'transcript': 'Turn on the kitchen',
        })
        ..server({'type': 'response.created'})
        ..server({
          'type': 'response.output_audio.delta',
          'item_id': 'a1',
          'delta': base64Encode([1, 0, 2, 0]),
        })
        ..server({
          'type': 'response.audio.delta',
          'item_id': 'a1',
          'delta': base64Encode([3, 0]),
        })
        ..server({
          'type': 'response.output_audio_transcript.delta',
          'delta': 'Done',
        })
        ..server({
          'type': 'response.done',
          'response': {'status': 'completed'},
        });
      await pumpEventQueue();
      expect(events.whereType<RealtimeReady>(), hasLength(1));
      expect(events.whereType<RealtimeSpeechStarted>(), hasLength(1));
      expect(
        events.whereType<RealtimeUserText>().single.text,
        'Turn on the kitchen',
      );
      final audio = events.whereType<RealtimeAudio>().toList();
      expect(audio.map((a) => a.itemId), ['a1', 'a1']);
      expect(audio.first.pcm, [1, 0, 2, 0]);
      expect(events.whereType<RealtimeAnswerText>().last.text, 'Done');
      expect(events.whereType<RealtimeResponseDone>(), hasLength(1));
      backend.sendAudio(Uint8List.fromList([9, 9]));
      expect(socket.sent.last['type'], 'input_audio_buffer.append');
      await backend.close();
    });

    test(
      'a tool runs, its output goes back and the model answers it',
      () async {
        final backend = make(
          const RealtimeConfig(provider: RealtimeProvider.openai),
        );
        await backend.start(const RealtimeStart());
        tools.gate = Completer<void>();
        socket
          ..server({'type': 'session.updated'})
          ..server({'type': 'response.created'})
          ..server({
            'type': 'response.function_call_arguments.done',
            'call_id': 'c1',
            'name': 'intent__HassTurnOn',
            'arguments': '{"name":"Kitchen"}',
          })
          ..server({'type': 'response.done'});
        await pumpEventQueue();
        // The answer is done but its tool is not: nothing asked yet.
        expect(socket.types, isNot(contains('response.create')));
        tools.gate!.complete();
        await pumpEventQueue();
        expect(tools.calls.single.$2, {'name': 'Kitchen'});
        final output = socket.sent.firstWhere(
          (m) => m['type'] == 'conversation.item.create',
        );
        expect((output['item'] as Map)['call_id'], 'c1');
        expect(socket.types.last, 'response.create');
        final activity = events.whereType<RealtimeToolActivity>().toList();
        expect(activity.map((a) => a.done), [false, true]);
        await backend.close();
      },
    );

    test(
      'end_conversation asks the session to end, with no new answer',
      () async {
        final backend = make(
          const RealtimeConfig(provider: RealtimeProvider.openai),
        );
        await backend.start(const RealtimeStart());
        socket
          ..server({'type': 'session.updated'})
          ..server({'type': 'response.created'})
          ..server({
            'type': 'response.function_call_arguments.done',
            'call_id': 'c2',
            'name': LocalToolbox.endConversation,
            'arguments': '{}',
          })
          ..server({'type': 'response.done'});
        await pumpEventQueue();
        expect(events.whereType<RealtimeEndRequested>(), hasLength(1));
        expect(socket.types, isNot(contains('response.create')));
        await backend.close();
      },
    );

    test('an interruption cancels the answer and truncates it', () async {
      final backend = make(
        const RealtimeConfig(provider: RealtimeProvider.openai),
      );
      await backend.start(const RealtimeStart());
      socket
        ..server({'type': 'session.updated'})
        ..server({'type': 'response.created'});
      await pumpEventQueue();
      backend.interrupted('a1', 1250);
      expect(socket.types.sublist(socket.types.length - 2), [
        'response.cancel',
        'conversation.item.truncate',
      ]);
      expect(socket.sent.last['audio_end_ms'], 1250);
      await backend.close();
    });

    test('talking over it leaves the cancel to the server', () async {
      final backend = make(
        const RealtimeConfig(provider: RealtimeProvider.openai),
      );
      await backend.start(const RealtimeStart());
      socket
        ..server({'type': 'session.updated'})
        ..server({'type': 'response.created'})
        ..server({'type': 'input_audio_buffer.speech_started'});
      await pumpEventQueue();
      backend.interrupted('a1', 800);
      expect(socket.types, isNot(contains('response.cancel')));
      expect(socket.types.last, 'conversation.item.truncate');
      await backend.close();
    });

    test('an error before the session is up closes it', () async {
      final backend = make(
        const RealtimeConfig(provider: RealtimeProvider.openai),
      );
      await backend.start(const RealtimeStart());
      socket.server({
        'type': 'error',
        'error': {'code': 'invalid_api_key', 'message': 'Incorrect API key'},
      });
      await pumpEventQueue();
      expect(
        events.whereType<RealtimeClosed>().single.error,
        'Incorrect API key',
      );
    });
  });

  group('RealtimeSession', () {
    test('streams the microphone once connected, the chime left out', () {
      fakeAsync((time) {
        final h = _Harness(time);
        unawaited(h.session.wake('Hey Jarvis'));
        time.flushMicrotasks();
        expect(h.chimes.chimes, ['wake']);
        expect(h.view.docked, isTrue);
        // Over the chime: dropped.
        h.mic.speak();
        time.elapse(const Duration(milliseconds: 600));
        // After it, before the connection: held.
        h.mic.speak();
        expect(h.backend.audio, isEmpty);
        h.backend.emit(const RealtimeReady());
        time.flushMicrotasks();
        expect(h.player.rate, 24000);
        // The held chunk, resampled to 24 kHz: 1280 samples become 1920.
        expect(h.backend.audio, hasLength(1));
        expect(h.backend.audio.single.length ~/ 2, closeTo(1920, 1));
        h.mic.speak();
        expect(h.backend.audio, hasLength(2));
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    test('plays the answer and talking over it cuts it where it was heard', () {
      fakeAsync((time) {
        final h = _Harness(time);
        h.wakeAndConnect();
        h.answer('a1', seconds: 2);
        expect(h.player.written, hasLength(1));
        expect(h.view.phase, AssistPhase.speaking);
        expect(h.stopArmed.last, isTrue);
        time.elapse(const Duration(milliseconds: 500));
        h.player.frames = 12000;
        h.backend.emit(const RealtimeSpeechStarted());
        time.flushMicrotasks();
        expect(h.player.flushes, 1);
        expect(h.backend.interruptions.single, ('a1', 500));
        expect(h.view.phase, AssistPhase.listening);
        expect(h.view.answer, isEmpty);
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    test('only the start of an answer waits for a buffer', () {
      fakeAsync((time) {
        final h = _Harness(time);
        h.wakeAndConnect();
        final tenth = _pcm(List.filled(2400, 3000));
        h.backend.emit(const RealtimeResponseStarted());
        h.backend.emit(RealtimeAudio('a1', tenth));
        time.flushMicrotasks();
        // 100 ms of a new answer: held.
        expect(h.player.written, isEmpty);
        h.backend.emit(RealtimeAudio('a1', tenth));
        h.backend.emit(RealtimeAudio('a1', tenth));
        time.flushMicrotasks();
        // 300 ms: out it goes.
        expect(h.player.written, hasLength(3));
        // The stream pauses longer than what was queued, then goes on:
        // the rest of the same answer is not held back again.
        time.elapse(const Duration(milliseconds: 500));
        h.backend.emit(RealtimeAudio('a1', tenth));
        time.flushMicrotasks();
        expect(h.player.written, hasLength(4));
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    test('the microphone goes as silence while an answer settles', () {
      fakeAsync((time) {
        final h = _Harness(time);
        h.wakeAndConnect();
        h.answer('a1', seconds: 5);
        h.backend.audio.clear();
        h.mic.speak(value: 2000);
        expect(h.backend.audio.single.every((b) => b == 0), isTrue);
        time.elapse(const Duration(milliseconds: 2100));
        h.backend.audio.clear();
        h.mic.speak(value: 2000);
        expect(h.backend.audio.single.any((b) => b != 0), isTrue);
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    test('without talk over the microphone is shut while it speaks', () {
      fakeAsync((time) {
        final h = _Harness(
          time,
          options: const RealtimeOptions(talkOver: false),
        );
        h.wakeAndConnect();
        h.answer('a1');
        final before = h.backend.audio.length;
        h.mic.speak();
        expect(h.backend.audio.length, before);
        // Played out, and past the echo tail: open again.
        h.player.frames = 24000;
        time.elapse(const Duration(seconds: 2));
        h.mic.speak();
        expect(h.backend.audio.length, before + 1);
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    test('ends after the silence, counting the last seconds down', () {
      fakeAsync((time) {
        final h = _Harness(
          time,
          options: const RealtimeOptions(idleSeconds: 8),
        );
        h.wakeAndConnect();
        time.elapse(const Duration(seconds: 5));
        expect(h.countdown.last, lessThan(1));
        expect(h.session.busy, isTrue);
        time.elapse(const Duration(seconds: 4));
        expect(h.session.busy, isFalse);
        expect(h.chimes.chimes.last, 'done');
        expect(h.mic.closes, 1);
        expect(h.backend.closed, isTrue);
        expect(h.player.open, isFalse);
        expect(h.view.visible, isFalse);
        expect(h.busy_, [true, false]);
        expect(h.idles, 1);
      });
    });

    test('someone talking holds the end off', () {
      fakeAsync((time) {
        final h = _Harness(
          time,
          options: const RealtimeOptions(idleSeconds: 5),
        );
        h.wakeAndConnect();
        h.backend.emit(const RealtimeSpeechStarted());
        time.elapse(const Duration(seconds: 20));
        expect(h.session.busy, isTrue);
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    test('the goodbye plays out before the conversation ends', () {
      fakeAsync((time) {
        final h = _Harness(time);
        h.wakeAndConnect();
        h.answer('a1');
        h.backend.emit(const RealtimeEndRequested());
        h.backend.emit(const RealtimeResponseDone());
        time.elapse(const Duration(milliseconds: 300));
        expect(h.session.busy, isTrue);
        h.player.frames = 24000;
        time.elapse(const Duration(seconds: 1));
        expect(h.session.busy, isFalse);
      });
    });

    test('a connection that fails ends it with the error chime', () {
      fakeAsync((time) {
        final h = _Harness(time);
        unawaited(h.session.wake(''));
        time.flushMicrotasks();
        h.backend.emit(const RealtimeClosed(error: 'could not connect'));
        time.flushMicrotasks();
        expect(h.errors, ['realtime']);
        expect(h.chimes.chimes.last, 'error');
        expect(h.session.busy, isFalse);
      });
    });

    test(
      'tools and the answer fill the bubble, a new question replaces them',
      () {
        fakeAsync((time) {
          final h = _Harness(time);
          h.wakeAndConnect();
          h.backend
            ..emit(const RealtimeSpeechStarted())
            ..emit(const RealtimeUserText('Dim the kitchen'))
            ..emit(const RealtimeSpeechStopped())
            ..emit(const RealtimeToolActivity('light__HassLightSet'))
            ..emit(const RealtimeAnswerText('Done.', complete: true));
          time.flushMicrotasks();
          expect(h.view.command, 'Dim the kitchen');
          expect(h.view.tools, ['Light set']);
          expect(h.view.answer, 'Done.');
          // Talking again keeps the last exchange up until the new words
          // arrive.
          h.backend.emit(const RealtimeSpeechStarted());
          time.flushMicrotasks();
          expect(h.view.command, 'Dim the kitchen');
          expect(h.view.answer, 'Done.');
          h.backend.emit(const RealtimeUserText('And the hallway'));
          time.flushMicrotasks();
          expect(h.view.command, 'And the hallway');
          expect(h.view.tools, isEmpty);
          expect(h.view.answer, isEmpty);
          h.session.cancel();
          time.flushMicrotasks();
        });
      },
    );
  });
}
