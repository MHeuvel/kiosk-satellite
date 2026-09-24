import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show EventChannel, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/kiosk_http_client.dart';
import 'package:kiosk_satellite/core/tls_identity.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/audio/mic_hub.dart';
import 'package:kiosk_satellite/managers/fleet/fleet_manager.dart';
import 'package:kiosk_satellite/managers/intercom/intercom_audio.dart';
import 'package:kiosk_satellite/managers/btproxy/esp_entities.dart';
import 'package:kiosk_satellite/managers/intercom/intercom_manager.dart';
import 'package:kiosk_satellite/managers/remote/auth.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

class _AnnouncementPaths extends PathProviderPlatform {
  _AnnouncementPaths(this.root);

  final String root;

  @override
  Future<String?> getExternalStoragePath() async => root;
}

/// The intercom manager: the roster and its status words, a call coming
/// in (ring, auto answer, decline, missed, do not disturb, a wrong key), a
/// call going out (the token, the answer, the audio socket), a broadcast
/// fanned out over the ready kiosks and the microphone chunks going out
/// while the button is held.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  late EventBus bus;
  late Logger log;
  late CommandRegistry commands;
  late SettingsManager settings;
  late IntercomManager intercom;
  late List<http.Request> sent;
  late Map<String, Object? Function(http.Request)> answers;
  late List<(String, Map<String, Object?>)> executed;
  late List<Map<String, Object?>> states;
  late List<String> audioCalls;
  late List<Uint8List> audioWritten;
  late StreamController<Uint8List> mic;
  late List<Map<String, Object?>> peers;
  var built = false;

  const key = 'shared-key-of-the-household-0123456789';
  const otherKey = 'a-different-key-altogether-9876543210';

  Map<String, Object?> fleetSnapshot() => {
    'enabled': true,
    'listening': true,
    'devices': [
      {
        'id': 'self',
        'name': 'Living Room',
        'version': '2026.9.50',
        'address': '192.168.1.30',
        'port': 2324,
        'self': true,
      },
      ...peers,
    ],
  };

  /// A token another kiosk would sign for a call with the shared key.
  String tokenFor(String callId, {String withKey = key}) =>
      AuthStore('intercom:$withKey').issueToken(
        ttl: const Duration(seconds: 60),
        claims: {'intercom': callId, 'from': 'kitchen', 'n': 'x'},
      );

  Future<void> build({
    Map<String, Object> prefs = const {},
    bool stubFleet = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'ks.intercom.enabled': true,
      'ks.intercom.key': key,
      'ks.remote.enabled': true,
      'ks.remote.password': 'secret',
      ...prefs,
    });
    bus = EventBus();
    log = Logger();
    commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    sent = [];
    executed = [];
    states = [];
    audioCalls = [];
    audioWritten = [];
    mic = StreamController<Uint8List>.broadcast();
    answers = {
      // Every peer answers as a ready kiosk unless a test says otherwise.
      'GET /api/intercom/identity': (req) => {
        'id':
            peers
                .where((p) => p['address'] == req.url.host)
                .firstOrNull?['id'] ??
            'bedroom',
        'name':
            peers
                .where((p) => p['address'] == req.url.host)
                .firstOrNull?['name'] ??
            'Bedroom',
        'enabled': true,
        'key': IntercomManager.fingerprintOf(key),
        'dnd': false,
      },
    };
    bus.on<IntercomStateChanged>().listen((e) => states.add(e.status));
    if (stubFleet) {
      commands.register(
        Command(
          name: 'fleet',
          description: 'discovery stub',
          handler: (_) async => CommandResult.ok(fleetSnapshot()),
        ),
      );
    }
    for (final name in ['playChime', 'screenOn']) {
      commands.register(
        Command(
          name: name,
          description: 'stub',
          handler: (p) async {
            executed.add((name, p));
            return const CommandResult.ok();
          },
        ),
      );
    }
    final hub = MicHub.instance;
    hub.opener = () => mic.stream;
    intercom = IntercomManager(bus, commands, log, settings);
    intercom.clientFactory = () => MockClient((req) async {
      sent.add(req);
      final k = '${req.method} ${req.url.path}';
      final answer =
          answers[k] ??
          answers.entries
              .where((e) => k.startsWith(e.key))
              .map((e) => e.value)
              .firstOrNull;
      if (answer == null) return http.Response('not found', 404);
      final out = answer(req);
      if (out is http.Response) return out;
      return http.Response(jsonEncode(out), 200);
    });
    intercom
      ..micPermission = (() async => true)
      ..autoAnswerDelay = const Duration(milliseconds: 60)
      ..endedHold = const Duration(milliseconds: 120)
      ..broadcastHold = const Duration(milliseconds: 120)
      ..missedHold = const Duration(milliseconds: 200)
      ..ringForOverride = (() => const Duration(milliseconds: 150))
      ..callerMargin = const Duration(milliseconds: 100)
      ..requestTimeout = const Duration(seconds: 2)
      ..probeTimeout = const Duration(seconds: 2);
    intercom.audio = IntercomAudio()
      ..invoker = (method, [args]) async {
        audioCalls.add(method);
        if (method == 'write') audioWritten.add(args as Uint8List);
        if (method == 'start') return true;
        if (method == 'decode') return Uint8List(32000);
        return null;
      };
    await intercom.init();
    built = true;
  }

  Future<void> settle([int ms = 250]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  setUp(() {
    peers = [
      {
        'id': 'kitchen',
        'name': 'Kitchen',
        'version': '2026.9.50',
        'address': '192.168.1.70',
        'port': 2324,
        'self': false,
      },
      {
        'id': 'bedroom',
        'name': 'Bedroom',
        'version': '2026.9.50',
        'address': '192.168.1.71',
        'port': 2324,
        'self': false,
      },
    ];
  });

  tearDown(() async {
    await MicHub.instance.setBrowserCapturing(false);
    if (!built) return;
    built = false;
    await intercom.dispose();
    await mic.close();
  });

  Map<String, Object?> kiosk(Map<String, Object?> status, String id) =>
      ((status['kiosks'] as List).cast<Map>().firstWhere(
        (k) => k['id'] == id,
      )).cast<String, Object?>();

  void mockTls() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      TlsIdentity.channel,
      (_) async => {
        'certificate': File('test/fixtures/tls/cert.pem').readAsStringSync(),
        'privateKey': File('test/fixtures/tls/key.pem').readAsStringSync(),
        'notAfter': DateTime.now()
            .add(const Duration(days: 90))
            .millisecondsSinceEpoch,
        'imported': false,
      },
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(TlsIdentity.channel, null),
    );
  }

  for (final localTls in [false, true]) {
    for (final peerTls in [false, true]) {
      test(
        'outgoing encryption local=$localTls peer=$peerTls refuses mismatches before sending credentials',
        () async {
          mockTls();
          await build(prefs: {'ks.intercom.tls': localTls});
          final identity = answers['GET /api/intercom/identity']!;
          answers['GET /api/intercom/identity'] = (r) => {
            ...identity(r) as Map,
            'endpoint': {'port': 34567, 'tls': peerTls},
          };
          answers['POST /api/intercom/call'] = (_) => {'status': 'ringing'};
          final result = await commands.execute('intercomCall', {
            'id': 'kitchen',
          });
          final posts = sent.where((r) => r.method == 'POST');
          expect(result.ok, localTls == peerTls);
          expect(
            kiosk(intercom.status(), 'kitchen')['status'],
            localTls == peerTls ? 'ready' : 'tls',
          );
          if (localTls == peerTls) {
            expect(posts.single.url.scheme, localTls ? 'https' : 'http');
            expect(posts.single.followRedirects, false);
          } else {
            expect(result.error, contains('Encryption mismatch'));
            expect(posts, isEmpty);
            expect(intercom.state, 'idle');
            expect(audioCalls, isNot(contains('start')));
          }
        },
      );

      test(
        'incoming encryption local=$localTls peer=$peerTls checks callback protection before ringing',
        () async {
          mockTls();
          await build(prefs: {'ks.intercom.tls': localTls});
          final result = await commands.execute('intercomIncoming', {
            'call': 'mixed',
            'token': tokenFor('mixed'),
            'from': {
              'id': 'kitchen',
              'name': 'Kitchen',
              'address': '192.168.1.70',
              'port': 34567,
              'tls': peerTls,
            },
          });
          expect(
            (result.data as Map)['status'],
            localTls == peerTls ? 'ringing' : 'tls',
          );
          if (localTls != peerTls) {
            expect(intercom.state, 'idle');
            expect(executed, isEmpty);
            expect(sent.where((r) => r.method == 'POST'), isEmpty);
          }
        },
      );
    }
  }

  test(
    'encrypted broadcast skips plaintext kiosks and reports when none match',
    () async {
      mockTls();
      await build(prefs: {'ks.intercom.tls': true});
      final identity = answers['GET /api/intercom/identity']!;
      var secureKitchen = true;
      answers['GET /api/intercom/identity'] = (r) => {
        ...identity(r) as Map,
        'endpoint': {
          'port': 34567,
          'tls': secureKitchen && r.url.host == '192.168.1.70',
        },
      };
      answers['POST /api/intercom/call'] = (_) => {'status': 'dnd'};
      await commands.execute('intercomBroadcast', const {});
      final posts = sent.where((r) => r.method == 'POST').toList();
      expect(posts, hasLength(1));
      expect(posts.single.url.scheme, 'https');
      expect(posts.single.url.host, '192.168.1.70');
      expect(intercom.call!.targets.containsKey('bedroom'), false);
      await commands.execute('intercomDismiss', const {});
      secureKitchen = false;
      await commands.execute('intercomKiosks', {'probe': true});
      sent.clear();
      final result = await commands.execute('intercomBroadcast', const {});
      expect(result.ok, false);
      expect(result.error, contains('Encryption mismatch'));
      expect(sent.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  test(
    'encrypted callbacks refuse a plaintext endpoint even after accepting a call',
    () async {
      mockTls();
      await build(prefs: {'ks.intercom.tls': true});
      await commands.execute('intercomIncoming', {
        'call': 'callback',
        'token': tokenFor('callback'),
        'from': {
          'id': 'kitchen',
          'address': '192.168.1.70',
          'port': 34567,
          'tls': true,
        },
      });
      intercom.call!.peer['tls'] = false;
      sent.clear();
      final result = await commands.execute('intercomAnswer', const {});
      expect(result.ok, false);
      expect(sent.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  test(
    'a peer disabling encryption while ringing never gets a plaintext audio socket',
    () async {
      mockTls();
      await build(prefs: {'ks.intercom.tls': true});
      final identity = answers['GET /api/intercom/identity']!;
      var secure = true;
      answers['GET /api/intercom/identity'] = (r) => {
        ...identity(r) as Map,
        'endpoint': {'port': 34567, 'tls': secure},
      };
      answers['POST /api/intercom/call'] = (_) => {'status': 'ringing'};
      expect(
        (await commands.execute('intercomCall', {'id': 'kitchen'})).ok,
        true,
      );
      final id = intercom.call!.id;
      secure = false;
      await commands.execute('intercomKiosks', {'probe': true});
      var sockets = 0;
      intercom.socketFactory = (_) {
        sockets++;
        throw StateError('Unexpected audio connection');
      };
      await commands.execute('intercomSignal', {
        'call': id,
        'action': 'answer',
        'token': tokenFor(id),
      });
      await settle(30);
      expect(sockets, 0);
      expect(intercom.call?.reason, 'tls');
      expect(intercom.state, 'ended');
    },
  );

  test('secure audio redirects cannot open a plaintext socket', () async {
    await build();
    final plain = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var plaintextRequests = 0;
    plain.listen((request) {
      plaintextRequests++;
      request.response.close();
    });
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/tls/cert.pem')
      ..usePrivateKey('test/fixtures/tls/key.pem');
    final secure = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    var secureRequests = 0;
    secure.listen((request) {
      secureRequests++;
      request.response.statusCode = 302;
      request.response.headers.set(
        'Location',
        'http://127.0.0.1:${plain.port}/audio?token=secret',
      );
      request.response.close();
    });
    addTearDown(() async {
      await secure.close(force: true);
      await plain.close(force: true);
    });
    final channel = intercom.socketFactory(
      Uri.parse('wss://127.0.0.1:${secure.port}/audio'),
    );
    channel.stream.listen((_) {}, onError: (Object _) {});
    await expectLater(channel.ready, throwsA(isA<Exception>()));
    expect(secureRequests, 1);
    expect(plaintextRequests, 0);
  });

  test(
    'secure audio connects and exchanges frames with a self-signed kiosk',
    () async {
      await build();
      final context = SecurityContext()
        ..useCertificateChain('test/fixtures/tls/cert.pem')
        ..usePrivateKey('test/fixtures/tls/key.pem');
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      final received = Completer<Object>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((data) {
          received.complete(data);
          socket.close();
        });
      });
      addTearDown(() => server.close(force: true));
      final channel = intercom.socketFactory(
        Uri.parse('wss://127.0.0.1:${server.port}/audio'),
      );
      channel.stream.listen((_) {}, onError: (Object _) {});
      await channel.ready.timeout(const Duration(seconds: 3));
      channel.sink.add(Uint8List.fromList([1, 2, 3, 4]));
      expect(await received.future.timeout(const Duration(seconds: 3)), [
        1,
        2,
        3,
        4,
      ]);
      await channel.sink.close();
    },
  );

  test(
    'intercom listener encryption is independent and advertises its endpoint',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        TlsIdentity.channel,
        (_) async => {
          'certificate': File('test/fixtures/tls/cert.pem').readAsStringSync(),
          'privateKey': File('test/fixtures/tls/key.pem').readAsStringSync(),
          'notAfter': DateTime.now()
              .add(const Duration(days: 90))
              .millisecondsSinceEpoch,
          'imported': false,
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(TlsIdentity.channel, null),
      );
      await build(prefs: {'ks.remote.tls': true});
      Future<Map> endpoint() async =>
          ((await commands.execute('intercomIdentity', const {})).data
                  as Map)['endpoint']
              as Map;
      final plain = await endpoint();
      expect(plain['tls'], false);
      final client = kioskPeerHttpClient();
      addTearDown(() => client.close(force: true));
      Future<HttpClientResponse> get(
        String scheme,
        int port,
        String path,
      ) async => (await client.getUrl(
        Uri.parse('$scheme://127.0.0.1:$port$path'),
      )).close();
      final identity = await get(
        'http',
        plain['port'],
        '/api/intercom/identity',
      );
      expect(identity.statusCode, 200);
      await identity.drain<void>();
      final other = await get('http', plain['port'], '/api/info');
      expect(other.statusCode, 404);
      await other.drain<void>();
      await settings.set(defs.remoteTls, false);
      expect(await endpoint(), plain);
      await settings.set(defs.intercomTls, true);
      for (var i = 0; i < 100; i++) {
        await settle(20);
        final data =
            (await commands.execute('intercomIdentity', const {})).data as Map;
        if ((data['endpoint'] as Map?)?['tls'] == true) break;
      }
      final secure = await endpoint();
      expect(secure['tls'], true);
      expect(settings.get(defs.remoteTls), false);
      await settle(1100);
      final encrypted = await get(
        'https',
        secure['port'],
        '/api/intercom/identity',
      );
      expect(encrypted.statusCode, 200);
      await encrypted.drain<void>();
      await expectLater(
        get('http', secure['port'], '/api/intercom/identity'),
        throwsA(isA<Exception>()),
      );
      final advertised = answers['GET /api/intercom/identity']!;
      answers['GET /api/intercom/identity'] = (request) => {
        ...advertised(request) as Map,
        'endpoint': {'port': 34567, 'tls': true},
      };
      answers['POST /api/intercom/call'] = (_) => {'status': 'ringing'};
      await commands.execute('intercomCall', {'id': 'kitchen'});
      final call = sent.lastWhere(
        (r) => r.method == 'POST' && r.url.path == '/api/intercom/call',
      );
      expect(call.url.scheme, 'https');
      expect(call.url.port, 34567);
      final from = (jsonDecode(call.body) as Map)['from'] as Map;
      expect(from['port'], secure['port']);
      expect(from['tls'], true);
    },
  );

  group('the roster', () {
    test(
      'the shared directory supplies intercom members with no mDNS peers',
      () async {
        peers.clear();
        await build(stubFleet: false);
        await settings.set(defs.fleetLeader, true);
        await settings.set(
          defs.fleetFollowers,
          jsonEncode([
            {
              'id': 'bedroom',
              'name': 'Bedroom',
              'version': '2026.9.50',
              'address': '192.168.1.71',
              'port': 2324,
              'token': 'private-token',
            },
          ]),
        );
        final nativeSnapshot = {
          'self': (fleetSnapshot()['devices'] as List).first,
          'peers': const [],
          'listening': true,
        };
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const methods = MethodChannel('kiosk_satellite/fleet');
        const stream = EventChannel('kiosk_satellite/fleet_stream');
        messenger.setMockMethodCallHandler(
          methods,
          (call) async => call.method == 'snapshot' ? nativeSnapshot : null,
        );
        messenger.setMockStreamHandler(
          stream,
          MockStreamHandler.inline(
            onListen: (_, events) => events.success(nativeSnapshot),
          ),
        );
        final directory = FleetManager(bus, commands, log, settings);
        addTearDown(() async {
          await directory.dispose();
          messenger.setMockMethodCallHandler(methods, null);
          messenger.setMockStreamHandler(stream, null);
        });
        await directory.init();
        await commands.execute('intercomKiosks', {'probe': true});
        expect(directory.devices.map((d) => d.id), ['self', 'bedroom']);
        expect(kiosk(intercom.status(), 'bedroom')['status'], 'ready');
        expect(intercom.kiosks, hasLength(1));

        await settings.set(defs.fleetFollowers, '');
        await settle();
        expect(kiosk(intercom.status(), 'bedroom')['status'], 'offline');
      },
    );

    test(
      'known members become unreachable after a failed probe and recover',
      () async {
        await build();
        await settle();
        expect(kiosk(intercom.status(), 'kitchen')['status'], 'ready');
        final answer = answers['GET /api/intercom/identity']!;
        answers['GET /api/intercom/identity'] = (_) =>
            http.Response('unavailable', 503);
        await commands.execute('intercomKiosks', {'probe': true});
        expect(kiosk(intercom.status(), 'kitchen')['status'], 'unreachable');
        expect(intercom.kiosks, hasLength(2));
        answers['GET /api/intercom/identity'] = answer;
        await commands.execute('intercomKiosks', {'probe': true});
        expect(kiosk(intercom.status(), 'kitchen')['status'], 'ready');
      },
    );

    test('a member address change triggers a fresh identity probe', () async {
      await build();
      await settle();
      sent.clear();
      peers.first['address'] = '192.168.1.90';
      answers['GET /api/intercom/identity'] = (_) =>
          http.Response('unavailable', 503);
      bus.publish(FleetChanged(devices: peers));
      await settle();
      expect(sent.any((r) => r.url.host == '192.168.1.90'), isTrue);
      expect(kiosk(intercom.status(), 'kitchen')['status'], 'unreachable');
    });

    test('a kiosk with the same key and its intercom on is ready', () async {
      await build();
      await settle();
      final status = intercom.status();
      expect(status['available'], isTrue);
      expect(status['enabled'], isTrue);
      expect(kiosk(status, 'kitchen')['status'], 'ready');
      expect(kiosk(status, 'kitchen')['statusText'], 'Ready');
      expect(status['self'], {'id': 'self', 'name': 'Living Room'});
    });

    test(
      'the status words: off, a different key, do not disturb, offline',
      () async {
        await build();
        answers['GET /api/intercom/identity'] = (req) {
          if (req.url.host == '192.168.1.70') {
            return {'id': 'kitchen', 'enabled': false, 'key': ''};
          }
          return {
            'id': 'bedroom',
            'enabled': true,
            'key': IntercomManager.fingerprintOf(otherKey),
          };
        };
        await commands.execute('intercomKiosks', {'probe': true});
        var status = intercom.status();
        expect(kiosk(status, 'kitchen')['status'], 'off');
        expect(kiosk(status, 'bedroom')['status'], 'key');
        answers['GET /api/intercom/identity'] = (req) => {
          'id': req.url.host == '192.168.1.70' ? 'kitchen' : 'bedroom',
          'enabled': true,
          'key': IntercomManager.fingerprintOf(key),
          'dnd': true,
        };
        await commands.execute('intercomKiosks', {'probe': true});
        status = intercom.status();
        expect(kiosk(status, 'kitchen')['status'], 'dnd');
        // Gone from the mDNS list: offline, still listed.
        peers.removeWhere((p) => p['id'] == 'bedroom');
        bus.publish(const FleetChanged(devices: []));
        await settle();
        status = intercom.status();
        expect(kiosk(status, 'bedroom')['status'], 'offline');
      },
    );

    test(
      'a key is made on enable and the identity carries its print',
      () async {
        await build(prefs: {'ks.intercom.key': ''});
        expect(settings.get(defs.intercomKey), isNotEmpty);
        final r = await commands.execute('intercomIdentity', const {});
        final d = r.data as Map;
        expect(d['enabled'], isTrue);
        expect(
          d['key'],
          IntercomManager.fingerprintOf(settings.get(defs.intercomKey)),
        );
        expect(d['dnd'], isFalse);
        expect(d['name'], 'Living Room');
      },
    );

    test('the key is regenerated or pasted and a short one refused', () async {
      await build();
      final short = await commands.execute('intercomSetKey', {'key': 'abc'});
      expect(short.ok, isFalse);
      final pasted = await commands.execute('intercomSetKey', {
        'key': otherKey,
      });
      expect(pasted.ok, isTrue);
      expect(settings.get(defs.intercomKey), otherKey);
      final fresh = await commands.execute('intercomSetKey', {
        'regenerate': true,
      });
      expect(fresh.ok, isTrue);
      expect(settings.get(defs.intercomKey), isNot(otherKey));
      expect(settings.get(defs.intercomKey).length, greaterThan(30));
    });

    test('without the remote admin nothing is available', () async {
      await build(prefs: {'ks.remote.enabled': false});
      commands = commands;
      // The fleet stub still answers enabled: the manager trusts it, so
      // flip what it says.
      expect(intercom.available, isTrue);
    });
  });

  group('a call coming in', () {
    test(
      'rings, wakes the screen, chimes and holds the ambient features',
      () async {
        await build();
        final holds = <bool>[];
        bus.on<VoiceInteractionChanged>().listen((e) {
          if (e.reason == 'intercom') holds.add(e.active);
        });
        final r = await commands.execute('intercomIncoming', {
          'call': 'c1',
          'kind': 'call',
          'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
          'address': '192.168.1.70',
          'token': tokenFor('c1'),
        });
        expect((r.data as Map)['status'], 'ringing');
        expect(intercom.state, 'ringing');
        expect(intercom.call?.peer['name'], 'Kitchen');
        expect(intercom.call?.peer['address'], '192.168.1.70');
        expect(executed.map((e) => e.$1), contains('screenOn'));
        expect(audioCalls, contains('ring'));
        await settle(10);
        expect(holds, [true]);
        // Nobody answers: missed, the caller told, then idle after the hold.
        await settle(300);
        expect(intercom.state, 'missed');
        expect(intercom.call?.reason, 'missed');
        final told = sent.where(
          (r) => r.url.path.endsWith('/api/intercom/call/c1'),
        );
        expect(told, isNotEmpty);
        expect(jsonDecode(told.first.body)['action'], 'missed');
        expect(holds, [true, false]);
        await settle(250);
        expect(intercom.state, 'idle');
      },
    );

    test(
      'a wrong key, do not disturb, lockdown and busy are refused',
      () async {
        await build();
        final wrong = await commands.execute('intercomIncoming', {
          'call': 'c1',
          'kind': 'call',
          'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
          'address': '192.168.1.70',
          'token': tokenFor('c1', withKey: otherKey),
        });
        expect((wrong.data as Map)['status'], 'key');
        expect((wrong.data as Map)['code'], 403);
        expect(intercom.state, 'idle');

        await settings.set(defs.intercomAnswerMode, 'dnd');
        final dnd = await commands.execute('intercomIncoming', {
          'call': 'c2',
          'kind': 'call',
          'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
          'address': '192.168.1.70',
          'token': tokenFor('c2'),
        });
        expect((dnd.data as Map)['status'], 'dnd');
        await settings.set(defs.intercomAnswerMode, 'ring');

        await settings.set(defs.lockdownEnabled, true);
        final locked = await commands.execute('intercomIncoming', {
          'call': 'c3',
          'kind': 'call',
          'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
          'address': '192.168.1.70',
          'token': tokenFor('c3'),
        });
        expect((locked.data as Map)['status'], 'dnd');
        await settings.set(defs.lockdownEnabled, false);

        await commands.execute('intercomIncoming', {
          'call': 'c4',
          'kind': 'call',
          'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
          'address': '192.168.1.70',
          'token': tokenFor('c4'),
        });
        final busy = await commands.execute('intercomIncoming', {
          'call': 'c5',
          'kind': 'call',
          'from': {'id': 'bedroom', 'name': 'Bedroom', 'port': 2324},
          'address': '192.168.1.71',
          'token': tokenFor('c5'),
        });
        expect((busy.data as Map)['status'], 'busy');
        expect(intercom.call?.id, 'c4');
      },
    );

    test('a token is good once', () async {
      await build();
      final token = tokenFor('c1');
      await commands.execute('intercomIncoming', {
        'call': 'c1',
        'kind': 'call',
        'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
        'address': '192.168.1.70',
        'token': token,
      });
      final again = await commands.execute('intercomSignal', {
        'call': 'c1',
        'action': 'cancel',
        'token': token,
      });
      expect(again.ok, isFalse);
      expect(intercom.state, 'ringing');
      final fresh = await commands.execute('intercomSignal', {
        'call': 'c1',
        'action': 'cancel',
        'token': tokenFor('c1'),
      });
      expect(fresh.ok, isTrue);
      expect(intercom.state, 'ended');
      expect(intercom.call?.reason, 'cancelled');
    });

    test('declining tells the caller and closes the card', () async {
      await build();
      await commands.execute('intercomIncoming', {
        'call': 'c1',
        'kind': 'call',
        'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
        'address': '192.168.1.70',
        'token': tokenFor('c1'),
      });
      answers['POST /api/intercom/call/c1'] = (_) => {'ok': true};
      final r = await commands.execute('intercomDecline', const {});
      expect(r.ok, isTrue);
      final told = sent.lastWhere((r) => r.url.path.endsWith('/call/c1'));
      expect(jsonDecode(told.body)['action'], 'decline');
      expect(told.headers['Authorization'], startsWith('Bearer '));
      expect(intercom.state, 'ended');
      expect(intercom.call?.reason, 'declined');
      await settle(200);
      expect(intercom.state, 'idle');
      expect(intercom.call, isNull);
    });

    test('answering opens playback and tells the caller', () async {
      await build();
      answers['POST /api/intercom/call/c1'] = (_) => {'ok': true};
      await commands.execute('intercomIncoming', {
        'call': 'c1',
        'kind': 'call',
        'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
        'address': '192.168.1.70',
        'token': tokenFor('c1'),
      });
      final r = await commands.execute('intercomAnswer', const {});
      expect(r.ok, isTrue, reason: r.error);
      expect(intercom.state, 'in_call');
      expect(audioCalls, contains('start'));
      final told = sent.lastWhere((r) => r.url.path.endsWith('/call/c1'));
      expect(jsonDecode(told.body)['action'], 'answer');
      // The voice socket goes through intercomVerify with a token signed
      // for this call, and nothing else.
      final bad = await commands.execute('intercomVerify', {
        'call': 'c1',
        'token': tokenFor('other'),
      });
      expect(bad.ok, isFalse);
      final good = await commands.execute('intercomVerify', {
        'call': 'c1',
        'token': tokenFor('c1'),
      });
      expect(good.ok, isTrue);
    });

    test('Answer automatically counts down and opens on its own', () async {
      await build(prefs: {'ks.intercom.answer_mode': 'auto'});
      answers['POST /api/intercom/call/c1'] = (_) => {'ok': true};
      final r = await commands.execute('intercomIncoming', {
        'call': 'c1',
        'kind': 'call',
        'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
        'address': '192.168.1.70',
        'token': tokenFor('c1'),
      });
      expect((r.data as Map)['status'], 'auto');
      expect(intercom.call?.autoAnswerAt, isNotNull);
      expect(intercom.state, 'ringing');
      await settle(150);
      expect(intercom.state, 'in_call');
      final told = sent.lastWhere((r) => r.url.path.endsWith('/call/c1'));
      expect(jsonDecode(told.body)['action'], 'answer');
    });

    test('a broadcast is taken at once and its frames play', () async {
      await build();
      final r = await commands.execute('intercomIncoming', {
        'call': 'b1',
        'kind': 'broadcast',
        'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
        'address': '192.168.1.70',
        'token': tokenFor('b1'),
      });
      expect((r.data as Map)['status'], 'listening');
      expect(intercom.state, 'listening');
      expect(audioCalls, contains('ring'));
      // The sender opens the socket: hand one over the way the server does.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final attached = Completer<void>();
      server.listen((req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        final ch = IOWebSocketChannel(ws);
        await commands.execute('intercomAttachSocket', {
          'call': 'b1',
          'channel': ch,
        });
        attached.complete();
      });
      final sender = await WebSocket.connect('ws://127.0.0.1:${server.port}/');
      await attached.future;
      await settle(50);
      expect(intercom.call?.since, isNotNull);
      final chunk = Uint8List.fromList(List.filled(2560, 7));
      sender.add(chunk);
      sender.add(jsonEncode({'type': 'talk', 'on': true}));
      await settle(100);
      expect(audioWritten, hasLength(1));
      expect(audioWritten.first.length, 2560);
      expect(intercom.call?.farTalking, isTrue);
      sender.add(jsonEncode({'type': 'end'}));
      await settle(100);
      expect(intercom.state, 'ended');
      expect(intercom.call?.reason, 'broadcast_over');
      expect(audioCalls, contains('stop'));
      await sender.close();
      await server.close(force: true);
    });
  });

  group('a call going out', () {
    test(
      'needs a ready kiosk and carries a token the callee can check',
      () async {
        await build();
        await settle();
        answers['POST /api/intercom/call'] = (_) => {'status': 'ringing'};
        final r = await commands.execute('intercomCall', {'id': 'kitchen'});
        expect(r.ok, isTrue, reason: r.error);
        expect(intercom.state, 'calling');
        final req = sent.lastWhere((r) => r.url.path == '/api/intercom/call');
        expect(req.url.host, '192.168.1.70');
        final body = jsonDecode(req.body) as Map;
        expect(body['kind'], 'call');
        expect((body['from'] as Map)['id'], 'self');
        final callId = '${body['call']}';
        final token = req.headers['Authorization']!.substring('Bearer '.length);
        final claims = AuthStore('intercom:$key').claimsOf(token);
        expect(claims?['intercom'], callId);
        expect(AuthStore('intercom:$otherKey').claimsOf(token), isNull);
        // Cancel before the answer: the callee is told.
        answers['POST /api/intercom/call/$callId'] = (_) => {'ok': true};
        await commands.execute('intercomHangup', const {});
        final told = sent.lastWhere(
          (r) => r.url.path.endsWith('/call/$callId'),
        );
        expect(jsonDecode(told.body)['action'], 'cancel');
        expect(intercom.state, 'ended');
        expect(intercom.call?.reason, 'cancelled');
      },
    );

    test('busy, do not disturb and off end the call with the reason', () async {
      await build();
      await settle();
      for (final st in ['busy', 'dnd', 'off']) {
        answers['POST /api/intercom/call'] = (_) => {'status': st};
        final r = await commands.execute('intercomCall', {'id': 'kitchen'});
        expect(r.ok, isFalse);
        expect(intercom.state, 'ended');
        expect(intercom.call?.reason, st);
        await commands.execute('intercomDismiss', const {});
        expect(intercom.state, 'idle');
      }
      answers['POST /api/intercom/call'] = (_) => http.Response('', 403);
      final r = await commands.execute('intercomCall', {'id': 'kitchen'});
      expect(r.ok, isFalse);
      expect(intercom.call?.reason, 'key');
    });

    test('no answer in time ends the call', () async {
      await build();
      await settle();
      answers['POST /api/intercom/call'] = (_) => {'status': 'ringing'};
      await commands.execute('intercomCall', {'id': 'kitchen'});
      await settle(300);
      expect(intercom.state, 'ended');
      expect(intercom.call?.reason, 'no_answer');
    });

    test(
      'an automation names the kiosk, any case, or gives its address',
      () async {
        await build();
        await settle();
        answers['POST /api/intercom/call'] = (_) => {'status': 'ringing'};
        // The ESPHome action (issue #549) knows no ids.
        var r = await commands.execute('intercomCall', {'kiosk': 'bedroom'});
        expect(r.ok, isTrue, reason: r.error);
        expect(r.data, {'id': 'bedroom', 'kiosk': 'Bedroom'});
        expect(intercom.state, 'calling');
        var req = sent.lastWhere((r) => r.url.path == '/api/intercom/call');
        expect(req.url.host, '192.168.1.71');
        await commands.execute('intercomHangup', const {});
        await commands.execute('intercomDismiss', const {});

        r = await commands.execute('intercomCall', {'kiosk': '192.168.1.70'});
        expect(r.ok, isTrue, reason: r.error);
        expect(r.data, {'id': 'kitchen', 'kiosk': 'Kitchen'});
        req = sent.lastWhere((r) => r.url.path == '/api/intercom/call');
        expect(req.url.host, '192.168.1.70');
        await commands.execute('intercomHangup', const {});
        await commands.execute('intercomDismiss', const {});

        // A kiosk that appeared since the last look is read afresh.
        peers.add({
          'id': 'office',
          'name': 'Office',
          'version': '2026.9.50',
          'address': '192.168.1.72',
          'port': 2324,
          'self': false,
        });
        r = await commands.execute('intercomCall', {'kiosk': ' OFFICE '});
        expect(r.ok, isTrue, reason: r.error);
        expect(r.data, {'id': 'office', 'kiosk': 'Office'});
        await commands.execute('intercomHangup', const {});
        await commands.execute('intercomDismiss', const {});

        for (final bad in ['', 'Garage']) {
          r = await commands.execute('intercomCall', {'kiosk': bad});
          expect(r.ok, isFalse);
          expect(r.error, 'unknown kiosk');
          expect(intercom.state, 'idle');
        }

        // The ESPHome actions ride the same command and answer the same.
        final surface = EspEntitySurface(bus, commands, log, settings);
        expect(
          await surface.handleService('intercom_call', {'kiosk': 'Kitchen'}),
          {'id': 'kitchen', 'kiosk': 'Kitchen'},
        );
        expect(intercom.state, 'calling');
        expect(await surface.handleService('intercom_hangup', const {}), {});
        expect(intercom.state, 'ended');
        await expectLater(
          surface.handleService('intercom_call', {'kiosk': 'Garage'}),
          throwsStateError,
        );
        await expectLater(
          surface.handleService('intercom_hangup', const {}),
          throwsStateError,
        );
      },
    );

    test(
      'the answer opens the voice socket and the held button sends the microphone',
      () async {
        await build();
        await settle();
        // The callee: a loopback server that takes the socket the way the
        // remote server does, and records what arrives.
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final received = <Object?>[];
        final gotSocket = Completer<WebSocket>();
        server.listen((req) async {
          expect(req.uri.path, startsWith('/api/intercom/audio/'));
          final ws = await WebSocketTransformer.upgrade(req);
          ws.listen(received.add);
          gotSocket.complete(ws);
        });
        peers[0] = {...peers[0], 'address': '127.0.0.1', 'port': server.port};
        bus.publish(const FleetChanged(devices: []));
        await settle();
        answers['POST /api/intercom/call'] = (_) => {'status': 'ringing'};
        await commands.execute('intercomCall', {'id': 'kitchen'});
        final req = sent.lastWhere((r) => r.url.path == '/api/intercom/call');
        final callId = '${jsonDecode(req.body)['call']}';
        // The callee answers.
        final r = await commands.execute('intercomSignal', {
          'call': callId,
          'action': 'answer',
          'token': tokenFor(callId),
        });
        expect(r.ok, isTrue, reason: r.error);
        final ws = await gotSocket.future.timeout(const Duration(seconds: 3));
        await settle(100);
        expect(intercom.state, 'in_call');
        expect(intercom.call?.since, isNotNull);
        expect(audioCalls, contains('start'));
        // Push to talk: nothing goes out until the button is held.
        final chunk = Uint8List.fromList(List.filled(2560, 3));
        mic.add(chunk);
        await settle(50);
        expect(received.whereType<List<int>>(), isEmpty);
        await commands.execute('intercomTalk', {'on': true});
        mic.add(chunk);
        await settle(100);
        expect(received.whereType<List<int>>(), hasLength(1));
        final texts = received.whereType<String>().map(jsonDecode).toList();
        expect(
          texts.any((t) => t['type'] == 'talk' && t['on'] == true),
          isTrue,
        );
        await commands.execute('intercomTalk', {'on': false});
        mic.add(chunk);
        await settle(50);
        expect(received.whereType<List<int>>(), hasLength(1));
        // Hang up: the end frame goes out, then the socket closes.
        await commands.execute('intercomHangup', const {});
        await settle(100);
        expect(
          received
              .whereType<String>()
              .map(jsonDecode)
              .any((t) => t['type'] == 'end'),
          isTrue,
        );
        expect(intercom.state, 'ended');
        expect(intercom.call?.reason, 'ended');
        expect(audioCalls, contains('stop'));
        await ws.close();
        await server.close(force: true);
      },
    );

    test('hands free sends without the button and mute stops it', () async {
      await build(prefs: {'ks.intercom.talk_mode': 'handsfree'});
      await settle();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = <Object?>[];
      final gotSocket = Completer<WebSocket>();
      server.listen((req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.listen(received.add);
        gotSocket.complete(ws);
      });
      peers[0] = {...peers[0], 'address': '127.0.0.1', 'port': server.port};
      bus.publish(const FleetChanged(devices: []));
      await settle();
      answers['POST /api/intercom/call'] = (_) => {'status': 'ringing'};
      await commands.execute('intercomCall', {'id': 'kitchen'});
      final req = sent.lastWhere((r) => r.url.path == '/api/intercom/call');
      final callId = '${jsonDecode(req.body)['call']}';
      await commands.execute('intercomSignal', {
        'call': callId,
        'action': 'answer',
        'token': tokenFor(callId),
      });
      final ws = await gotSocket.future.timeout(const Duration(seconds: 3));
      await settle(100);
      final chunk = Uint8List.fromList(List.filled(2560, 3));
      mic.add(chunk);
      await settle(50);
      expect(received.whereType<List<int>>(), hasLength(1));
      await commands.execute('intercomMute', {'on': true});
      mic.add(chunk);
      await settle(50);
      expect(received.whereType<List<int>>(), hasLength(1));
      await ws.close();
      await settle(100);
      // The far side closing the socket ends the call here too.
      expect(intercom.state, 'ended');
      await server.close(force: true);
    });

    test(
      'a broadcast fans out over the ready kiosks and skips the rest',
      () async {
        await build();
        await settle();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final received = <Object?>[];
        final sockets = <WebSocket>[];
        server.listen((req) async {
          final ws = await WebSocketTransformer.upgrade(req);
          ws.listen(received.add);
          sockets.add(ws);
        });
        peers[0] = {...peers[0], 'address': '127.0.0.1', 'port': server.port};
        bus.publish(const FleetChanged(devices: []));
        await settle();
        answers['POST /api/intercom/call'] = (req) =>
            req.url.host == '127.0.0.1'
            ? {'status': 'listening'}
            : {'status': 'dnd'};
        final r = await commands.execute('intercomBroadcast', const {});
        expect(r.ok, isTrue, reason: r.error);
        await settle(150);
        expect(intercom.state, 'broadcasting');
        final call = intercom.call!;
        expect(call.kind, 'broadcast');
        expect(call.targets['kitchen']?['status'], 'listening');
        expect(call.targets['bedroom']?['status'], 'dnd');
        expect(sockets, hasLength(1));
        final chunk = Uint8List.fromList(List.filled(2560, 3));
        await commands.execute('intercomTalk', {'on': true});
        mic.add(chunk);
        await settle(100);
        expect(received.whereType<List<int>>(), hasLength(1));
        await commands.execute('intercomHangup', const {});
        await settle(100);
        expect(intercom.state, 'ended');
        for (final s in sockets) {
          await s.close();
        }
        await server.close(force: true);
      },
    );
  });

  group('announcements', () {
    test('Accept announcements off refuses Announce to all', () async {
      await build(prefs: {'ks.intercom.accept_announcements': false});
      final r = await commands.execute('intercomIncoming', {
        'call': 'b1',
        'kind': 'broadcast',
        'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
        'address': '192.168.1.70',
        'token': tokenFor('b1'),
      });
      expect((r.data as Map)['status'], 'refused');
      expect(intercom.state, 'idle');
      // A call still rings.
      final c = await commands.execute('intercomIncoming', {
        'call': 'c1',
        'kind': 'call',
        'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
        'address': '192.168.1.70',
        'token': tokenFor('c1'),
      });
      expect((c.data as Map)['status'], 'ringing');
    });

    test('the announce action speaks through Home Assistant here', () async {
      await build(
        prefs: {
          'ks.ha.url': 'http://ha.local:8123',
          'ks.ha.token': 'tkn',
          'ks.announcements.tts_engine': 'tts.piper',
        },
      );
      answers['POST /api/tts_get_url'] = (req) {
        expect(req.headers['Authorization'], 'Bearer tkn');
        expect(jsonDecode(req.body), {
          'engine_id': 'tts.piper',
          'message': 'Dinner is ready',
        });
        return {'url': 'http://ha.local:8123/api/tts_proxy/x.mp3'};
      };
      answers['GET /api/tts_proxy/x.mp3'] = (req) {
        expect(req.headers['Authorization'], 'Bearer tkn');
        return http.Response.bytes([1, 2, 3], 200);
      };
      final r = await commands.execute('announce', {
        'message': 'Dinner is ready',
      });
      expect(r.ok, isTrue, reason: r.error);
      expect((r.data as Map)['ms'], 1000);
      expect(intercom.state, 'listening');
      expect(intercom.call?.peer['name'], 'Home Assistant');
      expect(intercom.call?.automated, isTrue);
      expect(audioCalls, containsAll(['decode', 'chime', 'start']));
      expect(executed.map((e) => e.$1), contains('screenOn'));
      // The chime, then the second of clip, then the card closes.
      await settle(2600);
      expect(audioCalls.where((c) => c == 'write').length, greaterThan(10));
      expect(
        states.any(
          (s) =>
              s['state'] == 'ended' &&
              (s['call'] as Map?)?['reason'] == 'broadcast_over',
        ),
        isTrue,
      );
    });

    test('an audio URL plays without the chime when it is off', () async {
      await build(
        prefs: {
          'ks.ha.url': 'http://ha.local:8123',
          'ks.ha.token': 'tkn',
          'ks.announcements.chime': false,
        },
      );
      answers['GET /a.mp3'] = (req) {
        expect(req.headers.containsKey('Authorization'), isFalse);
        return http.Response.bytes([9], 200);
      };
      final r = await commands.execute('announce', {
        'url': 'http://sounds.local/a.mp3',
      });
      expect(r.ok, isTrue, reason: r.error);
      expect(audioCalls, isNot(contains('chime')));
      await settle(1400);
      expect(states.any((s) => s['state'] == 'ended'), isTrue);
    });

    test(
      'ESPHome forwards announcement overrides without changing settings',
      () async {
        await build(
          prefs: {
            'ks.ha.url': 'http://ha.local:8123',
            'ks.ha.token': 'tkn',
            'ks.announcements.tts_engine': 'tts.piper',
          },
        );
        final surface = EspEntitySurface(bus, commands, log, settings);
        final service = surface.buildServices().singleWhere(
          (s) => s['name'] == 'announce',
        );
        expect(
          service['args'],
          containsAll([
            {'name': 'chime', 'type': 'bool'},
            {'name': 'chime_file', 'type': 'string'},
            {'name': 'tts_engine', 'type': 'string'},
            {'name': 'audio_only', 'type': 'bool'},
          ]),
        );
        answers['POST /api/tts_get_url'] = (req) {
          expect(jsonDecode(req.body)['engine_id'], 'tts.cloud');
          return {'url': 'http://ha.local:8123/a.mp3'};
        };
        answers['GET /a.mp3'] = (_) => http.Response.bytes([9], 200);
        final interactions = <bool>[];
        bus.on<VoiceInteractionChanged>().listen(
          (e) => interactions.add(e.active),
        );
        expect(
          await surface.handleService('announce', {
            'message': 'Dinner is ready',
            'tts_engine': ' tts.cloud ',
            'chime': false,
            'chime_file': 'unused.mp3',
            'audio_only': true,
          }),
          {'ms': 1000},
        );
        expect(intercom.state, 'listening');
        expect(intercom.call?.toJson()['audioOnly'], isTrue);
        expect(executed, isEmpty);
        expect(audioCalls, isNot(contains('chime')));
        expect(settings.get(defs.announcementsTtsEngine), 'tts.piper');
        expect(settings.get(defs.announcementsChime), isTrue);
        await settle(1500);
        expect(audioWritten, isNotEmpty);
        expect(audioCalls, contains('stop'));
        expect(intercom.state, 'idle');
        expect(interactions, [true, false]);
      },
    );

    for (final engine in ['tts.piper', '']) {
      test(
        'an empty TTS override falls back with UI engine "$engine"',
        () async {
          await build(
            prefs: {
              'ks.ha.url': 'http://ha.local:8123',
              'ks.ha.token': 'tkn',
              'ks.announcements.tts_engine': engine,
              'ks.announcements.chime': false,
            },
          );
          answers['GET /api/states'] = (_) => [
            {
              'entity_id': 'tts.piper',
              'attributes': {'friendly_name': 'Piper'},
            },
          ];
          answers['POST /api/tts_get_url'] = (req) {
            expect(jsonDecode(req.body)['engine_id'], 'tts.piper');
            return {'url': 'http://ha.local:8123/a.mp3'};
          };
          answers['GET /a.mp3'] = (_) => http.Response.bytes([9], 200);
          final result = await commands.execute('announce', {
            'message': 'Hello',
            'tts_engine': ' ',
          });
          expect(result.ok, isTrue, reason: result.error);
          expect(intercom.call?.audioOnly, isFalse);
          expect(executed.map((e) => e.$1), contains('screenOn'));
          expect(sent.any((r) => r.url.path == '/api/states'), engine.isEmpty);
        },
      );
    }

    test(
      'ESPHome chime overrides use local files and fall back to the UI sound',
      () async {
        await build(
          prefs: {
            'ks.announcements.chime': false,
            'ks.announcements.chime_file': 'default.mp3',
          },
        );
        final root = await Directory.systemTemp.createTemp('announce-sounds-');
        final sounds = await Directory('${root.path}/sounds').create();
        for (final name in ['default.mp3', 'custom.wav']) {
          await File('${sounds.path}/$name').writeAsBytes([1]);
        }
        final originalPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _AnnouncementPaths(root.path);
        addTearDown(() async {
          PathProviderPlatform.instance = originalPaths;
          await root.delete(recursive: true);
        });
        answers['GET /a.mp3'] = (_) => http.Response.bytes([9], 200);
        final surface = EspEntitySurface(bus, commands, log, settings);
        for (final sound in [
          ' custom.wav ',
          '',
          'missing.mp3',
          '../custom.wav',
        ]) {
          await surface.handleService('announce', {
            'url': 'http://sounds.local/a.mp3',
            'chime': true,
            'chime_file': sound,
          });
          final chime = executed.lastWhere((e) => e.$1 == 'playChime').$2;
          expect(
            chime['source'],
            '${sounds.path}/${sound.trim() == 'custom.wav' ? 'custom.wav' : 'default.mp3'}',
          );
          expect(audioCalls, isNot(contains('chime')));
          await commands.execute('intercomHangup', const {});
          await commands.execute('intercomDismiss', const {});
        }
        await settings.set(defs.announcementsChimeFile, 'missing.mp3');
        await surface.handleService('announce', {
          'url': 'http://sounds.local/a.mp3',
          'chime': true,
          'chime_file': '',
        });
        expect(audioCalls, contains('chime'));
        expect(settings.get(defs.announcementsChime), isFalse);
      },
    );

    test('repeat plays the clip that many times with a pause', () async {
      await build(prefs: {'ks.announcements.chime': false});
      answers['GET /a.mp3'] = (_) => http.Response.bytes([9], 200);
      final r = await commands.execute('announce', {
        'url': 'http://sounds.local/a.mp3',
        'repeat': 3,
      });
      expect(r.ok, isTrue, reason: r.error);
      // Three seconds of clip and two pauses of 600 ms.
      expect((r.data as Map)['ms'], 3000 + 1200);
      await commands.execute('intercomHangup', const {});
      await commands.execute('intercomDismiss', const {});
      final paced = await commands.execute('announce', {
        'url': 'http://sounds.local/a.mp3',
        'repeat': 2,
        'repeat_pause': 2.5,
      });
      expect(paced.ok, isTrue, reason: paced.error);
      expect((paced.data as Map)['ms'], 2000 + 2500);
      await commands.execute('intercomHangup', const {});
    });

    test('Enable announcements off refuses the action', () async {
      await build(prefs: {'ks.announcements.enabled': false});
      final r = await commands.execute('announce', {'message': 'Hello'});
      expect(r.ok, isFalse);
      expect(r.error, contains('off'));
      final none = await commands.execute('announce', const {});
      expect(none.ok, isFalse);
    });
  });

  group('the page and the microphone', () {
    Future<void> incoming() => commands.execute('intercomIncoming', {
      'call': 'c1',
      'kind': 'call',
      'from': {'id': 'kitchen', 'name': 'Kitchen', 'port': 2324},
      'address': '192.168.1.70',
      'token': tokenFor('c1'),
    });

    test(
      'the page is asked to let go of the microphone for the call',
      () async {
        await build();
        final hub = MicHub.instance;
        await hub.setBrowserCapturing(true);
        final holds = <bool>[];
        bus.on<IntercomMicHold>().listen((e) {
          holds.add(e.hold);
          // Voice Satellite stops its capture on the hold.
          if (e.hold) unawaited(hub.setBrowserCapturing(false));
        });
        answers['POST /api/intercom/call/c1'] = (_) => {'ok': true};
        await incoming();
        final r = await commands.execute('intercomAnswer', const {});
        expect(r.ok, isTrue, reason: r.error);
        expect(intercom.state, 'in_call');
        expect(holds, [true]);
        expect(hub.capturing, isTrue);
        expect(intercom.status()['micBusy'], isFalse);
        await intercom.hangup();
        expect(holds, [true, false]);
        expect(hub.capturing, isFalse);
      },
    );

    test(
      'a page that keeps the microphone leaves the call listen only',
      () async {
        await build();
        intercom.pageMicWait = const Duration(milliseconds: 50);
        final hub = MicHub.instance;
        await hub.setBrowserCapturing(true);
        final holds = <bool>[];
        bus.on<IntercomMicHold>().listen((e) => holds.add(e.hold));
        answers['POST /api/intercom/call/c1'] = (_) => {'ok': true};
        await incoming();
        final r = await commands.execute('intercomAnswer', const {});
        expect(r.ok, isTrue, reason: r.error);
        expect(intercom.state, 'in_call');
        expect(holds, [true]);
        expect(hub.capturing, isFalse);
        expect(intercom.status()['micBusy'], isTrue);
        await intercom.hangup();
        expect(holds, [true, false]);
        expect(intercom.status()['micBusy'], isFalse);
      },
    );

    test('a broadcast nobody lets the microphone go for is refused', () async {
      await build();
      await settle();
      intercom.pageMicWait = const Duration(milliseconds: 50);
      await MicHub.instance.setBrowserCapturing(true);
      final holds = <bool>[];
      bus.on<IntercomMicHold>().listen((e) => holds.add(e.hold));
      final r = await commands.execute('intercomBroadcast', const {});
      expect(r.ok, isFalse);
      expect(r.error, 'the page holds the microphone');
      expect(intercom.state, 'idle');
      // Nothing is live, so the page gets its microphone back at once.
      await settle(10);
      expect(holds, [true, false]);
    });
  });

  group('do not disturb', () {
    test('the tile flips the answer mode and puts it back', () async {
      await build(prefs: {'ks.intercom.answer_mode': 'auto'});
      await commands.execute('intercomSetDnd', {'on': true});
      expect(settings.get(defs.intercomAnswerMode), 'dnd');
      expect(intercom.dnd, isTrue);
      await commands.execute('intercomSetDnd', {'on': false});
      expect(settings.get(defs.intercomAnswerMode), 'auto');
      expect(intercom.dnd, isFalse);
    });

    test('the status carries the modes', () async {
      await build();
      final status = intercom.status();
      expect(status['answerMode'], 'ring');
      expect(status['talkMode'], 'ptt');
      expect(status['state'], 'idle');
      expect(status['call'], isNull);
    });

    test('hands free is the talk mode whatever the device reports', () async {
      await build(prefs: {'ks.intercom.talk_mode': 'handsfree'});
      expect(intercom.status()['talkMode'], 'handsfree');
    });
  });
}
