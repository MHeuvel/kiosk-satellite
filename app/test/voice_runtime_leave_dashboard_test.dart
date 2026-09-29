import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/home_assistant/home_assistant_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A kiosk left on the dashboard runtime with the Voice Satellite
/// integration uninstalled (issue #753) had no way to native voice: the
/// page only offered to install the integration again. Home Assistant's own
/// 404 for the integration's script moves it to native; anything less
/// certain leaves it alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  late HttpServer server;
  late int status;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.statusCode =
          request.uri.path == '/voice_satellite/voice-satellite-card.js'
          ? status
          : 404;
      request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Future<SettingsManager> connect({String runtime = 'dashboard'}) async {
    SharedPreferences.setMockInitialValues({
      'ks.ha.url': 'http://127.0.0.1:${server.port}',
      'ks.ha.token': 'token',
      'ks.voice.runtime': runtime,
    });
    final bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    final settings = SettingsManager(bus, commands, log);
    await settings.init();
    final ha = HomeAssistantManager(bus, commands, log, settings);
    await ha.init();
    ha.connectionOk.value = true;
    // The check is a real request to the local server.
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (settings.get(defs.voiceRuntime) == 'native') break;
    }
    return settings;
  }

  test(
    'the integration gone: the kiosk runs Voice Satellite natively',
    () async {
      status = 404;
      final settings = await connect();
      expect(settings.get(defs.voiceRuntime), 'native');
      // Voice stays off until its owner turns it on.
      expect(settings.get(defs.voiceEnabled), isFalse);
    },
  );

  test('the integration installed: the dashboard runtime stays', () async {
    status = 200;
    final settings = await connect();
    expect(settings.get(defs.voiceRuntime), 'dashboard');
  });

  test('an unclear answer changes nothing', () async {
    status = 503;
    final settings = await connect();
    expect(settings.get(defs.voiceRuntime), 'dashboard');
  });
}
