import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'mic_hub.dart';

/// Live microphone level for the level meters, read off the shared capture
/// rather than the wake word engine. The meter then works before Voice
/// Satellite has started an engine, which is when people check whether a new
/// microphone works at all: tied to the engine, a meter on a device without
/// one sat empty and looked exactly like a dead microphone.
///
/// Reference counted. With the engine running this is one more listener on
/// the capture it already holds. Without it, the capture opens for the
/// meters and closes [linger] after the last one stops.
class MicLevelMonitor {
  MicLevelMonitor._();

  static final MicLevelMonitor instance = MicLevelMonitor._();

  /// The PCM16 mono capture to measure. Replaced in tests.
  Stream<Uint8List> Function() source = () => MicHub.instance.stream();

  /// How long the capture stays open after the last watcher leaves. Pages
  /// rebuild their meter (a settings refresh, the remote admin re-rendering
  /// a tab) and drop and re-add it within moments, and without this every
  /// rebuild closed and reopened the microphone.
  Duration linger = const Duration(seconds: 3);

  final _levels = StreamController<double>.broadcast();
  StreamSubscription<Uint8List>? _capture;
  Timer? _closing;
  int _watchers = 0;

  /// RMS (0..1) of each captured chunk while at least one watcher holds
  /// [start] open. Gain is already applied: it is what the engines hear.
  Stream<double> get levels => _levels.stream;

  bool get watching => _watchers > 0;

  void start() {
    if (_watchers++ > 0) return;
    _closing?.cancel();
    _closing = null;
    if (_capture != null) return;
    _capture = source().listen(
      (chunk) => _levels.add(rmsOf(chunk)),
      // A refused capture (no permission, the page holds the microphone)
      // leaves the meter dark: the app log already says why.
      onError: (Object _) {},
    );
  }

  void stop() {
    if (_watchers == 0) return;
    if (--_watchers > 0) return;
    _closing?.cancel();
    _closing = linger == Duration.zero ? null : Timer(linger, _close);
    if (_closing == null) _close();
  }

  void _close() {
    _closing = null;
    final capture = _capture;
    _capture = null;
    unawaited(capture?.cancel());
  }

  /// RMS of little-endian PCM16, on the same 0..1 scale as the engines'
  /// telemetry.
  static double rmsOf(Uint8List pcm) {
    final samples = pcm.lengthInBytes ~/ 2;
    if (samples == 0) return 0;
    final data = ByteData.sublistView(pcm);
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    return math.sqrt(sum / samples);
  }
}
