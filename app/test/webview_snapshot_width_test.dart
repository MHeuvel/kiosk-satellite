import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/browser/webview_snapshot_width.dart';

void main() {
  test('converts the physical width to logical pixels', () {
    expect(
      webViewSnapshotWidth(
        width: 1080,
        physicalWidth: 1080,
        devicePixelRatio: 3,
      ),
      360,
    );
  });

  test('never asks for more than the screen holds', () {
    // The ESPHome camera asks for 1920 in landscape; on a 1080-wide phone
    // that must not become a 5760-pixel upscale.
    expect(
      webViewSnapshotWidth(
        width: 1920,
        physicalWidth: 1080,
        devicePixelRatio: 3,
      ),
      360,
    );
  });

  test('scales down when asked for less', () {
    expect(
      webViewSnapshotWidth(
        width: 640,
        physicalWidth: 1280,
        devicePixelRatio: 2,
      ),
      320,
    );
  });

  test('leaves the capture unscaled without a usable answer', () {
    expect(
      webViewSnapshotWidth(width: 0, physicalWidth: 1080, devicePixelRatio: 3),
      isNull,
    );
    expect(
      webViewSnapshotWidth(width: 800, physicalWidth: 0, devicePixelRatio: 0),
      isNull,
    );
  });
}
