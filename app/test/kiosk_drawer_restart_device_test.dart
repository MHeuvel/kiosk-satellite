import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/ui/kiosk_drawer.dart';
import 'package:kiosk_satellite/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('Rubik')
      ..addFont(rootBundle.load('assets/fonts/Rubik.ttf'));
    await font.load();
  });

  testWidgets('Restart Device follows the restart support answer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = AppContainer();
    await container.settings.init();
    container.device.appVersion = 'test';
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await container.settings.dispose();
      await container.bus.dispose();
      await container.log.dispose();
    });
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> pumpDrawer({required bool restricted}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: KioskDrawer(
              container: container,
              onClose: () {},
              onSettings: () {},
              restricted: restricted,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    // No owner, no Shizuku: the entry stays out, Exit is where it was.
    await pumpDrawer(restricted: false);
    expect(find.text('Restart Device'), findsNothing);
    expect(find.text('Exit Application'), findsOneWidget);

    container.kiosk.rebootSupported.value = true;
    await pumpDrawer(restricted: false);
    expect(find.text('Restart Device'), findsOneWidget);
    expect(find.text('Exit Application'), findsOneWidget);

    // The confirm dialog stands between the tap and the reboot.
    await tester.tap(find.text('Restart Device'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Restart this device? Kiosk Satellite comes back when it boots.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Restart'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Quick-actions mode keeps every escape behind the exit gesture.
    await pumpDrawer(restricted: true);
    expect(find.text('Restart Device'), findsNothing);
    expect(find.text('Exit Application'), findsNothing);
  });
}
