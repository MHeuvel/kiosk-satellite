import 'dart:async';

import '../../core/event_bus.dart';
import '../../core/events.dart';
import '../../core/logging.dart';
import '../settings/definitions.dart' as defs;
import '../settings/settings_manager.dart';
import '../voice/ha_socket.dart';
import 'alarm_manager.dart';
import 'alarm_model.dart';

/// Alarms set by voice through Home Assistant. The Kiosk Satellite alarms
/// script (a blueprint in this repository) is exposed to Assist, so any
/// LLM conversation agent can call it in any language. It fires
/// [requestEvent]; every kiosk hears it over its own Home Assistant
/// socket, and the one being asked answers with [resultEvent], which the
/// script hands back to the LLM.
///
/// The kiosk being asked is the one named in the request, or else the one
/// in a voice turn right now: the tool runs while the conversation is
/// still going, so that is the kiosk that heard it. Nothing here needs an
/// ESPHome entity, so adding or removing alarms never restarts the ESPHome
/// server.
class AlarmRequests {
  AlarmRequests(
    this._bus,
    this._log,
    this._settings,
    this._alarms, {
    DateTime Function()? clock,
    HaSocket? socket,
  }) : _clock = clock ?? DateTime.now,
       _socket =
           socket ??
           HaSocket(
             baseUrl: () => _settings.get(defs.haUrl),
             token: () => _settings.get(defs.haToken),
           );

  static const requestEvent = 'kiosk_satellite_alarm';
  static const resultEvent = 'kiosk_satellite_alarm_result';

  /// A voice turn that ended this recently still counts, for a runtime
  /// that reports the end before the tool's event arrives.
  static const _grace = Duration(seconds: 5);

  /// Interactions that are a conversation with this kiosk, a `vs_show`
  /// prompt included. The page's unnamed one is a legacy Voice Satellite
  /// reporting a turn.
  static const _turnReasons = {
    'voice',
    'show',
    'start_conversation',
    'ask_question',
  };

  final EventBus _bus;
  final Logger _log;
  final SettingsManager _settings;
  final AlarmManager _alarms;
  final DateTime Function() _clock;
  final HaSocket _socket;

  final _turns = <String>{};
  DateTime? _turnEnded;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _watch;
  Future<void> Function()? _unsubscribe;
  int _subscribedOn = -1;
  bool _subscribing = false;

  static const _name = 'alarms';

  void start() {
    _subs
      ..add(_bus.on<VoiceInteractionChanged>().listen(_onInteraction))
      ..add(
        _bus.on<SettingChanged>().listen((e) {
          if (e.key == defs.haUrl.key || e.key == defs.haToken.key) {
            unawaited(_resubscribe());
          }
        }),
      );
    // The socket does not reconnect on its own: look again now and then.
    _watch = Timer.periodic(const Duration(seconds: 30), (_) => _follow());
    unawaited(_follow());
  }

  Future<void> dispose() async {
    _watch?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _socket.close();
  }

  void _onInteraction(VoiceInteractionChanged e) {
    final reason = e.reason.isEmpty && e.source == InteractionSource.page
        ? 'voice'
        : e.reason;
    if (!_turnReasons.contains(reason)) return;
    if (e.active) {
      _turns.add(reason);
    } else if (_turns.remove(reason) && _turns.isEmpty) {
      _turnEnded = _clock();
    }
  }

  /// This kiosk is in a conversation, or just finished one.
  bool get inVoiceTurn {
    if (_turns.isNotEmpty) return true;
    final ended = _turnEnded;
    return ended != null && _clock().difference(ended) <= _grace;
  }

  bool get _configured =>
      _settings.get(defs.haUrl).trim().isNotEmpty &&
      _settings.get(defs.haToken).isNotEmpty;

  Future<void> _resubscribe() async {
    _unsubscribe = null;
    _subscribedOn = -1;
    await _socket.close();
    await _follow();
  }

