import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/kiosk/kiosk_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The volume key routing flag the kiosk manager pushes to the native
/// side (issue #544): what the kiosk screen asked for, unless lockdown
/// is on, under which no key does anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lockChannel = MethodChannel('kiosk_satellite/kiosk_lock');
  final binding = TestDefaultBinaryMessengerBinding.instance;
  late List<MethodCall> calls;
  late SettingsManager settings;
  late KioskManager kiosk;

  Future<void> build(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(lockChannel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    kiosk = KioskManager(bus, commands, log, settings);
  }

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(lockChannel, null);
  });

  Object? lastPush() =>
      calls.lastWhere((c) => c.method == 'volumeKeys').arguments;

  test('pushes what the screen asked for', () async {
    await build({});
    await kiosk.setVolumeKeys(true);
    expect(lastPush(), isTrue);
    await kiosk.setVolumeKeys(false);
    expect(lastPush(), isFalse);
  });

  test('lockdown keeps the keys dead', () async {
    await build({'ks.lockdown.enabled': true});
    await kiosk.setVolumeKeys(true);
    expect(lastPush(), isFalse);
    await settings.set(defs.lockdownEnabled, false);
    await kiosk.setVolumeKeys(true);
    expect(lastPush(), isTrue);
  });
}
