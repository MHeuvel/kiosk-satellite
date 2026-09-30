import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';

import 'realtime_backend.dart';
import 'realtime_tools.dart';

/// The providers a direct backend talks to. Both speak OpenAI's realtime
/// protocol; they differ in where the session puts the voice and the turn
/// detection.
enum RealtimeProvider {
  openai(
    id: 'openai',
    endpoint: 'wss://api.openai.com/v1/realtime',
    model: 'gpt-realtime',
    voice: 'marin',
  ),
  xai(
    id: 'xai',
    endpoint: 'wss://api.x.ai/v1/realtime',
    model: 'grok-voice-latest',
    voice: 'eve',
  );

  const RealtimeProvider({
    required this.id,
    required this.endpoint,
    required this.model,
    required this.voice,
  });

  final String id;
  final String endpoint;
  final String model;
  final String voice;

  static RealtimeProvider byId(String id) =>
      values.firstWhere((p) => p.id == id, orElse: () => openai);
}

class RealtimeConfig {
  const RealtimeConfig({
    required this.provider,
    this.endpoint = '',
    this.apiKey = '',
    this.model = '',
    this.voice = '',
    this.instructions = '',
  });

  final RealtimeProvider provider;

  /// Empty for the provider's own address. A relay on the local network
  /// goes here, and then [apiKey] may stay empty.
  final String endpoint;
  final String apiKey;
  final String model;
  final String voice;
  final String instructions;

  String get effectiveModel =>
      model.trim().isEmpty ? provider.model : model.trim();
  String get effectiveVoice =>
      voice.trim().isEmpty ? provider.voice : voice.trim();

  /// The WebSocket address, with the model in the query unless the
  /// address already names one.
  Uri get url {
    final base = endpoint.trim().isEmpty ? provider.endpoint : endpoint.trim();
    final uri = Uri.parse(
      base
          .replaceFirst(RegExp('^https://'), 'wss://')
          .replaceFirst(RegExp('^http://'), 'ws://'),
    );
    if (uri.queryParameters.containsKey('model')) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'model': effectiveModel},
    );
  }
}

/// A text socket, so tests can stand in for the network.
abstract class RealtimeSocket {
  Stream<Object?> get messages;
  void send(String message);
  Future<void> close();

  /// The close code and reason the peer gave, once closed.
  String? get closeReason;
}

typedef RealtimeConnector =
    Future<RealtimeSocket> Function(Uri url, Map<String, String> headers);

class _ChannelSocket implements RealtimeSocket {
  _ChannelSocket(this._channel);
  final IOWebSocketChannel _channel;

  @override
  Stream<Object?> get messages => _channel.stream;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  Future<void> close() => _channel.sink.close();

  @override
  String? get closeReason {
    final code = _channel.closeCode;
    final reason = _channel.closeReason;
    if (code == null) return null;
    return reason == null || reason.isEmpty ? '$code' : '$code $reason';
  }
}

Future<RealtimeSocket> _connect(Uri url, Map<String, String> headers) async {
  final channel = IOWebSocketChannel.connect(
    url,
    headers: headers,
    pingInterval: const Duration(seconds: 20),
    connectTimeout: const Duration(seconds: 10),
  );
  await channel.ready;
  return _ChannelSocket(channel);
}

/// A direct backend over OpenAI's realtime protocol. Runs the tools itself:
/// Home Assistant's through its MCP server, and the app's own.
class OpenAiRealtimeBackend implements RealtimeBackend {
  OpenAiRealtimeBackend({
    required this.config,
    required this.toolbox,
    RealtimeConnector? connector,
    this.log,
    this.readyTimeout = const Duration(seconds: 10),
  }) : _connector = connector ?? _connect;

  final RealtimeConfig config;
  final RealtimeToolbox toolbox;
  final RealtimeConnector _connector;
  final void Function(String line)? log;
  final Duration readyTimeout;

  static const rate = 24000;

