import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/managers/device_camera/camera_resolutions.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('streaming page keeps the resolution notice below its select', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'ks.camera.enabled': true,
      'ks.camera.rtsp.enabled': true,
    });
    final container = AppContainer();
    await container.settings.init();
    const channel = MethodChannel('kiosk_satellite/camera');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => switch (call.method) {
        'hasCamera' => true,
        'facings' => ['front'],
        'streamCapabilities' => {
          'withAnalysis': ['640x480'],
          'withoutAnalysis': ['640x480', '1920x1080'],
          'encoderRejected': <String>[],
          'captureRejected': <String>[],
        },
        _ => null,
      },
    );
    container.settings.updateCameraStreamingCapabilities(
      CameraStreamingCapabilities.fromJson({
        'withAnalysis': ['640x480'],
        'withoutAnalysis': ['640x480', '1920x1080'],
        'encoderRejected': <String>[],
        'captureRejected': <String>[],
      }),
    );
    tester.view.physicalSize = const Size(1100, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SubpageSettingsScreen(
          container: container,
          category: 'Camera',
          subpage: 'RTSP & ONVIF Streaming',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final notice = find.text(container.settings.cameraResolutionNotice);
    expect(notice, findsOneWidget);
    expect(
      tester.getTopLeft(notice).dy,
      greaterThan(tester.getBottomLeft(find.text('Resolution')).dy),
    );
    expect(
      tester.getBottomLeft(notice).dy,
      lessThan(tester.getTopLeft(find.text(cameraRtspAnalysis.title)).dy),
    );
    await tester.pumpWidget(const SizedBox());
    messenger.setMockMethodCallHandler(channel, null);
    await container.deviceCamera.dispose();
    await container.settings.dispose();
    await container.bus.dispose();
    await container.log.dispose();
  });
}
