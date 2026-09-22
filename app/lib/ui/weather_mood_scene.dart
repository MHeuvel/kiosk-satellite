import 'dart:math' as math;

/// Values match the approved scenes: clouds, night, rain, fog, snow, wind,
/// downpour, lightning, hail and storm darkness.
const weatherMoodPresets = <String, List<double>>{
  'sunny': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'clear-night': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'partlycloudy': [.065, 0, 0, 0, 0, 0, 0, 0, 0, 0],
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
  double _stormStart = 18, _strikeTime = 1.2, _nextStrike = 1.2;
  int _strikeId = -1;

  void update({
    required String condition,
    required bool night,
    required bool lightning,
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
    if (!lightning) values[7] = 0;
    if (immediate) values = [...next];
  }

  void advance(double seconds) {
    final dt = seconds.clamp(0.0, .15);
    time += dt;
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

/// Bounds GPU work before the first frame and reduces it after sustained load.
class WeatherMoodQuality {
  WeatherMoodQuality({required this.lowPower}) : scale = lowPower ? .64 : 1;
  final bool lowPower;
  // Start older GPUs near their sustainable size instead of making the first
  // several cloud frames stall while the adaptive limit catches up.
  double scale;
  int _slowFrames = 0;
  int get fps => lowPower ? 20 : 30;
  int get cloudFps => lowPower ? 5 : fps;
  int get steps => lowPower ? 40 : 96;
  double get width => (lowPower ? 560 : 1100) * scale;
  double get height => (lowPower ? 350 : 720) * scale;
  void recordFrame(Duration duration) {
    if (duration.inMicroseconds > 1000000 / fps * 1.8) {
      _slowFrames++;
    } else {
      _slowFrames = math.max(0, _slowFrames - 1);
    }
    if (_slowFrames >= 8 && scale > .5) {
      scale = math.max(.5, scale * .8);
      _slowFrames = 0;
    }
  }
}