  static const defaultInstructions =
      'You are a voice assistant on a wall tablet in the user\'s home. Keep '
      'answers short and conversational, since they are spoken aloud. Use '
      'the tools to check and control the home. Answer in the language the '
      'user speaks to you. When the user is done, call end_conversation.';

  final _events = StreamController<RealtimeEvent>();
  RealtimeSocket? _socket;
  StreamSubscription<Object?>? _sub;
  bool _closing = false;
  bool _ready = false;
  Timer? _readyTimer;

  /// An answer is being generated.
  bool _responding = false;

  /// The server heard the user start talking over the answer: with server
  /// VAD it cancels the answer itself, so the kiosk does not.
  bool _serverInterrupted = false;

  /// Tool calls of the current answer still running, and whether the
  /// answer ended with outputs the model has not answered yet.
  int _calls = 0;
  bool _outputsPending = false;
  bool _responseDone = true;

  final _userText = <String, String>{};
  final _answer = StringBuffer();

  @override
  RealtimeCapabilities get capabilities =>
      const RealtimeCapabilities(inputRate: rate, outputRate: rate);

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  void _emit(RealtimeEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Future<void> start(RealtimeStart start) async {
    final url = config.url;
    log?.call('connecting to ${url.replace(query: '')}');
    List<RealtimeToolSpec> tools;
    try {
      tools = await toolbox.list();
    } catch (e) {
      tools = const [];
      _emit(RealtimeWarning('tools: $e'));
    }
    if (toolbox case final CombinedToolbox box when box.problems.isNotEmpty) {
      for (final problem in box.problems) {
        _emit(RealtimeWarning(problem));
      }
    }
    if (_closing) return;
    try {
      _socket = await _connector(url, {
        if (config.apiKey.trim().isNotEmpty)
          'Authorization': 'Bearer ${config.apiKey.trim()}',
      });
    } catch (e) {
      // The provider turning the connection down answers the upgrade with
      // an HTTP status: say what that usually means.
      final status = RegExp(r'status code: (\d+)').firstMatch('$e')?.group(1);
      _finish(
        error: switch (status) {
          '400' || '401' || '403' =>
            'The provider refused the connection (HTTP $status). Check the '
                'API key.',
          '404' => 'The endpoint has no realtime service (HTTP 404).',
          '429' =>
            'The provider is limiting requests (HTTP 429). Check the '
                'account\'s quota.',
          _ => _describe(e),
        },
      );
      return;
    }
    if (_closing) {
      await _socket?.close();
      return;
    }
    _sub = _socket!.messages.listen(
      _onMessage,
      onError: (Object e) => _finish(error: _describe(e)),
      onDone: () {
        final reason = _socket?.closeReason;
        _finish(
          error: _closing
              ? null
              : 'connection closed${reason == null ? '' : ' ($reason)'}',
        );
      },
    );
    _send(_sessionUpdate(start, tools));
    _readyTimer = Timer(readyTimeout, () {
      if (!_ready) _finish(error: 'no answer from the provider');
    });
  }

  Map<String, Object?> _sessionUpdate(
    RealtimeStart start,
    List<RealtimeToolSpec> tools,
  ) {
    final instructions = config.instructions.trim().isEmpty
        ? defaultInstructions
        : config.instructions.trim();
    const format = {'type': 'audio/pcm', 'rate': rate};
    final language = start.language.split(RegExp('[-_]')).first.toLowerCase();
    final toolList = [for (final tool in tools) tool.toJson()];
    final turnDetection = {
      'type': 'server_vad',
      'silence_duration_ms': 500,
      'prefix_padding_ms': 300,
    };
    final session = switch (config.provider) {
      RealtimeProvider.openai => {
        'type': 'realtime',
        'model': config.effectiveModel,
        'instructions': instructions,
        'output_modalities': ['audio'],
        'audio': {
          'input': {
            'format': format,
            'transcription': {
              'model': 'gpt-4o-mini-transcribe',
              if (language.length == 2) 'language': language,
            },
            'turn_detection': {
              ...turnDetection,
              'create_response': true,
              'interrupt_response': true,
            },
          },
          'output': {'format': format, 'voice': config.effectiveVoice},
        },
        if (toolList.isNotEmpty) 'tools': toolList,
        if (toolList.isNotEmpty) 'tool_choice': 'auto',
      },
      RealtimeProvider.xai => {
        'voice': config.effectiveVoice,
        'instructions': instructions,
        'turn_detection': turnDetection,
        'audio': {
          'input': {
            'format': format,
            if (language.length == 2)
              'transcription': {'language_hint': language},
          },
          'output': {'format': format},
        },
        if (toolList.isNotEmpty) 'tools': toolList,
      },
    };
    return {'type': 'session.update', 'session': session};
  }

  void _send(Map<String, Object?> message) {
    final socket = _socket;
    if (socket == null || _closing) return;
    try {
      socket.send(jsonEncode(message));
    } catch (_) {}
  }

  @override
  void sendAudio(Uint8List pcm) {
    if (!_ready || pcm.isEmpty) return;
    _send({'type': 'input_audio_buffer.append', 'audio': base64Encode(pcm)});
  }

  @override
  void interrupted(String itemId, int playedMs) {
    if (_responding && !_serverInterrupted) _send({'type': 'response.cancel'});
    if (itemId.isEmpty) return;
    _send({
      'type': 'conversation.item.truncate',
      'item_id': itemId,
      'content_index': 0,
      'audio_end_ms': playedMs < 0 ? 0 : playedMs,
    });
  }

  void _onMessage(Object? raw) {
    final Map<String, Object?> msg;
    try {
      msg =
          (jsonDecode(raw is String ? raw : utf8.decode(raw as List<int>))
                  as Map)
              .cast<String, Object?>();
    } catch (_) {
      return;
    }
    final type = '${msg['type'] ?? ''}';
    switch (type) {
      case 'session.updated':
        _markReady();
      case 'session.created':
        // Some servers only confirm the update through a later event: the
        // session is usable once it exists, if nothing else comes.
        Timer(const Duration(seconds: 2), _markReady);
      case 'error':
        _onError(msg['error']);
      case 'input_audio_buffer.speech_started':
        _serverInterrupted = _responding;
        _emit(const RealtimeSpeechStarted());
      case 'input_audio_buffer.speech_stopped':
        _emit(const RealtimeSpeechStopped());
      case 'conversation.item.input_audio_transcription.delta':
        final id = '${msg['item_id'] ?? ''}';
        final text = '${_userText[id] ?? ''}${msg['delta'] ?? ''}';
        _userText[id] = text;
        _emit(RealtimeUserText(text, complete: false));
      case 'conversation.item.input_audio_transcription.updated':
        final text = '${msg['transcript'] ?? msg['text'] ?? ''}';
        if (text.isNotEmpty) _emit(RealtimeUserText(text, complete: false));
      case 'conversation.item.input_audio_transcription.completed':
        final id = '${msg['item_id'] ?? ''}';
        _userText.remove(id);
        final text = '${msg['transcript'] ?? ''}'.trim();
        if (text.isNotEmpty) _emit(RealtimeUserText(text));
      case 'response.created':
        _responding = true;
        _serverInterrupted = false;
        _responseDone = false;
        _answer.clear();
        _emit(const RealtimeResponseStarted());
      case 'response.output_audio.delta' || 'response.audio.delta':
        final delta = msg['delta'];
        if (delta is String && delta.isNotEmpty) {
          try {
            _emit(
              RealtimeAudio('${msg['item_id'] ?? ''}', base64Decode(delta)),
            );
          } catch (_) {}
        }
      case 'response.output_audio_transcript.delta' ||
          'response.audio_transcript.delta' ||
          'response.output_text.delta' ||
          'response.text.delta':
        final delta = '${msg['delta'] ?? ''}';
        if (delta.isNotEmpty) {
          _answer.write(delta);
          _emit(RealtimeAnswerText(_answer.toString()));
        }
      case 'response.output_audio_transcript.done' ||
          'response.audio_transcript.done':
        final text = '${msg['transcript'] ?? ''}';
        if (text.isNotEmpty) {
          _answer
            ..clear()
            ..write(text);
        }
        _emit(RealtimeAnswerText(_answer.toString(), complete: true));
      case 'response.function_call_arguments.done':
        unawaited(
          _runTool(
            '${msg['call_id'] ?? ''}',
            '${msg['name'] ?? ''}',
            '${msg['arguments'] ?? ''}',
          ),
        );
      case 'response.done':
        _responding = false;
        _responseDone = true;
        final response = msg['response'];
        if (response is Map && response['status'] == 'failed') {
          final details = response['status_details'];
          final error = details is Map ? details['error'] : null;
          _emit(
            RealtimeWarning(
              error is Map
                  ? '${error['message'] ?? 'the answer failed'}'
                  : 'the answer failed',
            ),
          );
        }
        _emit(const RealtimeResponseDone());
        _answerTools();
    }
  }

  void _markReady() {
    if (_ready || _closing) return;
    _ready = true;
    _readyTimer?.cancel();
    log?.call('session ready');
    _emit(const RealtimeReady());
  }

  /// Errors the protocol produces in normal use: a cancel with nothing to
  /// cancel, a truncate past what was sent.
  static bool _benign(String code, String message) =>
      code == 'response_cancel_not_active' ||
      message.contains('no active response') ||
      message.toLowerCase().contains('truncat');

  void _onError(Object? error) {
    final map = error is Map ? error : const {};
    final code = '${map['code'] ?? ''}';
    final message = '${map['message'] ?? 'error'}';
    log?.call('error $code: $message');
    if (_ready && _benign(code, message)) return;
    if (!_ready) {
      _finish(error: message);
      return;
    }
    _emit(RealtimeWarning(message));
  }

  Future<void> _runTool(String callId, String name, String arguments) async {
    if (callId.isEmpty || name.isEmpty) return;
    _calls++;
    final display = toolbox.originalName(name);
    _emit(RealtimeToolActivity(display));
    Map<String, Object?> args;
    try {
      final decoded = arguments.isEmpty ? const {} : jsonDecode(arguments);
      args = decoded is Map ? decoded.cast<String, Object?>() : const {};
    } catch (_) {
      args = const {};
    }
    final output = await toolbox.call(name, args);
    _calls--;
    if (_closing) return;
    _emit(RealtimeToolActivity(display, done: true, error: output.error));
    _send({
      'type': 'conversation.item.create',
      'item': {
        'type': 'function_call_output',
        'call_id': callId,
        'output': output.text,
      },
    });
    if (output.endConversation) {
      _emit(const RealtimeEndRequested());
      return;
    }
    _outputsPending = true;
    _answerTools();
  }

  /// Once an answer's tool calls are all back and the answer itself is
  /// done, ask the model to answer the outputs.
  void _answerTools() {
    if (!_outputsPending || _calls > 0 || !_responseDone) return;
    _outputsPending = false;
    _send({'type': 'response.create'});
  }

  void _finish({String? error}) {
    _readyTimer?.cancel();
    if (_events.isClosed) return;
    if (error != null) log?.call('closed: $error');
    _emit(RealtimeClosed(error: error));
    unawaited(_events.close());
  }

  static String _describe(Object e) {
    // The socket's wrapper adds nothing a person needs to read.
    final text = '$e'.replaceFirst('WebSocketChannelException: ', '');
    return text.length > 200 ? '${text.substring(0, 200)}...' : text;
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    _readyTimer?.cancel();
    await _sub?.cancel();
    await _socket?.close();
    toolbox.close();
    if (!_events.isClosed) await _events.close();
  }
}
