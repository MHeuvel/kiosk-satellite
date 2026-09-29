import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/managers/screen/adaptive_brightness.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart';
import 'package:kiosk_satellite/ui/brightness_curve_editor.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The device settings mirror the remote admin's adaptive brightness rows
/// (issue #343): Default brightness stands down with the reason while the
/// switch is on, the screensaver's brightness sliders carry the
/// bright-room hint, the page shows the live reading, and a device without
/// the sensor gets a disabled switch with the reason.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owns = 'Adaptive brightness is on.';
  const hint =
      'Level in a bright room. Adaptive brightness dims it from there.';
  const noSensor = 'No ambient light sensor on this device.';

  Future<AppContainer> open(
    WidgetTester tester,
    Map<String, Object> prefs, {
    bool sensor = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'ks.ha.url': 'http://ha.local:8123',
      'ks.ha.token': 'token',
      'ks.screen.set_brightness_on_launch': true,
      'ks.screensaver.brightness_enabled': true,
      ...prefs,
    });
    final container = AppContainer();
    await container.settings.init();
    container.homeAssistant.connectionOk.value = true;
    container.device.hasLightSensor = sensor;
    container.device.lightLux = 12;
    // Tall enough that a page renders whole: off-screen rows do not exist.
    tester.view.physicalSize = const Size(500, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(container: container)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  Future<void> tab(WidgetTester tester, String title) async {
    await tester.tap(find.text(title).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('Default brightness stands down with the reason while the '
      'switch is on', (tester) async {
    await open(tester, {'ks.screen.adaptive_brightness': true});
    await tab(tester, 'Screen & Audio');
    expect(find.text('Default brightness'), findsOneWidget);
    expect(find.text(owns), findsOneWidget);
  });

  testWidgets('Default brightness is an ordinary slider with the switch off', (
    tester,
  ) async {
    await open(tester, {'ks.screen.adaptive_brightness': false});
    await tab(tester, 'Screen & Audio');
    expect(find.text('Default brightness'), findsOneWidget);
    expect(find.text(owns), findsNothing);
  });

  testWidgets('the screensaver brightness slider carries the bright-room '
      'hint while the switch is on', (tester) async {
    await open(tester, {'ks.screen.adaptive_brightness': true});
    await tab(tester, 'Screensaver');
    expect(find.text('Brightness level'), findsOneWidget);
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets('the Dim level carries it too, beside its own warning', (
    tester,
  ) async {
    await open(tester, {
      'ks.screen.adaptive_brightness': true,
      'ks.screensaver.mode': 'dim',
    });
    await tab(tester, 'Screensaver');
    expect(find.text('Dim level'), findsOneWidget);
    expect(find.text(hint), findsNWidgets(2));
  });

  testWidgets('no hints with the switch off', (tester) async {
    await open(tester, {'ks.screen.adaptive_brightness': false});
    await tab(tester, 'Screensaver');
    expect(find.text(hint), findsNothing);
  });

  testWidgets('a flip made elsewhere (the remote admin) refreshes the page', (
    tester,
  ) async {
    final container = await open(tester, {
      'ks.screen.adaptive_brightness': false,
    });
    await tab(tester, 'Screen & Audio');
    expect(find.text(owns), findsNothing);
    await container.settings.setFromJson(
      'screen.adaptive_brightness',
      true,
      source: 'remote admin',
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text(owns), findsOneWidget);
  });

  testWidgets('the page shows the live reading under the switch', (
    tester,
  ) async {
    await open(tester, {'ks.screen.adaptive_brightness': true});
    await tab(tester, 'Screen & Audio');
    await tab(tester, 'Adaptive brightness');
    expect(find.text('Ambient light'), findsOneWidget);
    expect(find.text('12 lx (last known)'), findsOneWidget);
  });

  // The curve editor (issue #742): the four settings rows are one chart
  // with a chip per point.
  testWidgets('the curve replaces the four rows, a chip per point', (
    tester,
  ) async {
    await open(tester, {
      'ks.screen.adaptive_brightness': true,
      'ks.screen.adaptive_dark_lux': 5,
      'ks.screen.adaptive_bright_lux': 300,
    });
    await tab(tester, 'Screen & Audio');
    await tab(tester, 'Adaptive brightness');
    expect(find.text('Brightness curve'), findsOneWidget);
    expect(find.byType(BrightnessCurveEditor), findsOneWidget);
    expect(find.text('Minimum brightness'), findsNothing);
    expect(find.text('Dark room (lx)'), findsNothing);
    // The ends as set, the middle on the straight line between them.
    expect(find.text('5 lx'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget);
    expect(find.text('300 lx'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('19.6 lx'), findsOneWidget);
    expect(find.text('37%'), findsOneWidget);
  });

  testWidgets('a chip opens its point for typed values and writes them', (
    tester,
  ) async {
    final container = await open(tester, {
      'ks.screen.adaptive_brightness': true,
    });
    await tab(tester, 'Screen & Audio');
    await tab(tester, 'Adaptive brightness');
    await tester.tap(find.text('19.6 lx'));
    await tester.pumpAndSettle();
    expect(find.text('Point 2'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '10');
    await tester.enterText(fields.at(1), '20');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Point 2'), findsNothing);
    final s = container.settings;
    expect(
      s.get(adaptivePoint2Position),
      closeTo(AdaptiveCurve.positionFor(10, 5, 300), 1e-6),
    );
    expect(
      s.get(adaptivePoint2Level),
      closeTo(AdaptiveCurve.shareFor(0.2, 0.15, 0.8), 1e-6),
    );
    // The ends stay where they were.
    expect(s.get(adaptiveDarkLux), 5);
    expect(s.get(adaptiveMaxBrightness), 0.8);
    expect(find.text('10 lx'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('a typed value past a neighbor is refused in the dialog', (
    tester,
  ) async {
    final container = await open(tester, {
      'ks.screen.adaptive_brightness': true,
    });
    await tab(tester, 'Screen & Audio');
    await tab(tester, 'Adaptive brightness');
    await tester.tap(find.text('19.6 lx'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '3');
    await tester.enterText(find.byType(TextField).at(1), '90');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a light level between 5 and 76.6 lx'), findsOne);
    expect(find.text('Enter a brightness from 15% to 58%'), findsOne);
    expect(find.text('Point 2'), findsOneWidget);
    expect(
      container.settings.get(adaptivePoint2Position),
      closeTo(1 / 3, 1e-9),
    );
  });

  testWidgets('dragging the top point down lowers Maximum brightness and the '
      'page does not scroll under it', (tester) async {
    final container = await open(tester, {
      'ks.screen.adaptive_brightness': true,
    });
    await tab(tester, 'Screen & Audio');
    await tab(tester, 'Adaptive brightness');
    final chart = find.descendant(
      of: find.byType(BrightnessCurveEditor),
      matching: find.byType(CustomPaint),
    );
    final box = tester.getRect(chart.first);
    // The narrow chart: 210 tall, plot 14 to 184, 40 in from the left and
    // 10 from the right, 1 to 1000 lx across.
    final x = box.left + 40 + log(300) / log(1000) * (box.width - 50);
    final y = box.top + 184 - 0.8 * 170;
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
    final before = scroll.position.pixels;
    await tester.dragFrom(Offset(x, y), const Offset(0, 34));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, before);
    expect(container.settings.get(adaptiveMaxBrightness), closeTo(0.6, 0.011));
    expect(container.settings.get(adaptiveBrightLux), 300);
  });

  testWidgets('without the sensor the switch is disabled with the reason, '
      'and Default brightness keeps working', (tester) async {
    await open(tester, {'ks.screen.adaptive_brightness': true}, sensor: false);
    await tab(tester, 'Screen & Audio');
    expect(find.text(owns), findsNothing);
    await tab(tester, 'Adaptive brightness');
    expect(find.text(noSensor), findsOneWidget);
  });
}
