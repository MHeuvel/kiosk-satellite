import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/browser/browser_manager.dart';
import 'package:kiosk_satellite/managers/home_assistant/home_assistant_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Go to dashboard with view rotation on (issue #719): loadStartUrl has no
/// touch behind it, so it must hold rotation for the pause window the same
/// way the Dashboard view select does. Otherwise the next tick navigates
/// straight back off the start page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CommandRegistry commands;
  late Logger log;

  Future<void> build() async {
    SharedPreferences.setMockInitialValues({
      'ks.ha.url': 'http://ha.test:8123',
      'ks.ha.token': 'token',
      'ks.browser.start_url': 'http://ha.test:8123/lovelace/home',
      'ks.ha.rotation_enabled': true,
      'ks.ha.rotation_dashboards': '["lovelace/kitchen","lovelace/bath"]',
      'ks.ha.rotation_seconds': 5,
      'ks.ha.rotation_pause_seconds': 30,
    });
    final bus = EventBus();
    log = Logger();
    commands = CommandRegistry(log);
    final settings = SettingsManager(bus, commands, log);
    await settings.init();
    await BrowserManager(bus, commands, log, settings).init();
    await HomeAssistantManager(bus, commands, log, settings).init();
  }

  // Each rotation step pushes a view through evalJs. No page is attached,
  // so the command log is where the attempts show up.
  Iterable<String> navigations() => log.recent
      .where((e) => e.tag == 'command')
      .map((e) => e.message)
      .where((m) => m.startsWith('evalJs') && m.contains('history.pushState'));

  Iterable<String> rotationLog() =>
      log.recent.where((e) => e.tag == 'home_assistant').map((e) => e.message);

  test('loadStartUrl holds rotation for the pause window', () {
    fakeAsync((async) {
      unawaited(build());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      unawaited(commands.execute('loadStartUrl', const {}));
      async.flushMicrotasks();
      expect(rotationLog(), contains('rotation paused by touch (30s)'));
      // Well past the 5 second dwell: the start page stays up.
      async.elapse(const Duration(seconds: 29));
      expect(navigations(), isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(rotationLog(), contains('rotation resumed'));
      async.elapse(const Duration(seconds: 5));
      expect(navigations(), hasLength(1));
    });
  });

  test('without a Go to dashboard press the ring keeps turning', () {
    fakeAsync((async) {
      unawaited(build());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 11));
      expect(navigations(), hasLength(2));
      expect(rotationLog(), isNot(contains(startsWith('rotation paused'))));
    });
  });
}
