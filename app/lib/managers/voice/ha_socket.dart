import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// One authenticated Home Assistant websocket for the native voice
/// satellite: registry lookups, the chat log, related searches, pipeline
/// runs. Connected on first use and again after a drop; nothing reconnects
/// on its own, the next request does.
class HaSocket {
  HaSocket({required this.baseUrl, required this.token});

  /// Read on every connect, so a changed address or token is picked up.
  final String Function() baseUrl;
  final String Function() token;

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _sub;
  Future<void>? _connecting;
  int _nextId = 1;
  final _pending = <int, Completer<Object?>>{};
  final _events = <int, void Function(Map<String, Object?> event)>{};

  bool get connected => _channel != null && _connecting == null;

  /// Counts the connections made. A subscription lives only as long as its
  /// connection, so a holder compares this to tell it has to subscribe
  /// again.
  int connections = 0;

  Future<void> _ensure() {
    if (_channel != null && _connecting == null) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    final base = baseUrl().trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty || token().isEmpty) {
      throw StateError('Home Assistant not configured');
    }
    final ws = base
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final channel = WebSocketChannel.connect(Uri.parse('$ws/api/websocket'));
    final authed = Completer<void>();
    _channel = channel;
    _sub = channel.stream.listen(
      (raw) {
        final Map<String, Object?> msg;
        try {
          msg = (jsonDecode(raw as String) as Map).cast<String, Object?>();
        } catch (_) {
          return;
        }
        switch (msg['type']) {
          case 'auth_required':
            channel.sink.add(
              jsonEncode({'type': 'auth', 'access_token': token()}),
            );
          case 'auth_ok':
            if (!authed.isCompleted) authed.complete();
          case 'auth_invalid':
            if (!authed.isCompleted) {
              authed.completeError(StateError('Home Assistant auth invalid'));
            }
          case 'result':
            final id = msg['id'];
            final done = id is int ? _pending.remove(id) : null;
            if (done == null) return;
            if (msg['success'] == true) {
              done.complete(msg['result']);
            } else {
              _events.remove(id);
              final error = msg['error'];
              done.completeError(
                StateError(
                  error is Map ? '${error['message'] ?? error}' : '$error',
                ),
              );
            }
          case 'event':
            final id = msg['id'];
            final event = msg['event'];
            if (id is int && event is Map) {
              _events[id]?.call(event.cast<String, Object?>());
            }
        }
      },
      onError: (Object e) => _drop(e),
      onDone: () => _drop(StateError('Home Assistant socket closed')),
      cancelOnError: true,
    );
    await authed.future.timeout(const Duration(seconds: 10));
    connections++;
  }

  void _drop(Object error) {
    _sub?.cancel();
    _sub = null;
    final channel = _channel;
    _channel = null;
    unawaited(channel?.sink.close() ?? Future.value());
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _pending.clear();
    _events.clear();
  }

  /// One command and its result.
  Future<Object?> request(
    Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _ensure();
    final id = _nextId++;
    final done = Completer<Object?>();
    _pending[id] = done;
    _channel!.sink.add(jsonEncode({...command, 'id': id}));
    try {
      return await done.future.timeout(timeout);
    } finally {
      _pending.remove(id);
    }
  }

  /// A subscription: [onEvent] gets every event until the returned function
  /// unsubscribes (or the socket drops).
  Future<Future<void> Function()> subscribe(
    Map<String, Object?> command,
    void Function(Map<String, Object?> event) onEvent, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _ensure();
    final id = _nextId++;
    final done = Completer<Object?>();
    _pending[id] = done;
    _events[id] = onEvent;
    _channel!.sink.add(jsonEncode({...command, 'id': id}));
    try {
      await done.future.timeout(timeout);
    } catch (_) {
      _events.remove(id);
      rethrow;
    } finally {
      _pending.remove(id);
    }
    return () async {
      if (_events.remove(id) == null) return;
      try {
        await request({'type': 'unsubscribe_events', 'subscription': id});
      } catch (_) {}
    };
  }

  Future<void> close() async => _drop(StateError('closed'));
}
