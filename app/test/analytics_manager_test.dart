import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/analytics/analytics_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kiosk Satellite Analytics, as docs/analytics.md promises it: a daily
/// snapshot with only the parts whose switches are on, one report per
/// distinct crash while Diagnostics is on, a random install id that goes
/// away with the last switch, and nothing at all otherwise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceInfo = {
    'manufacturer': 'Amazon',
    'model': 'Amazon KFONWI',
    'device': 'onyx',
    'board': 'mt8168',
    'abis': ['armeabi-v7a'],
    'osVersion': 'Android 11',
    'sdkInt': 30,
    'screenWidth': 1280,
    'ramTotal': 7 * 1024 * 1024 * 1024 + 600 * 1024 * 1024, // 7.6 GiB
    'screenHeight': 800,
    'screenDensity': 1.5,
    'appVersion': '2026.9.43',
    'buildNumber': '250',
    'buildMode': 'release',
    'name': 'KS Echo Show 8 Office',
    'ip': '192.168.1.70',
  };

  String crash = '';
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('kiosk_satellite/background'),
          (call) async => call.method == 'getLastCrash' ? crash : null,
        );
  });

  late EventBus bus;
  late CommandRegistry commands;
  late Logger log;
  late SettingsManager settings;
  late AnalyticsManager analytics;
  late List<http.Request> sent;
  late int status;
  late DateTime now;

  Future<void> build(
    Map<String, Object> initial, {
    Duration firstDelay = Duration.zero,
    Duration tickInterval = const Duration(days: 1),
  }) async {
    SharedPreferences.setMockInitialValues(initial);
    bus = EventBus();
    log = Logger();
    commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    commands.register(
      Command(
        name: 'getDeviceInfo',
        description: 'stub',
        handler: (_) async => const CommandResult.ok(deviceInfo),
      ),
    );
    commands.register(
      Command(
        name: 'getPluginState',
        description: 'stub',
        handler: (_) async => const CommandResult.ok({
          'enabled': true,
          'plugins': [
            {'id': 'a'},
            {'id': 'b'},
          ],
        }),
      ),
    );
    commands.register(
      Command(
        name: 'getWakeWordState',
        description: 'stub',
        handler: (_) async => const CommandResult.ok({
          'engine': 'vsWakeWord',
          'engineLabel': 'vsWakeWord',
          'released': false,
          'models': [
            {'id': 'ok_nova', 'wakeWord': 'Ok Nova'},
          ],
        }),
      ),
    );
    commands.register(
      Command(
        name: 'vsEngineState',
        description: 'stub',
        handler: (_) async => const CommandResult.ok({
          'config': {'skin': 'kiosk-satellite', 'theme_mode': 'auto'},
          'satellite': 'assist_satellite.office',
        }),
      ),
    );
    sent = [];
    status = 200;
    now = DateTime.utc(2026, 9, 12, 20);
    analytics = AnalyticsManager(
      bus,
      commands,
      log,
      settings,
      endpoint: 'https://analytics.test/v1/report',
      clientFactory: () => MockClient((req) async {
        sent.add(req);
        return http.Response('', status);
      }),
      firstDelay: firstDelay,
      tickInterval: tickInterval,
      now: () => now,
    );
    addTearDown(analytics.dispose);
    await analytics.init();
  }

  Map<String, Object?> bodyOf(http.Request r) =>
      jsonDecode(r.body) as Map<String, Object?>;

  Future<void> pump() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'the defaults send one snapshot with both parts, and then wait',
    () async {
      await build({});
      await pump();
      expect(sent, hasLength(1));
      final body = bodyOf(sent.single);
      expect(sent.single.url.toString(), 'https://analytics.test/v1/report');
      expect(
        sent.single.headers['content-type'],
        startsWith('application/json'),
      );
      expect(body['schema'], AnalyticsManager.schema);
      expect(body['kind'], 'snapshot');
      expect(body['install_id'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(body['install_id'], analytics.installId);
      expect((body['app'] as Map)['version'], '2026.9.43');
      final basic = body['basic'] as Map;
      expect(basic['model'], 'Amazon KFONWI');
      expect(basic['android'], 'Android 11');
      expect((basic['screen'] as Map)['width'], 1280);
      expect(basic['ram_gb'], 8.0);
      final usage = body['usage'] as Map;
      expect(usage['plugins'], 2);
      expect(usage['plugin_ids'], ['a', 'b']);
      expect(usage['fleet_role'], 'none');
      expect(usage['wake_word_engine'], 'vsWakeWord');
      expect(usage['wake_word'], 'Ok Nova');
      expect(usage['wake_word_2'], '');
      expect(usage['vs_skin'], 'kiosk-satellite');
      expect(analytics.lastSnapshot, now);
      // Not due again until a day has passed.
      expect(await analytics.sendSnapshot(), isFalse);
      now = now.add(const Duration(hours: 25));
      expect(await analytics.sendSnapshot(), isTrue);
      expect(sent, hasLength(2));
    },
  );

  test('memory rounds up to the nominal size in half gigabytes', () {
    const gib = 1024 * 1024 * 1024;
    expect(AnalyticsManager.nominalRamGb((1.4 * gib).round()), 1.5);
    expect(AnalyticsManager.nominalRamGb((1.9 * gib).round()), 2.0);
    expect(AnalyticsManager.nominalRamGb((3.6 * gib).round()), 4.0);
    expect(AnalyticsManager.nominalRamGb((5.6 * gib).round()), 6.0);
    expect(AnalyticsManager.nominalRamGb((11.4 * gib).round()), 12.0);
    expect(AnalyticsManager.nominalRamGb(0), isNull);
    expect(AnalyticsManager.nominalRamGb(null), isNull);
  });

  test('nothing in a report names the device, its network or its HA', () async {
    await build({
      'ks.ha.url': 'https://home.example.com:8123',
      'ks.device.name': 'Kitchen tablet',
    });
    await pump();
    final raw = sent.single.body;
    expect(raw, isNot(contains('example.com')));
    expect(raw, isNot(contains('Kitchen')));
    expect(raw, isNot(contains('192.168')));
    expect(raw, isNot(contains('Echo Show 8 Office')));
    expect(raw, isNot(contains('onyx')));
    // Usage is flags and picks only, plus one list of plugin ids: short
    // plain names, the same rule the receiver enforces.
    final usage = bodyOf(sent.single)['usage'] as Map;
    for (final entry in usage.entries) {
      final v = entry.value;
      if (entry.key == 'plugin_ids') {
        expect(v, isA<List>());
        for (final id in v as List) {
          expect(id, isA<String>());
          expect((id as String).length, lessThanOrEqualTo(64));
          expect(id, isNot(contains('://')));
        }
        continue;
      }
      expect(v is bool || v is num || v is String, isTrue, reason: '$v');
      if (v is String) expect(v, isNot(contains('://')));
    }
  });

  test('each switch gates its own part', () async {
    await build({'ks.analytics.usage': false});
    await pump();
    final body = bodyOf(sent.single);
    expect(body.containsKey('basic'), isTrue);
    expect(body.containsKey('usage'), isFalse);
  });

  test('with Basic and Usage off no snapshot goes out', () async {
    await build({'ks.analytics.basic': false, 'ks.analytics.usage': false});
    await pump();
    expect(sent, isEmpty);
    expect(await analytics.buildSnapshot(), isNull);
    expect(await analytics.sendSnapshot(force: true), isFalse);
  });

  test(
    'with every switch off there is no install id and nothing is sent',
    () async {
      await build({
        'ks.analytics.basic': false,
        'ks.analytics.usage': false,
        'ks.analytics.diagnostics': false,
        'ks.internal.analytics_install_id': 'deadbeefdeadbeefdeadbeefdeadbeef',
      });
      crash = 'FATAL EXCEPTION: main\njava.lang.RuntimeException: boom';
      await pump();
      expect(sent, isEmpty);
      expect(analytics.installId, isEmpty);
    },
  );

  test(
    'turning the last switch off forgets the id; on again mints a new one',
    () async {
      await build({});
      await pump();
      final first = analytics.installId;
      expect(first, isNotEmpty);
      await settings.set(defs.analyticsBasic, false);
      await settings.set(defs.analyticsUsage, false);
      await settings.set(defs.analyticsDiagnostics, false);
      await pump();
      expect(analytics.installId, isEmpty);
      expect(analytics.lastSnapshot, isNull);
      await settings.set(defs.analyticsUsage, true);
      await pump();
      expect(await analytics.sendSnapshot(), isTrue);
      expect(analytics.installId, isNotEmpty);
      expect(analytics.installId, isNot(first));
    },
  );

  test(
    'a recorded crash is reported once, scrubbed, while Diagnostics is on',
    () async {
      crash =
          'FATAL EXCEPTION: main\n'
          'java.lang.IllegalStateException: https://home.example.com/api down\n'
          '\tat me.jxl.kiosk_satellite.MainActivity.onCreate(MainActivity.kt:42)';
      await build({'ks.analytics.basic': false, 'ks.analytics.usage': false});
      await pump();
      expect(sent, hasLength(1));
      final body = bodyOf(sent.single);
      expect(body['kind'], 'crash');
      expect(body['install_id'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect((body['android'] as Map)['sdk'], 30);
      expect(body['crash'], contains('MainActivity.onCreate'));
      expect(body['crash'], contains('<url>'));
      expect(body['crash'], isNot(contains('example.com')));
      expect(body.containsKey('basic'), isFalse);
      // The journal still holds the same trace at the next tick: not again.
      expect(await analytics.sendCrashIfAny(), isFalse);
      expect(sent, hasLength(1));
      // A different crash is new.
      crash = 'FATAL EXCEPTION: main\njava.lang.RuntimeException: other';
      expect(await analytics.sendCrashIfAny(), isTrue);
      expect(sent, hasLength(2));
    },
  );

  test('deliberate restarts stay home; each real crash goes once, newest '
      'first, under the version that crashed', () async {
    crash = '''
\tat java.lang.reflect.Method.invoke(Native Method)

=== crash at 2026-09-08 15:32:33 (app 2026.9.30, thread main) ===
java.lang.RuntimeException: process restarted deliberately: restart requested (kiosk menu, remote admin or ESPHome)
\tat a7.jc.a(r8-map-id:23)

=== crash at 2026-09-09 09:00:00 (app 2026.9.35, thread main) ===
java.lang.NullPointerException: older
\tat me.jxl.kiosk_satellite.A.b(A.kt:1)

=== crash at 2026-09-09 10:00:00 (app 2026.9.35, thread main) ===
java.lang.RuntimeException: process restarted deliberately: the frame watchdog found the UI wedged (no frames for 30s)
\tat a7.jc.a(r8-map-id:23)

=== crash at 2026-09-10 08:01:02 (app 2026.9.41, thread main) ===
java.lang.IllegalStateException: WebView gone
\tat me.jxl.kiosk_satellite.MainActivity.onCreate(MainActivity.kt:42)
''';
    await build({'ks.analytics.basic': false, 'ks.analytics.usage': false});
    await pump();
    final kinds = sent.map((r) => bodyOf(r)['kind']).toList();
    expect(kinds, ['crash', 'crash', 'crash']);
    final first = bodyOf(sent[0]);
    final second = bodyOf(sent[1]);
    final third = bodyOf(sent[2]);
    expect(first['crash'], contains('WebView gone'));
    expect(first['cause'], 'exception');
    expect((first['app'] as Map)['version'], '2026.9.41');
    expect(first['recorded_at'], '2026-09-10 08:01:02');
    expect(second['cause'], 'watchdog');
    expect(second['crash'], contains('frame watchdog'));
    expect(third['crash'], contains('older'));
    expect((third['app'] as Map)['version'], '2026.9.35');
    for (final r in sent) {
      expect(r.body, isNot(contains('restart requested')));
      expect(r.body, isNot(contains('Method.invoke')));
    }
    // The same journal at the next tick: nothing new.
    expect(await analytics.sendCrashIfAny(), isFalse);
    expect(sent, hasLength(3));
  });

  test('Diagnostics off keeps a recorded crash on the device', () async {
    crash = 'FATAL EXCEPTION: main\njava.lang.RuntimeException: boom';
    await build({'ks.analytics.diagnostics': false});
    await pump();
    expect(sent.map((r) => bodyOf(r)['kind']), ['snapshot']);
  });

  test(
    'a refused snapshot is not marked sent, so the next tick retries',
    () async {
      await build({});
      status = 500;
      await pump();
      expect(sent, hasLength(1));
      expect(analytics.lastSnapshot, isNull);
      status = 200;
      expect(await analytics.sendSnapshot(), isTrue);
      expect(analytics.lastSnapshot, now);
    },
  );

  test('the report command shows what would go out', () async {
    await build({}, firstDelay: const Duration(days: 1));
    final r = await commands.execute('getAnalyticsReport', const {});
    final data = r.data as Map;
    expect(data['lastSnapshot'], isNull);
    expect((data['snapshot'] as Map)['kind'], 'snapshot');
    expect(sent, isEmpty);
  });

  tearDown(() => crash = '');
}
