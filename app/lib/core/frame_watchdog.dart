import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app_container.dart';
import 'events.dart';
import 'logging.dart';
import '../managers/settings/definitions.dart' as defs;

/// Detects a wedged renderer and restarts the process.
///
/// When the Activity is destroyed and recreated (a permission dialog is
/// enough on some devices), re-attaching the process-wide cached engine can
/// silently fail: the launch splash stays on screen forever while the Dart
/// isolate runs on underneath — on a kiosk with the hardware buttons
/// blocked, a dead wall until someone kills the process.
///
/// Detection leans on two ground truths, chosen because everything subtler
/// lies in this state (the native first-frame callback reports "displayed"
/// from the previous attach; Dart frame callbacks keep completing into a
/// surface nobody sees):
///
///  1. The Activity is in front — from native onResume/onPause via the
///     background bridge, not the engine's lifecycle reporting.
///  2. A configured kiosk has no WebView attached — the platform view
///     cannot come up without a working attach, so its prolonged absence
///     is the wedge. Transients (a settings-triggered WebView rebuild) last
///     moments; the watchdog needs three consecutive strikes 5s apart.
///
/// Recovery escalates. First a WebView rebuild in place: the create-raced-
/// attach variant (issue #145 — the platform view was requested before the
/// Activity attached, failed once, and never retries) heals with a fresh
/// widget now that the Activity is up. Then, strikes later, a full process
/// restart through the background bridge: for the failed-re-attach variant
/// a rebuild has been observed to leave the wedge in place, and only a
/// restart reliably comes back.
class FrameWatchdog {
  FrameWatchdog(this._container);

  static const _channel = MethodChannel('kiosk_satellite/background');
  static const _interval = Duration(seconds: 5);

  /// 30s of foregrounded-with-no-WebView before restarting. Generous on
  /// purpose: a healthy cold boot on a fast tablet already reaches two
  /// 5s strikes before the WebView attaches, and slow devices need real
  /// headroom — a false trip here would be a restart loop.
  static const _strikesToTrip = 6;

  /// The in-place rebuild attempt, past any healthy slow boot (20s in)
  /// and early enough that a rebuild that works averts the restart.
  static const _strikesToRebuild = 4;

  final AppContainer _container;
  Timer? _timer;
  int _strikes = 0;
  DateTime? _firstStrikeAt;
  bool _checking = false;
  bool _tripped = false;
  bool _stoodDown = false;

  /// Dart frames drawn since the watchdog armed. Whether this moves while
  /// the strikes pile up is the one fact that tells a dead engine (nothing
  /// draws) from a live one whose platform view never comes (issue #145,
  /// #465), and neither the log nor the journal used to carry it.
  int _frames = 0;
  int _framesAtFirstStrike = 0;
  bool _rebuildRequested = false;

  void start() {
    _container.log.info('watchdog', 'armed (${_interval.inSeconds}s checks)');
    try {
      SchedulerBinding.instance.addPersistentFrameCallback((_) => _frames++);
    } catch (_) {
      // No binding (a bare test): the count simply stays at zero.
    }
    _timer = Timer.periodic(_interval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
  }

  /// One probe at a time, and strikes paced by the clock rather than the
  /// count. The resume probe is a platform call, and the wedge it looks
  /// for tends to stall the platform thread: analytics showed a Lenovo
  /// tablet whose six probes were all answered in the same two seconds
  /// once the thread came back, so the counter hit six and restarted the
  /// process two seconds after asking for the rebuild it was supposed to
  /// give thirty. A probe still in flight now skips the tick, and a strike
  /// only counts once the interval has really passed since the first.
  Future<void> _check() async {
    if (_tripped || _checking) return;
    _checking = true;
    try {
      await _checkOnce();
    } finally {
      _checking = false;
    }
  }

  void _clear() {
    _strikes = 0;
    _firstStrikeAt = null;
  }

  Future<void> _checkOnce() async {
    if (_container.settings.get(defs.startUrl).isEmpty) {
      _clear();
      return;
    }
    // No provider at all: the WebView is never coming, and a restart only
    // starts the same wait over. The browser has logged it and the kiosk
    // screen says so; the watchdog stands down.
    if (_container.browser.webViewMissing) {
      if (!_stoodDown) {
        _stoodDown = true;
        _container.log.warn(
          'watchdog',
          'the WebView cannot be created on this device; standing down',
        );
      }
      _clear();
      return;
    }
    _stoodDown = false;
    bool resumed;
    try {
      resumed = await _channel.invokeMethod<bool>('isActivityResumed') ?? false;
    } catch (e) {
      _container.log.warn('watchdog', 'resume probe failed: $e');
      return;
    }
    if (!resumed || _container.browser.hasWebView) {
      _clear();
      return;
    }
    final now = DateTime.now();
    final first = _firstStrikeAt ??= now;
    _strikes++;
    if (_strikes == 1) _framesAtFirstStrike = _frames;
    final strike = pacedStrike(
      strikes: _strikes,
      sinceFirst: now.difference(first),
      interval: _interval,
    );
    _container.log.warn(
      'watchdog',
      'strike $strike/$_strikesToTrip: resumed with no WebView',
    );
    if (strike >= _strikesToRebuild && !_rebuildRequested) {
      _container.log.warn(
        'watchdog',
        'requesting a WebView rebuild before restarting',
      );
      _rebuildRequested = true;
      _container.bus.publish(const WebViewRebuildRequested());
      return;
    }
    if (strike < _strikesToTrip) return;
    _tripped = true;
    _container.log.error(
      'watchdog',
      'foregrounded with no WebView for '
          '${_interval.inSeconds * _strikesToTrip}s: renderer wedged, '
          'restarting the process',
    );
    // Lands in the crash journal: this kill throws nothing, and the
    // in-memory log dies with the process, so the note is all a report
    // ever shows. The first line is the stable name of the failure; what
    // follows is the state that decides what kind of wedge it was.
    final reason = await _describeTrip();
    // Give the log line a moment to flush.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await _channel.invokeMethod<void>('restartProcess', {'reason': reason});
    } catch (e) {
      _container.log.error('watchdog', 'restart failed: $e');
      _tripped = false;
    }
  }

