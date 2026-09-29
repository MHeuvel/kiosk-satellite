import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/browser/browser_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A WebView provider that is installed but fails to start gets the same
/// stand-down as a missing one, and then a retry: the flag clears after
/// the wait and the kiosk screen is told to build the WebView again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BrowserManager browser;
  late EventBus bus;
  late Logger log;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ks.browser.start_url': 'http://192.168.1.10:8123/lovelace/home',
    });
    bus = EventBus();
    log = Logger();
    final commands = CommandRegistry(log);
    final settings = SettingsManager(bus, commands, log);
    await settings.init();
    browser = BrowserManager(bus, commands, log, settings);
  });

  test('a failed provider stands the dashboard down, then retries', () async {
    final events = <WebViewMissing>[];
    bus.on<WebViewMissing>().listen(events.add);
    browser.markWebViewBroken(
      'InvocationTargetException',
      retryAfter: const Duration(milliseconds: 50),
    );
    expect(browser.webViewMissing, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(events, hasLength(1));
    expect(
      log.recent.map((e) => e.message),
      contains(contains('trying again in 0 minutes')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(browser.webViewMissing, isFalse);
    expect(events, hasLength(2));
    expect(
      log.recent.map((e) => e.message),
      contains(contains('retrying the WebView')),
    );
  });

  test(
    'a second failure during the wait does not stack a second retry',
    () async {
      var events = 0;
      bus.on<WebViewMissing>().listen((_) => events++);
      browser.markWebViewBroken(
        'x',
        retryAfter: const Duration(milliseconds: 50),
      );
      browser.markWebViewBroken(
        'x',
        retryAfter: const Duration(milliseconds: 50),
      );
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(events, 2);
      expect(browser.webViewMissing, isFalse);
    },
  );

  test('a missing provider is final: no retry is scheduled', () async {
    var events = 0;
    bus.on<WebViewMissing>().listen((_) => events++);
    browser.markWebViewMissing('no package');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(browser.webViewMissing, isTrue);
    expect(events, 1);
  });
}