  Future<void> _follow() async {
    if (_subscribing || !_configured) return;
    if (_unsubscribe != null &&
        _socket.connected &&
        _socket.connections == _subscribedOn) {
      return;
    }
    _subscribing = true;
    try {
      _unsubscribe = await _socket.subscribe({
        'type': 'subscribe_events',
        'event_type': requestEvent,
      }, (event) => unawaited(_onRequest(event['data'])));
      _subscribedOn = _socket.connections;
      _log.debug(_name, 'listening for alarm requests');
    } catch (e) {
      _unsubscribe = null;
      // A token without admin rights cannot follow custom events.
      _log.debug(_name, 'alarm requests not followed: $e');
    } finally {
      _subscribing = false;
    }
  }

  Future<void> _onRequest(Object? raw) async {
    if (raw is! Map) return;
    final data = raw.cast<String, Object?>();
    if (!isForMe(data)) return;
    final result = await handle(data);
    _log.info(
      _name,
      'voice request ${data['action']}: '
      '${result['ok'] == true ? result['result'] : result['error']}',
    );
    try {
      await _socket.request({
        'type': 'fire_event',
        'event_type': resultEvent,
        'event_data': {'id': data['id'], ...result},
      });
    } catch (e) {
      _log.warn(_name, 'could not answer the alarm request: $e');
    }
  }

