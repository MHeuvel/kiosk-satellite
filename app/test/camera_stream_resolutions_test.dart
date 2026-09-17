import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/device_camera/camera_resolutions.dart';
import 'package:kiosk_satellite/managers/device_camera/device_camera_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const portal = ['320x240', '640x480', '1280x720'];
  const channel = MethodChannel('kiosk_satellite/camera');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late EventBus bus;
  late SettingsManager settings;
  late DeviceCameraManager camera;
  late CommandRegistry commands;
  late Future<List<String>> Function(String) probe;
  Map<String, Object>? capabilities;
  final requests = <Map>[];

  Future<void> settle() async {
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> start(String saved) async {
    SharedPreferences.setMockInitialValues({
      'ks.camera.rtsp.resolution': saved,
    });
    bus = EventBus();
    final log = Logger();
    commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    camera = DeviceCameraManager(bus, commands, log, settings);
    await camera.init();
    await settle();
  }

  setUp(() {
    probe = (_) async => portal;
    capabilities = null;
    requests.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'streamCapabilities') {
        requests.add(call.arguments as Map);
        if (capabilities != null) return capabilities;
        final sizes = await probe((call.arguments as Map)['camera'] as String);
        return {
          'withAnalysis': sizes,
          'withoutAnalysis': sizes,
          'encoderRejected': <String>[],
          'captureRejected': <String>[],
        };
      }
      return switch (call.method) {
        'hasCamera' => true,
        'facings' => ['front', 'back'],
        _ => null,
      };
    });
  });

  tearDown(() async {
    await camera.dispose();
    await settings.dispose();
    await bus.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  for (final (saved, expected) in [
    ('480', '640x480'),
    ('720', '1280x720'),
    ('1080', '1280x720'),
    ('1920x1080', '1280x720'),
    ('320x240', '320x240'),
  ]) {
    test('migrates $saved to $expected using the camera inventory', () async {
      await start(saved);
      expect(settings.get(cameraRtspResolution), expected);
      expect(settings.optionsFor(cameraRtspResolution), portal);
      expect(cameraRtspResolution.perDevice, true);
      final schema = settings.describe(keys: {cameraRtspResolution.key}).single;
      expect(schema['options'], portal);
      expect((schema['optionLabels'] as Map)['1280x720'], '1280 × 720');
      expect(schema['value'], expected);
      expect(settings.get(cameraSnapshotResolution), '480');
    });
  }

  test(
    'remote writes and old imports normalize without exposing preset choices',
    () async {
      await start('480');
      expect(await settings.setFromJson(cameraRtspResolution.key, '720'), true);
      await settle();
      expect(settings.get(cameraRtspResolution), '1280x720');
      expect(
        await settings.setFromJson(cameraRtspResolution.key, '320x240'),
        true,
      );
      await settle();
      expect(settings.get(cameraRtspResolution), '320x240');
      for (final invalid in [
        '0x720',
        '-1x480',
        '1280x0',
        '1280X720',
        '1080p',
        '',
      ]) {
        expect(
          await settings.setFromJson(cameraRtspResolution.key, invalid),
          false,
        );
      }
    },
  );

  test(
    'a stale camera probe cannot replace the newly selected camera',
    () async {
      await start('720');
      final stale = Completer<List<String>>();
      probe = (facing) =>
          facing == 'front' ? stale.future : Future.value(['1920x1080']);
      final pending = camera.refreshStreamResolutions();
      await settings.set(cameraDevice, 'back');
      await settle();
      expect(settings.optionsFor(cameraRtspResolution), ['1920x1080']);
      expect(settings.get(cameraRtspResolution), '1920x1080');
      stale.complete(portal);
      await pending;
      expect(settings.optionsFor(cameraRtspResolution), ['1920x1080']);
    },
  );

  test(
    'unavailable inventory preserves the saved size and retries on attachment',
    () async {
      probe = (_) async => throw PlatformException(code: 'detached');
      await start('1080');
      expect(settings.get(cameraRtspResolution), '1080');
      expect(settings.optionsFor(cameraRtspResolution), isEmpty);
      probe = (_) async => portal;
      bus.publish(const ActivityAttached());
      await settle();
      expect(settings.get(cameraRtspResolution), '1280x720');
    },
  );

  test(
    'empty inventory disables choices without inventing a resolution',
    () async {
      probe = (_) async => [];
      await start('1280x720');
      expect(settings.optionsFor(cameraRtspResolution), isEmpty);
      expect(settings.get(cameraRtspResolution), '1280x720');
      final events = <SettingOptionsChanged>[];
      final subscription = bus.on<SettingOptionsChanged>().listen(events.add);
      probe = (_) async => portal;
      final result = await commands.execute('getCameraStreamResolutions', {});
      await settle();
      expect(result.data, portal);
      expect(events.single.key, cameraRtspResolution.key);
      await camera.refreshStreamResolutions();
      await settle();
      expect(events, hasLength(1));
      await subscription.cancel();
    },
  );

  test(
    'dimension parsing preserves portrait and square camera modes',
    () async {
      await start('480');
      expect(cameraStreamResolution('720x1280'), (720, 1280));
      expect(cameraStreamResolution('1080x1080'), (1080, 1080));
      expect(
        closestCameraResolution('720x1280', ['1280x720', '720x1280']),
        '720x1280',
      );
    },
  );
  test('an imported size waits for the camera in the same backup', () async {
    probe = (facing) async =>
        facing == 'front' ? ['320x240'] : ['640x480', '1280x720'];
    await start('320x240');
    await settings.import({
      cameraRtspResolution.key: '1280x720',
      cameraDevice.key: 'back',
    });
    await settle();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(settings.get(cameraRtspResolution), '1280x720');
    expect(settings.optionsFor(cameraRtspResolution), ['640x480', '1280x720']);
  });
  test(
    'encoder exclusions appear below the picker and cannot be selected',
    () async {
      capabilities = {
        'withAnalysis': portal,
        'withoutAnalysis': portal,
        'encoderRejected': ['1280x960', '1600x896', '1600x1200'],
        'captureRejected': <String>[],
      };
      await start('1600x1200');
      expect(settings.get(cameraRtspResolution), '1280x720');
      expect(settings.optionsFor(cameraRtspResolution), portal);
      expect(settings.cameraResolutionNotice, contains('encoder cannot use'));
      expect(settings.cameraResolutionNotice, contains('1600 × 1200'));
      expect(settings.cameraResolutionNotice, isNot(contains('to also use')));
      final schema = settings.describe(keys: {cameraRtspResolution.key}).single;
      expect(schema['notice'], settings.cameraResolutionNotice);
      await settings.set(cameraRtspAnalysis, false);
      await settle();
      expect(settings.optionsFor(cameraRtspResolution), portal);
    },
  );

  test('higher sizes require an explicit analysis mode change', () async {
    capabilities = {
      'withAnalysis': portal,
      'withoutAnalysis': [...portal, '1920x1080'],
      'encoderRejected': <String>[],
      'captureRejected': <String>[],
    };
    await start('1280x720');
    expect(
      settings.cameraResolutionNotice,
      contains('Turn off Motion analysis'),
    );
    expect(settings.cameraResolutionNotice, contains('1920 × 1080'));
    expect(
      settings.optionsFor(cameraRtspResolution),
      isNot(contains('1920x1080')),
    );
    await settings.set(cameraRtspAnalysis, false);
    await settle();
    expect(settings.optionsFor(cameraRtspResolution), contains('1920x1080'));
    expect(
      settings.cameraResolutionNotice,
      contains('Snapshots use video frames'),
    );
    await settings.set(cameraRtspResolution, '1920x1080');
    await settle();
    expect(settings.get(cameraRtspResolution), '1920x1080');
    await settings.set(cameraRtspAnalysis, true);
    await settle();
    expect(settings.get(cameraRtspResolution), '1280x720');
    expect(settings.optionsFor(cameraRtspResolution), portal);
    expect(requests, hasLength(1));
  });

  test(
    'frame rate bitrate and snapshot size refresh native capabilities',
    () async {
      await start('720');
      await settings.set(cameraRtspFps, 30);
      await settle();
      expect(requests.last['fps'], 30);
      await settings.set(cameraRtspBitrate, 1500);
      await settle();
      expect(requests.last['bitrate'], 1500000);
      await settings.set(cameraSnapshotResolution, '1080');
      await settle();
      expect(requests.last['snapshotWidth'], 1440);
      expect(requests.last['snapshotHeight'], 1080);
      expect(requests, hasLength(4));
    },
  );

  test(
    'a pending probe for old encoder settings cannot replace current sizes',
    () async {
      await start('720');
      final old = Completer<List<String>>();
      probe = (_) => old.future;
      final pending = camera.refreshStreamResolutions();
      probe = (_) async => ['640x480'];
      await settings.set(cameraRtspFps, 30);
      await settle();
      expect(settings.optionsFor(cameraRtspResolution), ['640x480']);
      old.complete(portal);
      await pending;
      expect(settings.optionsFor(cameraRtspResolution), ['640x480']);
    },
  );
}
