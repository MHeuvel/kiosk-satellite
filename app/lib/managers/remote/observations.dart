import 'dart:async';
import 'dart:convert';

import '../../core/command_registry.dart';

/// Native diagnostics without change callbacks share one observer across
/// viewers. No active subscription means no timer or native reads.
class RemoteObservations {
  RemoteObservations(this.commands, this.emit);

  final CommandRegistry commands;
  final void Function(String topic, Map<String, Object?> results) emit;
  final _timers = <String, Timer>{};
  final _reading = <String>{};
  final _signatures = <String, String>{};
  Set<String> _active = {};

  static const _sources = {
    'rtsp': ['getRtspStatus'],
    'bluetooth': ['bluetoothAdapterOn', 'esphomeStatus'],
    'bluetooth-nearby': ['btProxyNearby'],
    'service': ['getServiceStatus', 'getSystemPermissions', 'hasUiGuard'],
    'home-role': ['homeLauncherStatus'],
    'artwork-cache': ['albumArtCacheStats'],
    'filter': ['evalJs'],
  };

  /// Whether [topic] is one of the diagnostics this observer samples.
  static bool covers(String topic) => _sources.containsKey(topic);

  /// A manager said the state behind [topic] moved: sample it now rather
  /// than at the next tick, so viewers get the new results at once and
  /// nothing at all when the sample turns out unchanged.
  void poke(String topic) {
    if (!_active.contains(topic)) return;
    _timers.remove(topic)?.cancel();
    unawaited(_read(topic));
  }

  void observe(Set<String> topics) {
    _active = topics.intersection(_sources.keys.toSet());
    for (final topic in _timers.keys.toList()) {
      if (!_active.contains(topic)) _timers.remove(topic)?.cancel();
    }
    _signatures.removeWhere((topic, _) => !_active.contains(topic));
    for (final topic in _active) {
      if (!_timers.containsKey(topic) && !_reading.contains(topic)) {
        unawaited(_read(topic));
      }
    }
  }

  Future<void> _read(String topic) async {
    if (!_active.contains(topic) || !_reading.add(topic)) return;
    try {
      final results = <String, Object?>{};
      for (final name in _sources[topic]!) {
        // These are fixed, read-only observations. Calling their handlers
        // avoids a log entry for every diagnostic sample.
        final command = commands.all.where((c) => c.name == name).firstOrNull;
        if (command == null) continue;
        final result = await command
            .handler(
              name == 'evalJs'
                  ? const {
                      'code':
                          'JSON.stringify(window.__ksWs ? window.__ksWs.stats() : null)',
                    }
                  : const {},
            )
            .timeout(const Duration(seconds: 5));
        results[name] = result.toJson();
      }
      if (!_active.contains(topic)) return;
      final signature = jsonEncode(_stable(results));
      if (_signatures[topic] != signature) {
        _signatures[topic] = signature;
        emit(topic, results);
      }
    } catch (_) {
      // A native bridge can be temporarily unavailable during a restart.
      // Release the read before scheduling another attempt.
    } finally {
      _reading.remove(topic);
      if (_active.contains(topic)) {
        _timers[topic] = Timer(
          Duration(
            seconds: topic == 'rtsp'
                ? 2
                : topic == 'bluetooth-nearby'
                ? 15
                : 5,
          ),
          () {
            _timers.remove(topic);
            unawaited(_read(topic));
          },
        );
      }
    }
  }

  /// Fields that move on every sample without anything having changed:
  /// clocks, and the Bluetooth proxy's advertisement counters and log
  /// lines. Left out of the signature, or a proxy relaying beacons would
  /// push an "update" every five seconds and the Overview would re-read
  /// its whole health row each time. The emitted results still carry
  /// them.
  static const _volatile = {
    'uptimeMs',
    'connectedSeconds',
    'age',
    'ageMs',
    'lastSeen',
    'received',
    'forwarded',
    'lastAdvertisementAt',
    'log',
  };

  Object? _stable(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          if (!_volatile.contains(entry.key)) entry.key: _stable(entry.value),
      };
    }
    if (value is List) return value.map(_stable).toList();
    return value;
  }

  void dispose() {
    _active = {};
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _signatures.clear();
  }
}
