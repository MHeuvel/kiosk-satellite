import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Values match the approved scenes: clouds, night, rain, fog, snow, wind,
/// downpour, lightning, hail and storm darkness.
const weatherMoodPresets = <String, List<double>>{
  'sunny': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'clear-night': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'partlycloudy': [.10, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'cloudy': [.68, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'rainy': [.95, 0, 1, 0, 0, 0, 0, 0, 0, 0],
  'snowy': [.77, 0, 0, 0, 1, 0, 0, 0, 0, 0],
  'fog': [.7, 0, 0, 1, 0, 0, 0, 0, 0, 0],
  'pouring': [1, 0, 1, 0, 0, .24, 1, 0, 0, .55],
  'snowy-rainy': [.88, 0, .62, 0, .75, .08, 0, 0, 0, .12],
  'windy': [.065, 0, 0, 0, 0, 1, 0, 0, 0, 0],
  'windy-variant': [.87, 0, 0, 0, 0, 1, 0, 0, 0, .12],
  'lightning': [.98, 0, 0, 0, 0, .20, 0, 1, 0, .68],
  'lightning-rainy': [1, 0, 1, 0, 0, .32, .36, 1, 0, .68],
  'hail': [.94, 0, 0, 0, 0, .14, 0, 0, 1, .44],
  'exceptional': [.48, 0, 0, 0, 0, 0, 0, 0, 0, 0],
};

double weatherMoodRandom(double value) {
  final n = math.sin(value * 127.1 + 311.7) * 43758.5453;
  return n - n.floorToDouble();
}

class WeatherMoodLightning {
  const WeatherMoodLightning(this.strength, this.x, this.y, this.id);
  static const none = WeatherMoodLightning(0, .5, 0, -1);
  final double strength, x, y;
  final int id;
}

class WeatherMoodScene {
  String condition = 'exceptional';
  List<double> values = [...weatherMoodPresets['exceptional']!];
  List<double> _target = [...weatherMoodPresets['exceptional']!];
  double time = 18, windTime = 0;
  double twilight = 0, _targetTwilight = 0;
  double _stormStart = 18, _strikeTime = 1.2, _nextStrike = 1.2;
  int _strikeId = -1;

  void update({
    required String condition,
    required bool night,
    required bool lightning,
    double twilight = 0,
    bool immediate = false,
  }) {
    if (weatherMoodPresets.containsKey(condition)) {
      this.condition = condition;
    }
    final next = [...weatherMoodPresets[this.condition]!];
    next[1] = night ? 1 : 0;
    if (!lightning) next[7] = 0;
    if (next[7] > 0 && _target[7] == 0) {
      _stormStart = time;
      _strikeTime = _nextStrike = 1.2;
      _strikeId = -1;
    }
    _target = next;
    _targetTwilight = twilight.clamp(0.0, 1.0);
    if (!lightning) values[7] = 0;
    if (immediate) {
      values = [...next];
      this.twilight = _targetTwilight;
    }
  }

  void advance(double seconds) {
    final dt = seconds.clamp(0.0, .15);
    time += dt;
    twilight += (_targetTwilight - twilight) * math.min(1, dt * 1.1);
    for (var i = 0; i < values.length; i++) {
      values[i] += (_target[i] - values[i]) * math.min(1, dt * 1.1);
    }
    windTime += dt * values[5];
  }

  WeatherMoodLightning get lightning {
    if (values[7] < .001) return WeatherMoodLightning.none;
    final elapsed = math.max(0.0, time - _stormStart);
    while (_nextStrike <= elapsed) {
      _strikeId++;
      _strikeTime = _nextStrike;
      _nextStrike += 2.8 + weatherMoodRandom(_strikeId + 78.0) * 4.4;
    }
    if (_strikeId < 0) return WeatherMoodLightning.none;
    final age = elapsed - _strikeTime;
    var envelope = 0.0, onset = 0.0;
    final pulses = 1 + (weatherMoodRandom(_strikeId + 19.0) * 3).floor();
    for (var i = 0; i < pulses; i++) {
      if (i > 0) {
        onset += .34 + weatherMoodRandom(_strikeId * 7.0 + i + 3) * .32;
      }
      final local = age - onset;
      final decay = .09 + weatherMoodRandom(_strikeId * 13.0 + i + 8) * .13;
      if (local >= 0 && local < .8) {
        envelope = math.max(
          envelope,
          math.min(1, local / .018) *
              math.exp(-local / decay) *
              (i == 0
                  ? 1
                  : .55 + weatherMoodRandom(_strikeId + i.toDouble()) * .45),
        );
      }
    }
    return WeatherMoodLightning(
      envelope * values[7],
      .26 + weatherMoodRandom(_strikeId + 13.0) * .48,
      -.06 + weatherMoodRandom(_strikeId + 37.0) * .10,
      _strikeId,
    );
  }
}

/// Bounds GPU work per frame. Clouds are built in bands over several frames
/// so no single frame waits for a whole cloud image, and the band count
/// follows the frame rate this device actually reaches.
class WeatherMoodQuality {
  WeatherMoodQuality({required this.lowPower})
    : scale = _learnedScale[lowPower] ?? (lowPower ? .64 : 1),
      tiles = _learnedTiles[lowPower] ?? (lowPower ? 12 : 1),
      _slowAt = _learnedSlowAt[lowPower] ?? 0;
  // Later screensaver sessions start where the previous one settled.
  static final _learnedTiles = <bool, int>{};
  static final _learnedScale = <bool, double>{};
  static final _learnedSlowAt = <bool, int>{};
  final bool lowPower;
  // Start older GPUs near their sustainable size instead of making the first
  // several cloud frames stall while the adaptive limit catches up.
  double scale;

  /// Frames spent building each cloud keyframe, one band per frame.
  int tiles;
  int _slowAt;
  int _ticks = 0, _slow = 0, _quiet = 0, _slowWindows = 0;
  int _skip = 0;
  Duration _spent = Duration.zero, _raster = Duration.zero;
  int _frames = 0;
  int get fps => lowPower ? 20 : 30;
  int get steps => lowPower ? 40 : 96;
  double get width => (lowPower ? 560 : 1100) * scale;
  double get height => (lowPower ? 350 : 720) * scale;

  /// The display's refresh period. Frames land on every [vsyncs]th refresh
  /// so motion keeps an even cadence.
  Duration period = const Duration(microseconds: 16667);
  int get vsyncs =>
      math.max(1, (1000000 / fps / period.inMicroseconds).round());
  Duration get interval => period * vsyncs;

  /// Scene wind from 0 to 1, set by the renderer.
  double wind = 0;

  /// Slow clouds hide a long crossfade, while wind-driven clouds would show
  /// it, so keyframes come closer together as the wind picks up.
  int get maxTiles => math.max(
    1,
    (1200000 * (1 - wind.clamp(0.0, 1.0) * .5) / interval.inMicroseconds)
        .round(),
  );

  /// Leaves out the next few frame intervals, which carry deliberate one-off
  /// work such as the first full cloud image after a settings change.
  void skipTick() => _skip = 3;

  /// Records the time between two animation frames.
  void recordTick(Duration elapsed) {
    if (_skip > 0) {
      _skip--;
      return;
    }
    _ticks++;
    _spent += elapsed;
    // A frame that missed its refresh shows a whole period late.
    if (elapsed > interval + period ~/ 2) _slow++;
    if (_ticks < 10) return;
    final average = _spent ~/ _ticks;
    final raster = _frames == 0 ? Duration.zero : _raster ~/ _frames;
    if (_slow >= 4) {
      _quiet = 0;
      _slowAt = math.max(_slowAt, tiles);
      _slowWindows++;
      if (tiles < maxTiles) {
        final ratio = (average.inMicroseconds / interval.inMicroseconds).clamp(
          1.5,
          4.0,
        );
        tiles = math.min(maxTiles, (tiles * ratio).ceil());
      } else if (scale > .5 && _slowWindows >= 3) {
        // Resolution is the last resort, after sustained slow frames.
        scale = math.max(.5, scale * .8);
        _slowWindows = 0;
      }
    } else if (_slow == 0 && raster < interval * .4 && tiles - 1 > _slowAt) {
      // Only give back frames that never proved too slow on this device.
      if (++_quiet >= 3) {
        tiles--;
        _quiet = 0;
      }
    } else {
      _quiet = 0;
    }
    if (_slow < 4) _slowWindows = 0;
    _ticks = _slow = _frames = 0;
    _spent = _raster = Duration.zero;
    _learnedTiles[lowPower] = tiles;
    _learnedScale[lowPower] = scale;
    _learnedSlowAt[lowPower] = _slowAt;
  }

  /// Records the raster time of a rendered frame.
  void recordFrame(Duration raster) {
    _frames++;
    _raster += raster;
  }

  @visibleForTesting
  static void resetLearned() {
    _learnedTiles.clear();
    _learnedScale.clear();
    _learnedSlowAt.clear();
  }
}
