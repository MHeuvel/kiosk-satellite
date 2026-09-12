import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/screensaver/screensaver_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A dpad press driving the menu or the settings restarts the idle clock
/// without the dismissal side of an activity ping (issue #377).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EventBus bus;
  late ScreensaverManager saver;
  late SettingsManager settings;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ks.screensaver.enabled': true,
      'ks.screensaver.mode': 'black',
      'ks.screensaver.timeout_seconds': 60,
    });
    bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    saver = ScreensaverManager(bus, commands, log, settings);
    now = DateTime(2026, 9, 12, 12);
    saver.clock = () => now;
    await saver.init();
    addTearDown(() async {
      await saver.dispose();
      await settings.dispose();
      await bus.dispose();
    });
  });

  test('extendIdle pushes the idle deadline out from now', () async {
    saver.notifyActivity('touch');
    final first = saver.idleDue;
    expect(first, now.add(const Duration(seconds: 60)));
    now = now.add(const Duration(seconds: 30));
    saver.extendIdle();
    expect(saver.idleDue, now.add(const Duration(seconds: 60)));
    expect(saver.isActive, isFalse);
  });

  test('extendIdle leaves a running screensaver alone', () async {
    saver.notifyActivity('touch');
    await saver.start();
    expect(saver.isActive, isTrue);
    final due = saver.idleDue;
    now = now.add(const Duration(seconds: 30));
    saver.extendIdle();
    expect(saver.isActive, isTrue);
    expect(saver.idleDue, due);
  });
}
