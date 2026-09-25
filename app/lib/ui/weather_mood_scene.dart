import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Values match the approved scenes: clouds, night, rain, fog, snow, wind,
/// downpour, lightning, hail and storm darkness.
const weatherMoodPresets = <String, List<double>>{
  'sunny': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'clear-night': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'partlycloudy': [.10, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'cloudy': [.51, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'rainy': [.71, 0, 1, 0, 0, 0, 0, 0, 0, 0],
  'snowy': [.58, 0, 0, 0, 1, 0, 0, 0, 0, 0],
  'fog': [.7, 0, 0, 1, 0, 0, 0, 0, 0, 0],
  'pouring': [1, 0, 1, 0, 0, .24, 1, 0, 0, .55],
  'snowy-rainy': [.88, 0, .62, 0, .75, .08, 0, 0, 0, .12],
  'windy': [.065, 0, 0, 0, 0, 1, 0, 0, 0, 0],
  'windy-variant': [.65, 0, 0, 0, 0, 1, 0, 0, 0, .12],
  'lightning': [.98, 0, 0, 0, 0, .20, 0, 1, 0, .68],
  'lightning-rainy': [1, 0, 1, 0, 0, .32, .36, 1, 0, .68],
  'hail': [.94, 0, 0, 0, 0, .14, 0, 0, 1, .44],
  'exceptional': [.48, 0, 0, 0, 0, 0, 0, 0, 0, 0],
};

double weatherMoodRandom(double value) {
  final n = math.sin(value * 127.1 + 311.7) * 43758.5453;
  return n - n.floorToDouble();
}

/// How far the cloud shader's volume moves from one moment to another, in
/// the shader's world units. The renderer slides cached cloud keyframes by
/// this much, so moving clouds glide between keyframes instead of fading
/// from one place to the next. Mirrors density() in
/// weather_mood_common.glsl.
({double x, double y, double z}) weatherMoodCloudShift({
  required double fromTime,
  required double fromWind,
  required double toTime,
  required double toWind,
  required double clouds,
}) {
  // Scattered cumulus drift slowly and ride the wind sideways.
  double sparseX(double time, double wind) =>
      .65 * math.sin((time - 18) * .016) - .085 * wind;
  double sparseZ(double time) => .17 * math.sin((time - 18) * .009);
  final sparseDx = sparseX(toTime, toWind) - sparseX(fromTime, fromWind),
      sparseDz = sparseZ(toTime) - sparseZ(fromTime);
  // Overcast noise moves in a rotated space. Turned back, its drift also
  // sinks a little.
  final dt = toTime - fromTime;
  final ax = .032 * dt + .17 * (toWind - fromWind), az = .014 * dt;
  final overcastDx = -(.8 * ax + .36 * az) / 2.1,
      overcastDy = -(.6 * ax - .48 * az) / 2.1,
      overcastDz = -.8 * az / 2.1;
  final t = ((clouds - .10) / .30).clamp(0.0, 1.0);
  final k = t * t * (3 - 2 * t);
  return (
    x: sparseDx + (overcastDx - sparseDx) * k,
    y: overcastDy * k,
    z: sparseDz + (overcastDz - sparseDz) * k,
  );
}

/// Where the cloud keyframe saw what [viewX], [viewY] shows once cloud at
/// [height] has moved by [shift]. Positions are screen fractions with y
/// pointing up. Mirrors weather_mood_blend.frag.
({double x, double y}) weatherMoodCloudSource(
  double viewX,
  double viewY,
  ({double x, double y, double z}) shift,
  double aspect, {
  double height = 1.5,
}) {
  final rayX = (viewX - .5) * aspect * .9, rayY = .28 + viewY * .9;
  final reach = height / rayY;
  final x = rayX * reach - shift.x,
      y = rayY * reach - shift.y,
      z = 1.35 * reach - shift.z;
  final scale = 1.35 / z;
  return (x: x * scale / (.9 * aspect) + .5, y: (y * scale - .28) / .9);
}

class WeatherMoodLightning {
  const WeatherMoodLightning(this.strength, this.x, this.y, this.id);
  static const none = WeatherMoodLightning(0, .5, 0, -1);
  final double strength, x, y;
  final int id;
}

/// The scattered cumulus in weather_mood_common.glsl: center, size and
/// proportions.
const _cumulus = [
  (x: -1.18, z: 3.5, size: .62, width: 1.18, depth: .92),
  (x: 1.65, z: 5.7, size: .74, width: 1.36, depth: .76),
  (x: .72, z: 2.6, size: .37, width: .88, depth: 1.05),
];

class WeatherMoodScene {
  String condition = 'exceptional';
  List<double> values = [...weatherMoodPresets['exceptional']!];
  List<double> _target = [...weatherMoodPresets['exceptional']!];
  double time = 18, windTime = 0;

  /// The view's width over its height, which sets how far the cumulus
  /// travel before they come around again.
  double aspect = 16 / 9;

  /// How far wind has carried each cumulus from its resting spot.
  final _carried = [0.0, 0.0, 0.0];
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
      _carried.fillRange(0, _carried.length, 0);
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
    // Wind carries the cumulus away. Once it drops, they glide back to
    // where a calm scene has them, since wherever the wind left them could
    // be out of view.
    final calm = (1 - values[5] / .25).clamp(0.0, 1.0);
    for (var i = 0; i < _carried.length; i++) {
      final loop = _loop(i);
      final away = _wrap(_carried[i], loop);
      final glide = -away.sign * math.min(.04, away.abs() * .2);
      _carried[i] = _wrap(
        away + dt * (-values[5] * .085 * (1 - calm) + glide * calm),
        loop,
      );
    }
  }

  /// Each cumulus travels a loop centered on the view, as wide as the view
  /// at its far side plus the reach of its edges, so it never shows twice
  /// and leaves one edge just as it comes back at the other.
  double _loop(int i) {
    final cloud = _cumulus[i];
    // The widest the clouds grow, when the sky is fullest.
    final size = cloud.size * 1.12;
    return aspect * (cloud.z + 1.5 * size * cloud.depth) / 1.5 +
        2 * 1.9 * size * cloud.width;
  }

  static double _wrap(double value, double loop) =>
      value - loop * ((value + loop / 2) / loop).floorToDouble();

  /// Where each cumulus sits right now, as an offset from its resting spot
  /// that keeps it inside its loop.
  List<double> get cumulus => [
    for (var i = 0; i < _carried.length; i++) _slide(i, 0),
  ];

  /// The same for the windy sky's second clouds in the left and near lanes,
  /// half a loop behind the first.
  List<double> get cumulusCopies => [_slide(0, .5), _slide(2, .5)];

  double _slide(int i, double behind) {
    final loop = _loop(i);
    return _wrap(
          _cumulus[i].x +
              .65 * math.sin((time - 18) * .016) +
              _carried[i] +
              behind * loop,
          loop,
        ) -
        _cumulus[i].x;
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
      tiles = _learnedTiles[lowPower] ?? (lowPower ? 6 : 1),
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

  /// Ray samples a single band may take. One draw over the whole cloud
  /// image ran long enough on a busy Portal Go for the GPU driver to reset
  /// the GPU and kill the app, so every device splits keyframes at least
  /// this finely, whatever the frame rate allows.
  static const maxBandSamples = 6000000;

  /// The fewest bands a [width] by [height] cloud image may render in.
  int minimumTiles(int width, int height) =>
      math.max(1, (width * height * steps / maxBandSamples).ceil());

  /// Scene wind from 0 to 1, set by the renderer.
  double wind = 0;

  /// Keyframes slide along with the wind, but a keyframe slid for long
  /// smears thick cloud, so keyframes come closer together as the wind
  /// picks up. A band on every frame keeps each frame's GPU work alike: a
  /// heavy band every other frame made frames reach the screen one or two
  /// refreshes apart from an even render cadence, which showed as judder.
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
