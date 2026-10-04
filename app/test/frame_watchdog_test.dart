import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/frame_watchdog.dart';
import 'package:kiosk_satellite/core/logging.dart';

/// The note a watchdog restart leaves behind: a stable first line the
/// crash dashboard groups on, then the facts that separate a dead engine
/// from a platform view that never came.
void main() {
  foldedTailTests();
  pacedStrikeTests();
  renderWedgeTests();
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

/// Strikes are paced by the clock: a burst of probes answered together
/// after a platform stall must not count as thirty seconds of no WebView.
void pacedStrikeTests() {
  const five = Duration(seconds: 5);

  test('one strike per interval, whatever the probe count', () {
    expect(
      pacedStrike(
        strikes: 6,
        sinceFirst: const Duration(seconds: 2),
        interval: five,
      ),
      1,
    );
    expect(
      pacedStrike(
        strikes: 6,
        sinceFirst: const Duration(seconds: 16),
        interval: five,
      ),
      4,
    );
  });

  test('a steady cadence counts every probe', () {
    for (var n = 1; n <= 6; n++) {
      expect(
        pacedStrike(strikes: n, sinceFirst: five * (n - 1), interval: five),
        n,
      );
    }
  });

  test('a tick a few milliseconds early still counts', () {
    expect(
      pacedStrike(
        strikes: 2,
        sinceFirst: const Duration(milliseconds: 4998),
        interval: five,
      ),
      2,
    );
  });

  test('a late probe never counts more than once', () {
    expect(
      pacedStrike(
        strikes: 2,
        sinceFirst: const Duration(seconds: 40),
        interval: five,
      ),
      2,
    );
  });
}

/// A line repeating fills a twelve-line tail with itself; folded, the tail
/// keeps the lines around it and says how often it repeated.
void foldedTailTests() {
  LogEntry entry(String tag, String message, {int second = 0}) => LogEntry(
    DateTime.utc(2026, 9, 21, 12, 0, second),
    LogLevel.info,
    tag,
    message,
  );
  test('a repeating line folds into one entry with its count', () {
    final note = describeWatchdogTrip(
      seconds: 30,
      framesDuringWait: 400,
      rebuildRequested: true,
      device: const {},
      impellerDisabled: false,
      legacyWebView: false,
      recentLog: [
        entry('browser', 'loaded <url>', second: 1),
        for (var i = 2; i < 40; i++)
          entry('device', 'activity attached (HomeAlias)', second: i),
        entry('watchdog', 'strike 6/6: resumed with no WebView', second: 40),
      ],
    );
    expect(note, contains('12:00:01 browser: loaded <url>'));
    expect(note, contains('device: activity attached (HomeAlias) (x38)'));
    expect(note, contains('12:00:40 watchdog: strike 6/6'));
    expect('activity attached'.allMatches(note), hasLength(1));
  });
}

/// The render wedge (issue #830): a context on the main thread while the
/// raster thread keeps waking up. Readings from an Echo Show 8 (Impeller
/// on OpenGL ES): the dashboard holds the context on the main thread with
/// zero raster wakes, a screensaver leaves the main thread clear with
/// hundreds.
void renderWedgeTests() {
  test('no context on the main thread is clear, whatever the raster does', () {
    expect(
      readRenderProbe(mainContext: false, switches: 1800, previous: 0),
      RenderProbe.clear,
    );
  });

  test('a merged frame loop leaves the raster thread asleep', () {
    expect(
      readRenderProbe(mainContext: true, switches: 500, previous: 500),
      RenderProbe.quiet,
    );
  });

  test('the raster thread waking up behind a held context is locked out', () {
    expect(
      readRenderProbe(mainContext: true, switches: 520, previous: 500),
      RenderProbe.lockedOut,
    );
  });

  test('a stray wakeup or two is not a wedge', () {
    expect(
      readRenderProbe(mainContext: true, switches: 502, previous: 500),
      RenderProbe.quiet,
    );
    expect(
      readRenderProbe(
        mainContext: true,
        switches: 501,
        previous: 500,
        minWakes: 1,
      ),
      RenderProbe.lockedOut,
    );
  });

  test('no baseline or an unreadable thread never strikes', () {
    expect(
      readRenderProbe(mainContext: true, switches: 900, previous: null),
      RenderProbe.quiet,
    );
    expect(
      readRenderProbe(mainContext: true, switches: -1, previous: 500),
      RenderProbe.quiet,
    );
    expect(
      readRenderProbe(mainContext: true, switches: 900, previous: -1),
      RenderProbe.quiet,
    );
  });

  test('the restart note groups as a watchdog restart of its own', () {
    final note = describeRenderWedge(
      seconds: 15,
      impellerDisabled: false,
      recentLog: [
        LogEntry(
          DateTime.utc(2026, 10, 3, 21, 35, 14),
          LogLevel.info,
          'browser',
          'rendering resumed',
        ),
        LogEntry(
          DateTime.utc(2026, 10, 3, 21, 35, 15),
          LogLevel.info,
          'command',
          'getBrightness [esphome]',
        ),
      ],
    );
    final lines = note.split('\n');
    expect(
      lines.first,
      'the frame watchdog found Flutter locked out of its EGL context for '
      '15s (held by the main thread)',
    );
    expect(lines.first, contains('frame watchdog'));
    expect(note, contains('renderer: impeller on'));
    expect(note, contains('21:35:14 browser: rendering resumed'));
    expect(note, isNot(contains('getBrightness')));
  });
}
