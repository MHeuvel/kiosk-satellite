import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/command_registry.dart';
import '../../core/events.dart';
import '../../core/manager.dart';

/// A countdown handed over by Voice Satellite. Times are epoch milliseconds.
class VoiceTimer {
  const VoiceTimer({
    required this.id,
    required this.name,
    required this.totalSeconds,
    required this.startedAt,
    required this.active,
    this.finished = false,
  });

  final String id;
  final String name;
  final int totalSeconds;
  final int startedAt;
  final bool active;
  final bool finished;

  int remaining(DateTime now) => max(
    0,
    totalSeconds -
        (active ? max(0, (now.millisecondsSinceEpoch - startedAt) ~/ 1000) : 0),
  );

  static VoiceTimer? parse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final seconds = raw['totalSeconds'];
    final start = raw['startedAt'];
    if (id is! String ||
        id.isEmpty ||
        seconds is! num ||
        !seconds.isFinite ||
        seconds < 0 ||
        start is! num ||
        !start.isFinite) {
      return null;
    }
    return VoiceTimer(
      id: id,
      name: raw['name'] is String ? raw['name'] as String : '',
      totalSeconds: seconds.toInt(),
      startedAt: start.toInt(),
      active: raw['isActive'] != false,
    );
  }
}

String voiceTimerTime(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Owns timer presentation and alert audio from integration state updates.
class VoiceTimerManager extends Manager {
  VoiceTimerManager(super.bus, super.commands, super.log);

  @override
  String get name => 'voice_timers';

  final timers = ValueNotifier<List<VoiceTimer>>(const []);
  final alerts = ValueNotifier<List<VoiceTimer>>(const []);
  bool _muted = false;
  Timer? _ring;
  String? _soundId;
  int _soundGeneration = 0;
  bool _playing = false;
  final error = ValueNotifier<int>(0);
  String _entity = '';
  StreamSubscription<VoiceTimersCleared>? _clearSub;

  @override
  Future<void> init() async {
    _clearSub = bus.on<VoiceTimersCleared>().listen((_) {
      _clearAlert();
      _entity = '';
      timers.value = const [];
    });
    commands.register(
      Command(
        name: 'setVoiceTimers',
        description: 'Hand Voice Satellite countdown pills to the kiosk.',
        handler: (p) async {
          final entity = p['entityId'];
          final raw = p['timers'];
          if (entity is! String || entity.isEmpty || raw is! List) {
            return const CommandResult.fail('Invalid timer snapshot');
          }
          final parsed = raw.map(VoiceTimer.parse).toList();
          if (parsed.any((t) => t == null) ||
              parsed.map((t) => t!.id).toSet().length != parsed.length) {
            return const CommandResult.fail('Invalid timer snapshot');
          }
          _entity = entity;
          timers.value = parsed.cast<VoiceTimer>();
          return const CommandResult.ok();
        },
      ),
    );
    commands.register(
      Command(
        name: 'setVoiceTimerAlert',
        description: 'Show or dismiss a local Voice Satellite timer alert.',
        handler: (p) async {
          final entity = p['entityId'];
          final raw = p['timers'];
          if (entity is! String || entity.isEmpty || raw is! List) {
            return const CommandResult.fail('Invalid timer alert');
          }
          final parsed = raw.map(VoiceTimer.parse).toList();
          if (parsed.any((t) => t == null) ||
              parsed.map((t) => t!.id).toSet().length != parsed.length) {
            return const CommandResult.fail('Invalid timer alert');
          }
          _entity = entity;
          if (raw.isEmpty) {
            _clearAlert();
          } else {
            alerts.value = [
              for (final timer in parsed.cast<VoiceTimer>())
                VoiceTimer(
                  id: timer.id,
                  name: timer.name,
                  totalSeconds: 0,
                  startedAt: 0,
                  active: false,
                  finished: true,
                ),
            ];
            final wasMuted = _muted;
            _muted = p['muted'] == true;
            if (_muted && !wasMuted) _stopSound();
            if (_ring == null) {
              unawaited(_chime());
              _ring = Timer.periodic(
                const Duration(seconds: 3),
                (_) => unawaited(_chime()),
              );
            } else if (wasMuted && !_muted) {
              unawaited(_chime());
            }
          }
          return const CommandResult.ok();
        },
      ),
    );
    commands.register(
      Command(
        name: 'voiceTimerActionFailed',
        description: 'Report a failed timer action from Voice Satellite.',
        handler: (p) async {
          if (p['entityId'] == _entity) error.value++;
          return const CommandResult.ok();
        },
      ),
    );
  }

  void control(String id, String action) {
    if (alerts.value.any((t) => t.id == id)) {
      _clearAlert();
      bus.publish(
        VoiceTimerAction(entityId: _entity, id: id, action: 'dismiss'),
      );
      return;
    }
    if (!{'pause', 'resume', 'cancel'}.contains(action) ||
        !timers.value.any((t) => t.id == id)) {
      return;
    }
    bus.publish(VoiceTimerAction(entityId: _entity, id: id, action: action));
  }

  Future<void> _chime() async {
    if (_muted || alerts.value.isEmpty || _playing) return;
    final generation = _soundGeneration;
    _playing = true;
    try {
      final result = await commands.execute('playTimerChime', const {});
      final data = result.data;
      if (data is Map && data['id'] is String) {
        final id = data['id'] as String;
        if (generation != _soundGeneration || _muted || alerts.value.isEmpty) {
          await commands.execute('stopSound', {'id': id});
        } else {
          _soundId = id;
        }
      }
    } finally {
      _playing = false;
    }
  }

  void _stopSound() {
    _soundGeneration++;
    final id = _soundId;
    _soundId = null;
    if (id != null) unawaited(commands.execute('stopSound', {'id': id}));
  }

  void _clearAlert() {
    _ring?.cancel();
    _ring = null;
    _stopSound();
    alerts.value = const [];
  }

  @override
  Future<void> dispose() async {
    _clearAlert();
    alerts.dispose();
    await _clearSub?.cancel();
    timers.dispose();
    error.dispose();
  }
}
