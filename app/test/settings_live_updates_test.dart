import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device Media Player follows remote setting writes', (
    tester,
  ) async {
    final port = await tester.runAsync(() async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      return port;
    });
    SharedPreferences.setMockInitialValues({
      'ks.sendspin.player_active': true,
      'ks.browser.start_url': 'http://ha.local/',
      'ks.remote.enabled': true,
      'ks.remote.password': 'secret',
      'ks.remote.port': port!,
    });
    final container = AppContainer();
    await container.settings.init();
    late WebSocket socket;
    late Stream<Map> messages;
    final httpOverrides = HttpOverrides.current;
    await tester.runAsync(() async {
      HttpOverrides.global = null;
      await container.remote.init();
      final client = HttpClient();
      final request = await client.post('127.0.0.1', port, '/api/login');
      request.write(jsonEncode({'password': 'secret'}));
      final response = await request.close();
      final token =
          (jsonDecode(await utf8.decodeStream(response)) as Map)['token'];
      client.close();
      socket = await WebSocket.connect(
        'ws://127.0.0.1:$port/api/ws?token=$token',
      );
      messages = socket
          .map((raw) => jsonDecode(raw as String) as Map)
          .asBroadcastStream();
      messages.listen((_) {});
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await socket.close();
        await container.remote.dispose();
        await container.settings.dispose();
        await container.bus.dispose();
        await container.log.dispose();
        HttpOverrides.global = httpOverrides;
      });
    });
    var requestId = 0;
    Future<void> writeRemote(String key, Object value) async {
      await tester.runAsync(() async {
        final id = ++requestId;
        final reply = messages.firstWhere(
          (message) => message['type'] == 'result' && message['id'] == id,
        );
        socket.add(
          jsonEncode({
            'type': 'settings',
            'id': id,
            'values': {key: value},
          }),
        );
        expect((await reply.timeout(const Duration(seconds: 5)))['ok'], isTrue);
      });
      await tester.pump();
      await tester.pump();
    }

    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CategorySettingsScreen(
          container: container,
          category: 'Sendspin',
          title: 'Media Player',
        ),
      ),
    );
    await tester.pump();
    Finder duckLabel(String value) => find.descendant(
      of: find.widgetWithText(ListTile, sendspinDuckPercent.title),
      matching: find.text(value),
    );
    expect(duckLabel('10%'), findsOneWidget);
    await writeRemote(sendspinDuckPercent.key, 20);
    expect(container.settings.get(sendspinDuckPercent), 20);
    expect(duckLabel('20%'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: SubpageSettingsScreen(
          container: container,
          category: 'Sendspin',
          subpage: 'Now Playing',
        ),
      ),
    );
    await tester.pump();
    expect(find.text(sendspinFullscreenTextScale.title), findsNothing);
    await writeRemote(sendspinFullscreen.key, true);
    expect(find.text(sendspinFullscreenTextScale.title), findsOneWidget);
    await writeRemote(sendspinFullscreenTextScale.key, 150);
    expect(find.text('150%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
