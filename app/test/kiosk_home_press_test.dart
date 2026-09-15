import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/kiosk/kiosk_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A HOME intent on the already-front kiosk becomes a HomeKeyPressed
/// event, except while the screen is off (issue #553): a Meta Portal's
/// stock dream launches HOME on every sleep, and with the kiosk as the
/// home app that arrived as a HOME press a second after the kiosk's own
/// screenOff and relit the panel through the screensaver dismissal.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EventBus bus;
  late KioskManager kiosk;
  late List<HomeKeyPressed> presses;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    final settings = SettingsManager(bus, commands, log);
    await settings.init();
    kiosk = KioskManager(bus, commands, log, settings);
    await kiosk.init();
    presses = [];
    bus.on<HomeKeyPressed>().listen(presses.add);
  });

  tearDown(() => kiosk.dispose());

  test('a HOME press on a lit screen goes through', () async {
    kiosk.onHomePressed();
    await pumpEventQueue();
    expect(presses, hasLength(1));
  });

  test('a HOME intent while the screen is off is dropped', () async {
    bus.publish(const ScreenStateChanged(on: false, source: 'app'));
    await pumpEventQueue();
    kiosk.onHomePressed();
    await pumpEventQueue();
    expect(presses, isEmpty);
  });

  test('the gate lifts when the screen comes back', () async {
    bus.publish(const ScreenStateChanged(on: false, source: 'app'));
    await pumpEventQueue();
    kiosk.onHomePressed();
    bus.publish(const ScreenStateChanged(on: true));
    await pumpEventQueue();
    kiosk.onHomePressed();
    await pumpEventQueue();
    expect(presses, hasLength(1));
  });
}
