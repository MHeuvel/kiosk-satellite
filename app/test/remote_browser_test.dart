import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/tls_identity.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/remote/remote_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);
  test(
    'remote browser follows device settings without polling',
    () async {
      final available = await Process.run('python', [
        '-c',
        'import playwright',
      ]);
      if (available.exitCode != 0) {
        markTestSkipped('Python Playwright is required for this browser test');
        return;
      }
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      SharedPreferences.setMockInitialValues({
        'ks.browser.start_url': 'http://ha.local/',
        'ks.remote.enabled': true,
        'ks.remote.password': 'secret',
        'ks.remote.port': port,
        'ks.screensaver.enabled': true,
        'ks.camera.enabled': true,
        'ks.sendspin.player_source': 'ha',
        'ks.sendspin.player_active': true,
        'ks.sendspin.player': 'ha:media_player.first',
        'ks.sendspin.player_name': 'First speaker',
      });
      final bus = EventBus();
      final log = Logger();
      final commands = CommandRegistry(log);
      final settings = SettingsManager(bus, commands, log);
      await settings.init();
      commands.register(
        Command(
          name: 'testSlowCommand',
          description: '',
          handler: (_) async {
            await Future<void>.delayed(const Duration(seconds: 3));
            return const CommandResult.ok();
          },
        ),
      );
      var appVersion = '2026.9.58';
      commands.register(
        Command(
          name: 'getDeviceInfo',
          description: '',
          handler: (_) async => CommandResult.ok({
            'name': 'Test kiosk',
            'model': 'Test device',
            'battery': 90,
            'appVersion': appVersion,
            'buildNumber': 259,
          }),
        ),
      );
      // Stands in for the app restarting on a new build: the next state
      // snapshot names a version the page was not loaded against.
      commands.register(
        Command(
          name: 'testSetVersion',
          description: '',
          handler: (p) async {
            appVersion = p['version'] as String;
            return const CommandResult.ok();
          },
        ),
      );
      commands.register(
        Command(
          name: 'testSetSetting',
          description: '',
          handler: (p) async => CommandResult.ok(
            await settings.setFromJson(p['key'] as String, p['value']),
          ),
        ),
      );
      commands.register(
        Command(
          name: 'mediaPlayers',
          description: '',
          handler: (p) async => CommandResult.ok({
            'players': [
              for (final source in ['ha', 'ma', 'sonos'])
                for (final name in ['first', 'second'])
                  {
                    'group': source,
                    'id': '$source:media_player.$name',
                    'name': '${name == 'first' ? 'First' : 'Second'} speaker',
                  },
            ],
          }),
        ),
      );
      commands.register(
        Command(
          name: 'cameraGetConfig',
          description: '',
          handler: (_) async => const CommandResult.ok({
            'servers': [],
            'cameras': [],
            'views': [],
          }),
        ),
      );
      var audioConnected = false;
      commands.register(
        Command(
          name: 'getAudioDevices',
          description: '',
          handler: (_) async => CommandResult.ok({
            'inputs': [],
            'outputs': [
              if (audioConnected)
                {'selector': 'usb|1|USB Speaker', 'label': 'USB Speaker'},
            ],
            'micSelected': '',
            'speakerSelected': settings.get(defs.audioSpeakerDevice),
          }),
        ),
      );
      commands.register(
        Command(
          name: 'testAudioConnected',
          description: '',
          handler: (_) async {
            audioConnected = true;
            bus.publish(const AudioDevicesChanged(capturePathChanged: false));
            return const CommandResult.ok();
          },
        ),
      );
      commands.register(
        Command(
          name: 'sonosSpeakers',
          description: '',
          handler: (_) async {
            final hosts =
                jsonDecode(settings.get(defs.sendspinSonosHosts)) as Map;
            return CommandResult.ok([
              for (final entry in hosts.entries)
                {'id': entry.key, ...(entry.value as Map<String, dynamic>)},
            ]);
          },
        ),
      );
      final remote = RemoteManager(bus, commands, log, settings);
      await remote.init();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            TlsIdentity.channel,
            (_) async => {
              'certificate': File(
                'test/fixtures/tls/cert.pem',
              ).readAsStringSync(),
              'privateKey': File(
                'test/fixtures/tls/key.pem',
              ).readAsStringSync(),
              'notAfter': DateTime.utc(2036).millisecondsSinceEpoch,
            },
          );
      try {
        final result = await Process.run('python', [
          'test/remote_live_ui_test.py',
          'http://127.0.0.1:$port',
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(TlsIdentity.channel, null);
        await remote.dispose();
        await settings.dispose();
        await bus.dispose();
        await log.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
