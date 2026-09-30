import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/voice/ha_socket.dart';

/// The Home Assistant socket shared by native Voice Satellite and voice
/// alarms: a failed connect or a refused token is a plain error, and the
/// next request connects again.
void main() {
  test('an unreachable Home Assistant is a caught error', () async {
    final socket = HaSocket(
      baseUrl: () => 'http://127.0.0.1:1',
      token: () => 'token',
    );
    await expectLater(socket.request({'type': 'ping'}), throwsA(anything));
    expect(socket.connected, isFalse);
  });

  group('against a server', () {
    late HttpServer server;
    var accept = true;

    setUp(() async {
      accept = true;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.add(jsonEncode({'type': 'auth_required'}));
        ws.listen((raw) {
          final msg = jsonDecode(raw as String) as Map;
          if (msg['type'] == 'auth') {
            ws.add(jsonEncode({'type': accept ? 'auth_ok' : 'auth_invalid'}));
          } else {
            ws.add(
              jsonEncode({
                'id': msg['id'],
                'type': 'result',
                'success': true,
                'result': 'pong',
              }),
            );
          }
        });
      });
    });

    tearDown(() => server.close(force: true));

    HaSocket socket() => HaSocket(
      baseUrl: () => 'http://127.0.0.1:${server.port}',
      token: () => 'token',
    );

    test('answers a request', () async {
      final ha = socket();
      expect(await ha.request({'type': 'ping'}), 'pong');
      expect(ha.connected, isTrue);
      expect(ha.connections, 1);
      await ha.close();
    });

    test(
      'a refused token leaves it disconnected, and it tries again',
      () async {
        final ha = socket();
        accept = false;
        await expectLater(ha.request({'type': 'ping'}), throwsStateError);
        expect(ha.connected, isFalse);
        accept = true;
        expect(await ha.request({'type': 'ping'}), 'pong');
        await ha.close();
      },
    );
  });
}
