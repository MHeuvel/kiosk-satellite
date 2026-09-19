import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:kiosk_satellite/managers/sound/sound_manager.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getExternalStoragePath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late PathProviderPlatform oldPaths;
  late SoundManager sound;
  late SettingsManager settings;
  late EventBus bus;
  late CommandRegistry commands;
  final plays = <Map<dynamic, dynamic>>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('voice-chimes');
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(dir.path);
    SharedPreferences.setMockInitialValues({
      'ks.voice_chimes.alert': 'siren.mp3',
      'ks.voice_chimes.wake': 'missing.mp3',
      'ks.voice_chimes.error': 'broken.mp3',
    });
    await Directory('${dir.path}/sounds').create();
    await File('${dir.path}/sounds/siren.mp3').writeAsBytes([1]);
    await File('${dir.path}/sounds/broken.mp3').writeAsBytes([2]);
    plays.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('kiosk_satellite/sound'),
          (call) async {
            final args = (call.arguments as Map?) ?? {};
            if (call.method == 'duration') {
              final path = args['source'] as String;
              return path.endsWith('broken.mp3')
                  ? null
                  : path.endsWith('siren.mp3')
                  ? (File(path).lengthSync() == 1 ? 7.824 : 4.0)
                  : 0.63;
            }
            if (call.method == 'play') plays.add(args);
            return true;
          },
        );
    bus = EventBus();
    final log = Logger();
    commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    sound = SoundManager(bus, commands, log, settings: settings);
    await sound.init();
  });

  tearDown(() async {
    await sound.dispose();
    await settings.dispose();
    await bus.dispose();
    PathProviderPlatform.instance = oldPaths;
    await dir.delete(recursive: true);
  });

  test(
    'native timers and integration alerts use the same selected file',
    () async {
      expect((await commands.execute('playTimerChime', {})).ok, isTrue);
      expect(
        (await commands.execute('playSound', {
          'url': 'https://ha.test/voice_satellite/sounds/alert.mp3',
          'cache': true,
        })).ok,
        isTrue,
      );
      expect(
        plays.map((p) => p['source']),
        everyElement('${dir.path}/sounds/siren.mp3'),
      );
      expect(plays.map((p) => p['id']).toSet().length, 2);
    },
  );

  test(
    'missing and unreadable selections fall back to bundled defaults',
    () async {
      for (final kind in ['wake', 'error']) {
        final result = await commands.execute('previewVoiceChime', {
          'kind': kind,
        });
        expect(result.ok, isTrue);
        expect(
          await File(plays.last['source'] as String).readAsBytes(),
          await File('assets/sounds/voice-$kind.mp3').readAsBytes(),
        );
      }
    },
  );

  test(
    'duration metadata follows selected files and same-name replacement',
    () async {
      var result = await commands.execute('getVoiceChimeDurations', {});
      expect((result.data as Map)['alert.mp3'], 7.824);
      expect((result.data as Map).length, 5);
      await File('${dir.path}/sounds/siren.mp3').writeAsBytes([1, 2]);
      result = await commands.execute('getVoiceChimeDurations', {});
      expect((result.data as Map)['alert.mp3'], 4.0);
      await File('${dir.path}/sounds/siren.mp3').delete();
      result = await commands.execute('getVoiceChimeDurations', {});
      expect((result.data as Map)['alert.mp3'], 0.63);
    },
  );

  test('only the five canonical chime URLs select local sounds', () {
    expect(
      SoundManager.voiceChimeKind('/voice_satellite/sounds/wake.mp3?v=2'),
      'wake',
    );
    for (final url in [
      '/api/tts/wake.mp3',
      '/voice_satellite/sounds/my-siren.mp3',
      '/voice_satellite/sounds/alert.mp3/other',
    ]) {
      expect(SoundManager.voiceChimeKind(url), isNull);
    }
  });
}
