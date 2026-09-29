import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/screen/adaptive_brightness.dart';

/// The adaptive brightness curve (issues #343 and #742): four points the
/// screen brightness follows as the room's light moves, and the factor
/// every brightness setting is multiplied by.
void main() {
  AdaptiveCurve line({
    double min = 0.2,
    double max = 1.0,
    double dark = 5,
    double bright = 500,
  }) => AdaptiveCurve.fromSettings(
    minLevel: min,
    maxLevel: max,
    darkLux: dark,
    brightLux: bright,
    point2Position: 1 / 3,
    point2Level: 1 / 3,
    point3Position: 2 / 3,
    point3Level: 2 / 3,
  );

  // The shape from issue #742: a sensor that reads low in the evening,
  // so the curve climbs steeply between 10 and 15 lx.
  final steep = AdaptiveCurve([
    (lux: 5, level: 0.05),
    (lux: 10, level: 0.10),
    (lux: 15, level: 0.30),
    (lux: 300, level: 1.0),
  ]);

  test('the default middle points draw the straight log line the curve was '
      'before they existed', () {
    final curve = line();
    // sqrt(5 * 500) = 50 lx sits halfway up the log scale.
    expect(curve.levelAt(50), closeTo(0.6, 1e-9));
    for (final lux in [7.0, 20.0, 120.0, 400.0]) {
      final t = (log(lux) - log(5)) / (log(500) - log(5));
      expect(curve.levelAt(lux), closeTo(0.2 + 0.8 * t, 1e-9), reason: '$lux');
    }
  });

  test('the same numbers as the remote admin', () {
    // test/adaptive_curve_test.mjs pins the same values on the remote.
    final expected = {
      6.0: 0.060943507576,
      7.0: 0.069020084484,
      12.0: 0.176648713345,
      40.0: 0.580238677605,
      120.0: 0.808277772294,
    };
    for (final e in expected.entries) {
      expect(steep.levelAt(e.key), closeTo(e.value, 1e-9), reason: '${e.key}');
    }
  });

  test('flat before the first point and after the last', () {
    expect(steep.levelAt(0), 0.05);
    expect(steep.levelAt(5), 0.05);
    expect(steep.levelAt(300), 1.0);
    expect(steep.levelAt(50000), 1.0);
  });

  test('passes through every point', () {
    for (final p in steep.points) {
      expect(steep.levelAt(p.lux), closeTo(p.level, 1e-9), reason: '${p.lux}');
    }
  });

  test('never dips where the points climb, and never overshoots a point', () {
    var last = -1.0;
    for (var lux = 1.0; lux <= 1000; lux *= 1.01) {
      final level = steep.levelAt(lux);
      expect(level, greaterThanOrEqualTo(last - 1e-12), reason: '$lux');
      last = level;
    }
    for (var lux = 10.0; lux <= 15; lux += 0.1) {
      expect(steep.levelAt(lux), inInclusiveRange(0.10, 0.30));
    }
  });

  test('two points at one brightness hold it between them', () {
    final shelf = AdaptiveCurve([
      (lux: 2, level: 0.1),
      (lux: 20, level: 0.5),
      (lux: 100, level: 0.5),
      (lux: 400, level: 0.9),
    ]);
    for (var lux = 20.0; lux <= 100; lux += 5) {
      expect(shelf.levelAt(lux), closeTo(0.5, 1e-9), reason: '$lux');
    }
  });

  test('the factor is the level over the top point', () {
    final curve = line(min: 0.15, max: 0.8, dark: 5, bright: 300);
    expect(curve.factor(1), closeTo(0.15 / 0.8, 1e-9));
    expect(curve.factor(1000), 1.0);
    expect(curve.factor(40), closeTo(curve.levelAt(40) / 0.8, 1e-9));
  });

  test('the middle points are shares of the span between the ends, so a '
      'new Maximum stretches the curve', () {
    const dark = 5.0;
    const bright = 300.0;
    final position = AdaptiveCurve.positionFor(10, dark, bright);
    final share = AdaptiveCurve.shareFor(0.2, 0.15, 0.8);
    AdaptiveCurve at(double max) => AdaptiveCurve.fromSettings(
      minLevel: 0.15,
      maxLevel: max,
      darkLux: dark,
      brightLux: bright,
      point2Position: position,
      point2Level: share,
      point3Position: 0.8,
      point3Level: 0.9,
    );
    final before = at(0.8);
    expect(before.points[1].lux, closeTo(10, 1e-9));
    expect(before.points[1].level, closeTo(0.2, 1e-9));
    // Home Assistant turns Maximum down: the middle follows, still under it.
    final after = at(0.5);
    expect(after.points[1].lux, closeTo(10, 1e-9));
    expect(after.points[1].level, closeTo(0.15 + share * 0.35, 1e-9));
    expect(after.points[2].level, lessThan(0.5));
  });

  test('points that crossed mid-edit flatten instead of turning back', () {
    final crossed = AdaptiveCurve([
      (lux: 50, level: 0.4),
      (lux: 10, level: 0.2),
      (lux: 100, level: 0.6),
      (lux: 200, level: 0.9),
    ]);
    expect(crossed.points[1].lux, 50);
    expect(crossed.points[1].level, 0.4);
    expect(crossed.levelAt(49), 0.4);
    expect(crossed.levelAt(75).isNaN, isFalse);
  });

  test('a zero light level does not produce NaN', () {
    final zero = line(dark: 0);
    expect(zero.levelAt(0), 0.2);
    expect(zero.levelAt(1).isNaN, isFalse);
    expect(zero.levelAt(1), greaterThan(0.2));
  });

  test('ends that met become a step at the bright point', () {
    final equal = line(dark: 50, bright: 50);
    expect(equal.levelAt(49), 0.2);
    expect(equal.levelAt(50), 1.0);
  });
}
