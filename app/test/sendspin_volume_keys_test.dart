import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/sendspin/ma_remote_player.dart';
import 'package:kiosk_satellite/managers/sendspin/music_assistant_api.dart';
import 'package:kiosk_satellite/managers/sendspin/sendspin_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The hardware volume keys steering a followed player (issue #544): when
/// the manager wants them, and how presses turn into player commands.

class _Api extends MusicAssistantApi {
  _Api() : super(baseUrl: 'ma.local', token: 'token');
  @override
  Future<MusicAssistantResult> call(
    String command, {
    Map<String, Object?> args = const {},
    Duration timeout = const Duration(seconds: 15),
  }) async => const MusicAssistantResult.success(null, {});
}

class _Remote extends MaRemotePlayer {
  _Remote({
    required super.playerId,
    required super.onSnapshot,
    required super.log,
  }) : super(baseUrl: 'ma.local', token: 'token');
  int level = 40;
  bool playing = true;
  bool supported = true;
  final writes = <int>[];
  final mutes = <bool>[];
  Completer<bool>? gate;

  void emit() => onSnapshot({
    'title': 'Song',
    'playing': playing,
    'volume': level,
    'supportedCommands': [if (supported) 'volume'],
  });

  @override
  void start() => emit();

  @override
  Future<void> stop() async {}

  @override
  Future<bool> setVolume(int percent) async {
    writes.add(percent);
    final pending = gate;
    gate = null;
    if (pending != null) await pending.future;
    level = percent;
    emit();
    return true;
  }

  @override
  Future<bool> setMute(bool muted) async {
    mutes.add(muted);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kiosk_satellite/sendspin');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late EventBus bus;
  late SendspinManager manager;
  late SettingsManager settings;
  final remotes = <_Remote>[];

  Future<void> boot(String source, {String mode = 'playing'}) async {
    SharedPreferences.setMockInitialValues({
      'ks.device.name': 'Tablet',
      'ks.sendspin.enabled': true,
      'ks.sendspin.client_id': 'tablet',
      'ks.sendspin.player_source': source,
      'ks.sendspin.player': source.isEmpty ? '' : '$source:p1',
      'ks.sendspin.ma_url': 'ma.local',
      'ks.sendspin.ma_token': 'token',
      'ks.ha.url': 'http://ha.local',
      'ks.ha.token': 'token',
      'ks.sendspin.lyrics': false,
      'ks.sendspin.volume_keys': mode,
    });
    remotes.clear();
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    manager = SendspinManager(bus, commands, log, settings);
    manager.apiFactory = ({required baseUrl, required token}) => _Api();
    _Remote create(String id, void Function(Map<String, Object?>?) onSnapshot) {
      final remote = _Remote(playerId: id, onSnapshot: onSnapshot, log: log);
      remotes.add(remote);
      return remote;
    }

    manager.remoteFactory =
        ({
          required baseUrl,
          required token,
          required playerId,
          required onSnapshot,
          required log,
          String label = 'remote player',
        }) => create(playerId, onSnapshot);
    manager.haRemoteFactory =
        ({
          required baseUrl,
          required token,
          required entityId,
          required onSnapshot,
          required log,
        }) => create(entityId, onSnapshot);
    await manager.init();
    await pumpEventQueue();
  }

  Future<void> press(String direction) async {
    bus.publish(VolumeKeyPressed(direction: direction));
    await pumpEventQueue();
  }

  tearDown(() async {
    await manager.dispose();
    await bus.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('wanted', () {
    test('off never routes the keys', () async {
      await boot('ma', mode: 'off');
      expect(manager.volumeKeysWanted(viewShown: true), isFalse);
      expect(manager.volumeKeysWanted(viewShown: false), isFalse);
    });

    test('while playing: the view or playback', () async {
      await boot('ma');
      expect(manager.volumeKeysWanted(viewShown: false), isTrue);
      expect(manager.volumeKeysWanted(viewShown: true), isTrue);
      remotes.single
        ..playing = false
        ..emit();
      expect(manager.volumeKeysWanted(viewShown: false), isFalse);
      expect(manager.volumeKeysWanted(viewShown: true), isTrue);
    });

    test('while Now Playing is shown: the view alone', () async {
      await boot('ma', mode: 'now_playing');
      expect(manager.volumeKeysWanted(viewShown: false), isFalse);
      expect(manager.volumeKeysWanted(viewShown: true), isTrue);
    });

    test('this device as the source keeps the keys', () async {
      await boot('');
      expect(manager.volumeKeysWanted(viewShown: true), isFalse);
    });

    test('a player without a volume keeps the keys', () async {
      await boot('ha');
      remotes.single
        ..supported = false
        ..emit();
      expect(manager.volumeKeysWanted(viewShown: true), isFalse);
    });

    test('the setting flips live', () async {
      await boot('ma', mode: 'off');
      await settings.set(defs.sendspinVolumeKeys, 'playing');
      expect(manager.volumeKeysWanted(viewShown: false), isTrue);
    });
  });

  group('presses', () {
    test('up and down step the player by five and stack', () async {
      await boot('ma');
      final remote = remotes.single;
      await press('up');
      expect(remote.writes, [45]);
      expect(manager.volumeLevel, 45);
      await press('up');
      await press('down');
      await press('down');
      expect(remote.writes, [45, 50, 45, 40]);
      expect(manager.volumeNudge.value, 4);
    });

    test('presses while a command is out fold into one trailing one', () async {
      await boot('ha');
      final remote = remotes.single;
      final gate = Completer<bool>();
      remote.gate = gate;
      await press('up');
      await press('up');
      await press('up');
      expect(remote.writes, [45]);
      // The slider already shows where the presses are heading.
      expect(manager.volumeLevel, 55);
      gate.complete(true);
      await pumpEventQueue();
      expect(remote.writes, [45, 55]);
      expect(remote.level, 55);
    });

    test('the level stays within the range', () async {
      await boot('ma');
      final remote = remotes.single
        ..level = 98
        ..emit();
      await press('up');
      expect(remote.writes, [100]);
      await press('up');
      expect(remote.writes, [100, 100]);
      remote
        ..level = 3
        ..emit();
      // The last press's target still stands in for the report for a
      // moment, so step from the fresh report only once it lapses; here
      // the report arrived under the hold, and the next press stacks on
      // the target the way a person holding the key expects.
      expect(manager.volumeLevel, 100);
    });

    test('mute toggles the player', () async {
      await boot('ma');
      final remote = remotes.single;
      await press('mute');
      expect(remote.mutes, [true]);
      expect(remote.writes, isEmpty);
    });

    test('this device ignores a stray press', () async {
      await boot('');
      final before = settings.get(defs.mediaVolume);
      await press('up');
      expect(settings.get(defs.mediaVolume), before);
      expect(manager.volumeNudge.value, 0);
    });
  });
}
