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
import 'package:kiosk_satellite/managers/voice/realtime/realtime_history.dart';
import 'package:kiosk_satellite/managers/voice/realtime/realtime_player.dart';
import 'package:kiosk_satellite/managers/voice/realtime/realtime_session.dart';
import 'package:kiosk_satellite/managers/voice/realtime/realtime_tools.dart';
import 'package:kiosk_satellite/managers/voice/voice_manager.dart'
    show realtimeLocationLine;
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
  final turns = <bool>[];
  RealtimeStart? started;
  bool closed = false;
  bool clientTurns = false;

  @override
  RealtimeCapabilities get capabilities =>
      RealtimeCapabilities(clientTurns: clientTurns);

  @override
  void userTurn({required bool keep}) => turns.add(keep);

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
  _Harness(this.time, {this.options = const RealtimeOptions(), this.location}) {
    session = RealtimeSession(
      location: location,
      // A new backend once a conversation closed its own, as the app
      // makes one per conversation.
      backend: () => backend.closed
          ? backend = (_Backend()..clientTurns = backend.clientTurns)
          : backend,
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
      onTrace: (step, {text}) => traces.add(step),
      now: () => DateTime(2026).add(time.elapsed),
    );
  }

  final FakeAsync time;
  RealtimeOptions options;
  final Future<String> Function()? location;
  late final RealtimeSession session;
  var backend = _Backend();
  final mic = _Mic();
  final player = _Player();
  final chimes = _Chimes();
  final views = <AssistView>[];
  final countdown = <double>[];
  final busy_ = <bool>[];
  final stopArmed = <bool>[];
  final errors = <String>[];
  final traces = <String>[];
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
      // The session takes the turns: speech neither stops nor gets a reply
      // on its own.
      expect((input['turn_detection'] as Map)['interrupt_response'], false);
      expect((input['turn_detection'] as Map)['create_response'], false);
      expect((input['transcription'] as Map)['language'], 'es');
      expect((session['tools'] as List).length, 2);
      await backend.close();
    });

    test('where the kiosk is joins the instructions, with xAI the earlier '
        'exchanges too', () async {
      const history = [
        RealtimeTurn(user: true, text: 'Dim the kitchen'),
        RealtimeTurn(user: false, text: 'Done.'),
      ];
      for (final provider in RealtimeProvider.values) {
        final backend = make(
          RealtimeConfig(provider: provider, instructions: 'Be brief.'),
        );
        await backend.start(
          const RealtimeStart(
            context: 'This kiosk is in the Kitchen area.',
            history: history,
          ),
        );
        final instructions =
            (socket.sent.first['session'] as Map)['instructions'] as String;
        if (provider == RealtimeProvider.xai) {
          expect(
            instructions,
            'Be brief.\n\n${realtimeContextText(context: 'This kiosk is in the Kitchen area.', history: history)}',
          );
          expect(
            instructions,
            endsWith('User: Dim the kitchen\nAssistant: Done.'),
          );
          expect(socket.sent, hasLength(1));
        } else {
          expect(
            instructions,
            'Be brief.\n\nThis kiosk is in the Kitchen area.',
          );
        }
        await backend.close();
      }
      // Neither: the instructions alone.
      final backend = make(
        const RealtimeConfig(provider: RealtimeProvider.openai),
      );
      await backend.start(const RealtimeStart());
      expect(
        (socket.sent.first['session'] as Map)['instructions'],
        OpenAiRealtimeBackend.defaultInstructions,
      );
      expect(socket.sent, hasLength(1));
      await backend.close();
    });

    test(
      'OpenAI: earlier exchanges replay as the conversation\'s items',
      () async {
        final backend = make(
          const RealtimeConfig(provider: RealtimeProvider.openai),
        );
        await backend.start(
          const RealtimeStart(
            history: [
              RealtimeTurn(user: true, text: 'Turn on the AC.'),
              RealtimeTurn(user: false, text: 'The office AC is now on.'),
            ],
          ),
        );
        expect(socket.sent.first['type'], 'session.update');
        expect(socket.sent.skip(1).toList(), [
          {
            'type': 'conversation.item.create',
            'item': {
              'type': 'message',
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': 'Turn on the AC.'},
              ],
            },
          },
          {
            'type': 'conversation.item.create',
            'item': {
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'output_text', 'text': 'The office AC is now on.'},
              ],
            },
          },
        ]);
        await backend.close();
      },
    );

    test('Azure: the key goes in the api-key header', () async {
      final backend = make(
        const RealtimeConfig(
          provider: RealtimeProvider.openai,
          endpoint: 'https://res.openai.azure.com/openai/v1/realtime?model=dep',
          apiKey: 'az',
        ),
      );
      await backend.start(const RealtimeStart());
      expect(
        url.toString(),
        'wss://res.openai.azure.com/openai/v1/realtime?model=dep',
      );
      expect(headers, {'api-key': 'az'});
      await backend.close();
    });

    test('a failed connection never shows a key in the address', () async {
      final backend = OpenAiRealtimeBackend(
        config: const RealtimeConfig(
          provider: RealtimeProvider.openai,
          apiKey: 'sk',
        ),
        toolbox: _Tools(),
        connector: (u, h) async => throw ArgumentError(
          "Unsupported scheme 'wss' in URI "
          'wss://res.openai.azure.com/v1/realtime?model=m&api-key=secret',
        ),
      );
      final closed = backend.events.firstWhere((e) => e is RealtimeClosed);
      await backend.start(const RealtimeStart());
      final error = (await closed as RealtimeClosed).error!;
      expect(error, contains('api-key=***'));
      expect(error, isNot(contains('secret')));
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

    test('xAI: talking over it leaves the cancel to the server', () async {
      final backend = make(
        const RealtimeConfig(provider: RealtimeProvider.xai),
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

    test('OpenAI: the session stops the answer and takes the turns', () async {
      final backend = make(
        const RealtimeConfig(provider: RealtimeProvider.openai),
      );
      expect(backend.capabilities.clientTurns, isTrue);
      await backend.start(const RealtimeStart());
      socket
        ..server({'type': 'session.updated'})
        ..server({'type': 'response.created'})
        ..server({'type': 'input_audio_buffer.speech_started'})
        ..server({
          'type': 'input_audio_buffer.speech_stopped',
          'item_id': 'u1',
        });
      await pumpEventQueue();
      // Not the user: the item goes, and its transcript is not shown.
      backend.userTurn(keep: false);
      expect(socket.types.last, 'conversation.item.delete');
      socket.server({
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'u1',
        'transcript': 'Stop.',
      });
      await pumpEventQueue();
      expect(events.whereType<RealtimeUserText>(), isEmpty);
      // The user: the answer is cancelled and a reply asked for.
      backend.interrupted('a1', 800);
      expect(socket.types, contains('response.cancel'));
      backend.userTurn(keep: true);
      // Any answer still open on the server goes first.
      expect(socket.types.skip(socket.types.length - 2), [
        'response.cancel',
        'response.create',
      ]);
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

  group('RealtimeHistory', () {
    test('drops what is older than the duration, keeps the rest in order', () {
      var now = DateTime(2026);
      final history = RealtimeHistory(now: () => now);
      history.add(user: true, text: 'first');
      now = now.add(const Duration(minutes: 40));
      history
        ..add(user: true, text: 'second')
        ..add(user: false, text: '  ')
        ..add(user: false, text: 'answer');
      now = now.add(const Duration(minutes: 30));
      expect(history.recent(const Duration(hours: 1)).map((t) => t.text), [
        'second',
        'answer',
      ]);
      // Gone for good, even if the duration grows again.
      expect(history.recent(const Duration(hours: 12)).map((t) => t.text), [
        'second',
        'answer',
      ]);
    });

    test('hands over the newest exchanges within the limits', () {
      final history = RealtimeHistory();
      for (var i = 0; i < 100; i++) {
        history.add(user: i.isEven, text: 'turn $i');
      }
      final recent = history.recent(const Duration(hours: 1));
      expect(recent, hasLength(RealtimeHistory.maxTurns));
      expect(recent.last.text, 'turn 99');
      history
        ..clear()
        ..add(user: true, text: 'x' * 5000)
        ..add(user: true, text: 'y' * 5000);
      expect(history.recent(const Duration(hours: 1)).map((t) => t.text[0]), [
        'y',
      ]);
    });
  });

  test('the location line names the device, not the assistant', () {
    expect(
      realtimeLocationLine(name: 'KS Portal Go', area: 'Kitchen'),
      'You run on a device named "KS Portal Go" in Home Assistant. That is '
      'its name, not yours. The device is in the Kitchen area. '
      "When the user doesn't name an area, use this one.",
    );
    expect(
      realtimeLocationLine(name: 'KS Portal Go', area: ''),
      'You run on a device named "KS Portal Go" in Home Assistant. That is '
      'its name, not yours.',
    );
    expect(
      realtimeLocationLine(name: '', area: 'Kitchen'),
      "The device is in the Kitchen area. When the user doesn't name an "
      'area, use this one.',
    );
    expect(realtimeLocationLine(name: '', area: ''), '');
  });

  group('RealtimeSession', () {
    test(
      'what was said carries into the next conversation for the session duration',
      () {
        fakeAsync((time) {
          final h = _Harness(
            time,
            options: const RealtimeOptions(historyHours: 1),
          );
          h.wakeAndConnect();
          expect(h.backend.started?.history, isEmpty);
          h.backend
            ..emit(const RealtimeUserText('Dim the kitchen'))
            ..emit(const RealtimeAnswerText('Dim'))
            ..emit(const RealtimeAnswerText('Dimmed to half.', complete: true));
          time.flushMicrotasks();
          h.session.cancel();
          time.flushMicrotasks();
          time.elapse(const Duration(minutes: 30));
          h.wakeAndConnect();
          expect(h.backend.started?.history.map((t) => (t.user, t.text)), [
            (true, 'Dim the kitchen'),
            (false, 'Dimmed to half.'),
          ]);
          h.session.cancel();
          time.flushMicrotasks();
          time.elapse(const Duration(minutes: 31));
          h.wakeAndConnect();
          expect(h.backend.started?.history, isEmpty);
          h.session.cancel();
          time.flushMicrotasks();
        });
      },
    );

    test(
      'where the kiosk is reaches the provider, and a slow lookup does not hold it up',
      () {
        fakeAsync((time) {
          final h = _Harness(
            time,
            location: () async => 'This kiosk is in the Kitchen area.',
          );
          h.wakeAndConnect();
          expect(
            h.backend.started?.context,
            'This kiosk is in the Kitchen area.',
          );
          h.session.cancel();
          time.flushMicrotasks();
          final slow = _Harness(
            time,
            location: () => Completer<String>().future,
          );
          unawaited(slow.session.wake('Hey Jarvis'));
          time.elapse(
            RealtimeSession.locationWait + const Duration(milliseconds: 100),
          );
          expect(slow.backend.started?.context, '');
          slow.session.cancel();
          time.flushMicrotasks();
        });
      },
    );

    test('quiet speech survives a pause and a long continuous utterance', () {
      fakeAsync((time) {
        final h = _Harness(time);
        h.wakeAndConnect();
        for (var i = 0; i < 65; i++) {
          h.mic.speak(value: 50);
          time.elapse(const Duration(milliseconds: 80));
        }
        h.backend.audio.clear();
        // A quiet first syllable must not need an absolute gate threshold.
        h.mic.speak(value: 100);
        expect(
          RealtimeSession.meanAbs(h.backend.audio.single),
          closeTo(100, 2),
        );
        for (var i = 0; i < 80; i++) {
          h.mic.speak(value: 250);
          time.elapse(const Duration(milliseconds: 80));
        }
        // Continuous speech must not become the gate's new noise floor.
        expect(RealtimeSession.meanAbs(h.backend.audio.last), closeTo(250, 2));
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

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
        h.backend.clientTurns = true;
        h.wakeAndConnect();
        h.answer('a1', seconds: 5);
        h.backend.audio.clear();
        h.mic.speak(value: 2000);
        expect(h.backend.audio.single.every((b) => b == 0), isTrue);
        // A microphone that never quiets down under the voice waits the
        // whole settling out.
        time.elapse(const Duration(milliseconds: 2100));
        h.backend.audio.clear();
        h.mic.speak(value: 2000);
        expect(h.backend.audio.single.every((b) => b == 0), isTrue);
        time.elapse(const Duration(milliseconds: 2000));
        h.backend.audio.clear();
        h.mic.speak(value: 2000);
        expect(h.backend.audio.single.any((b) => b != 0), isTrue);
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    test('the settling ends once the canceller keeps the voice out', () {
      fakeAsync((time) {
        final h = _Harness(time);
        h.backend.clientTurns = true;
        h.wakeAndConnect();
        h.answer('a1', seconds: 5);
        // Quiet chunks while the voice speaks, past the least it waits:
        // the echo is out.
        time.elapse(RealtimeSession.settleAtLeast);
        for (var i = 0; i < RealtimeSession.settledAfter; i++) {
          time.elapse(const Duration(milliseconds: 80));
          h.mic.speak(value: 10);
        }
        h.backend.audio.clear();
        h.mic.speak(value: 2000);
        expect(
          RealtimeSession.meanAbs(h.backend.audio.single),
          closeTo(2000, 2),
        );
        expect(h.traces, contains(startsWith('echo settled after')));
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    test('the room\'s noise stands in while the canceller mutes it', () {
      fakeAsync((time) {
        // A noise floor (an air conditioner) that comes back all at once
        // when the canceller lets go reads as someone talking.
        final h = _Harness(time);
        h.backend.clientTurns = true;
        h.wakeAndConnect();
        for (var i = 0; i < 20; i++) {
          h.mic.speak(value: 50);
        }
        int level(Uint8List pcm) => RealtimeSession.meanAbs(pcm);
        h.answer('a1', seconds: 5);
        h.backend.audio.clear();
        h.mic.speak(value: 2000);
        expect(level(h.backend.audio.single), closeTo(50, 2));
        time.elapse(RealtimeSession.echoSettle);
        h.backend.audio.clear();
        h.mic.speak(value: 0);
        expect(level(h.backend.audio.single), closeTo(50, 2));
        h.backend.audio.clear();
        h.mic.speak(value: 2000);
        expect(level(h.backend.audio.single), closeTo(2000, 2));
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    test('a quiet room goes as it is', () {
      fakeAsync((time) {
        final h = _Harness(time);
        h.wakeAndConnect();
        for (var i = 0; i < 20; i++) {
          h.mic.speak(value: 2);
        }
        h.answer('a1', seconds: 5);
        time.elapse(const Duration(milliseconds: 2100));
        h.backend.audio.clear();
        h.mic.speak(value: 0);
        expect(RealtimeSession.meanAbs(h.backend.audio.single), 0);
        h.session.cancel();
        time.flushMicrotasks();
      });
    });

    group('with the turns in the session', () {
      test('quiet speech over an answer is dropped, the answer goes on', () {
        fakeAsync((time) {
          final h = _Harness(time);
          h.backend.clientTurns = true;
          h.wakeAndConnect();
          h.answer('a1', seconds: 8);
          time.elapse(RealtimeSession.echoSettle);
          h.backend.emit(const RealtimeSpeechStarted());
          time.flushMicrotasks();
          for (var i = 0; i < 5; i++) {
            time.elapse(const Duration(milliseconds: 80));
            h.mic.speak(value: 300);
          }
          h.backend.emit(const RealtimeSpeechStopped());
          time.flushMicrotasks();
          expect(h.player.flushes, 0);
          expect(h.backend.interruptions, isEmpty);
          expect(h.backend.turns, [false]);
          h.session.cancel();
          time.flushMicrotasks();
        });
      });

      test('loud speech over an answer stops it and gets a reply', () {
        fakeAsync((time) {
          final h = _Harness(time);
          h.backend.clientTurns = true;
          h.wakeAndConnect();
          h.answer('a1', seconds: 8);
          time.elapse(RealtimeSession.echoSettle);
          h.backend.emit(const RealtimeSpeechStarted());
          time.flushMicrotasks();
          for (var i = 0; i < RealtimeSession.bargeInChunks; i++) {
            time.elapse(const Duration(milliseconds: 80));
            h.mic.speak(value: 3000);
          }
          time.flushMicrotasks();
          expect(h.player.flushes, 1);
          expect(h.backend.interruptions.single.$1, 'a1');
          h.backend.emit(const RealtimeSpeechStopped());
          time.flushMicrotasks();
          expect(h.backend.turns, [true]);
          h.session.cancel();
          time.flushMicrotasks();
        });
      });

      test('the rest of a cut answer does not play', () {
        fakeAsync((time) {
          final h = _Harness(time);
          h.backend.clientTurns = true;
          h.wakeAndConnect();
          h.answer('a1', seconds: 8);
          time.elapse(RealtimeSession.echoSettle);
          h.backend.emit(const RealtimeSpeechStarted());
          time.flushMicrotasks();
          for (var i = 0; i < RealtimeSession.bargeInChunks; i++) {
            time.elapse(const Duration(milliseconds: 80));
            h.mic.speak(value: 3000);
          }
          time.flushMicrotasks();
          expect(h.player.flushes, 1);
          final written = h.player.written.length;
          // What the provider had already sent of it arrives late.
          h.backend.emit(RealtimeAudio('a1', _pcm(List.filled(24000, 3000))));
          time.flushMicrotasks();
          expect(h.player.written, hasLength(written));
          // The user goes on talking, and the provider hears it.
          h.backend.audio.clear();
          h.mic.speak(value: 3000);
          expect(
            RealtimeSession.meanAbs(h.backend.audio.single),
            closeTo(3000, 2),
          );
          h.session.cancel();
          time.flushMicrotasks();
        });
      });

      test('the loud speech it already heard counts', () {
        fakeAsync((time) {
          final h = _Harness(time);
          h.backend.clientTurns = true;
          h.wakeAndConnect();
          h.answer('a1', seconds: 8);
          time.elapse(RealtimeSession.echoSettle);
          // The user speaks; the provider says so half a second later.
          for (var i = 0; i < RealtimeSession.bargeInChunks; i++) {
            time.elapse(const Duration(milliseconds: 80));
            h.mic.speak(value: 3000);
          }
          h.backend.emit(const RealtimeSpeechStarted());
          time.flushMicrotasks();
          expect(h.player.flushes, 1);
          h.session.cancel();
          time.flushMicrotasks();
        });
      });

      test('speech with nothing playing gets a reply', () {
        fakeAsync((time) {
          final h = _Harness(time);
          h.backend.clientTurns = true;
          h.wakeAndConnect();
          h.backend.emit(const RealtimeSpeechStarted());
          time.flushMicrotasks();
          h.mic.speak(value: 2000);
          h.backend.emit(const RealtimeSpeechStopped());
          time.flushMicrotasks();
          expect(h.backend.turns, [true]);
          expect(h.player.flushes, 0);
          h.session.cancel();
          time.flushMicrotasks();
        });
      });
    });

    group('with the turns in the provider', () {
      test('the provider hears the room over an answer, not the echo', () {
        fakeAsync((time) {
          final h = _Harness(time);
          h.wakeAndConnect();
          for (var i = 0; i < 20; i++) {
            h.mic.speak(value: 50);
          }
          h.answer('a1', seconds: 8);
          time.elapse(RealtimeSession.echoSettle);
          h.backend.audio.clear();
          for (var i = 0; i < 5; i++) {
            time.elapse(const Duration(milliseconds: 80));
            h.mic.speak(value: 600);
          }
          expect(h.backend.audio, hasLength(5));
          expect(
            h.backend.audio.map(RealtimeSession.meanAbs),
            everyElement(closeTo(50, 2)),
          );
          expect(h.player.flushes, 0);
          expect(h.backend.interruptions, isEmpty);
          h.session.cancel();
          time.flushMicrotasks();
        });
      });

      test('loud speech over an answer stops it and reaches the provider', () {
        fakeAsync((time) {
          final h = _Harness(time);
          h.wakeAndConnect();
          h.answer('a1', seconds: 8);
          time.elapse(RealtimeSession.echoSettle);
          h.backend.audio.clear();
          for (var i = 0; i < RealtimeSession.bargeInChunks; i++) {
            time.elapse(const Duration(milliseconds: 80));
            h.mic.speak(value: 3000);
          }
          time.flushMicrotasks();
          expect(h.player.flushes, 1);
          expect(h.backend.interruptions.single.$1, 'a1');
          // The comfort noise that went out while it weighed the first
          // chunks, then all three as they were heard.
          final levels = h.backend.audio.map(RealtimeSession.meanAbs).toList();
          expect(
            levels.skip(levels.length - RealtimeSession.bargeInChunks),
            everyElement(closeTo(3000, 2)),
          );
          h.backend.audio.clear();
          h.mic.speak(value: 3000);
          expect(
            RealtimeSession.meanAbs(h.backend.audio.single),
            closeTo(3000, 2),
          );
          h.session.cancel();
          time.flushMicrotasks();
        });
      });

      test('the next answer holds the microphone back again', () {
        fakeAsync((time) {
          final h = _Harness(time);
          h.wakeAndConnect();
          h.answer('a1', seconds: 8);
          time.elapse(RealtimeSession.echoSettle);
          for (var i = 0; i < RealtimeSession.bargeInChunks; i++) {
            time.elapse(const Duration(milliseconds: 80));
            h.mic.speak(value: 3000);
          }
          time.flushMicrotasks();
          time.elapse(const Duration(seconds: 3));
          h.answer('a2', seconds: 8);
          time.elapse(RealtimeSession.echoSettle);
          h.backend.audio.clear();
          h.mic.speak(value: 600);
          expect(
            RealtimeSession.meanAbs(h.backend.audio.single),
            lessThan(600),
          );
          h.session.cancel();
          time.flushMicrotasks();
        });
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

    test('a slow tool holds the end off, and the countdown resumes after', () {
      fakeAsync((time) {
        final h = _Harness(
          time,
          options: const RealtimeOptions(idleSeconds: 5),
        );
        h.wakeAndConnect();
        h.backend
          ..emit(const RealtimeResponseStarted())
          ..emit(const RealtimeToolActivity('weather__GetForecast'))
          ..emit(const RealtimeResponseDone());
        time.elapse(const Duration(seconds: 20));
        expect(h.countdown.last, 1);
        expect(h.session.busy, isTrue);
        // The tool comes back and its answer is asked for: still waiting.
        h.backend.emit(
          const RealtimeToolActivity('weather__GetForecast', done: true),
        );
        time.elapse(const Duration(seconds: 3));
        expect(h.countdown.last, 1);
        h.answer('a1');
        h.backend.emit(const RealtimeResponseDone());
        h.player.frames = 24000;
        time.elapse(const Duration(seconds: 4));
        expect(h.countdown.last, lessThan(1));
        time.elapse(const Duration(seconds: 3));
        expect(h.session.busy, isFalse);
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

    test('asked to end after the answer, it ends once that plays', () {
      fakeAsync((time) {
        final h = _Harness(
          time,
          options: const RealtimeOptions(idleSeconds: 30),
        );
        h.wakeAndConnect();
        // The intercom script runs as a tool: the ask comes mid tool.
        h.backend
          ..emit(const RealtimeResponseStarted())
          ..emit(const RealtimeToolActivity('script__intercom'))
          ..emit(const RealtimeResponseDone());
        time.flushMicrotasks();
        h.session.endAfterAnswer();
        h.backend.emit(
          const RealtimeToolActivity('script__intercom', done: true),
        );
        time.elapse(const Duration(seconds: 2));
        expect(h.session.busy, isTrue);
        h.answer('a1');
        h.backend.emit(const RealtimeResponseDone());
        time.elapse(const Duration(milliseconds: 300));
        expect(h.session.busy, isTrue);
        h.player.frames = 24000;
        time.elapse(const Duration(seconds: 1));
        // Long before the 30 second silence.
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
