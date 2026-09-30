import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/alarms/alarm_manager.dart';
import 'package:kiosk_satellite/managers/alarms/alarm_requests.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:kiosk_satellite/managers/voice/ha_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alarms asked for through the Kiosk Satellite alarms script: which kiosk
/// answers, and what each action does to the list and says back to the
/// LLM. 2026-10-02 is a Friday.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EventBus bus;
  AlarmManager? built;
  late AlarmManager alarms;
  late AlarmRequests requests;
  late SettingsManager settings;
  var now = DateTime(2026, 10, 2, 9);

  Future<void> build(
    List<Map<String, Object?>> list, {
    Map<String, Object> extra = const {},
    HaSocket? socket,
  }) async {
    SharedPreferences.setMockInitialValues({
      'ks.alarms.list': jsonEncode(list),
      'ks.device.name': 'Bedroom Kiosk',
      ...extra,
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
      haSocket: socket,
    );
    await alarms.init();
    requests = alarms.requests;
    await pumpEventQueue();
  }

  tearDown(() async {
    await built?.dispose();
    built = null;
  });

  group('who answers', () {
    test('the kiosk in a voice turn, and only while in it', () async {
      now = DateTime(2026, 10, 2, 9);
      await build([]);
      expect(requests.isForMe({'action': 'list'}), isFalse);
      bus.publish(
        const VoiceInteractionChanged(
          active: true,
          reason: 'voice',
          source: InteractionSource.native,
        ),
      );
      await pumpEventQueue();
      expect(requests.isForMe({'action': 'list'}), isTrue);
      bus.publish(
        const VoiceInteractionChanged(
          active: false,
          reason: 'voice',
          source: InteractionSource.native,
        ),
      );
      await pumpEventQueue();
      // A moment of grace for a runtime that reports the end first.
      expect(requests.isForMe({'action': 'list'}), isTrue);
      now = now.add(const Duration(seconds: 10));
      expect(requests.isForMe({'action': 'list'}), isFalse);
    });

    test('a timer or an announcement is not a conversation', () async {
      await build([]);
      bus.publish(
        const VoiceInteractionChanged(
          active: true,
          reason: 'timer',
          source: InteractionSource.native,
        ),
      );
      await pumpEventQueue();
      expect(requests.isForMe({'action': 'list'}), isFalse);
    });

    test('a named kiosk answers whatever it is doing', () async {
      await build([]);
      expect(requests.isForMe({'kiosk': 'bedroom'}), isTrue);
      expect(requests.isForMe({'kiosk': 'Bedroom Kiosk'}), isTrue);
      expect(requests.isForMe({'kiosk': 'kitchen'}), isFalse);
    });

    test('a request for another kiosk is not taken mid turn', () async {
      await build([]);
      bus.publish(
        const VoiceInteractionChanged(
          active: true,
          reason: 'voice',
          source: InteractionSource.page,
        ),
      );
      await pumpEventQueue();
      expect(requests.isForMe({'kiosk': 'kitchen'}), isFalse);
    });
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

  group('following requests', () {
    Future<_FakeSocket> follow({required bool admin}) async {
      final socket = _FakeSocket(admin: admin);
      await build(
        [],
        extra: {'ks.ha.url': 'http://ha.local:8123', 'ks.ha.token': 'token'},
        socket: socket,
      );
      return socket;
    }

    test('a non-admin token is never refused by Home Assistant', () async {
      final socket = await follow(admin: false);
      expect(socket.subscribes, 0);
      expect(socket.userChecks, 1);
    });

    test('an admin token listens for requests', () async {
      final socket = await follow(admin: true);
      expect(socket.subscribes, 1);
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

class _FakeSocket extends HaSocket {
  _FakeSocket({required this.admin})
    : super(baseUrl: () => '', token: () => '');

  final bool admin;
  int userChecks = 0;
  int subscribes = 0;

  @override
  bool get connected => true;

  @override
  Future<Object?> request(
    Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (command['type'] == 'auth/current_user') {
      userChecks++;
      return {'id': 'u', 'is_admin': admin};
    }
    return null;
  }

  @override
  Future<Future<void> Function()> subscribe(
    Map<String, Object?> command,
    void Function(Map<String, Object?> event) onEvent, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    subscribes++;
    return () async {};
  }

  @override
  Future<void> close() async {}
}
