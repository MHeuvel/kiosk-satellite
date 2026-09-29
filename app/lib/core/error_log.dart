import 'package:flutter/foundation.dart';

import 'logging.dart';

/// Routes Flutter framework errors and uncaught Dart errors into the app's
/// own log, where the Logs screen, the remote admin and the watchdog's
/// restart note look. Until now they only reached logcat, which a report
/// never carries: a WebView whose platform view failed to create left the
/// watchdog note with no line saying why.
///
/// Capped at [perMinute] entries a minute and never the same message twice
/// in a row, so a build loop cannot flood the 500-line ring buffer and push
/// out the lines that matter.
/// [onMissingWebView] fires when an error says the platform has no WebView
/// provider (Android's MissingWebViewPackageException), the one failure
/// that surfaces only as an uncaught platform-view error.
/// [onBrokenWebView] fires when the WebView creation threw Android's
/// AndroidRuntimeException wrapping an InvocationTargetException: a
/// provider that is installed but cannot start, mid-update or broken.
void installErrorLog(
  Logger log, {
  int perMinute = 20,
  void Function()? onMissingWebView,
  void Function()? onBrokenWebView,
}) {
  final previous = FlutterError.onError;
  var minute = -1;
  var count = 0;
  String? last;

  void note(String tag, String message) {
    if (message.contains('MissingWebViewPackageException')) {
      onMissingWebView?.call();
    } else if (message.contains('AndroidRuntimeException') &&
        message.contains('InvocationTargetException')) {
      onBrokenWebView?.call();
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    if (now != minute) {
      minute = now;
      count = 0;
    }
    if (message == last) return;
    if (++count > perMinute) return;
    last = message;
    log.error(tag, message);
  }

  FlutterError.onError = (details) {
    previous?.call(details);
    final frames = details.stack
        ?.toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(3)
        .join('\n');
    note(
      'flutter',
      '${details.exceptionAsString()}'
          '${details.library == null ? '' : ' (${details.library})'}'
          '${frames == null || frames.isEmpty ? '' : '\n$frames'}',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    final frames = stack
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(3)
        .join('\n');
    note('dart', '$error${frames.isEmpty ? '' : '\n$frames'}');
    // Not handled: the engine still prints it to logcat as before, and the
    // app keeps running as it always did after an uncaught async error.
    return false;
  };
}
