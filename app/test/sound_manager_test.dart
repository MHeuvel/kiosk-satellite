import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/sound/sound_manager.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TimerSoundPaths extends PathProviderPlatform {
  _TimerSoundPaths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

/// Volume is a native concern (the mixer model, issues #62/#69/#79): the
/// platform side composes master, media and assistant. This side must pass
/// sound volumes through untouched, or something gets scaled twice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CommandRegistry commands;
  final sent = <MethodCall>[];

  Future<void> build() async {
    sent.clear();
    final log = Logger();
    commands = CommandRegistry(log);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('kiosk_satellite/sound'),
          (call) async {
            sent.add(call);
            return true;
          },
        );
    final sound = SoundManager(EventBus(), commands, log);
    await sound.init();
  }

  test('the chime plays a file of its own at an absolute volume', () async {
    await build();
    // A real file: the resolver only asks that a device path exist, and a
    // path that does not falls through to the next candidate.
    final dir = await Directory.systemTemp.createTemp('ks_chime');
    final file = File('${dir.path}/bell.ogg');
    await file.writeAsBytes(const [0, 1, 2]);
    try {
      final r = await commands.execute('playChime', {
        'source': '${dir.path}/gone.ogg',
        'fallback': file.path,
        'volume': 0.4,
      });
      expect(r.ok, isTrue);
      final call = sent.singleWhere((c) => c.method == 'play');
      final args = call.arguments as Map;
      expect(args['source'], file.path);
      expect((args['volume'] as num).toDouble(), closeTo(0.4, 1e-9));
      // Outside the assistant fader: the notification has its own slider.
      expect(args['absolute'], isTrue);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test(
    'timer chime uses bundled Voice Satellite audio at assistant volume',
    () async {
      await build();
      final dir = await Directory.systemTemp.createTemp('ks_timer_sound');
      final oldPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TimerSoundPaths(dir.path);
      try {
        final result = await commands.execute('playTimerChime', const {});
        expect(result.ok, true);
        final args =
            sent.singleWhere((c) => c.method == 'play').arguments as Map;
        expect(args['id'], (result.data as Map)['id']);
        expect(args['volume'], 1.0);
        expect(args['absolute'], isNot(true));
        expect(
          await File(args['source'] as String).readAsBytes(),
          await File('assets/sounds/timer-alert.mp3').readAsBytes(),
        );
      } finally {
        PathProviderPlatform.instance = oldPaths;
        await dir.delete(recursive: true);
      }
    },
  );

  test('sound volumes pass through unscaled - native owns the mixer', () async {
    await build();
    final r = await commands.execute('setSoundVolume', {
      'id': 'snd1',
      'volume': 0.8,
    });
    expect(r.ok, isTrue);
    final call = sent.singleWhere((c) => c.method == 'setVolume');
    expect(
      ((call.arguments as Map)['volume'] as num).toDouble(),
      closeTo(0.8, 1e-9),
    );
  });
}
