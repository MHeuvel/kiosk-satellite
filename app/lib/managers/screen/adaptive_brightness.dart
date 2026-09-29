import 'dart:math';

/// One point on the adaptive brightness curve: a light level and the
/// screen brightness there, both absolute (lux, 0..1).
typedef CurvePoint = ({double lux, double level});

/// The adaptive brightness curve (issues #343 and #742): four points the
/// screen brightness follows as the room's light moves. The two ends are
/// Dark room at Minimum brightness and Bright room at Maximum brightness;
/// below the first and above the last the level stays put. Between them a
/// smooth curve runs through all four, on the log of the light level,
/// because the eye judges light on a log scale (a linear map parks the
/// panel at the floor for the whole 0..50 lx evening and then jumps).
///
/// The curve is monotone cubic (Fritsch-Carlson): it passes through every
/// point, never overshoots one, and never dips where the points climb, so
/// a brighter room never dims the screen. Four points on one line draw
/// that line, which is the curve every install had before the middle two
/// points existed.
///
/// Pure: the screen manager owns the sensor stream, the ceiling every
/// setting supplies, and the write discipline; this is only the shape.
class AdaptiveCurve {
  AdaptiveCurve(List<CurvePoint> points) : points = _sane(points);

  /// The curve from its settings. The middle two points are stored as
  /// shares of the span between the ends (their light level on the log
  /// scale, their brightness between Minimum and Maximum), so turning
  /// Maximum brightness from Home Assistant stretches the whole curve
  /// instead of pushing the top end under the middle.
  factory AdaptiveCurve.fromSettings({
    required double minLevel,
    required double maxLevel,
    required double darkLux,
    required double brightLux,
    required double point2Position,
    required double point2Level,
    required double point3Position,
    required double point3Level,
  }) {
    final dark = max(darkLux, _luxFloor);
    final bright = max(brightLux, _luxFloor);
    double lux(double position) =>
        exp(log(dark) + position.clamp(0.0, 1.0) * (log(bright) - log(dark)));
    double level(double share) =>
        minLevel + share.clamp(0.0, 1.0) * (maxLevel - minLevel);
    return AdaptiveCurve([
      (lux: dark, level: minLevel),
      (lux: lux(point2Position), level: level(point2Level)),
      (lux: lux(point3Position), level: level(point3Level)),
      (lux: bright, level: maxLevel),
    ]);
  }

  /// The points, light levels rising and brightness never falling.
  final List<CurvePoint> points;

  /// The lowest light level the log scale takes: a sensor reports 0 in a
  /// dark room and log(0) is not a number.
  static const _luxFloor = 0.01;

  /// Where a middle point sits between the ends, for storing it: its
  /// light level as a share of the ends' log span.
  static double positionFor(double lux, double darkLux, double brightLux) {
    final dark = log(max(darkLux, _luxFloor));
    final bright = log(max(brightLux, _luxFloor));
    if (bright <= dark) return 0;
    return ((log(max(lux, _luxFloor)) - dark) / (bright - dark)).clamp(
      0.0,
      1.0,
    );
  }

  /// Its brightness as a share of Minimum to Maximum.
  static double shareFor(double level, double minLevel, double maxLevel) {
    if (maxLevel <= minLevel) return 0;
    return ((level - minLevel) / (maxLevel - minLevel)).clamp(0.0, 1.0);
  }

  /// Light levels that crossed or met (a write landing between two others)
  /// and brightness that fell are flattened, not trusted: the curve stays
  /// a function and stays monotone whatever the settings say mid-edit.
  static List<CurvePoint> _sane(List<CurvePoint> raw) {
    final out = <CurvePoint>[];
    for (final p in raw) {
      var lux = max(p.lux, _luxFloor);
      var level = p.level.clamp(0.0, 1.0);
      if (out.isNotEmpty) {
        lux = max(lux, out.last.lux);
        level = max(level, out.last.level);
      }
      out.add((lux: lux, level: level));
    }
    return List.unmodifiable(out);
  }

  /// The screen brightness for a light reading.
  double levelAt(double lux) {
    final first = points.first;
    final last = points.last;
    // The top end first: ends that met are a step at the bright point.
    if (lux >= last.lux) return last.level;
    if (lux <= first.lux) return first.level;
    final xs = [for (final p in points) log(p.lux)];
    final ys = [for (final p in points) p.level];
    final x = log(lux);
    var k = 0;
    while (k < points.length - 2 && x >= xs[k + 1]) {
      k++;
    }
    final h = xs[k + 1] - xs[k];
    // Two points at one light level are a step: the reading has passed
    // the first, so it is at the second.
    if (h <= 0) return ys[k + 1];
    final m = _tangents(xs, ys);
    final t = (x - xs[k]) / h;
    final t2 = t * t;
    final t3 = t2 * t;
    final y =
        (2 * t3 - 3 * t2 + 1) * ys[k] +
        (t3 - 2 * t2 + t) * h * m[k] +
        (-2 * t3 + 3 * t2) * ys[k + 1] +
        (t3 - t2) * h * m[k + 1];
    // The Hermite form can land a hair outside its neighbors in float.
    return y.clamp(ys[k], ys[k + 1]);
  }

  /// What the ceiling is multiplied by: the level here as a share of the
  /// top one, since the same factor scales the screensaver's own level and
  /// it should reach the same share of it in the dark.
  double factor(double lux) {
    final top = points.last.level;
    if (top <= 0) return 1.0;
    return (levelAt(lux) / top).clamp(0.0, 1.0);
  }

  /// Fritsch-Butland tangents: the weighted harmonic mean of the two
  /// neighboring slopes, zero at a flat step or a turn, one-sided at the
  /// ends. That keeps every segment inside its two points.
  static List<double> _tangents(List<double> xs, List<double> ys) {
    final n = xs.length;
    final h = [for (var i = 0; i < n - 1; i++) xs[i + 1] - xs[i]];
    final d = [
      for (var i = 0; i < n - 1; i++)
        h[i] <= 0 ? 0.0 : (ys[i + 1] - ys[i]) / h[i],
    ];
    final m = List<double>.filled(n, 0);
    m[0] = d[0];
    m[n - 1] = d[n - 2];
    for (var i = 1; i < n - 1; i++) {
      if (d[i - 1] <= 0 || d[i] <= 0) continue;
      final w1 = 2 * h[i] + h[i - 1];
      final w2 = h[i] + 2 * h[i - 1];
      m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i]);
    }
    return m;
  }
}
