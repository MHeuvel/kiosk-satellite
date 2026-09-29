import 'dart:convert';
import 'dart:math';

/// One alarm as `alarms.list` stores it. Times are local wall time; the
/// ring moments are worked out against the device clock whenever they are
/// needed, so a time zone or a DST change moves them with the wall.
class Alarm {
  const Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.days = const [],
    this.date,
    this.label = '',
    this.tone = '',
    this.sunrise = false,
    this.on = true,
  });

  final String id;
  final int hour, minute;

  /// Weekdays it repeats on, 0 = Sunday. Empty rings once, on [date].
  final List<int> days;

  /// The day a one time alarm rings, `yyyy-MM-dd`. Null on a repeating
  /// alarm, and on a one time alarm that is off.
  final String? date;
  final String label;

  /// Empty follows the default tone; `builtin` is the built-in alarm;
  /// anything else is a file in the sounds folder.
  final String tone;
  final bool sunrise, on;

  bool get repeats => days.isNotEmpty;

  String get time =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Alarm copyWith({
    int? hour,
    int? minute,
    List<int>? days,
    String? Function()? date,
    String? label,
    String? tone,
    bool? sunrise,
    bool? on,
  }) => Alarm(
    id: id,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    days: days ?? this.days,
    date: date != null ? date() : this.date,
    label: label ?? this.label,
    tone: tone ?? this.tone,
    sunrise: sunrise ?? this.sunrise,
    on: on ?? this.on,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'time': time,
    'days': days,
    if (date != null) 'date': date,
    'label': label,
    'tone': tone,
    'sunrise': sunrise,
    'on': on,
  };

  /// Null for anything that is not an alarm, so one bad entry never takes
  /// the list down with it.
  static Alarm? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final time = RegExp(
      r'^([01]\d|2[0-3]):([0-5]\d)$',
    ).firstMatch('${raw['time'] ?? ''}');
    if (time == null) return null;
    final id = '${raw['id'] ?? ''}'.trim();
    final days = <int>{
      for (final d in (raw['days'] is List ? raw['days'] as List : const []))
        if (d is num && d >= 0 && d <= 6) d.toInt(),
    }.toList()..sort();
    final date = '${raw['date'] ?? ''}';
    return Alarm(
      id: id.isEmpty ? newAlarmId() : id,
      hour: int.parse(time.group(1)!),
      minute: int.parse(time.group(2)!),
      days: days,
      date: RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ? date : null,
      label: '${raw['label'] ?? ''}'.trim(),
      tone: '${raw['tone'] ?? ''}'.trim(),
      sunrise: raw['sunrise'] == true,
      on: raw['on'] != false,
    );
  }
}

final _random = Random();

/// A short id that names an alarm across both surfaces and the runtime
/// state. Random, not a counter, so two surfaces adding at once never
/// collide.
String newAlarmId() => List.generate(
  8,
  (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
).join();

List<Alarm> decodeAlarms(String json) {
  try {
    final raw = jsonDecode(json);
    if (raw is! List) return const [];
    final seen = <String>{};
    return [
      for (final item in raw)
        if (Alarm.fromJson(item) case final alarm? when seen.add(alarm.id))
          alarm,
    ];
  } catch (_) {
    return const [];
  }
}

String encodeAlarms(List<Alarm> alarms) =>
    jsonEncode([for (final a in alarms) a.toJson()]);

/// By time of day, the order the list shows them in.
List<Alarm> sortAlarms(List<Alarm> alarms) => [...alarms]
  ..sort((a, b) {
    final t = (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
    return t != 0 ? t : a.id.compareTo(b.id);
  });

String dateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DateTime? _parseDate(String? key) {
  if (key == null) return null;
  final parts = key.split('-');
  if (parts.length != 3) return null;
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

DateTime _at(DateTime day, Alarm alarm) =>
    DateTime(day.year, day.month, day.day, alarm.hour, alarm.minute);

/// The day a one time alarm set now rings: today if its time is still
/// ahead, else tomorrow.
String onceDate(int hour, int minute, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return dateKey(
    today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, hour, minute),
  );
}

/// The next time [alarm] rings strictly after [now], or null when it is
/// off or a one time alarm whose day is behind.
DateTime? nextRing(Alarm alarm, DateTime now) {
  if (!alarm.on) return null;
  if (!alarm.repeats) {
    final day = _parseDate(alarm.date);
    if (day == null) return null;
    final at = _at(day, alarm);
    return at.isAfter(now) ? at : null;
  }
  for (var d = 0; d <= 7; d++) {
    final at = _at(DateTime(now.year, now.month, now.day + d), alarm);
    if (at.isAfter(now) && alarm.days.contains(at.weekday % 7)) return at;
  }
  return null;
}

/// The latest time [alarm] was due at or before [now], or null.
DateTime? lastRing(Alarm alarm, DateTime now) {
  if (!alarm.on) return null;
  if (!alarm.repeats) {
    final day = _parseDate(alarm.date);
    if (day == null) return null;
    final at = _at(day, alarm);
    return at.isAfter(now) ? null : at;
  }
  for (var d = 0; d <= 7; d++) {
    final at = _at(DateTime(now.year, now.month, now.day - d), alarm);
    if (!at.isAfter(now) && alarm.days.contains(at.weekday % 7)) return at;
  }
  return null;
}

/// The next ring across every alarm: which one and when.
({Alarm alarm, DateTime at})? nextOf(List<Alarm> alarms, DateTime now) {
  ({Alarm alarm, DateTime at})? best;
  for (final alarm in alarms) {
    final at = nextRing(alarm, now);
    if (at != null && (best == null || at.isBefore(best.at))) {
      best = (alarm: alarm, at: at);
    }
  }
  return best;
}

/// Which days a repeat covers, in words: Every day, Weekdays, Weekends or
/// null for any other set (the caller lists the day names).
String? repeatWord(List<int> days) {
  final set = days.toSet();
  if (set.length == 7) return 'Every day';
  if (set.length == 5 && !set.contains(0) && !set.contains(6)) {
    return 'Weekdays';
  }
  if (set.length == 2 && set.contains(0) && set.contains(6)) {
    return 'Weekends';
  }
  return null;
}
