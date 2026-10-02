import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/alarms/alarm_manager.dart';
import 'package:kiosk_satellite/managers/alarms/alarm_requests.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alarms asked for through the Kiosk Satellite alarms script: what each
/// action does to the list and says back to the LLM. 2026-10-02 is a Friday.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EventBus bus;
  AlarmManager? built;
  late AlarmManager alarms;
  late AlarmRequests requests;
  late SettingsManager settings;
  var now = DateTime(2026, 10, 2, 9);

  Future<void> build(List<Map<String, Object?>> list) async {
    SharedPreferences.setMockInitialValues({
      'ks.alarms.list': jsonEncode(list),
      'ks.device.name': 'Bedroom Kiosk',
    });
    bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    for (final name in [
      'bringToFront',
      'screenOn',
      'stopScreensaver',
      'alarmBrightness',
      'setStopWordArmed',
      'alarmTakeover',
      'holdScreensaver',
    ]) {
      commands.register(
        Command(
          name: name,
          description: 'stub',
          handler: (_) async => const CommandResult.ok(),
        ),
      );
    }
    alarms = built = AlarmManager(
      bus,
      commands,
      log,
      settings,
      clock: () => now,
    );
    await alarms.init();
    requests = alarms.requests;
    await pumpEventQueue();
  }

  tearDown(() async {
    await built?.dispose();
    built = null;
  });

  group('actions', () {
    test('set adds a weekday alarm and says when it rings', () async {
      now = DateTime(2026, 10, 2, 9);
      await build([]);
      final r = await requests.handle({
        'action': 'set',
        'time': '06:30',
        'days': ['mon', 'tue', 'wed', 'thu', 'fri'],
        'label': 'Gym',
      });
      expect(r['ok'], isTrue);
      expect(r['result'], 'set');
      expect(r['kiosk'], 'Bedroom Kiosk');
      final alarm = r['alarm']! as Map;
      expect(alarm['time'], '06:30');
      expect(alarm['days'], ['mon', 'tue', 'wed', 'thu', 'fri']);
      expect(alarm['label'], 'Gym');
      expect(alarm['next_ring'], 'Monday 2026-10-05 06:30');
      expect(alarms.alarms.value.single.days, [1, 2, 3, 4, 5]);
    });

    test('set with no days rings once, next time the clock reads it', () async {
      now = DateTime(2026, 10, 2, 9);
      await build([]);
      final r = await requests.handle({'action': 'set', 'time': '7:15'});
      final alarm = r['alarm']! as Map;
      expect(alarm['days'], 'once');
      expect(alarm['next_ring'], 'Saturday 2026-10-03 07:15');
    });

    test('set on an existing alarm turns it on instead', () async {
      await build([
        {'id': 'a', 'time': '06:30', 'on': false},
      ]);
      final r = await requests.handle({'action': 'set', 'time': '06:30'});
      expect(r['result'], 'already_existed_now_on');
      expect(alarms.alarms.value.single.on, isTrue);
      expect(alarms.alarms.value, hasLength(1));
    });

    test('set refuses a time it cannot read', () async {
      await build([]);
      final r = await requests.handle({'action': 'set', 'time': 'soon'});
      expect(r['ok'], isFalse);
      expect(alarms.alarms.value, isEmpty);
    });

    test('list returns every alarm', () async {
      await build([
        {'id': 'a', 'time': '06:30', 'label': 'Gym', 'on': true},
        {
          'id': 'b',
          'time': '08:00',
          'days': [0, 6],
          'on': false,
        },
      ]);
      final r = await requests.handle({'action': 'list'});
      final list = r['alarms']! as List;
      expect(list, hasLength(2));
      expect((list.last as Map)['days'], ['sun', 'sat']);
      expect((list.last as Map)['on'], isFalse);
    });

    test('delete by label, and turn off by time', () async {
      await build([
        {'id': 'a', 'time': '06:30', 'label': 'Gym', 'on': true},
        {'id': 'b', 'time': '08:00', 'on': true},
      ]);
      var r = await requests.handle({'action': 'turn_off', 'time': '08:00'});
      expect(r['result'], 'turned_off');
      expect(alarms.alarms.value.last.on, isFalse);
      r = await requests.handle({'action': 'delete', 'label': 'gym'});
      expect(r['result'], 'deleted');
      expect(alarms.alarms.value.map((a) => a.id), ['b']);
    });

    test('requests that arrive together apply one after the other', () async {
      // An agent sends "delete my 6:30 alarm and set one for 7" as two
      // tool calls at once: the set must not write back the deleted alarm.
      await build([
        {'id': 'a', 'time': '06:30', 'on': true},
      ]);
      await Future.wait([
        requests.handle({'action': 'delete', 'time': '06:30'}),
        requests.handle({'action': 'set', 'time': '07:00'}),
      ]);
      expect(alarms.alarms.value.map((a) => a.time), ['07:00']);
    });

    test('several matches ask which one and change nothing', () async {
      await build([
        {'id': 'a', 'time': '06:30', 'on': true},
        {
          'id': 'b',
          'time': '06:30',
          'days': [1],
          'on': true,
        },
      ]);
      final r = await requests.handle({'action': 'delete', 'time': '06:30'});
      expect(r['ok'], isFalse);
      expect(r['alarms'], hasLength(2));
      expect(alarms.alarms.value, hasLength(2));
    });
  });

  group('parsing', () {
    test('times', () {
      expect(parseAlarmTime('06:30'), (hour: 6, minute: 30));
      expect(parseAlarmTime('18:05:00'), (hour: 18, minute: 5));
      expect(parseAlarmTime('6:30 pm'), (hour: 18, minute: 30));
      expect(parseAlarmTime('12 am'), (hour: 0, minute: 0));
      expect(parseAlarmTime('7'), (hour: 7, minute: 0));
      expect(parseAlarmTime('25:00'), isNull);
      expect(parseAlarmTime('13 pm'), isNull);
      expect(parseAlarmTime(''), isNull);
    });

    test('days', () {
      expect(parseAlarmDays(['mon', 'Friday']), [1, 5]);
      expect(parseAlarmDays('weekdays'), [1, 2, 3, 4, 5]);
      expect(parseAlarmDays(['weekends']), [0, 6]);
      expect(parseAlarmDays('daily'), [0, 1, 2, 3, 4, 5, 6]);
      expect(parseAlarmDays([0, 6, 9]), [0, 6]);
      expect(parseAlarmDays(null), isEmpty);
      expect(parseAlarmDays('[]'), isEmpty);
    });
  });
}
