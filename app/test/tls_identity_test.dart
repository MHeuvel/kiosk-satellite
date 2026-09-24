import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/core/kiosk_http_client.dart';
import 'package:kiosk_satellite/core/tls_identity.dart';
import 'package:kiosk_satellite/managers/remote/remote_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsManager settings;
  late EventBus bus;
  late Logger log;
  late CommandRegistry commands;
  late Map<String, Object?> stored;
  late int loads;
  RemoteManager? remote;
  HttpServer? peer;
  final clients = <HttpClient>[];

  Map<String, Object?> material([
    String cert = 'cert.pem',
    String key = 'key.pem',
  ]) => {
    'certificate': File('test/fixtures/tls/$cert').readAsStringSync(),
    'privateKey': File('test/fixtures/tls/$key').readAsStringSync(),
    'notAfter': DateTime.utc(2036, 1, 1).millisecondsSinceEpoch,
    'imported': false,
  };

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({
      'ks.browser.start_url': 'http://ha.local/',
    });
    bus = EventBus();
    log = Logger();
    commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    stored = material();
    loads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TlsIdentity.channel, (call) async {
          if (call.method == 'load') loads++;
          if (call.method == 'renew') stored = material('renewed.pem');
          if (call.method == 'replace') {
            stored = material('other-cert.pem', 'other-key.pem');
          }
          if (call.method == 'import') {
            throw PlatformException(
              code: 'tls',
              message: 'Invalid certificate',
            );
          }
          return stored;
        });
  });

  tearDown(() async {
    for (final client in clients) {
      client.close(force: true);
    }
    clients.clear();
    await remote?.dispose();
    remote = null;
    await peer?.close(force: true);
    peer = null;
    await settings.dispose();
    await bus.dispose();
    await log.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TlsIdentity.channel, null);
  });

  Future<int> freePort() async {
    final socket = await ServerSocket.bind('127.0.0.1', 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<int> startRemote({bool tls = true}) async {
    final port = await freePort();
    await settings.set(remoteEnabled, true);
    await settings.set(remotePassword, 'test-password');
    await settings.set(remotePort, port);
    if (tls) await settings.set(remoteTls, true);
    remote = RemoteManager(bus, commands, log, settings);
    await remote!.init();
    return port;
  }

  HttpClient client() {
    final client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    clients.add(client);
    return client;
  }

  Future<String> login(int port, {bool tls = true}) async {
    final req = await client().postUrl(
      Uri.parse('${tls ? 'https' : 'http'}://127.0.0.1:$port/api/login'),
    );
    req.write(jsonEncode({'password': 'test-password'}));
    final response = await req.close();
    expect(response.statusCode, 200);
    return (jsonDecode(await utf8.decodeStream(response)) as Map)['token']
        as String;
  }

  test(
    'concurrent loads share one identity and renewal preserves the private key',
    () async {
      final loaded = await Future.wait(
        List.generate(10, (_) => settings.tls.load()),
      );
      expect(loads, 1);
      expect(loaded.every((value) => identical(value, loaded.first)), true);
      final renewed = await settings.tls.change('renew');
      expect(renewed.fingerprint, isNot(loaded.first.fingerprint));
      expect(renewed.privateKey, loaded.first.privateKey);
      final replaced = await settings.tls.change('replace');
      expect(replaced.privateKey, isNot(renewed.privateKey));
    },
  );

  test(
    'failed import preserves the identity and keys never enter config exports',
    () async {
      final original = await settings.tls.load();
      await expectLater(
        settings.tls.change('import', {
          'certificate': 'bad',
          'privateKey': 'bad',
        }),
        throwsA(isA<PlatformException>()),
      );
      expect(identical(await settings.tls.load(), original), true);
      expect(original.publicInfo.containsKey('privateKey'), false);
      expect(
        jsonEncode(settings.export(withSecrets: true)),
        isNot(contains('PRIVATE KEY')),
      );
    },
  );

  test('HTTPS login and WSS work and plaintext is refused', () async {
    final port = await startRemote();
    final token = await login(port);
    final ws = await WebSocket.connect(
      'wss://127.0.0.1:$port/api/ws?token=$token',
      customClient: client(),
    );
    expect(jsonDecode(await ws.first as String), isA<Map>());
    await ws.close();
    await expectLater(login(port, tls: false), throwsA(anything));
  });

  test(
    'renewal through HTTPS returns before listener restart and tokens survive',
    () async {
      final port = await startRemote();
      final token = await login(port);
      final req = await client().postUrl(
        Uri.parse('https://127.0.0.1:$port/api/commands/renewTlsCertificate'),
      );
      req.headers.set('Authorization', 'Bearer $token');
      req.write('{}');
      final res = await req.close();
      expect(res.statusCode, 200);
      expect((jsonDecode(await utf8.decodeStream(res)) as Map)['ok'], true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final after = await client().getUrl(
        Uri.parse('https://127.0.0.1:$port/api/settings'),
      );
      after.headers.set('Authorization', 'Bearer $token');
      final response = await after.close();
      expect(response.statusCode, 200);
      await response.drain<void>();
    },
  );

  test(
    'plain admin stays available when only the streaming certificate changes',
    () async {
      final port = await startRemote(tls: false);
      await settings.tls.change('renew');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(await login(port, tls: false), isNotEmpty);
    },
  );

  test(
    'kiosk HTTPS accepts self-signed and replacement certificates without pairing',
    () async {
      for (final identity in [
        await settings.tls.load(),
        TlsMaterial(material('renewed.pem')),
        TlsMaterial(material('other-cert.pem', 'other-key.pem')),
      ]) {
        peer = await HttpServer.bindSecure(
          '127.0.0.1',
          0,
          identity.securityContext(),
        );
        peer!.listen((request) {
          expect(request.headers.value('authorization'), 'Bearer test-token');
          request.response.write('encrypted');
          request.response.close();
        });
        final uri = Uri.parse('https://127.0.0.1:${peer!.port}/');
        final kiosk = kioskPeerClient();
        expect(
          (await kiosk.get(
            uri,
            headers: {'Authorization': 'Bearer test-token'},
          )).body,
          'encrypted',
        );
        kiosk.close();
        final external = HttpClient();
        clients.add(external);
        await expectLater(
          external.getUrl(uri).then((request) => request.close()),
          throwsA(isA<HandshakeException>()),
        );
        await peer!.close(force: true);
        peer = null;
      }
    },
  );

  test('kiosk WSS connects without a separate trust setup', () async {
    final port = await startRemote();
    final token = await login(port);
    final kiosk = kioskPeerHttpClient();
    clients.add(kiosk);
    final socket = await WebSocket.connect(
      'wss://127.0.0.1:$port/api/ws?token=$token',
      customClient: kiosk,
    );
    expect(jsonDecode(await socket.first as String), isA<Map>());
    await socket.close();
  });

  test('certificate restart waits for a slow mutating response', () async {
    final port = await startRemote();
    final token = await login(port);
    commands.register(
      Command(
        name: 'slowRenew',
        description: 'Test renewal',
        handler: (_) async {
          await settings.tls.change('renew');
          await Future<void>.delayed(const Duration(milliseconds: 1800));
          return const CommandResult.ok('finished');
        },
      ),
    );
    final req = await client().postUrl(
      Uri.parse('https://127.0.0.1:$port/api/commands/slowRenew'),
    );
    req.headers.set('Authorization', 'Bearer $token');
    req.write('{}');
    final response = await req.close();
    expect(response.statusCode, 200);
    expect(
      (jsonDecode(await utf8.decodeStream(response)) as Map)['data'],
      'finished',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(await login(port), isNotEmpty);
  });

  test('an unfinished login cannot hold the listener on plaintext', () async {
    final port = await startRemote(tls: false);
    final slow = await Socket.connect('127.0.0.1', port);
    addTearDown(slow.destroy);
    slow.write(
      'POST /api/login HTTP/1.1\r\nHost: localhost\r\nContent-Length: 1000\r\n\r\n{',
    );
    await slow.flush();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await settings.set(remoteTls, true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(await login(port), isNotEmpty);
    await expectLater(login(port, tls: false), throwsA(anything));
  });

  test(
    'a failed certificate load never opens a plaintext admin listener',
    () async {
      SharedPreferences.setMockInitialValues({
        'ks.browser.start_url': 'http://ha.local/',
        'ks.remote.tls': true,
        'ks.remote.enabled': true,
        'ks.remote.password': 'test-password',
        'ks.remote.port': await freePort(),
      });
      commands = CommandRegistry(log);
      settings = SettingsManager(bus, commands, log);
      await settings.init();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            TlsIdentity.channel,
            (_) async => throw PlatformException(
              code: 'tls',
              message: 'Damaged identity',
            ),
          );
      remote = RemoteManager(bus, commands, log, settings);
      await remote!.init();
      expect(remote!.stoppedReason.value, contains('Damaged identity'));
      await expectLater(
        Socket.connect('127.0.0.1', settings.get(remotePort).toInt()),
        throwsA(isA<SocketException>()),
      );
    },
  );
}
