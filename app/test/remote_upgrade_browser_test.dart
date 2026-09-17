import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/remote/remote_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);
  test(
    'upgrade does not execute a cached unversioned settings module',
    () async {
      final available = await Process.run('python', [
        '-c',
        'import playwright',
      ]);
      if (available.exitCode != 0) {
        markTestSkipped('Python Playwright is required for this browser test');
        return;
      }
      // Reproduce the previous server's import stamping and immutable cache.
      // The browser keeps that cache when this server becomes the new build.
      final legacy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = legacy.port;
      SharedPreferences.setMockInitialValues({
        'ks.browser.start_url': 'http://ha.local/',
        'ks.remote.enabled': true,
        'ks.remote.password': 'secret',
        'ks.remote.port': port,
        'ks.ui.language': 'es',
      });
      final bus = EventBus();
      final log = Logger();
      final commands = CommandRegistry(log);
      final settings = SettingsManager(bus, commands, log);
      await settings.init();
      commands.register(
        Command(
          name: 'getDeviceInfo',
          description: 'test fixture',
          handler: (_) async => const CommandResult.ok({
            'name': 'Test kiosk',
            'appVersion': 'test',
            'buildNumber': 258,
          }),
        ),
      );
      commands.register(
        Command(
          name: 'getAudioDevices',
          description: 'test fixture',
          handler: (_) async =>
              const CommandResult.ok({'inputs': [], 'outputs': []}),
        ),
      );
      commands.register(
        Command(
          name: 'mediaPlayers',
          description: 'test fixture',
          handler: (_) async => const CommandResult.ok({'players': []}),
        ),
      );
      final remote = RemoteManager(bus, commands, log, settings);
      const oldVersion = '111111111111';
      var upgraded = false;
      legacy.listen((request) async {
        final path = request.uri.path;
        if (path == '/upgrade') {
          request.response.write('ok');
          await request.response.close();
          await legacy.close(force: true);
          await remote.init();
          upgraded = true;
          return;
        }
        if (path == '/api/setup/status') {
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"setupNeeded":false}');
        } else {
          final asset = path == '/' ? 'index.html' : path.substring(1);
          try {
            var source = await rootBundle.loadString('assets/remote-ui/$asset');
            request.response.headers.set(
              'cache-control',
              path == '/' ? 'no-store' : 'public, max-age=31536000, immutable',
            );
            if (path == '/') {
              request.response.headers.contentType = ContentType.html;
              source = source.replaceAll('__KSV__', oldVersion);
            } else if (path.endsWith('.js')) {
              request.response.headers.set('content-type', 'text/javascript');
              if (path.endsWith('/tabs.js') &&
                  !source.contains('import"./settings.js"')) {
                source = 'import"./settings.js";\n$source';
              }
              source = source.replaceAllMapped(
                RegExp(r"""(from\s*['"]\./[A-Za-z0-9._-]+\.js)(['"])"""),
                (m) => '${m[1]}?v=$oldVersion${m[2]}',
              );
            } else if (path.endsWith('.css')) {
              request.response.headers.set('content-type', 'text/css');
            }
            request.response.add(utf8.encode(source));
          } catch (_) {
            request.response.statusCode = 404;
          }
        }
        await request.response.close();
      });
      try {
        final result = await Process.run('python', [
          'test/remote_upgrade_ui_test.py',
          'http://127.0.0.1:$port',
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      } finally {
        if (!upgraded) await legacy.close(force: true);
        await remote.dispose();
        await settings.dispose();
        await bus.dispose();
        await log.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
