import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/remote/remote_manager.dart';
import 'package:kiosk_satellite/managers/device_camera/camera_resolutions.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);
  late EventBus bus;
  late Logger log;
  late CommandRegistry commands;
  late SettingsManager settings;
  late RemoteManager remote;
  late int port;
  late String token;
  final clients = <WebSocket>[];

  setUp(() async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = probe.port;
    await probe.close();
    SharedPreferences.setMockInitialValues({
      'ks.browser.start_url': 'http://ha.local/',
      'ks.remote.enabled': true,
      'ks.remote.password': 'secret',
      'ks.remote.port': port,
    });
    bus = EventBus();
    log = Logger();
    commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    remote = RemoteManager(bus, commands, log, settings);
    await remote.init();
    final http = HttpClient();
    final request = await http.post('127.0.0.1', port, '/api/login');
    request.write(jsonEncode({'password': 'secret'}));
    final response = await request.close();
    token =
        (jsonDecode(await utf8.decodeStream(response)) as Map)['token']
            as String;
    http.close();
  });
  tearDown(() async {
    for (final client in clients) {
      await client.close();
    }
    clients.clear();
    await remote.dispose();
    await settings.dispose();
    await bus.dispose();
    await log.dispose();
  });

  Future<({WebSocket socket, Stream<Map> messages})> connect([
    String? auth,
  ]) async {
    final socket = await WebSocket.connect(
      'ws://127.0.0.1:$port/api/ws?token=${auth ?? token}',
    );
    clients.add(socket);
    final messages = socket
        .map((raw) => jsonDecode(raw as String) as Map)
        .asBroadcastStream();
    // Subscribe before the initial asynchronous state arrives.
    messages.listen((_) {});
    return (socket: socket, messages: messages);
  }

  Future<Map> matching(Stream<Map> messages, bool Function(Map) match) =>
      messages.firstWhere(match).timeout(const Duration(seconds: 3));
  Future<void> subscribe(
    ({WebSocket socket, Stream<Map> messages}) client,
    List<String> topics,
  ) async {
    final ack = matching(client.messages, (m) => m['id'] == 'subscription');
    client.socket.add(
      jsonEncode({'type': 'subscribe', 'id': 'subscription', 'topics': topics}),
    );
    await ack;
  }

  test(
    'on-device settings push masked deltas and reconnect sends current settings',
    () async {
      final client = await connect();
      final snapshot = matching(
        client.messages,
        (m) => m['type'] == 'settings',
      );
      await subscribe(client, ['settings']);
      expect((await snapshot)['snapshot'], true);
      final changed = matching(client.messages, (m) => m['type'] == 'settings');
      await settings.set(defs.screensaverMode, 'black');
      await settings.set(defs.haToken, 'do-not-disclose');
      final message = await changed;
      final updates = {
        for (final s in message['settings'] as List) s['key']: s['value'],
      };
      expect(updates['screensaver.mode'], 'black');
      expect(updates['ha.token'], '__set__');
      expect(jsonEncode(message), isNot(contains('do-not-disclose')));
      expect(updates.length, 2);
      final next = await connect();
      final fresh = matching(next.messages, (m) => m['type'] == 'settings');
      await subscribe(next, ['settings']);
      expect(
        (await fresh)['settings'],
        contains(
          predicate(
            (dynamic s) =>
                s['key'] == 'screensaver.mode' && s['value'] == 'black',
          ),
        ),
      );
    },
  );

  test(
    'get requests answer the boot reads and the snapshot names pages',
    () async {
      commands.register(
        Command(
          name: 'getDeviceInfo',
          description: '',
          handler: (_) async => const CommandResult.ok({
            'name': 'Test kiosk',
            'appVersion': '2026.9.59',
            'buildNumber': 260,
          }),
        ),
      );
      final client = await connect();
      final snapshot = matching(
        client.messages,
        (m) => m['type'] == 'settings',
      );
      await subscribe(client, ['settings']);
      expect((await snapshot)['subpageHints'], isA<Map>());
      final info = matching(client.messages, (m) => m['id'] == 'info');
      client.socket.add(
        jsonEncode({'type': 'get', 'id': 'info', 'name': 'info'}),
      );
      final device = (await info)['data'] as Map;
      expect(device['appVersion'], '2026.9.59');
      expect(device['buildNumber'], 260);
      expect(device.containsKey('currentUrl'), isTrue);
      final read = matching(client.messages, (m) => m['id'] == 'settings');
      client.socket.add(
        jsonEncode({'type': 'get', 'id': 'settings', 'name': 'settings'}),
      );
      final payload = (await read)['data'] as Map;
      expect(payload['settings'], isA<List>());
      expect(payload['subpageHints'], isA<Map>());
      final logs = matching(client.messages, (m) => m['id'] == 'logs');
      client.socket.add(
        jsonEncode({'type': 'get', 'id': 'logs', 'name': 'logs'}),
      );
      expect(((await logs)['data'] as Map)['logs'], isA<List>());
      final refused = matching(client.messages, (m) => m['id'] == 'nope');
      client.socket.add(
        jsonEncode({'type': 'get', 'id': 'nope', 'name': 'secrets'}),
      );
      expect((await refused)['ok'], false);
    },
  );

  test(
    'camera choices push to an open admin without a settings write',
    () async {
      final client = await connect();
      await subscribe(client, ['settings']);
      final update = matching(client.messages, (m) => m['type'] == 'settings');
      settings.updateCameraStreamingCapabilities(
        CameraStreamingCapabilities.fromJson({
          'withAnalysis': ['320x240', '640x480', '1280x720'],
          'withoutAnalysis': ['320x240', '640x480', '1280x720', '1920x1080'],
          'encoderRejected': <String>[],
          'captureRejected': <String>[],
        }),
      );
      final entries = (await update)['settings'] as List;
      expect(entries, hasLength(1));
      expect(entries.single['key'], defs.cameraRtspResolution.key);
      expect(entries.single['options'], ['320x240', '640x480', '1280x720']);
      expect(entries.single['optionLabels']['1280x720'], '1280 × 720');
      expect(entries.single['value'], '640x480');
      expect(entries.single['notice'], contains('Turn off Motion analysis'));
      expect(entries.single['notice'], contains('1920 × 1080'));
    },
  );

  test('only voice-related settings ask the voice cards to re-read', () async {
    final client = await connect();
    await subscribe(client, ['voice']);
    final received = <Map>[];
    client.messages.listen(received.add);
    await settings.set(defs.screensaverMode, 'black');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(received.where((m) => m['type'] == 'update'), isEmpty);
    final voice = matching(
      client.messages,
      (m) => m['type'] == 'update' && m['topic'] == 'voice',
    );
    await settings.set(defs.haSatelliteEntity, 'assist_satellite.kiosk');
    await voice;
  });

  test('a settings write is not a status change', () async {
    var reasons = ['wake_word'];
    commands.register(
      Command(
        name: 'getServiceStatus',
        description: '',
        handler: (_) async =>
            CommandResult.ok({'running': true, 'reasons': reasons}),
      ),
    );
    commands.register(
      Command(
        name: 'getSystemPermissions',
        description: '',
        handler: (_) async => const CommandResult.ok({'microphone': true}),
      ),
    );
    commands.register(
      Command(
        name: 'hasUiGuard',
        description: '',
        handler: (_) async => const CommandResult.ok(false),
      ),
    );
    final client = await connect();
    final topics = ['ha', 'media', 'service', 'update', 'plugin-tiles'];
    final first = matching(
      client.messages,
      (m) => m['type'] == 'update' && m['topic'] == 'service',
    );
    await subscribe(client, topics);
    // The service sample arrives once, with its results attached.
    expect(((await first)['results'] as Map)['getServiceStatus'], isNotNull);
    final received = <Map>[];
    client.messages.listen(received.add);
    await settings.set(defs.keepScreenOn, !settings.get(defs.keepScreenOn));
    await settings.set(defs.screensaverMode, 'black');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(received.where((m) => m['type'] == 'update'), isEmpty);
    // A manager announcing an unchanged sample sends nothing either.
    bus.publish(const RemoteStatusChanged('service'));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(received.where((m) => m['type'] == 'update'), isEmpty);
    // A changed one carries the new results, so the page paints from
    // the push without a command of its own.
    reasons = ['wake_word', 'camera'];
    final moved = matching(
      client.messages,
      (m) => m['type'] == 'update' && m['topic'] == 'service',
    );
    bus.publish(const RemoteStatusChanged('service'));
    final results = (await moved)['results'] as Map;
    expect((results['getServiceStatus'] as Map)['data']['reasons'], [
      'wake_word',
      'camera',
    ]);
    // The settings a status command reads straight from the store.
    final ha = matching(
      client.messages,
      (m) => m['type'] == 'update' && m['topic'] == 'ha',
    );
    await settings.set(defs.haUrl, 'http://ha.example');
    await ha;
    final media = matching(
      client.messages,
      (m) => m['type'] == 'update' && m['topic'] == 'media',
    );
    await settings.set(
      defs.sendspinEnabled,
      !settings.get(defs.sendspinEnabled),
    );
    await media;
  });

  test('subscriptions filter events and can be replaced', () async {
    final client = await connect();
    await subscribe(client, []);
    final received = <Map>[];
    client.messages.listen(received.add);
    bus.publish(const ScreenStateChanged(on: false));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(received.where((m) => m['type'] == 'event'), isEmpty);
    await subscribe(client, ['events']);
    final event = matching(client.messages, (m) => m['type'] == 'event');
    bus.publish(const ScreenStateChanged(on: true));
    expect((await event)['event'], 'screenon');
  });

  test('full screen views reach event subscribers and the snapshot', () async {
    bus.publish(const FullscreenViewChanged(view: 'intercom', shown: true));
    await pumpEventQueue();
    final client = await connect();
    final state = await matching(client.messages, (m) => m['type'] == 'state');
    expect((state['device'] as Map)['intercomShown'], true);
    expect((state['device'] as Map)['nowPlayingShown'], false);
    await subscribe(client, ['events']);
    final view = matching(
      client.messages,
      (m) => m['type'] == 'fullscreen-view',
    );
    bus.publish(const FullscreenViewChanged(view: 'nowPlaying', shown: true));
    final message = await view;
    expect(message['view'], 'nowPlaying');
    expect(message['shown'], true);
  });

  test(
    'concurrent commands keep IDs and settings use the same validator',
    () async {
      commands.register(
        Command(
          name: 'echo',
          description: '',
          handler: (p) async {
            await Future<void>.delayed(
              Duration(milliseconds: p['delay'] as int),
            );
            return CommandResult.ok(p['value']);
          },
        ),
      );
      final client = await connect();
      final slow = matching(client.messages, (m) => m['id'] == 1);
      final fast = matching(client.messages, (m) => m['id'] == 2);
      client.socket.add(
        jsonEncode({
          'type': 'command',
          'id': 1,
          'name': 'echo',
          'params': {'delay': 100, 'value': 'slow'},
        }),
      );
      client.socket.add(
        jsonEncode({
          'type': 'command',
          'id': 2,
          'name': 'echo',
          'params': {'delay': 0, 'value': 'fast'},
        }),
      );
      expect((await fast)['data'], 'fast');
      expect((await slow)['data'], 'slow');
      final saved = matching(client.messages, (m) => m['id'] == 3);
      client.socket.add(
        jsonEncode({
          'type': 'settings',
          'id': 3,
          'values': {'screensaver.mode': 'black', 'missing.setting': true},
        }),
      );
      final result = await saved;
      expect(result['ok'], false);
      expect(result['rejected'], ['missing.setting']);
      expect(settings.get(defs.screensaverMode), 'black');
      final denied = matching(client.messages, (m) => m['id'] == 4);
      client.socket.add(
        jsonEncode({'type': 'command', 'id': 4, 'name': 'fleetAccept'}),
      );
      expect((await denied)['ok'], false);
    },
  );

  test('fleet credentials cannot open the admin socket', () async {
    final issued = await commands.execute('issueFleetToken', {
      'leader': 'test',
    });
    await expectLater(
      WebSocket.connect('ws://127.0.0.1:$port/api/ws?token=${issued.data}'),
      throwsA(isA<WebSocketException>()),
    );
  });
}
