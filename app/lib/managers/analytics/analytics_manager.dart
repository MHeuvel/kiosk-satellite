import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/command_registry.dart';
import '../../core/events.dart';
import '../../core/manager.dart';
import '../settings/definitions.dart' as defs;
import '../settings/settings_manager.dart';
import '../update/update_http_client.dart';
import 'analytics_scrub.dart';
import 'crash_journal.dart';

/// Kiosk Satellite Analytics: what the three switches under Settings >
/// Device > Kiosk Satellite Analytics let leave the device, and when.
///
/// One snapshot a day carries the Basic analytics (the device) and Usage
/// (which features are on) parts, each only while its switch is on; a crash
/// the native CrashJournal recorded goes out once, on the next start, while
/// Diagnostics is on. Everything goes to one endpoint over HTTPS with
/// certificates always verified, under a random install id that exists only
/// while at least one switch is on. docs/analytics.md is the contract this
/// class implements; change one and change the other.
class AnalyticsManager extends Manager {
  AnalyticsManager(
    super.bus,
    super.commands,
    super.log,
    this._settings, {
    this.endpoint = defaultEndpoint,
    this.clientFactory = createStrictHttpClient,
    this.firstDelay = const Duration(minutes: 3),
    this.snapshotInterval = const Duration(hours: 24),
    this.tickInterval = const Duration(hours: 1),
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  static const defaultEndpoint =
      'https://analytics.kiosksatellite.com/v1/report';

  /// The wire format's version, bumped when a field changes meaning.
  static const schema = 1;

  static const _installIdKey = 'analytics_install_id';
  static const _lastSnapshotKey = 'analytics_last_snapshot';
  static const _sentCrashesKey = 'analytics_sent_crashes';

  /// How many crashes one tick reports at most: a journal that holds a
  /// history of them trickles out rather than bursting.
  static const crashesPerTick = 3;

  /// How many fingerprints to remember; the journal itself is capped.
  static const _rememberedCrashes = 50;
  static const _background = MethodChannel('kiosk_satellite/background');

  final SettingsManager _settings;
  final String endpoint;
  final http.Client Function() clientFactory;

  /// How long after start the first snapshot may go: the app has settled,
  /// the network is up, and a device that reboots in a loop never reports.
  final Duration firstDelay;
  final Duration snapshotInterval;
  final Duration tickInterval;
  final DateTime Function() _now;
  final Random _random;

  Timer? _first;
  Timer? _ticker;
  bool _sending = false;

  @override
  String get name => 'analytics';

  bool get basicOn => _settings.get(defs.analyticsBasic);
  bool get usageOn => _settings.get(defs.analyticsUsage);
  bool get diagnosticsOn => _settings.get(defs.analyticsDiagnostics);
  bool get anyOn => basicOn || usageOn || diagnosticsOn;

  /// The random id this install reports under; empty while every switch
  /// is off, since nothing is reported then and nothing should link a
  /// later opt-in to an earlier one.
  String get installId => _settings.internal(_installIdKey);

  /// When the last snapshot went out, null before the first.
  DateTime? get lastSnapshot {
    final raw = int.tryParse(_settings.internal(_lastSnapshotKey));
    return raw == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }

  @override
  Future<void> init() async {
    bus.on<SettingChanged>().listen((e) {
      if (e.key != defs.analyticsBasic.key &&
          e.key != defs.analyticsUsage.key &&
          e.key != defs.analyticsDiagnostics.key) {
        return;
      }
      if (!anyOn) unawaited(_forget());
    });
    if (!anyOn) await _forget();

    commands.register(
      Command(
        name: 'getAnalyticsReport',
        description:
            'The snapshot Kiosk Satellite Analytics would send right now, '
            'and when the last one went out',
        handler: (_) async {
          // The snapshot first: building it mints the id it reports under.
          final snapshot = await buildSnapshot();
          return CommandResult.ok({
            'installId': installId,
            'lastSnapshot': lastSnapshot?.toIso8601String(),
            'snapshot': snapshot,
          });
        },
      ),
    );
    commands.register(
      Command(
        name: 'sendAnalyticsNow',
        description:
            'Send the analytics snapshot without waiting for the '
            'daily schedule',
        handler: (_) async {
          final sent = await sendSnapshot(force: true);
          return sent
              ? const CommandResult.ok()
              : const CommandResult.fail('not sent');
        },
      ),
    );

    _first = Timer(firstDelay, () {
      unawaited(_tick());
      _ticker = Timer.periodic(tickInterval, (_) => unawaited(_tick()));
    });
  }

  @override
  Future<void> dispose() async {
    _first?.cancel();
    _ticker?.cancel();
  }

  Future<void> _tick() async {
    await sendCrashIfAny();
    await sendSnapshot();
  }

  /// Drop everything that identifies this install. Called when the last
  /// switch goes off, so turning one back on starts a new, unlinked id.
  Future<void> _forget() async {
    await _settings.setInternal(_installIdKey, '');
    await _settings.setInternal(_lastSnapshotKey, '');
    await _settings.setInternal(_sentCrashesKey, '');
  }

  Future<String> _ensureInstallId() async {
    final current = installId;
    if (current.isNotEmpty) return current;
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _settings.setInternal(_installIdKey, id);
    return id;
  }

  /// Whether a snapshot is due: never sent, or [snapshotInterval] ago.
  bool get snapshotDue {
    final last = lastSnapshot;
    return last == null || _now().toUtc().difference(last) >= snapshotInterval;
  }

  /// Send the daily snapshot if one is due (or [force]), while Basic
  /// analytics or Usage is on. True when the server accepted it.
  Future<bool> sendSnapshot({bool force = false}) async {
    if (!basicOn && !usageOn) return false;
    if (!force && !snapshotDue) return false;
    if (_sending) return false;
    _sending = true;
    try {
      final body = await buildSnapshot();
      if (body == null) return false;
      final ok = await _post(body);
      if (ok) {
        await _settings.setInternal(
          _lastSnapshotKey,
          '${_now().toUtc().millisecondsSinceEpoch}',
        );
      }
      return ok;
    } finally {
      _sending = false;
    }
  }

  /// Report the crashes the native journal holds that have not been
  /// reported yet, while Diagnostics is on: each entry once, by
  /// fingerprint. Frame watchdog restarts count (a wedged UI is a failure
  /// nobody asked for); restarts a person or an automation requested do
  /// not. The
  /// journal is left alone: the device manager keeps it for the Logs
  /// screen until the journal trims it, so the remembered fingerprints
  /// are what stop a repeat. True when at least one report went out.
  Future<bool> sendCrashIfAny() async {
    if (!diagnosticsOn) return false;
    final entries = parseCrashJournal(await _readCrashJournal());
    if (entries.isEmpty) return false;
    final sent = _sentCrashes();
    final pending = <(String, CrashEntry)>[];
    for (final e in entries.reversed) {
      if (!e.reportable) continue;
      final fp = sha256.convert(utf8.encode(e.text)).toString();
      if (sent.contains(fp)) continue;
      pending.add((fp, e));
      if (pending.length >= crashesPerTick) break;
    }
    if (pending.isEmpty) return false;
    final app = await _appInfo();
    final android = await _androidInfo();
    var any = false;
    for (final (fp, e) in pending) {
      final body = {
        'schema': schema,
        'kind': 'crash',
        'install_id': await _ensureInstallId(),
        'sent_at': _now().toUtc().toIso8601String(),
        // The version that crashed, when the journal says; the running
        // one is only a fallback for a headerless entry.
        'app': {...app, if (e.appVersion != null) 'version': e.appVersion},
        'android': android,
        if (e.recordedAt != null) 'recorded_at': e.recordedAt,
        'cause': e.watchdog ? 'watchdog' : 'exception',
        'crash': clipDiagnostics(scrubDiagnostics(e.text)),
      };
      if (!await _post(body)) break;
      any = true;
      sent.add(fp);
      await _settings.setInternal(
        _sentCrashesKey,
        sent
            .skip(
              sent.length > _rememberedCrashes
                  ? sent.length - _rememberedCrashes
                  : 0,
            )
            .join(','),
      );
    }
    return any;
  }

  List<String> _sentCrashes() => [
    for (final fp in _settings.internal(_sentCrashesKey).split(','))
      if (fp.isNotEmpty) fp,
  ];

  /// The snapshot as it would go out now: the parts whose switches are on,
  /// or null when neither is.
  Future<Map<String, Object?>?> buildSnapshot() async {
    if (!basicOn && !usageOn) return null;
    return {
      'schema': schema,
      'kind': 'snapshot',
      'install_id': await _ensureInstallId(),
      'sent_at': _now().toUtc().toIso8601String(),
      'app': await _appInfo(),
      if (basicOn) 'basic': await _basic(),
      if (usageOn) 'usage': await _usage(),
    };
  }

  Future<Map<String, Object?>> _deviceInfo() async {
    try {
      final r = await commands.execute('getDeviceInfo', const {});
      final data = r.data;
      if (data is Map) return Map<String, Object?>.from(data);
    } catch (_) {}
    return const {};
  }

  Future<Map<String, Object?>> _appInfo() async {
    final d = await _deviceInfo();
    return {
      'version': d['appVersion'] ?? '',
      'build': d['buildNumber'] ?? '',
      'mode': d['buildMode'] ?? (kDebugMode ? 'debug' : 'release'),
    };
  }

  Future<Map<String, Object?>> _androidInfo() async {
    final d = await _deviceInfo();
    return {'version': d['osVersion'] ?? '', 'sdk': d['sdkInt']};
  }

  /// Basic analytics: the device, as docs/analytics.md lists it. No name,
  /// no address, no id of the hardware's own.
  Future<Map<String, Object?>> _basic() async {
    final d = await _deviceInfo();
    final now = _now();
    return {
      'manufacturer': d['manufacturer'] ?? '',
      'model': d['model'] ?? '',
      'android': d['osVersion'] ?? '',
      'sdk': d['sdkInt'],
      'abis': d['abis'] ?? const [],
      'screen': {
        'width': d['screenWidth'],
        'height': d['screenHeight'],
        'density': d['screenDensity'],
      },
      'locale': Platform.localeName,
      'timezone': now.timeZoneName,
      'utc_offset_minutes': now.timeZoneOffset.inMinutes,
    };
  }

  /// Usage: which features are on. Booleans and picks only, never the
  /// values behind them (no URLs, names, entities or credentials).
  Future<Map<String, Object?>> _usage() async {
    final s = _settings;
    String fleetRole() {
      if (s.get(defs.fleetLeader)) return 'leader';
      if (s.get(defs.fleetLeaderInfo).trim().isNotEmpty) return 'follower';
      return 'none';
    }

    var mappings = 0;
    try {
      final raw = jsonDecode(s.get(defs.gestureMappings));
      if (raw is List) mappings = raw.length;
    } catch (_) {}

    var plugins = 0;
    var pluginsEnabled = false;
    try {
      final r = await commands.execute('getPluginState', const {});
      final data = r.data;
      if (data is Map) {
        pluginsEnabled = data['enabled'] == true;
        final list = data['plugins'];
        if (list is List) plugins = list.length;
      }
    } catch (_) {}

    // What Voice Satellite is listening for and with, and how it looks:
    // the wake word manager's state and the page's settings hook. Names
    // only; a model name is a catalog label, not the user's audio.
    var wakeEngine = '';
    var wakeWord = '';
    var wakeWord2 = '';
    try {
      final r = await commands.execute('getWakeWordState', const {});
      final data = r.data;
      if (data is Map) {
        wakeEngine = data['released'] == true
            ? 'home_assistant'
            : '${data['engineLabel'] ?? data['engine'] ?? ''}';
        final models = data['models'];
        if (models is List) {
          String word(int i) => models.length > i && models[i] is Map
              ? '${(models[i] as Map)['wakeWord'] ?? ''}'
              : '';
          wakeWord = word(0);
          wakeWord2 = word(1);
        }
      }
    } catch (_) {}
    var skin = '';
    try {
      final r = await commands.execute('vsEngineState', const {});
      final data = r.data;
      if (data is Map && data['config'] is Map) {
        skin = '${(data['config'] as Map)['skin'] ?? ''}';
      }
    } catch (_) {}

    return {
      'screensaver': s.get(defs.screensaverEnabled)
          ? s.get(defs.screensaverMode)
          : 'off',
      'screensaver_schedule': s.get(defs.screensaverScheduleEnabled),
      'glance': s.get(defs.screensaverGlanceEnabled),
      'wake_on_motion': s.get(defs.screensaverDismissOnMotion),
      'wake_on_face': s.get(defs.screensaverDismissOnFace),
      'wake_on_person': s.get(defs.screensaverDismissOnPerson),
      'wake_on_proximity': s.get(defs.screensaverDismissOnProximity),
      'voice_satellite': s.get(defs.wakeWordEnabled),
      'native_pipeline': s.get(defs.vsNativePipeline),
      'wake_word_engine': wakeEngine,
      'wake_word': wakeWord,
      'wake_word_2': wakeWord2,
      'vs_skin': skin,
      'esphome': s.get(defs.esphomeEnabled),
      'bluetooth_proxy': s.get(defs.btproxyEnabled),
      'gps_sensor': s.get(defs.locationEnabled),
      // The empty pick is the device's own Sendspin player.
      'media_player': !s.get(defs.sendspinEnabled)
          ? 'off'
          : s.get(defs.sendspinPlayerSource).isEmpty
          ? 'device'
          : s.get(defs.sendspinPlayerSource),
      'lyrics': s.get(defs.sendspinLyricsEnabled),
      'dlna': s.get(defs.dlnaEnabled),
      'device_camera': s.get(defs.cameraEnabled),
      'gesture_mappings': mappings,
      'kiosk_mode': s.get(defs.kioskEnabled),
      'lockdown': s.get(defs.lockdownEnabled),
      'app_launcher': s.get(defs.launcherEnabled),
      'home_launcher': s.get(defs.homeLauncherEnabled),
      'ha_kiosk_mode': s.get(defs.haKioskMode),
      'dashboard_carousel': s.get(defs.haDashboardCarousel),
      'dashboard_rotation': s.get(defs.haRotationEnabled),
      'adaptive_brightness': s.get(defs.adaptiveBrightness),
      'remote_admin': s.get(defs.remoteEnabled),
      'fleet_role': fleetRole(),
      'plugins_enabled': pluginsEnabled,
      'plugins': plugins,
      'theme': s.get(defs.uiTheme),
    };
  }

  /// The native journal's text, or nothing where there is no journal (a
  /// platform without the bridge answers with an exception).
  Future<String> _readCrashJournal() async {
    try {
      return await _background.invokeMethod<String>('getLastCrash') ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> _post(Map<String, Object?> body) async {
    final client = clientFactory();
    try {
      final res = await client
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        log.debug(name, 'sent ${body['kind']} (${res.statusCode})');
        return true;
      }
      log.debug(name, '${body['kind']} refused: HTTP ${res.statusCode}');
      return false;
    } catch (e) {
      // Offline, DNS-blocked, or the server is down: all fine, and none of
      // them worth more than a debug line. The next tick tries again.
      log.debug(name, '${body['kind']} not sent: $e');
      return false;
    } finally {
      client.close();
    }
  }
}
