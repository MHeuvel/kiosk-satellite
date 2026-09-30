import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/sendspin/remote_player.dart';
import 'package:kiosk_satellite/managers/sendspin/sendspin_manager.dart';
import 'package:kiosk_satellite/managers/sendspin/session_player.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Local Media Session player (issue #722): with this device as the
/// source, the Now Playing surfaces follow whichever other app plays on
/// it through its Android media session.

class _Session extends SessionPlayer {
  _Session({required super.package, required super.onSnapshot})
    : super(log: Logger());

  final commands = <String>[];

  @override
  void start() {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> control(String command) async {
    commands.add(command);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const sendspin = MethodChannel('kiosk_satellite/sendspin');
  const sessions = MethodChannel('kiosk_satellite/media_sessions');

  group('PlayerSource', () {
    test('parses and stores a media session pick', () {
      final app = PlayerSource.parse('session:com.spotify.music');
      expect(app.kind, PlayerSourceKind.mediaSession);
      expect(app.id, 'com.spotify.music');
      expect(app.value, 'session:com.spotify.music');
      expect(PlayerSource.parse('session:*').id, SessionPlayer.anyApp);
    });

    test('actions name the local media session', () {
      expect(SendspinManager.isLocalSessionName('media_session'), true);
      expect(SendspinManager.isLocalSessionName('Local Media Session'), true);
      expect(SendspinManager.isLocalSessionName('sendspin'), false);
      expect(SendspinManager.isLocalSessionName(''), false);
    });
  });

  group('SessionPlayer.snapshotFrom', () {
    test('types the platform map', () {
      final snap = SessionPlayer.snapshotFrom({
        'title': 'Waiting Room',
        'artist': 'Phoebe Bridgers',
        'playing': true,
        'supportedCommands': <Object?>['play', 'pause', 'seek'],
      })!;
      expect(snap['title'], 'Waiting Room');
      expect(snap['supportedCommands'], ['play', 'pause', 'seek']);
    });

    test('nothing to show without a title', () {
      expect(SessionPlayer.snapshotFrom({'title': ' '}), isNull);
      expect(SessionPlayer.snapshotFrom(null), isNull);
    });

    test('never hands the controls an empty command list', () {
      // Empty reads as "anything goes" to the controls, shuffle included.
      final snap = SessionPlayer.snapshotFrom({
        'title': 'Song',
        'supportedCommands': const <Object?>[],
      })!;
      expect(snap['supportedCommands'], ['play', 'pause']);
    });
  });

  group('SendspinManager with a media session', () {
    late EventBus bus;
    late SendspinManager manager;
    late SettingsManager settings;
    late CommandRegistry commands;
    final created = <_Session>[];

    Future<void> boot(String pick) async {
      SharedPreferences.setMockInitialValues({
        'ks.device.name': 'Tablet',
        'ks.sendspin.enabled': true,
        'ks.sendspin.client_id': 'tablet',
        'ks.sendspin.player_source': '',
        'ks.sendspin.player': pick,
        'ks.sendspin.player_name': 'Local Media Session',
        'ks.sendspin.lyrics': false,
        'ks.audio.media_volume': 30,
      });
      created.clear();
      messenger.setMockMethodCallHandler(sendspin, (call) async => null);
      messenger.setMockMethodCallHandler(sessions, (call) async => null);
      bus = EventBus();
      final log = Logger();
      commands = CommandRegistry(log);
      settings = SettingsManager(bus, commands, log);
      await settings.init();
      manager = SendspinManager(bus, commands, log, settings);
      manager.sessionRemoteFactory =
          ({required package, required onSnapshot, required log}) {
            final session = _Session(package: package, onSnapshot: onSnapshot);
            created.add(session);
            return session;
          };
      await manager.init();
      await pumpEventQueue();
    }

    tearDown(() async {
      await manager.dispose();
      await bus.dispose();
      messenger.setMockMethodCallHandler(sendspin, null);
      messenger.setMockMethodCallHandler(sessions, null);
    });

    test('follows the playing app and routes the transport to it', () async {
      await boot('session:*');
      expect(created.single.package, SessionPlayer.anyApp);
      // The load-time migration leaves this device's own pick under its
      // source instead of reading it as a Music Assistant player.
      expect(settings.get(defs.sendspinPlayerSource), '');
      expect(settings.get(defs.sendspinPlayerActive), true);
      // This device's Sendspin player is not what the surfaces follow, so
      // its switch leaves the page with the rest of its rows.
      expect(settings.visible(defs.sendspinEnabled), false);
      created.single.handleSnapshot({
        'title': 'Song',
        'playing': true,
        'appName': 'Spotify',
        'supportedCommands': ['play', 'pause', 'next'],
      });
      expect(manager.nowPlaying.value?['title'], 'Song');
      await manager.control('next');
      expect(created.single.commands, ['next']);
    });

    test('the volume is the device media volume', () async {
      await boot('session:*');
      created.single.handleSnapshot({
        'title': 'Song',
        'playing': true,
        'supportedCommands': ['play', 'pause'],
      });
      expect(manager.volumeAvailable, true);
      expect(manager.volumeLevel, 30);
      await manager.setVolume(55);
      expect(settings.get(defs.mediaVolume), 55);
      // The keys already move the device volume natively.
      expect(manager.volumeKeysWanted(viewShown: true), false);
    });

    test('the chip names the playing app', () async {
      await boot('session:*');
      created.single.handleSnapshot({
        'title': 'Song',
        'playing': true,
        'appName': 'Spotify',
        'supportedCommands': ['play', 'pause'],
      });
      expect(manager.playerChipName, 'Spotify');
    });

    test('the pick stands with this device as the source', () async {
      await boot('session:*');
      // A settings write elsewhere runs the reconcile; the pick is one of
      // this device's own, so it stays.
      await settings.set(defs.sendspinDuckPercent, 5);
      await pumpEventQueue();
      expect(settings.get(defs.sendspinPlayer), 'session:*');
      // Another source takes it away.
      await settings.set(defs.sendspinPlayerSource, 'ha');
      await pumpEventQueue();
      expect(settings.get(defs.sendspinPlayer), '');
    });

    test('the media summary follows the app and skips position ticks '
        '(issue #741)', () async {
      await boot('session:*');
      final seen = <Map<String, String>>[];
      final sub = bus.on<MediaSummaryChanged>().listen(
        (e) => seen.add(e.summary),
      );
      Map<String, Object?> snap(bool playing, int positionMs) => {
        'title': 'Song',
        'artist': 'Band',
        'playing': playing,
        'positionMs': positionMs,
        'appName': 'YouTube',
        'supportedCommands': ['play', 'pause', 'next', 'previous'],
      };
      created.single.handleSnapshot(snap(true, 1000));
      created.single.handleSnapshot(snap(true, 2000));
      created.single.handleSnapshot(snap(false, 2000));
      created.single.handleSnapshot(null);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.map((s) => s['state']), ['playing', 'paused', 'idle']);
      expect(seen.first, {
        'state': 'playing',
        'title': 'Song',
        'artist': 'Band',
        'source': 'YouTube',
      });
      final state = await commands.execute('mediaPlayerState', const {});
      expect((state.data as Map)['state'], 'idle');
    });

    test('the action picks it by name', () async {
      await boot('');
      final result = await commands.execute('mediaPlayerSet', {
        'source': 'device',
        'player': 'media_session',
      });
      expect(result.ok, true);
      await pumpEventQueue();
      expect(settings.get(defs.sendspinPlayer), 'session:*');
      expect(created.single.package, SessionPlayer.anyApp);
      await commands.execute('mediaPlayerSet', {'source': 'device'});
      await pumpEventQueue();
      expect(settings.get(defs.sendspinPlayer), '');
      expect(settings.visible(defs.sendspinEnabled), true);
    });
  });
}
