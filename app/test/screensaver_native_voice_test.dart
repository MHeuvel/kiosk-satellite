import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/screensaver/screensaver_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EventBus bus;
  late ScreensaverManager saver;
  late List<double> levels;

  Future<void> build({required String runtime}) async {
    SharedPreferences.setMockInitialValues({
      'ks.screensaver.enabled': true,
      'ks.screensaver.mode': 'clock',
      'ks.screensaver.brightness_enabled': true,
      'ks.screensaver.brightness_level': 0.1,
      'ks.voice.runtime': runtime,
      'ks.voice.enabled': true,
    });
    bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    levels = [];
    commands
      ..register(
        Command(
          name: 'getBrightness',
          description: '',
          handler: (_) async => const CommandResult.ok(0.8),
        ),
      )
      ..register(
        Command(
          name: 'setBrightness',
          description: '',
          handler: (p) async {
            levels.add((p['level'] as num).toDouble());
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'screenOn',
          description: '',
          handler: (_) async => const CommandResult.ok(),
        ),
      );
    final settings = SettingsManager(bus, commands, log);
    await settings.init();
    saver = ScreensaverManager(bus, commands, log, settings);
    await saver.init();
    addTearDown(() async {
      await saver.dispose();
      await settings.dispose();
      await bus.dispose();
    });
    await saver.start();
    await pumpEventQueue();
    expect(levels.last, 0.1);
  }

  Future<void> nativeTurn(bool active) async {
    if (active) {
      bus.publish(
        const WakeWordDetected(model: 'ok_nabu', phrase: 'Okay Nabu'),
      );
    }
    bus.publish(
      VoiceInteractionChanged(
        active: active,
        reason: 'voice',
        source: InteractionSource.native,
      ),
    );
    bus.publish(AssistOverlayVisibility(active));
    await pumpEventQueue();
  }

  test('a native turn draws over the screensaver at full brightness', () async {
    await build(runtime: 'native');
    await nativeTurn(true);
    // Still up, paused, and lit to where it was before it dimmed.
    expect(saver.isActive, isTrue);
    expect(saver.renderPaused.value, isTrue);
    expect(levels.last, 0.8);
    await nativeTurn(false);
    expect(saver.isActive, isTrue);
    expect(saver.renderPaused.value, isFalse);
    expect(levels.last, 0.1);
  });

  test('the integration in the dashboard still dismisses it', () async {
    await build(runtime: 'dashboard');
    bus.publish(const WakeWordDetected(model: 'ok_nabu', phrase: 'Okay Nabu'));
    bus.publish(const VoiceInteractionChanged(active: true, reason: 'voice'));
    await pumpEventQueue();
    expect(saver.isActive, isFalse);
  });
}
