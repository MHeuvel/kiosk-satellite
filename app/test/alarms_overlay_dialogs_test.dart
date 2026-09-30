import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/ui/alarms_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A dialog opened from the alarm screens sits on the root navigator, over
/// the overlay. When something else closes the overlay (the remote, Home
/// Assistant, the screensaver, a ring), the dialog goes with it instead of
/// staying on screen alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The list ticks with the clock, so it never settles for good.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('closing the alarm list from elsewhere closes its dialog', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ks.alarms.list': jsonEncode([
        {
          'id': 'a',
          'time': '07:00',
          'days': [1, 2, 3, 4, 5],
          'label': 'Gym',
          'speak': true,
          'on': true,
        },
      ]),
    });
    final container = AppContainer();
    // Real storage and timers: outside the test's fake clock.
    await tester.runAsync(() async {
      await container.settings.init();
      await container.alarms.init();
    });
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: Scaffold(
          body: Stack(children: [AlarmsOverlay(container: container)]),
        ),
      ),
    );
    container.alarms.visible.value = true;
    await settle(tester);

    await tester.tap(find.textContaining('Gym').first);
    await settle(tester);
    await tester.tap(find.text('Phrase'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);

    container.alarms.visible.value = false;
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Phrase'), findsNothing);
    await tester.runAsync(container.alarms.dispose);
  });
}
