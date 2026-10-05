import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/dlna/dlna_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue #847: foobar2000 cannot take an event notify while one of its own
/// requests is still open. The renderer used to hold its SOAP reply until
/// the notify was delivered, so each side waited on the other until the
/// controller gave up. No test binding here: it would mock out real HTTP.
void main() {
  late DlnaManager dlna;
  late HttpServer callback;
  late HttpClient client;
  late int port;

  /// Open while the controller has a request out. Notifies arriving then
  /// wait for it to close, like a controller with one worker thread.
  var busy = Completer<void>()..complete();

  setUp(() async {
    final probe = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    port = probe.port;
    await probe.close();
    SharedPreferences.setMockInitialValues({});
    final bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log)
      ..register(
        Command(
          name: 'getDeviceInfo',
          description: 'test',
          handler: (_) async => CommandResult.ok({'appVersion': '0.0.0'}),
        ),
      );
    final settings = SettingsManager(bus, commands, log);
    await settings.init();
    await settings.set(defs.dlnaPort, '$port');
    await settings.set(defs.dlnaEnabled, true);
    dlna = DlnaManager(bus, commands, log, settings);
    await dlna.init();
    client = HttpClient();
    for (var i = 0; i < 50; i++) {
      final status = await commands.execute('dlnaStatus', const {});
      if ((status.data as Map)['running'] == true) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    callback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    callback.listen((request) async {
      await busy.future;
      await request.drain<void>();
      request.response.statusCode = 200;
      await request.response.close();
    });
  });

  tearDown(() async {
    await dlna.dispose();
    await callback.close(force: true);
    client.close(force: true);
  });

  Future<int> soap(String action, String args) async {
    busy = Completer<void>();
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:$port/control/AVTransport'),
      );
      request.headers
        ..set('content-type', 'text/xml; charset="utf-8"')
        ..set(
          'soapaction',
          '"urn:schemas-upnp-org:service:AVTransport:1#$action"',
        );
      request.write(
        '<?xml version="1.0"?><s:Envelope '
        'xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body>'
        '<u:$action xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'
        '<InstanceID>0</InstanceID>$args</u:$action></s:Body></s:Envelope>',
      );
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    } finally {
      busy.complete();
    }
  }

  test('a controller that cannot take notifies mid-request still plays',
      () async {
    final subscribe = await client.openUrl(
      'SUBSCRIBE',
      Uri.parse('http://127.0.0.1:$port/event/AVTransport'),
    );
    subscribe.headers
      ..set('callback', '<http://127.0.0.1:${callback.port}/>')
      ..set('nt', 'upnp:event');
    await (await subscribe.close()).drain<void>();

    final watch = Stopwatch()..start();
    expect(
      await soap(
        'SetAVTransportURI',
        '<CurrentURI>http://127.0.0.1:1/a.wav</CurrentURI>'
            '<CurrentURIMetaData></CurrentURIMetaData>',
      ),
      200,
    );
    expect(await soap('Play', '<Speed>1</Speed>'), 200);
    expect(dlna.transportState.value, 'PLAYING');
    expect(await soap('Stop', ''), 200);
    expect(dlna.transportState.value, 'STOPPED');
    // Uncapped, each of the three waited out the 5 second notify timeout.
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
