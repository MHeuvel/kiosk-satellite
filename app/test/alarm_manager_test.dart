import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/alarms/alarm_manager.dart';
import 'package:kiosk_satellite/managers/alarms/alarm_model.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A ring from start to Stop, Snooze or Silence after, driven by a clock
/// the test moves: what rings, what it holds on the way (the screen, the
/// screensaver, the stop word, the brightness) and what survives a
/// restart. The native side is absent here, so only Dart's own timing and
/// the commands it reaches for are checked. 2026-10-02 is a Friday.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EventBus bus;
  late SettingsManager settings;
  late AlarmManager alarms;
  late List<(String, Map<String, Object?>)> calls;
  late List<VoiceInteractionChanged> holds;
  late DateTime now;
  var takeoverOk = true;

  Future<void> build(
    List<Map<String, Object?>> list, {
    Map<String, Object> extra = const {},
  }) async {
    SharedPreferences.setMockInitialValues({
      'ks.alarms.list': jsonEncode(list),
      ...extra,
    });
    bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    calls = [];
    holds = [];
    bus.on<VoiceInteractionChanged>().listen(holds.add);
    for (final name in [
      'bringToFront',
      'screenOn',
      'stopScreensaver',
      'alarmBrightness',
      'setStopWordArmed',
      'alarmTakeover',
    ]) {
      commands.register(
        Command(
          name: name,
          description: 'stub',
          handler: (p) async {
            calls.add((name, p));
            if (name == 'alarmTakeover' && p['phase'] != null && !takeoverOk) {
              return const CommandResult.fail('refused');
            }
            return const CommandResult.ok();
          },
        ),
      );
    }
    alarms = AlarmManager(bus, commands, log, settings, clock: () => now);
    await alarms.init();
    await pumpEventQueue();
  }

  tearDown(() async {
    await alarms.dispose();
  });

  Map<String, Object?> daily(
    String time, {
    String id = 'a',
    bool sunrise = false,
    String label = '',
  }) => {
    'id': id,
    'time': time,
    'days': [0, 1, 2, 3, 4, 5, 6],
    'label': label,
    'sunrise': sunrise,
    'on': true,
  };

  Iterable<String> named(String name) =>
      calls.where((c) => c.$1 == name).map((c) => jsonEncode(c.$2));

  test('a due alarm rings, comes forward and arms the stop word', () async {
    now = DateTime(2026, 10, 2, 7, 0, 5);
    await build([daily('07:00', label: 'Wake up')]);
    final s = alarms.status.value;
    expect(s.phase, AlarmPhase.ringing);
    expect(s.ids, ['a']);
    expect(s.labels, ['Wake up']);
    expect(s.takeover, isNull);
    expect(s.ownView, isTrue);
    expect(named('bringToFront'), isNotEmpty);
    expect(
      named('setStopWordArmed'),
      contains('{"armed":true,"holder":"alarm"}'),
    );
    expect(holds.single.active, isTrue);
    expect(holds.single.reason, 'alarm');
    expect(holds.single.source, InteractionSource.command);
  });

  test('an alarm is not due before its minute or long after it', () async {
    now = DateTime(2026, 10, 2, 6, 59, 30);
    await build([daily('07:00')]);
    expect(alarms.status.value.phase, AlarmPhase.idle);
    expect(alarms.status.value.next?.at, DateTime(2026, 10, 2, 7));
    // Asleep through the whole Silence after window: skipped, not late.
    now = DateTime(2026, 10, 2, 7, 11);
    await alarms.check();
    expect(alarms.status.value.phase, AlarmPhase.idle);
  });

  test(
    'snooze holds it off for the snooze length, then it rings again',
    () async {
      now = DateTime(2026, 10, 2, 7, 0, 5);
      await build([daily('07:00')]);
      expect(await alarms.snooze(), isTrue);
      var s = alarms.status.value;
      expect(s.phase, AlarmPhase.snoozed);
      expect(s.snoozedUntil, DateTime(2026, 10, 2, 7, 10, 5));
      expect(s.next?.at, DateTime(2026, 10, 2, 7, 10, 5));
      expect(holds.last.active, isFalse);
      now = DateTime(2026, 10, 2, 7, 10, 6);
      await alarms.check();
      s = alarms.status.value;
      expect(s.phase, AlarmPhase.ringing);
      expect(s.ids, ['a']);
    },
  );

  test('stop ends it and the same ring never comes back', () async {
    now = DateTime(2026, 10, 2, 7, 0, 5);
    await build([daily('07:00')]);
    expect(await alarms.stop(), isTrue);
    expect(alarms.status.value.phase, AlarmPhase.idle);
    expect(named('setStopWordArmed').last, '{"armed":false,"holder":"alarm"}');
    now = DateTime(2026, 10, 2, 7, 1);
    await alarms.check();
    expect(alarms.status.value.phase, AlarmPhase.idle);
    expect(alarms.status.value.next?.at, DateTime(2026, 10, 3, 7));
  });

  test('silence after ends a ring nobody stops, as stopped', () async {
    now = DateTime(2026, 10, 2, 7, 0, 5);
    await build([daily('07:00')]);
    now = DateTime(2026, 10, 2, 7, 10, 6);
    await alarms.check();
    expect(alarms.status.value.phase, AlarmPhase.idle);
  });

  test('a one time alarm turns itself off once it rings', () async {
    now = DateTime(2026, 10, 2, 7, 0, 5);
    await build([
      {'id': 'o', 'time': '07:00', 'date': '2026-10-02', 'on': true},
    ]);
    expect(alarms.status.value.phase, AlarmPhase.ringing);
    final stored = decodeAlarms(settings.get(defs.alarmsList)).single;
    expect(stored.on, isFalse);
    expect(stored.date, isNull);
  });

  test('saving a one time alarm dates it to its next ring', () async {
    now = DateTime(2026, 10, 2, 9);
    await build(const []);
    final saved = await alarms.save(const Alarm(id: 'n', hour: 8, minute: 0));
    expect(saved.date, '2026-10-03');
    expect(alarms.status.value.next?.at, DateTime(2026, 10, 3, 8));
  });

  test('Clock with Let alarms take over rings on the screensaver', () async {
    takeoverOk = true;
    now = DateTime(2026, 10, 2, 7, 0, 5);
    await build(
      [daily('07:00')],
      extra: {'ks.screensaver.enabled': true, 'ks.screensaver.mode': 'clock'},
    );
    final s = alarms.status.value;
    expect(s.phase, AlarmPhase.ringing);
    expect(s.takeover, 'clock');
    expect(s.ownView, isFalse);
    expect(named('alarmTakeover'), contains('{"phase":"ringing"}'));
    expect(holds.last.source, InteractionSource.native);
    await alarms.stop();
    expect(named('alarmTakeover').last, '{"phase":null}');
  });

  test('a refused takeover falls back to the alarm own view', () async {
    takeoverOk = false;
    now = DateTime(2026, 10, 2, 7, 0, 5);
    await build(
      [daily('07:00')],
      extra: {
        'ks.screensaver.enabled': true,
        'ks.screensaver.mode': 'weather_mood',
      },
    );
    expect(alarms.status.value.takeover, isNull);
    expect(alarms.status.value.ownView, isTrue);
    expect(holds.last.source, InteractionSource.command);
    takeoverOk = true;
  });

  test('the takeover switch off keeps the own view', () async {
    now = DateTime(2026, 10, 2, 7, 0, 5);
    await build(
      [daily('07:00')],
      extra: {
        'ks.screensaver.enabled': true,
        'ks.screensaver.mode': 'clock',
        'ks.screensaver.clock_alarm_takeover': false,
      },
    );
    expect(alarms.status.value.takeover, isNull);
    expect(named('alarmTakeover'), isEmpty);
  });

  test('a sunrise alarm brightens ahead and rings at full', () async {
    now = DateTime(2026, 10, 2, 6, 45);
    await build([daily('07:00', sunrise: true)]);
    var s = alarms.status.value;
    expect(s.phase, AlarmPhase.sunrise);
    expect(s.sunriseStart, DateTime(2026, 10, 2, 6, 30));
    final level = calls.lastWhere((c) => c.$1 == 'alarmBrightness').$2['level'];
    expect(level, closeTo(0.02 + 0.98 * 0.5, 0.01));
    now = DateTime(2026, 10, 2, 7, 0, 1);
    await alarms.check();
    s = alarms.status.value;
    expect(s.phase, AlarmPhase.ringing);
    expect(calls.lastWhere((c) => c.$1 == 'alarmBrightness').$2['level'], 1);
    await alarms.stop();
    expect(
      calls.lastWhere((c) => c.$1 == 'alarmBrightness').$2['level'],
      isNull,
    );
  });

  test('stopping a sunrise skips its ring', () async {
    now = DateTime(2026, 10, 2, 6, 45);
    await build([daily('07:00', sunrise: true)]);
    await alarms.stop();
    // The skipped ring no longer counts as the next one.
    expect(alarms.status.value.next?.at, DateTime(2026, 10, 3, 7));
    now = DateTime(2026, 10, 2, 7, 0, 1);
    await alarms.check();
    expect(alarms.status.value.phase, AlarmPhase.idle);
  });

  test('stopping the sunrise of a one time alarm turns it off', () async {
    now = DateTime(2026, 10, 2, 6, 45);
    await build([
      {'id': 'o', 'time': '07:00', 'date': '2026-10-02', 'sunrise': true},
    ]);
    expect(alarms.status.value.phase, AlarmPhase.sunrise);
    await alarms.stop();
    expect(decodeAlarms(settings.get(defs.alarmsList)).single.on, isFalse);
    expect(alarms.status.value.next, isNull);
  });

  test('a snooze survives a restart', () async {
    now = DateTime(2026, 10, 2, 7, 5);
    await build(
      [daily('07:00')],
      extra: {
        'ks.alarms.runtime': jsonEncode({
          'handled': {'a': DateTime(2026, 10, 2, 7).millisecondsSinceEpoch},
          'snooze': {
            'ids': ['a'],
            'at': DateTime(2026, 10, 2, 7).millisecondsSinceEpoch,
            'until': DateTime(2026, 10, 2, 7, 10).millisecondsSinceEpoch,
          },
        }),
      },
    );
    final s = alarms.status.value;
    expect(s.phase, AlarmPhase.snoozed);
    expect(s.snoozedUntil, DateTime(2026, 10, 2, 7, 10));
  });

  test('deleting a ringing alarm stops it', () async {
    now = DateTime(2026, 10, 2, 7, 0, 5);
    await build([daily('07:00')]);
    expect(await alarms.delete('a'), isTrue);
    expect(alarms.status.value.phase, AlarmPhase.idle);
    expect(alarms.alarms.value, isEmpty);
  });
}
