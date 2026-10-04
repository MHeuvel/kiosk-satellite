import 'dart:async';

import '../../core/event_bus.dart';
import '../../core/events.dart';

/// Whether this kiosk is in a conversation right now, from the
/// [VoiceInteractionChanged] events: a voice turn, a `vs_show` prompt or a
/// realtime session. Timers, announcements, media, alarms and intercom
/// calls are not conversations.
class VoiceTurns {
  VoiceTurns(this._bus, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// A voice turn that ended this recently still counts, for a runtime
  /// that reports the end before the tool's event arrives.
  static const grace = Duration(seconds: 5);

  /// Interactions that are a conversation with this kiosk, a `vs_show`
  /// prompt included. The page's unnamed one is a legacy Voice Satellite
  /// reporting a turn.
  static const reasons = {
    'voice',
    'show',
    // A realtime session: its model calls scripts over Home Assistant's
    // MCP Server while the conversation runs.
    'conversation',
    'start_conversation',
    'ask_question',
  };

  final EventBus _bus;
  final DateTime Function() _clock;
  final _turns = <String>{};
  DateTime? _ended;
  StreamSubscription<VoiceInteractionChanged>? _sub;
  final _waiting = <Completer<void>>[];

  void start() {
    _sub ??= _bus.on<VoiceInteractionChanged>().listen(_onInteraction);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _wake();
  }

  void _onInteraction(VoiceInteractionChanged e) {
    final reason = e.reason.isEmpty && e.source == InteractionSource.page
        ? 'voice'
        : e.reason;
    if (!reasons.contains(reason)) return;
    if (e.active) {
      _turns.add(reason);
    } else if (_turns.remove(reason) && _turns.isEmpty) {
      _ended = _clock();
      _wake();
    }
  }

  void _wake() {
    for (final c in _waiting) {
      if (!c.isCompleted) c.complete();
    }
    _waiting.clear();
  }

  /// In a conversation now.
  bool get active => _turns.isNotEmpty;

  /// In a conversation, or just finished one.
  bool get activeOrRecent {
    if (active) return true;
    final ended = _ended;
    return ended != null && _clock().difference(ended) <= grace;
  }

  /// Waits for the conversation to end. False when it still runs after
  /// [timeout].
  Future<bool> ended(Duration timeout) async {
    if (!active) return true;
    final c = Completer<void>();
    _waiting.add(c);
    try {
      await c.future.timeout(timeout);
      return true;
    } on TimeoutException {
      _waiting.remove(c);
      return false;
    }
  }
}