  /// Named in the request, or, with no name, in a voice turn.
  bool isForMe(Map<String, Object?> data) {
    final asked = _norm('${data['kiosk'] ?? ''}');
    if (asked.isEmpty) return inVoiceTurn;
    for (final own in [
      _settings.get(defs.deviceName),
      _settings.get(defs.esphomeNodeName),
    ]) {
      final name = _norm(own);
      if (name.isNotEmpty && (name.contains(asked) || asked.contains(name))) {
        return true;
      }
    }
    return false;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  /// Applies one request and says what came of it, in the shape the script
  /// returns to the LLM.
  Future<Map<String, Object?>> handle(Map<String, Object?> data) async {
    final kiosk = _settings.get(defs.deviceName);
    Map<String, Object?> fail(String error, [List<Alarm>? alarms]) => {
      'ok': false,
      'kiosk': kiosk,
      'error': error,
      if (alarms != null) 'alarms': [for (final a in alarms) describe(a)],
    };
    final action = '${data['action'] ?? ''}'.trim().toLowerCase();
    final all = _alarms.alarms.value;
    switch (action) {
      case 'list':
        return {
          'ok': true,
          'kiosk': kiosk,
          'result': 'listed',
          'alarms': [for (final a in all) describe(a)],
        };
      case 'set':
        final time = parseAlarmTime(data['time']);
        if (time == null) return fail('time must be HH:MM, 24 hour');
        final label = '${data['label'] ?? ''}'.trim();
        final days = parseAlarmDays(data['days']);
        final alarm = Alarm(
          id: newAlarmId(),
          hour: time.hour,
          minute: time.minute,
          days: days,
          label: label.length > 40 ? label.substring(0, 40) : label,
        );
        final existing = _alarms.duplicateOf(alarm);
        if (existing != null) {
          // The Nest Hub answer: that alarm exists, so it is turned on.
          final on = await _alarms.save(
            existing.copyWith(
              on: true,
              label: label.isEmpty ? null : alarm.label,
            ),
            allowDuplicate: true,
          );
          return {
            'ok': true,
            'kiosk': kiosk,
            'result': 'already_existed_now_on',
            'alarm': describe(on),
          };
        }
        final saved = await _alarms.save(alarm);
        return {
          'ok': true,
          'kiosk': kiosk,
          'result': 'set',
          'alarm': describe(saved),
        };
      case 'delete' || 'turn_on' || 'turn_off':
        final matches = _match(all, data);
        if (matches.isEmpty) return fail('no matching alarm', all);
        if (matches.length > 1) {
          return fail('several alarms match, ask which one', matches);
        }
        final alarm = matches.single;
        if (action == 'delete') {
          await _alarms.delete(alarm.id);
          return {
            'ok': true,
            'kiosk': kiosk,
            'result': 'deleted',
            'alarm': describe(alarm.copyWith(on: false)),
          };
        }
        final on = action == 'turn_on';
        await _alarms.setEnabled(alarm.id, on);
        final now = _alarms.alarms.value.where((a) => a.id == alarm.id);
        return {
          'ok': true,
          'kiosk': kiosk,
          'result': on ? 'turned_on' : 'turned_off',
          'alarm': describe(now.firstOrNull ?? alarm),
        };
      default:
        return fail('action must be set, list, delete, turn_on or turn_off');
    }
  }

  /// The alarms a delete or a switch means: by time, by label or both.
  /// With neither, every alarm, which is only one match when there is
  /// only one alarm.
  List<Alarm> _match(List<Alarm> all, Map<String, Object?> data) {
    final time = parseAlarmTime(data['time']);
    final label = '${data['label'] ?? ''}'.trim().toLowerCase();
    if (time == null && label.isEmpty) return all;
    return [
      for (final a in all)
        if ((time == null ||
                (a.hour == time.hour && a.minute == time.minute)) &&
            (label.isEmpty || a.label.toLowerCase().contains(label)))
          a,
    ];
  }

  /// An alarm as the LLM reads it: English day names and the next ring as
  /// the kiosk's local time.
  Map<String, Object?> describe(Alarm alarm) {
    final next = nextRing(alarm, _clock());
    return {
      'time': alarm.time,
      'days': alarm.repeats
          ? [for (final d in alarm.days) _dayNames[d]]
          : 'once',
      if (alarm.label.isNotEmpty) 'label': alarm.label,
      'on': alarm.on,
      if (next != null)
        'next_ring':
            '${_weekdayNames[next.weekday % 7]} '
            '${dateKey(next)} ${alarm.time}',
    };
  }

  static const _dayNames = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  static const _weekdayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
}

/// "06:30", "6:30", "18:05" or "6:30 pm" as a time of day, or null.
({int hour, int minute})? parseAlarmTime(Object? raw) {
  final m = RegExp(
    r'^\s*(\d{1,2})(?::(\d{2}))?(?::\d{2})?\s*([ap])?\.?\s*m?\.?\s*$',
    caseSensitive: false,
  ).firstMatch('${raw ?? ''}');
  if (m == null) return null;
  var hour = int.parse(m[1]!);
  final minute = int.parse(m[2] ?? '0');
  final half = m[3]?.toLowerCase();
  if (half != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (half == 'p' ? 12 : 0);
  }
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

/// The repeat days of a request, 0 = Sunday: day names in English (short
/// or long), numbers, "weekdays", "weekends" or "daily". Empty rings once.
List<int> parseAlarmDays(Object? raw) {
  final items = raw is List ? raw : '${raw ?? ''}'.split(RegExp(r'[\s,;]+'));
  const names = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  final days = <int>{};
  for (final item in items) {
    if (item is int && item >= 0 && item <= 6) {
      days.add(item);
      continue;
    }
    final word = '$item'.trim().toLowerCase();
    if (word.isEmpty) continue;
    if (word == 'weekdays') {
      days.addAll([1, 2, 3, 4, 5]);
    } else if (word == 'weekends') {
      days.addAll([0, 6]);
    } else if (word == 'daily' || word == 'everyday' || word == 'all') {
      days.addAll([0, 1, 2, 3, 4, 5, 6]);
    } else if (word.length >= 3 && names.contains(word.substring(0, 3))) {
      days.add(names.indexOf(word.substring(0, 3)));
    } else if (int.tryParse(word) case final n? when n >= 0 && n <= 6) {
      days.add(n);
    }
  }
  return days.toList()..sort();
}
