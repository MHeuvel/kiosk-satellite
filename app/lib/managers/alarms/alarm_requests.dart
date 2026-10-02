import '../settings/definitions.dart' as defs;
import '../settings/settings_manager.dart';
import 'alarm_manager.dart';
import 'alarm_model.dart';

/// Alarms set by voice through Home Assistant. The Kiosk Satellite alarms
/// script (a blueprint in this repository) is exposed to Assist, so any
/// LLM conversation agent can call it in any language. The voice requests
/// manager hears it and, on the kiosk being asked, runs it through the
/// `alarmsVoiceRequest` command, which lands in [handle].
class AlarmRequests {
  AlarmRequests(this._settings, this._alarms, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SettingsManager _settings;
  final AlarmManager _alarms;
  final DateTime Function() _clock;

  /// Applies one request and says what came of it, in the shape the script
  /// returns to the LLM.
  ///
  /// One at a time: an agent sends "delete my 6:30 alarm and set one for
  /// 7" as two tool calls at once, and each reads the list before the
  /// other has written it, so the set would bring the deleted alarm back.
  Future<Map<String, Object?>> handle(Map<String, Object?> data) {
    final done = _queue.then((_) => _apply(data));
    _queue = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<void> _queue = Future.value();

  Future<Map<String, Object?>> _apply(Map<String, Object?> data) async {
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
