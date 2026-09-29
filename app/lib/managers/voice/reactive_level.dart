/// The reactive bar's level, 0..1, from the microphone and from playback:
/// Voice Satellite's analyser (audio/analyser.js), whose mapping every skin
/// was tuned against. One per session: the microphone's floor and speech
/// envelope are learned across turns.
library;

import 'dart:math' as math;
import 'dart:typed_data';

class ReactiveLevel {
  // The two one-pole band splits of pushMicPcm, at 16 kHz.
  double _lp180 = 0;
  double _lp3400 = 0;

  // _normalizeMicLevel's references.
  double? _micFloor;
  double _micPeakEnv = 0;
  bool _micAdaptive = false;

  /// The length of the piece being measured, in analyser ticks.
  double _ticks = 1;

  /// The analyser's tick on a tablet, which the adaptive references' rates
  /// per call were tuned to.
  static const _tickMs = 33.3;

  /// Samples per slice of a microphone chunk: 20 ms at 16 kHz.
  static const sliceSamples = 320;

  /// Slices a level reads: the last 80 ms, the chunk's own length.
  static const _windowSlices = 4;

  /// The sums of the latest slices, oldest first.
  final _window = <_Sums>[];

  /// One chunk of 16 kHz PCM16 from the microphone, as a level per 20 ms
  /// slice, in order. A chunk is 80 ms, too coarse for the bar: its slices,
  /// played out over the chunk, move it 50 times a second. Each reads the
  /// last 80 ms rather than its own 20, as the analyser reads a window of
  /// recent audio on every tick: a short window of a quiet room flickers
  /// across the noise gate.
  List<double> micSlices(Uint8List pcm) {
    final n = pcm.length ~/ 2;
    if (n == 0) return const [0];
    final parts = math.max(1, n ~/ sliceSamples);
    final size = n ~/ parts * 2;
    final levels = <double>[];
    for (var i = 0; i < parts; i++) {
      final slice = Uint8List.sublistView(
        pcm,
        i * size,
        i == parts - 1 ? pcm.length : (i + 1) * size,
      );
      _window.add(_sum(slice));
      if (_window.length > _windowSlices) _window.removeAt(0);
      _ticks = slice.length / 2 / 16 / _tickMs;
      levels.add(_level(_window.reduce((a, b) => a + b)));
    }
    return levels;
  }

  /// One piece of 16 kHz PCM16 from the microphone.
  double mic(Uint8List pcm) {
    final n = pcm.length ~/ 2;
    if (n == 0) return 0;
    _ticks = n / 16 / _tickMs;
    return _level(_sum(pcm));
  }

  _Sums _sum(Uint8List pcm) {
    final n = pcm.length ~/ 2;
    final data = ByteData.sublistView(pcm);
    const a180 = 0.9318;
    const a3400 = 0.2628;
    var l180 = _lp180;
    var l3400 = _lp3400;
    var sumAll = 0.0, sumLow = 0.0, sumMid = 0.0;
    for (var i = 0; i < n; i++) {
      final x = data.getInt16(i * 2, Endian.little) / 32768.0;
      l180 = a180 * l180 + (1 - a180) * x;
      l3400 = a3400 * l3400 + (1 - a3400) * x;
      sumAll += x.abs();
      sumLow += l180.abs();
      sumMid += l3400.abs();
    }
    _lp180 = l180;
    _lp3400 = l3400;
    return _Sums(sumAll, sumLow, sumMid, n);
  }

  double _level(_Sums sums) {
    final n = math.max(1, sums.n);
    final all = sums.all / n;
    final low = sums.low / n;
    final mid = sums.mid / n;
    // Favor the speech band, suppress steady rumble and hiss.
    final voice = math.max(0.0, mid - low);
    final air = math.max(0.0, all - mid);
    final ratio = voice / math.max(1e-4, low + air + voice);
    final weight = (ratio * 1.2).clamp(0.18, 1.0);
    return micLevel(all * weight);
  }

  /// A speech-weighted mean amplitude from the microphone, mapped: first
  /// against the capture's own floor and speech envelope, so a quiet ROM
  /// capture moves the bar as a calibrated one does, then lifted with a
  /// small visible floor once there is speech.
  double micLevel(double meanAbs) {
    final normalized = _normalize(meanAbs);
    if (normalized == 0) return 0;
    final scaled = math.min(1.0, normalized * 7.5);
    final curved = math.pow(scaled, 0.6).toDouble();
    // Ambient noise renders dark, unless the adaptive gate already made
    // that call against this device's own floor.
    if (curved <= 0.06 && !_micAdaptive) return 0;
    return math.min(1.0, 0.05 + curved * 0.95);
  }

  /// A level the player measured from the decoded audio, before its volume:
  /// it runs hot next to what an element reads, so a gentle gain on a
  /// near-linear curve keeps speech's dynamics.
  double playback(double meanAbs) => math.min(1.0, meanAbs * 2.2);

  double _normalize(double meanAbs) {
    const eps = 1e-4;
    final prev = _micFloor;
    if (prev == null || meanAbs < prev) {
      _micFloor = math.max(meanAbs, eps);
    } else {
      // Capped below speech, so a long utterance never becomes its own floor.
      _micFloor = math.min(prev * math.pow(1.002, _ticks), 0.05);
    }
    if (meanAbs <= _micFloor! * 3) {
      _micAdaptive = false;
      return 0;
    }
    // Up to 64x toward what a healthy capture produces.
    const ref = 0.05;
    const maxBoost = 64.0;
    _micPeakEnv = math.max(_micPeakEnv * math.pow(0.997, _ticks), meanAbs);
    final boost = math.min(
      maxBoost,
      math.max(1.0, ref / math.max(_micPeakEnv, ref / maxBoost)),
    );
    _micAdaptive = boost > 1.01;
    return meanAbs * boost;
  }
}

/// Sums of absolute samples over a piece of audio: all of it, below 180 Hz
/// and below 3400 Hz.
class _Sums {
  const _Sums(this.all, this.low, this.mid, this.n);

  final double all;
  final double low;
  final double mid;
  final int n;

  _Sums operator +(_Sums o) =>
      _Sums(all + o.all, low + o.low, mid + o.mid, n + o.n);
}
