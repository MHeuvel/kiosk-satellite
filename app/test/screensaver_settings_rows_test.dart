import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('screen-off controls keep their position and permission state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ks.screensaver.screen_off_minutes': 5,
    });
    final container = AppContainer();
    await container.settings.init();
    const channel = MethodChannel('kiosk_satellite/background');
    var permissionReads = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'isScreenOffAvailable') {
        permissionReads++;
        return false;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CategorySettingsScreen(
          container: container,
          category: 'Screensaver',
          title: 'Screensaver',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.text(defs.screensaverScreenOffBlack.title);
    final notice = find.text('Not granted, so the screen cannot turn off.');
    expect(toggle, findsOneWidget);
    expect(notice, findsOneWidget);
    final toggleY = tester.getTopLeft(toggle).dy;
    expect(tester.getTopLeft(notice).dy, greaterThan(toggleY));
    final initialReads = permissionReads;
    for (final enabled in [true, false, true, false]) {
      await container.settings.set(defs.screensaverScreenOffBlack, enabled);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(toggle).dy, toggleY);
      expect(notice, enabled ? findsNothing : findsOneWidget);
      expect(permissionReads, initialReads);
    }
    await container.settings.set(defs.screensaverScreenOffMinutes, 10);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(toggle).dy, toggleY);
    expect(permissionReads, initialReads);
    await container.settings.set(defs.screensaverScreenOffMinutes, 0);
    await tester.pumpAndSettle();
    expect(toggle, findsNothing);
    expect(notice, findsOneWidget);
    await container.settings.set(defs.screensaverScreenOffMinutes, 5);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(toggle).dy, toggleY);
    expect(permissionReads, initialReads);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the dashboard view row follows the mode and saves a pick', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'ks.screensaver.mode': 'black'});
    final container = AppContainer();
    await container.settings.init();
    container.commands
      ..register(
        Command(
          name: 'haListDashboards',
          description: 'stub',
          handler: (_) async => const CommandResult.ok([
            {'url_path': 'wall', 'title': 'Wall'},
          ]),
        ),
      )
      ..register(
        Command(
          name: 'haListDashboardViews',
          description: 'stub',
          handler: (_) async => const CommandResult.ok([
            {'title': 'Clock', 'route': 'clock'},
            {'title': 'Weather', 'route': 'weather'},
          ]),
        ),
      );
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CategorySettingsScreen(
          container: container,
          category: 'Screensaver',
          title: 'Screensaver',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.text(defs.screensaverDashboardView.title);
    expect(row, findsNothing);
    await container.settings.set(defs.screensaverMode, 'dashboard');
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
    // In its own group, under the heading the other modes' groups use.
    final heading = find.text('Home Assistant Dashboard screensaver');
    expect(heading, findsOneWidget);
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(tester.getTopLeft(heading).dy),
    );
    await tester.tap(find.text('Select dashboard'));
    await tester.pumpAndSettle();
    // The kit's radio picker, each view over its navigation path.
    expect(find.byType(RadioListTile<String>), findsNWidgets(2));
    expect(find.text('Wall / Clock'), findsOneWidget);
    expect(find.text('wall/clock'), findsOneWidget);
    await tester.tap(find.text('Wall / Weather'));
    await tester.pumpAndSettle();
    expect(
      container.settings.get(defs.screensaverDashboardView),
      'wall/weather',
    );
    expect(find.text('wall/weather'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
