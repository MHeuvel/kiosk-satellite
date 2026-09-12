import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/analytics/analytics_scrub.dart';

/// docs/analytics.md: crash reports strip URLs, entity ids and file paths
/// before they leave the device. These pin the rules, and the one thing
/// they must not touch: the class names a stack trace is made of.
void main() {
  test('URLs, paths, addresses and entity ids are replaced', () {
    const trace = '''
E/flutter: Exception: failed to load https://home.example.com:8123/api/states
  at package:kiosk_satellite/managers/browser/browser_manager.dart:120
  file /data/user/0/me.jxl.kiosk_satellite/files/last_crash.txt missing
  connecting to 192.168.1.5:8123 for light.kitchen and sensor.front_door_temp
  mailto someone@example.com with Authorization: Bearer abc.def.ghi
  at me.jxl.kiosk_satellite.MainActivity.onCreate(MainActivity.kt:42)
''';
    final out = scrubDiagnostics(trace);
    expect(out, isNot(contains('home.example.com')));
    expect(out, isNot(contains('/data/user')));
    expect(out, isNot(contains('192.168.1.5')));
    expect(out, isNot(contains('light.kitchen')));
    expect(out, isNot(contains('front_door_temp')));
    expect(out, isNot(contains('someone@example.com')));
    expect(out, isNot(contains('abc.def.ghi')));
    expect(out, contains('<url>'));
    expect(out, contains('<path>'));
    expect(out, contains('<ip>'));
    expect(out, contains('<entity>'));
    expect(out, contains('<email>'));
    expect(out, contains('Authorization: <redacted>'));
    // What a crash report is for survives.
    expect(
      out,
      contains('package:kiosk_satellite/managers/browser/browser_manager.dart'),
    );
    expect(out, contains('me.jxl.kiosk_satellite.MainActivity.onCreate'));
    expect(out, contains('MainActivity.kt:42'));
  });

  test('a long trace keeps its head', () {
    final long = List.generate(2000, (i) => 'line $i').join('\n');
    final out = clipDiagnostics(long, max: 200);
    expect(out.length, lessThan(220));
    expect(out, startsWith('line 0'));
    expect(out, endsWith('<clipped>'));
    expect(clipDiagnostics('short'), 'short');
  });
}
