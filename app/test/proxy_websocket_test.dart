import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/proxy/proxy_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The secure context proxy's WebSocket leg. An add-on's ingress socket
/// (Music Assistant's web UI) is admitted on the ingress_session cookie the
/// frontend set; the bridge used to open the upstream socket bare, so Home
/// Assistant accepted the upgrade and dropped it at once, and the add-on's
/// client flapped between connected and reconnecting forever.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProxyManager proxy;
  late HttpServer upstream;

  /// Headers of the last upgrade request the upstream saw.
  HttpHeaders? seen;

  /// A Home Assistant stand-in: admits a socket only with a cookie, picks
  /// the last offered subprotocol so the echo can be told from the first,
  /// and echoes every message with a prefix.
  Future<void> startUpstream() async {
    upstream = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    upstream.listen((req) async {
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      seen = req.headers;
      if (req.headers.value('cookie') == null) {
        req.response.statusCode = HttpStatus.unauthorized;
        await req.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(
        req,
        protocolSelector: (offered) => offered.last,
      );
      ws.listen((m) {
        if (m == 'bye') {
          ws.close(4000, 'bye');
        } else {
          ws.add('echo:$m');
        }
      });
    });
  }

  setUp(() async {
    HttpOverrides.global = null;
    seen = null;
    await startUpstream();
    SharedPreferences.setMockInitialValues({
      'ks.browser.start_url': 'http://127.0.0.2:${upstream.port}/',
      'ks.browser.secure_proxy': true,
    });
    final bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    final settings = SettingsManager(bus, commands, log);
    await settings.init();
    proxy = ProxyManager(bus, commands, log, settings);
    await proxy.init();
    expect(proxy.running, isTrue);
  });

  tearDown(() async {
    await proxy.dispose();
    await upstream.close(force: true);
  });

  String wsPath() => 'ws://127.0.0.1:${proxy.port}/api/hassio_ingress/token/ws';

  test('the page cookie and subprotocol reach the upstream socket', () async {
    final page = await WebSocket.connect(
      wsPath(),
      protocols: ['first', 'second'],
      headers: {'cookie': 'ingress_session=abc'},
    );
    expect(seen?.value('cookie'), 'ingress_session=abc');
    expect(seen?['sec-websocket-protocol']?.join(','), contains('first'));
    expect(seen?['sec-websocket-protocol']?.join(','), contains('second'));
    // The loopback hop's own handshake fields are the bridge's, not the
    // page's: one key, one version, no doubled headers.
    expect(seen?['sec-websocket-key'], hasLength(1));
    expect(seen?['sec-websocket-version'], hasLength(1));
    expect(seen?.value('host'), isNot(startsWith('127.0.0.1')));
    // The upstream's pick is what the page is told.
    expect(page.protocol, 'second');

    page.add('ping');
    final reply = await page.first.timeout(const Duration(seconds: 5));
    expect(reply, 'echo:ping');
    await page.close();
  });

  test('a refused upstream handshake fails the page handshake', () async {
    // No cookie: the stand-in answers 401. The page must not get a socket
    // that opens and closes at once, the flap the add-on's client retried
    // forever; the upgrade itself is refused.
    await expectLater(
      WebSocket.connect(wsPath()),
      throwsA(isA<WebSocketException>()),
    );
    expect(seen, isNotNull);
    expect(seen?.value('cookie'), isNull);
  });

  test('a close propagates from upstream to the page with its code', () async {
    final page = await WebSocket.connect(
      wsPath(),
      headers: {'cookie': 'ingress_session=abc'},
    );
    final closed = Completer<void>();
    page.listen((_) {}, onDone: closed.complete);
    page.add('bye');
    await closed.future.timeout(const Duration(seconds: 5));
    expect(page.closeCode, 4000);
    expect(page.closeReason, 'bye');
  });
}
