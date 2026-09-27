import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Media Player page's Required system permissions group (issue #722):
/// Notification access, shown only while the Local Media Session is the
/// pick. Mirrored on the remote (panels.js, updateSessionPermissions).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sessions = MethodChannel('kiosk_satellite/media_sessions');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<AppContainer> open(
    WidgetTester tester,
    String pick, {
    bool granted = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'ks.sendspin.player_source': '',
      'ks.sendspin.player': pick,
    });
    messenger.setMockMethodCallHandler(sessions, (call) async {
      if (call.method == 'hasAccess') return granted;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(sessions, null));
    final container = AppContainer();
    await container.settings.init();
    tester.view.physicalSize = const Size(500, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(container: container)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Media Player').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    return container;
  }

  testWidgets('the Local Media Session shows the missing grant', (
    tester,
  ) async {
    await open(tester, 'session:*');
    expect(find.text('Local Media Session'), findsWidgets);
    expect(find.text('Required system permissions'), findsOneWidget);
    expect(find.text('Notification access'), findsOneWidget);
    expect(
      find.textContaining('Without this Android lists no media sessions'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Grant'), findsOneWidget);
  });

  testWidgets('a held grant has no button', (tester) async {
    await open(tester, 'session:*', granted: true);
    expect(find.text('Notification access'), findsOneWidget);
    expect(
      find.text('Now Playing can follow the apps playing on this device.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Grant'), findsNothing);
  });

  testWidgets('the Sendspin player needs no grant', (tester) async {
    await open(tester, '');
    expect(find.text('Sendspin Player'), findsWidgets);
    expect(find.text('Required system permissions'), findsNothing);
    expect(find.text('Notification access'), findsNothing);
  });
}