  Future<String> _describeTrip() async {
    var device = const <String, Object?>{};
    try {
      final r = await _container.commands
          .execute('getDeviceInfo', const {})
          .timeout(const Duration(seconds: 5));
      if (r.data is Map) device = Map<String, Object?>.from(r.data as Map);
    } catch (_) {}
    return describeWatchdogTrip(
      seconds: _interval.inSeconds * _strikesToTrip,
      framesDuringWait: _frames - _framesAtFirstStrike,
      rebuildRequested: _rebuildRequested,
      device: device,
      impellerDisabled: _container.settings.get(defs.disableImpeller),
      legacyWebView: _container.settings.get(defs.legacyWebView),
      recentLog: _container.log.recent,
    );
  }
}

/// The strike a probe really counts as: never more than one per interval
/// since the first strike, however many probes were answered in a burst.
/// Rounded to the nearest interval, so a tick a few milliseconds early
/// still counts and only a real burst is held back.
int pacedStrike({
  required int strikes,
  required Duration sinceFirst,
  required Duration interval,
}) {
  final ms = interval.inMilliseconds;
  final byClock = 1 + (sinceFirst.inMilliseconds + ms ~/ 2) ~/ ms;
  return strikes < byClock ? strikes : byClock;
}

/// The tags whose recent lines say what the WebView was doing when the
/// watchdog gave up on it.
const watchdogLogTags = {
  'watchdog',
  'browser',
  'webview',
  'kiosk',
  'device',
  'flutter',
  'dart',
};

/// The note a watchdog restart leaves in the crash journal. Line one is
/// the failure's name and stays word for word, so reports group; the rest
/// is context, one fact per line, with the last relevant log lines at the
/// end. Pure, so a test can pin the shape.
String describeWatchdogTrip({
  required int seconds,
  required int framesDuringWait,
  required bool rebuildRequested,
  required Map<String, Object?> device,
  required bool impellerDisabled,
  required bool legacyWebView,
  required List<LogEntry> recentLog,
  int logLines = 12,
}) {
  String mb(Object? bytes) =>
      bytes is num ? '${(bytes / (1024 * 1024)).round()} MB' : '?';
  // getDeviceInfo's uptime is {app: seconds, network: seconds, ...}.
  String uptime(Object? raw) {
    if (raw is Map) {
      final app = raw['app'];
      final net = raw['network'];
      return 'app ${app is num ? '${app.round()}s' : '?'}, '
          'network ${net is num ? '${net.round()}s' : '?'}';
    }
    return raw?.toString() ?? '?';
  }

  final screen = device['screenOn'];
  final lines = <String>[
    'the frame watchdog found no WebView for ${seconds}s while the app '
        'was in front',
    'flutter frames drawn during the wait: $framesDuringWait',
    'webview rebuild requested first: ${rebuildRequested ? 'yes' : 'no'}',
    'webview: ${device['webviewPackage'] ?? '?'} '
        '${device['webviewVersion'] ?? '?'}',
    'renderer: impeller ${impellerDisabled ? 'off' : 'on'}, '
        'legacy webview ${legacyWebView ? 'on' : 'off'}',
    'ram: ${mb(device['ramFree'])} free of ${mb(device['ramTotal'])}, '
        'screen ${screen == null ? '?' : (screen == true ? 'on' : 'off')}, '
        'uptime ${uptime(device['uptime'])}',
    'recent log:',
  ];
  // A run of one line repeating (an Activity attaching twice a second
  // pushed everything else out of a 12-line tail) folds into one entry
  // with its count, so the tail still shows what happened around it.
  final tail = <(LogEntry, int)>[];
  for (final e in recentLog) {
    if (!watchdogLogTags.contains(e.tag)) continue;
    if (tail.isNotEmpty &&
        tail.last.$1.tag == e.tag &&
        tail.last.$1.message == e.message) {
      tail[tail.length - 1] = (e, tail.last.$2 + 1);
    } else {
      tail.add((e, 1));
    }
  }
  final from = tail.length > logLines ? tail.length - logLines : 0;
  for (final (e, n) in tail.sublist(from)) {
    final t = e.time.toIso8601String().substring(11, 19);
    final msg = e.message.replaceAll('\n', ' ');
    lines.add(
      '  $t ${e.tag}: ${msg.length > 160 ? msg.substring(0, 160) : msg}'
      '${n > 1 ? ' (x$n)' : ''}',
    );
  }
  return lines.join('\n');
}
