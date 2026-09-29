import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/error_log.dart';
import 'package:kiosk_satellite/core/logging.dart';

/// Framework errors land in the app log, deduplicated and capped.
void main() {
  missingWebViewTests();
  brokenWebViewTests();
  test('a framework error is logged once per distinct message, capped', () {
    final log = Logger();
    final before = FlutterError.onError;
    installErrorLog(log, perMinute: 3);
    try {
      // Reporting goes to the previous handler too; flutter_test's own
      // handler would fail the test, so stand in for it.
      final seen = <String>[];
      FlutterError.onError = (details) => seen.add(details.exceptionAsString());
      installErrorLog(log, perMinute: 3);
      void report(String msg) => FlutterError.reportError(
        FlutterErrorDetails(exception: StateError(msg), library: 'webview'),
      );
      report('no WebView installed');
      report('no WebView installed');
      report('second');
      report('third');
      report('fourth');
      final lines = log.recent.where((e) => e.tag == 'flutter').toList();
      expect(lines.map((e) => e.message.split(' (').first), [
        'Bad state: no WebView installed',
        'Bad state: second',
        'Bad state: third',
      ]);
      expect(lines.first.message, contains('(webview)'));
      expect(lines.first.level, LogLevel.error);
      expect(seen, hasLength(5));
    } finally {
      FlutterError.onError = before;
    }
  });
}

/// A missing WebView provider surfaces only as an uncaught platform error;
/// the hook hands it to whoever can act on it.
void missingWebViewTests() {
  test('a MissingWebViewPackageException error fires the callback once', () {
    final log = Logger();
    final before = FlutterError.onError;
    var fired = 0;
    try {
      FlutterError.onError = (_) {};
      installErrorLog(log, onMissingWebView: () => fired++);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError(
            'PlatformException(error, android.webkit.WebViewFactory'
            r'$MissingWebViewPackageException: Failed to load WebView '
            'provider: No WebView installed, null, null)',
          ),
        ),
      );
      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('something else')),
      );
      expect(fired, 1);
    } finally {
      FlutterError.onError = before;
    }
  });
}

/// A provider that is installed but cannot start surfaces as Android's
/// runtime exception around an invocation failure; it goes to its own hook.
void brokenWebViewTests() {
  test(
    'an InvocationTargetException from the provider fires the broken hook',
    () {
      final log = Logger();
      final before = FlutterError.onError;
      var missing = 0;
      var broken = 0;
      try {
        FlutterError.onError = (_) {};
        installErrorLog(
          log,
          onMissingWebView: () => missing++,
          onBrokenWebView: () => broken++,
        );
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError(
              'PlatformException(error, java.lang.reflect.InvocationTargetException, '
              'null, android.util.AndroidRuntimeException: '
              'java.lang.reflect.InvocationTargetException ...)',
            ),
          ),
        );
        expect(broken, 1);
        expect(missing, 0);
      } finally {
        FlutterError.onError = before;
      }
    },
  );
}
