import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/sendspin/ma_remote_player.dart';
import 'package:kiosk_satellite/managers/sendspin/music_assistant_api.dart';
import 'package:kiosk_satellite/managers/sendspin/sendspin_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Now Playing volume slider while this device plays in a Music
/// Assistant group (issue #867): the whole group's volume and mute, or
/// this device's own with the switch off or no group.

class _Api extends MusicAssistantApi {
  _Api() : super(baseUrl: 'ma.local', token: 'token');

  final calls = <(String, Map<String, Object?>)>[];

  @override
  Future<MusicAssistantResult> call(
    String command, {
    Map<String, Object?> args = const {},
    Duration timeout = const Duration(seconds: 15),
  }) async {
    calls.add((command, args));
    return const MusicAssistantResult.success(null, {});
  }
}

class _Watcher extends MaRemotePlayer {
  _Watcher({
    required super.playerId,
    required super.onSnapshot,
    required super.log,
  }) : super(baseUrl: 'ma.local', token: 'token');

  final groupLevels = <int>[];
  final groupMutes = <bool>[];

  @override
  void start() {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> setGroupVolume(int percent) async {
    groupLevels.add(percent);
    return true;
  }

  @override
  Future<bool> setGroupMute(bool muted) async {
    groupMutes.add(muted);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kiosk_satellite/sendspin');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SettingsManager settings;
  late SendspinManager manager;
  late _Api api;
  _Watcher? watcher;

  Future<void> boot({bool groupVolume = true}) async {
    SharedPreferences.setMockInitialValues({
      'ks.sendspin.enabled': true,
      'ks.sendspin.client_id': 'tablet',
      'ks.sendspin.ma_url': 'ma.local',
      'ks.sendspin.ma_token': 'token',
      'ks.sendspin.lyrics': false,
      'ks.sendspin.group_volume': groupVolume,
      'ks.audio.media_volume': 30,
    });
    watcher = null;
    messenger.setMockMethodCallHandler(channel, (call) async => true);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    manager = SendspinManager(bus, commands, log, settings);
    api = _Api();
    manager.apiFactory = ({required baseUrl, required token}) => api;
    manager.remoteFactory =
        ({
          required baseUrl,
          required token,
          required playerId,
          required onSnapshot,
          required log,
          String label = 'remote player',
        }) => watcher = _Watcher(
          playerId: playerId,
          onSnapshot: onSnapshot,
          log: log,
        );
    await manager.init();
    addTearDown(manager.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // The local stream plays a track.
    const codec = StandardMethodCodec();
    for (final (method, args) in [
      ('metadataChanged', {'title': 'Song', 'durationMs': 180000}),
      ('playingChanged', {'playing': true}),
    ]) {
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );
    }
  }

  void grouped(int? level, {bool muted = false}) => watcher!.onSnapshot({
    'title': 'Song',
    'playing': true,
    'groupVolume': ?level,
    if (level != null) 'groupMuted': muted,
  });

  test('the switch is on by default on the Sendspin Player page', () {
    expect(defs.sendspinGroupVolume.defaultValue, isTrue);
    expect(defs.sendspinGroupVolume.subpage, 'Sendspin Player');
    expect(defs.sendspinGroupVolume.dependsOn, defs.sendspinEnabled.key);
  });

  test('grouped, the slider shows and sets the group volume', () async {
    await boot();
    expect(watcher, isNotNull);
    expect(manager.groupVolumeActive, isFalse);
    expect(manager.volumeLevel, 30);
    grouped(55);
    expect(manager.groupVolumeActive, isTrue);
    expect(manager.volumeLevel, 55);
    await manager.setVolume(70);
    expect(watcher!.groupLevels, [70]);
    // The device's own volume is Music Assistant's to move now.
    expect(settings.get(defs.mediaVolume), 30);
  });

  test('grouped, mute mutes the group', () async {
    await boot();
    grouped(55);
    expect(manager.muted, isFalse);
    await manager.toggleMute();
    expect(watcher!.groupMutes, [true]);
    grouped(55, muted: true);
    expect(manager.muted, isTrue);
    await manager.toggleMute();
    expect(watcher!.groupMutes, [true, false]);
    expect(settings.get(defs.mediaVolume), 30);
  });

  test('alone, the slider is the device volume again', () async {
    await boot();
    grouped(55);
    grouped(null);
    expect(manager.groupVolumeActive, isFalse);
    await manager.setVolume(40);
    expect(watcher!.groupLevels, isEmpty);
    expect(settings.get(defs.mediaVolume), 40);
  });

  test('with the switch off the slider stays on this device', () async {
    await boot(groupVolume: false);
    grouped(55);
    expect(manager.groupVolumeActive, isFalse);
    expect(manager.volumeLevel, 30);
    await manager.setVolume(40);
    expect(watcher!.groupLevels, isEmpty);
    expect(settings.get(defs.mediaVolume), 40);
  });

  test('a member slider in the group menu sets that player alone', () async {
    await boot();
    expect(await manager.setMemberVolume('kitchen', 120), isTrue);
    final (command, args) = api.calls.last;
    expect(command, 'players/cmd/volume_set');
    expect(args, {'player_id': 'kitchen', 'volume_level': 100});
  });
}
