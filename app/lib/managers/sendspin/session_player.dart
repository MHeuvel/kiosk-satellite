import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import '../../core/logging.dart';
import 'remote_player.dart';

/// The Now Playing surfaces following another app's media session on this
/// device: a Spotify Connect receiver, a podcast app, anything that
/// publishes one. [package] is the app to follow; the Media Player page's
/// Local Media Session pick is [anyApp], whichever one plays.
///
/// The native side (MediaSessionBridge) watches the sessions and pushes a
/// snapshot on every metadata or playback change, already in the map shape
/// every source publishes. Reading the sessions needs Android's
/// "Notification access" grant; without it the pick stands and nothing
/// shows until the grant lands.
///
/// Volume is the device's own media volume, which the manager handles as
/// it does for the local player, so the session is never asked for it.
class SessionPlayer implements RemotePlayer {
  SessionPlayer({
    required this.package,
    required this.onSnapshot,
    required this.log,
  });

  static const _name = 'sendspin';

  /// The pick that follows whichever app plays.
  static const anyApp = '*';

  static const channel = MethodChannel('kiosk_satellite/media_sessions');

  /// The one follower the native pushes go to: a replacement starts only
  /// after the old one stopped, so there is never more than one.
  static SessionPlayer? _active;
  static bool _handlerSet = false;

  final String package;
  final void Function(Map<String, Object?>? snapshot) onSnapshot;
  final Logger log;

  bool _stopped = false;
  Map<String, Object?>? _snapshot;

  @override
  String get playerId => package;

  @override
  bool queueEmpty = false;

  @override
  bool get hasQueue => false;

  @override
  Future<RemoteQueue?> fetchQueue() async => null;

  @override
  Future<bool> playQueueItem(String id) async => false;

  @override
  bool get hasGrouping => false;

  @override
  Future<RemoteGroup?> fetchGroup() async => null;

  @override
  Future<bool> setGrouped(String id, bool grouped) async => false;

  /// A session reports its position with every state change and the
  /// speed it moves at, which is as close as the local player's.
  @override
  bool get lyricsSynced => true;

  @override
  bool get hasFavorites => false;

  @override
  Future<bool> setFavorite(bool on) async => false;

  /// The framework's controls have no shuffle or repeat to read back, so
  /// the view offers neither.
  @override
  Future<bool> setShuffle(bool on) async => false;

  @override
  Future<bool> setRepeat(String mode) async => false;

  /// The device's media volume, set by the manager.
  @override
  Future<bool> setVolume(int percent) async => false;

  @override
  Future<bool> setMute(bool muted) async => false;

  /// The app that plays right now, for the Now Playing chip while the
  /// pick is [anyApp].
  String get appName => '${_snapshot?['appName'] ?? ''}';

  @override
  void start() {
    _active = this;
    if (!_handlerSet) {
      _handlerSet = true;
      channel.setMethodCallHandler((call) async {
        if (call.method == 'snapshot') _active?.handleSnapshot(call.arguments);
      });
    }
    unawaited(_invoke('follow', {'package': package}));
    log.info(_name, 'following media session of $package');
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    if (!identical(_active, this)) return;
    _active = null;
    await _invoke('unfollow');
  }

  @override
  void reveal() {
    unawaited(refresh());
  }

  @override
  Future<void> refresh() async {
    await _invoke('refresh');
  }

  @override
  Future<bool> control(String command) async =>
      await _invoke<bool>('control', {'command': command}) ?? false;

  @override
  Future<bool> seek(int positionMs) async =>
      await _invoke<bool>('seek', {'positionMs': positionMs}) ?? false;

  /// A native snapshot: a map with the track, or null with nothing to
  /// show.
  @visibleForTesting
  void handleSnapshot(Object? raw) {
    if (_stopped) return;
    final snap = snapshotFrom(raw);
    _snapshot = snap;
    queueEmpty = snap == null;
    onSnapshot(snap);
  }

  /// The platform map with its keys and command list typed.
  @visibleForTesting
  static Map<String, Object?>? snapshotFrom(Object? raw) {
    if (raw is! Map) return null;
    final snap = <String, Object?>{
      for (final e in raw.entries) '${e.key}': e.value,
    };
    if ('${snap['title'] ?? ''}'.trim().isEmpty) return null;
    final commands = [
      for (final c in (snap['supportedCommands'] as List? ?? const [])) '$c',
    ];
    // An empty list reads as "anything goes" to the controls, which would
    // offer shuffle and repeat a session cannot take.
    snap['supportedCommands'] = commands.isEmpty
        ? const ['play', 'pause']
        : commands;
    return snap;
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } catch (e) {
      log.warn(_name, 'media session $method failed: $e');
      return null;
    }
  }

  /// Whether "Notification access" is granted, without which no session
  /// can be read.
  static Future<bool> hasAccess() async {
    try {
      return await channel.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// A cover a snapshot named by a mediasession:// URL.
  static Future<Uint8List?> artwork(String url) async {
    try {
      return await channel.invokeMethod<Uint8List>('artwork', {'url': url});
    } catch (_) {
      return null;
    }
  }
}
