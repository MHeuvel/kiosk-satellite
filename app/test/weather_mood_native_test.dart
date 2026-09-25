import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/ui/weather_mood_renderer.dart';
import 'package:kiosk_satellite/ui/weather_mood_scene.dart';
import 'package:kiosk_satellite/ui/weather_mood_screensaver.dart';

void main() {
  test('native presets cover every Home Assistant condition', () {
    expect(weatherMoodPresets.keys.toSet(), weatherMoodConditions);
    final scene = WeatherMoodScene();
    for (final condition in weatherMoodConditions) {
      for (final night in [false, true]) {
        scene.update(
          condition: condition,
          night: night,
          lightning: true,
          immediate: true,
        );
        expect(scene.values.length, 10);
        expect(scene.values[1], night ? 1 : 0);
        expect(
          scene.values.every((v) => v.isFinite && v >= 0 && v <= 1),
          isTrue,
        );
      }
    }
    scene.update(
      condition: 'snowy',
      night: false,
      lightning: true,
      immediate: true,
    );
    scene.update(
      condition: 'unavailable',
      night: true,
      lightning: true,
      immediate: true,
    );
    expect(scene.condition, 'snowy');
    expect(scene.values[4], 1);
    expect(scene.values[1], 1);
  });

  test('weather transitions gradually and lightning stops immediately', () {
    final scene = WeatherMoodScene();
    scene.update(
      condition: 'sunny',
      night: false,
      lightning: true,
      immediate: true,
    );
    scene.update(
      condition: 'lightning-rainy',
      night: true,
      twilight: 1,
      lightning: true,
    );
    scene.advance(.1);
    expect(scene.values[0], inExclusiveRange(0, 1));
    expect(scene.twilight, inExclusiveRange(0, 1));
    scene.update(
      condition: 'lightning-rainy',
      night: true,
      lightning: true,
      immediate: true,
    );
    var flashes = 0;
    for (var i = 0; i < 500; i++) {
      scene.advance(.1);
      if (scene.lightning.strength > .05) flashes++;
    }
    expect(flashes, greaterThan(5));
    scene.update(condition: 'lightning-rainy', night: true, lightning: false);
    expect(scene.values[7], 0);
    expect(scene.lightning.strength, 0);
    expect(scene.values[2], 1);
  });

  test('cumulus the wind carried off glide back once it drops', () {
    final scene = WeatherMoodScene()..aspect = 1.6;
    scene.update(
      condition: 'windy',
      night: false,
      lightning: false,
      immediate: true,
    );
    final start = scene.cumulus;
    for (var i = 0; i < 100; i++) {
      scene.advance(.1);
    }
    // Ten seconds of full wind carry every cloud left.
    for (var i = 0; i < 3; i++) {
      expect(scene.cumulus[i], lessThan(start[i] - .5));
    }
    scene.update(condition: 'partlycloudy', night: false, lightning: false);
    for (var i = 0; i < 3000; i++) {
      scene.advance(.1);
    }
    // In calm air they end up where a fresh calm scene has them.
    final rest = .65 * math.sin((scene.time - 18) * .016);
    for (final offset in scene.cumulus) {
      expect(offset, closeTo(rest, 1e-6));
    }
    scene.update(condition: 'windy', night: false, lightning: false);
    for (var i = 0; i < 300; i++) {
      scene.advance(.1);
    }
    // A scene that starts over starts them at rest too.
    scene.update(
      condition: 'partlycloudy',
      night: false,
      lightning: false,
      immediate: true,
    );
    final settled = .65 * math.sin((scene.time - 18) * .016);
    for (final offset in scene.cumulus) {
      expect(offset, closeTo(settled, 1e-6));
    }
  });

  test('cloud keyframes slide with the wind', () {
    ({double x, double y, double z}) shift(double clouds, double wind) =>
        weatherMoodCloudShift(
          fromTime: 100,
          fromWind: 50,
          toTime: 100,
          toWind: 50 + wind,
          clouds: clouds,
        );
    // No time and no wind, no movement: the view samples itself.
    final still = weatherMoodCloudSource(.3, .7, shift(.5, 0), 1.6);
    expect(still.x, closeTo(.3, 1e-9));
    expect(still.y, closeTo(.7, 1e-9));
    // Wind carries scattered cumulus to the left, so the screen shows what
    // the keyframe had further right, and more so near the top, where the
    // cloud layer is closer.
    final sparse = shift(.065, 1);
    expect(sparse.x, closeTo(-.085, 1e-9));
    expect(sparse.y, 0);
    final low = weatherMoodCloudSource(.5, .1, sparse, 1.6),
        high = weatherMoodCloudSource(.5, .9, sparse, 1.6);
    expect(low.x, greaterThan(.5));
    expect(high.x - .5, greaterThan(2 * (low.x - .5)));
    expect(high.y, closeTo(.9, 1e-9));
    // Low clouds cross the screen faster than high ones.
    final near = weatherMoodCloudSource(.5, .5, sparse, 1.6, height: 1.2),
        far = weatherMoodCloudSource(.5, .5, sparse, 1.6, height: 2.4);
    expect(near.x - .5, closeTo(2 * (far.x - .5), 1e-9));
    // Overcast noise also sinks, so its keyframes need room above.
    final overcast = shift(.65, 1);
    expect(overcast.x, lessThan(0));
    expect(overcast.y, lessThan(0));
    expect(weatherMoodCloudSource(.5, .9, overcast, 1.6).y, greaterThan(.9));
  });

  test('quality spreads clouds over frames before shrinking them', () {
    WeatherMoodQuality.resetLearned();
    addTearDown(WeatherMoodQuality.resetLearned);
    final quality = WeatherMoodQuality(lowPower: true);
    expect(quality.steps, 40);
    expect(quality.fps, 20);
    expect(quality.tiles, 6);
    // Up to 1.2 seconds per keyframe, half that in full wind.
    expect(quality.maxTiles, 24);
    quality.wind = 1;
    expect(quality.maxTiles, 12);
    quality.wind = 0;
    expect(quality.width, lessThanOrEqualTo(360));
    const slow = Duration(milliseconds: 180), fast = Duration(milliseconds: 50);
    for (var i = 0; i < 10; i++) {
      quality.recordTick(slow);
    }
    // One window at a third of the target rate spreads clouds much further.
    expect(quality.tiles, 22);
    expect(quality.scale, .64);
    for (var i = 0; i < 100; i++) {
      quality.recordTick(slow);
    }
    expect(quality.tiles, quality.maxTiles);
    expect(quality.scale, .5);
    expect(quality.width, 280);
    expect(quality.height, 175);
    // A band count that proved too slow is never used again.
    for (var i = 0; i < 400; i++) {
      quality.recordFrame(const Duration(milliseconds: 5));
      quality.recordTick(fast);
    }
    expect(quality.tiles, quality.maxTiles);
    // Later sessions start from what this device sustained.
    final next = WeatherMoodQuality(lowPower: true);
    expect(next.tiles, quality.maxTiles);
    expect(next.scale, .5);
    final high = WeatherMoodQuality(lowPower: false);
    expect(high.tiles, 1);
    // No band may be large enough to trip a GPU hang reset: a full-size
    // Portal Go keyframe splits into 13 bands, an Echo Show one needs none.
    expect(high.minimumTiles(1100, 688), 13);
    expect(quality.minimumTiles(358, 224), 1);
    expect(high.fps, 30);
    // Deliberate one-off work, such as a full image after a settings
    // change, does not count against the device.
    high.skipTick();
    for (var i = 0; i < 3; i++) {
      high.recordTick(const Duration(milliseconds: 200));
    }
    expect(high.tiles, 1);
    // A 60 Hz display shows a 30 fps scene on every second refresh.
    expect(high.vsyncs, 2);
    high.period = const Duration(microseconds: 8333);
    expect(high.vsyncs, 4);
    high.period = const Duration(microseconds: 16667);
    for (var i = 0; i < 10; i++) {
      high.recordTick(const Duration(milliseconds: 50));
    }
    expect(high.tiles, 2);
    for (var i = 0; i < 400; i++) {
      high.recordFrame(const Duration(milliseconds: 3));
      high.recordTick(const Duration(milliseconds: 33));
    }
    expect(high.tiles, 2);
  });

  testWidgets('a hidden scene reports ready for the change it reflects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(96, 54);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Test frames all read as slow, and what the renderer learns from them
    // would carry into later tests.
    addTearDown(WeatherMoodQuality.resetLearned);
    addTearDown(resetWeatherMoodPrograms);
    final ready = <int>[];
    Future<void> show(String condition, int token) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WeatherMoodRenderer(
            condition: condition,
            night: false,
            lightning: false,
            active: true,
            lowPower: true,
            revealed: false,
            revealToken: token,
            onReady: ready.add,
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await show('exceptional', 0);
    expect(ready, [0]);
    // The first real weather arrives with a new token and snaps the scene.
    await show('cloudy', 1);
    expect(ready, [0, 1]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  });

  testWidgets('native shaders preserve skies and moon occlusion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final failures = <Object>[];
    Future<List<int>> render(
      String condition,
      bool night, {
      double twilight = 0,
      bool lowPower = true,
      bool active = false,
      bool reduced = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: WeatherMoodRenderer(
                key: ValueKey(lowPower),
                condition: condition,
                night: night,
                twilight: twilight,
                lightning: false,
                active: active,
                lowPower: lowPower,
                immediate: true,
                onError: failures.add,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      // GPU pictures complete outside the widget test's fake clock.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(failures, isEmpty);
      final pixels = await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: tester.view.devicePixelRatio);
        try {
          return (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List().toList();
        } finally {
          image.dispose();
        }
      });
      return pixels!;
    }

    int luminance(List<int> pixels, int x, int y) {
      final i = (y * 640 + x) * 4;
      return pixels[i] + pixels[i + 1] + pixels[i + 2];
    }

    final clear = await render('sunny', false);
    expect(luminance(clear, 320, 180), greaterThan(100));
    expect(luminance(clear, 538, 86), greaterThan(luminance(clear, 429, 86)));
    final night = await render('sunny', true);
    expect(luminance(night, 538, 86), greaterThan(500));
    expect(luminance(night, 320, 180), lessThan(luminance(clear, 320, 180)));
    expect(
      luminance(night, 516, 86),
      greaterThan(luminance(night, 429, 86) + 80),
    );
    // Changing display density must rebuild the cached sky at physical
    // resolution and keep the moon in the same place on the panel.
    tester.view.devicePixelRatio = 2;
    final denseNight = await render('sunny', true);
    expect(denseNight.length, night.length);
    expect(luminance(denseNight, 538, 86), greaterThan(500));
    tester.view.devicePixelRatio = 1;
    final fog = await render('fog', true);
    expect(luminance(fog, 538, 86), lessThan(luminance(night, 538, 86) * .6));
    final clouds = await render('cloudy', false, lowPower: false);
    expect(clouds, isNot(equals(clear)));
    expect(luminance(clouds, 320, 180), greaterThan(20));
    for (final condition in weatherMoodConditions) {
      for (final isNight in [false, true]) {
        final pixels = await render(condition, isNight);
        expect(
          luminance(pixels, 320, 180),
          greaterThan(0),
          reason: '$condition, night=$isNight',
        );
      }
    }
    // Check both shader variants and cached-sky invalidation on a period change.
    for (final lowPower in [false, true]) {
      final dawn = await render(
        'sunny',
        false,
        twilight: 1,
        lowPower: lowPower,
      );
      final i = (345 * 640 + 320) * 4;
      final upper = (60 * 640 + 320) * 4;
      expect(dawn[i], greaterThan(dawn[i + 2] * 1.1));
      expect(dawn[upper + 2], greaterThan(dawn[upper] * 1.5));
      expect(dawn, isNot(equals(clear)));
      final day = await render('sunny', false, lowPower: lowPower);
      expect(day[i + 2], greaterThan(day[i]));
      for (final condition in weatherMoodConditions) {
        final pixels = await render(
          condition,
          false,
          twilight: 1,
          lowPower: lowPower,
        );
        expect(
          luminance(pixels, 320, 180),
          greaterThan(0),
          reason: '$condition at dawn/dusk, lowPower=$lowPower',
        );
      }
    }
    final pausedRain = await render('rainy', true);
    expect(await render('rainy', true), equals(pausedRain));
    expect(
      await render('rainy', true, active: true),
      isNot(equals(pausedRain)),
    );
    final reducedRain = await render(
      'rainy',
      true,
      active: true,
      reduced: true,
    );
    expect(
      await render('rainy', true, active: true, reduced: true),
      equals(reducedRain),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    expect(tester.takeException(), isNull);
  });
}
