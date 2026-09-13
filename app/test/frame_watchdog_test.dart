import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/frame_watchdog.dart';
import 'package:kiosk_satellite/core/logging.dart';

/// The note a watchdog restart leaves behind: a stable first line the
/// crash dashboard groups on, then the facts that separate a dead engine
/// from a platform view that never came.
void main() {
  LogEntry entry(String tag, String message, {int second = 0}) => LogEntry(
    DateTime.utc(2026, 9, 13, 12, 0, second),
    LogLevel.info,
    tag,
    message,
  );

  test('the first line is the group key and carries the watchdog marker', () {
    final note = describeWatchdogTrip(
      seconds: 30,
      framesDuringWait: 0,
      rebuildRequested: true,
      device: const {},
      impellerDisabled: false,
      legacyWebView: false,
      recentLog: const [],
    );
    final lines = note.split('\n');
    expect(
      lines.first,
      'the frame watchdog found no WebView for 30s while the app was in front',
    );
    expect(lines.first, contains('frame watchdog'));
    expect(note, contains('flutter frames drawn during the wait: 0'));
    expect(note, contains('webview rebuild requested first: yes'));
    expect(note, contains('webview: ? ?'));
    expect(note, contains('ram: ? free of ?, screen ?, uptime ?'));
  });

  test('device facts and the relevant log tail follow, capped', () {
    final log = <LogEntry>[
      for (var i = 0; i < 20; i++)
        entry('browser', 'browser line $i', second: i),
      entry('sendspin', 'unrelated', second: 30),
      entry('watchdog', 'strike 6/6: resumed with no WebView', second: 31),
      entry('kiosk', 'x' * 400, second: 32),
    ];
    final note = describeWatchdogTrip(
      seconds: 30,
      framesDuringWait: 180,
      rebuildRequested: false,
      device: const {
        'webviewPackage': 'com.google.android.webview',
        'webviewVersion': '128.0.6613.88',
        'ramFree': 120 * 1024 * 1024,
        'ramTotal': 2048 * 1024 * 1024,
        'screenOn': true,
        'uptime': {'app': 7800, 'network': 385.4},
      },
      impellerDisabled: true,
      legacyWebView: true,
      recentLog: log,
    );
    expect(note, contains('flutter frames drawn during the wait: 180'));
    expect(note, contains('webview: com.google.android.webview 128.0.6613.88'));
    expect(note, contains('renderer: impeller off, legacy webview on'));
    expect(
      note,
      contains(
        'ram: 120 MB free of 2048 MB, screen on, uptime app 7800s, network 385s',
      ),
    );
    expect(note, isNot(contains('unrelated')));
    expect(note, contains('12:00:31 watchdog: strike 6/6'));
    // Twelve lines at most, the newest ones.
    final tail = note.split('recent log:\n').last.split('\n');
    expect(tail, hasLength(12));
    expect(tail.first, contains('browser line 10'));
    // A long line is cut, never dropped.
    expect(tail.last, contains('kiosk: ${'x' * 160}'));
    expect(tail.last.length, lessThan(200));
  });
}
