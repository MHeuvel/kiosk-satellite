import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'assist_art.dart';

/// The Lens Flares skin's background, ported from its script
/// (lens-flares.js): vertical light streaks and bokeh dots, twinkling and
/// drifting, built additively and drawn over black three times through
/// 60, 22 and 6 px blurs whose strength follows the audio. Its canvas caps
/// the pixel ratio at 1.25, so every size in the script is in those
/// pixels; they are converted to logical pixels here the same way.
class LensFlaresArt extends StatefulWidget {
  const LensFlaresArt({
    super.key,
    required this.mode,
    required this.reactive,
    required this.level,
  });

  final ArtMode mode;
  final bool reactive;
  final ValueListenable<double> level;

  @override
  State<LensFlaresArt> createState() => _LensFlaresArtState();
}

class _LensFlaresArtState extends State<LensFlaresArt>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _sim = _FlareSim();
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    final raw = switch (widget.mode) {
      ArtMode.thinking => 0.4,
      ArtMode.idle => 0.0,
      _ => widget.reactive ? widget.level.value.clamp(0.0, 1.0) : 0.0,
    };
    final watch = Stopwatch()..start();
    _sim.step(dt, raw, elapsed.inMicroseconds / 1e6);
    ArtCost.step(watch);
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _sim.sprites?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FlarePainter(_sim, _frame, math.min(dpr, 1.25)),
      ),
    );
  }
}

const _blueDeep = [10, 50, 240];
const _blueMid = [40, 130, 255];
const _blueLight = [120, 200, 255];
const _blueWhite = [200, 230, 255];
const _warmDeep = [230, 25, 90];
const _warmMid = [255, 60, 120];
const _warmLight = [255, 130, 170];

class _Streak {
  _Streak({
    required this.x,
    required this.width,
    required this.heightFrac,
    required this.yOff,
    required this.color,
    required this.alpha,
    required this.coreColor,
    required this.coreAlpha,
    required this.twinklePhase,
    required this.twinkleRate,
    required this.audioReactive,
    required this.driftScale,
  });

  final double x;
  final double width;
  final double heightFrac;
  final double yOff;
  final List<int> color;
  final double alpha;
  final List<int>? coreColor;
  final double coreAlpha;
  final double twinklePhase;
  final double twinkleRate;
  final bool audioReactive;
  final double driftScale;
}

class _Bokeh {
  _Bokeh({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.alpha,
    required this.twinklePhase,
    required this.twinkleRate,
    required this.audioReactive,
    required this.driftScale,
  });

  final double x;
  final double y;
  final double size;
  final List<int> color;
  final double alpha;
  final double twinklePhase;
  final double twinkleRate;
  final bool audioReactive;
  final double driftScale;
}

class _FlareSim {
  final _random = math.Random();
  final streaks = <_Streak>[];
  final bokeh = <_Bokeh>[];
  double smoothLevel = 0;
  double energyLevel = 0;
  double drift = 0;
  double time = 0;
  bool started = false;

  /// The scene's blurred sprites, built on the first frame at its size.
  _FlareSprites? sprites;

  _FlareSim() {
    _build();
  }

  List<int> _pickBlue() {
    final r = _random.nextDouble();
    if (r < 0.20) return _blueDeep;
    if (r < 0.65) return _blueMid;
    if (r < 0.92) return _blueLight;
    return _blueWhite;
  }

  List<int> _pickWarm() {
    final r = _random.nextDouble();
    if (r < 0.30) return _warmDeep;
    if (r < 0.75) return _warmMid;
    return _warmLight;
  }

  double _rand() => _random.nextDouble();

  void _build() {
    const nBlue = 16;
    for (var i = 0; i < nBlue; i++) {
      final isCore = _rand() < 0.45;
      streaks.add(
        _Streak(
          x: (i + 0.5) / nBlue + (_rand() - 0.5) * (0.5 / nBlue),
          width: 30 + _rand() * 220,
          heightFrac: 0.55 + _rand() * 0.40,
          yOff: (_rand() - 0.5) * 0.20,
          color: _pickBlue(),
          alpha: 0.36 + _rand() * 0.40,
          coreColor: isCore ? _blueWhite : null,
          coreAlpha: isCore ? 0.42 + _rand() * 0.36 : 0,
          twinklePhase: _rand() * math.pi * 2,
          twinkleRate: 0.4 + _rand() * 1.4,
          audioReactive: _rand() < 0.55,
          driftScale: 0.6 + _rand() * 0.8,
        ),
      );
    }
    for (var i = 0; i < 4; i++) {
      final isCore = _rand() < 0.6;
      streaks.add(
        _Streak(
          x: _rand(),
          width: 25 + _rand() * 90,
          heightFrac: 0.45 + _rand() * 0.45,
          yOff: (_rand() - 0.5) * 0.25,
          color: _pickWarm(),
          alpha: 0.44 + _rand() * 0.36,
          coreColor: isCore ? _warmLight : null,
          coreAlpha: isCore ? 0.40 + _rand() * 0.34 : 0,
          twinklePhase: _rand() * math.pi * 2,
          twinkleRate: 0.5 + _rand() * 1.2,
          audioReactive: _rand() < 0.65,
          driftScale: 0.6 + _rand() * 0.8,
        ),
      );
    }
    for (var i = 0; i < 36; i++) {
      final isWarm = _rand() < 0.22;
      bokeh.add(
        _Bokeh(
          x: _rand(),
          y: _rand(),
          size: 18 + _rand() * 90,
          color: isWarm ? _pickWarm() : _pickBlue(),
          alpha: 0.18 + _rand() * 0.42,
          twinklePhase: _rand() * math.pi * 2,
          twinkleRate: 0.3 + _rand() * 1.0,
          audioReactive: _rand() < 0.35,
          driftScale: 0.2 + _rand() * 0.4,
        ),
      );
    }
  }

  void step(double dt, double raw, double t) {
    started = true;
    time = t;
    smoothLevel +=
        (raw - smoothLevel) * easeOver(raw > smoothLevel ? 0.20 : 0.08, dt);
    energyLevel +=
        (raw - energyLevel) * easeOver(raw > energyLevel ? 0.08 : 0.03, dt);
    drift += dt * (0.0035 + energyLevel * 0.012);
    if (drift > 1) drift -= 1;
  }
}

/// One blur of the script's three: its radius in canvas pixels and the
/// scale its sprites are kept at. The wider the blur, the smaller the
/// sprite can be without showing it.
const _tiers = [(60.0, 0.125), (22.0, 0.25), (6.0, 0.5)];

/// One shape of the scene: a streak, its core or a bokeh dot, at alpha 1,
/// in a box of canvas pixels.
class _Shape {
  _Shape(this.size, this.paint);

  final Size size;
  final void Function(Canvas canvas) paint;
}

/// Every shape of the scene, blurred once per tier into one sheet.
///
/// A blur is linear, and each shape keeps its size and color for the life
/// of the scene: only its alpha, its drift and a slight stretch move. So a
/// frame is those sprites scaled back up and added over black at their
/// alphas, one textured draw, where blurring the scene every frame took
/// several offscreen passes that low end GPUs could not keep up with.
class _FlareSprites {
  _FlareSprites._(this.sheet, this.shader, this.rects, this.w, this.h);

  final ui.Image sheet;
  final ui.ImageShader shader;

  /// Per shape, per tier, its rect in [sheet].
  final List<List<Rect>> rects;
  final double w;
  final double h;

  static _FlareSprites build(List<_Shape> shapes, double w, double h) {
    // Shelf packing, one tier after another.
    const sheetW = 2048.0;
    final rects = [for (final _ in shapes) <Rect>[]];
    var x = 0.0, y = 0.0, shelf = 0.0;
    for (final (sigma, scale) in _tiers) {
      final pad = sigma * 3;
      for (var i = 0; i < shapes.length; i++) {
        final size = shapes[i].size;
        final sw = ((size.width + pad * 2) * scale).ceilToDouble();
        final sh = ((size.height + pad * 2) * scale).ceilToDouble();
        if (x + sw > sheetW) {
          x = 0;
          y += shelf + 2;
          shelf = 0;
        }
        rects[i].add(Rect.fromLTWH(x, y, sw, sh));
        x += sw + 2;
        shelf = math.max(shelf, sh);
      }
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var t = 0; t < _tiers.length; t++) {
      final (sigma, scale) = _tiers[t];
      final pad = sigma * 3;
      for (var i = 0; i < shapes.length; i++) {
        final r = rects[i][t];
        final size = shapes[i].size;
        // The layer opens after the scale so its blur is in canvas
        // pixels: Impeller shrinks a layer's blur by any scale applied
        // inside it.
        canvas
          ..save()
          ..clipRect(r)
          ..translate(r.left, r.top)
          ..scale(scale)
          ..translate(pad, pad)
          ..saveLayer(
            Rect.fromLTWH(
              -pad,
              -pad,
              size.width + pad * 2,
              size.height + pad * 2,
            ),
            Paint()
              ..imageFilter = ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
          );
        shapes[i].paint(canvas);
        canvas
          ..restore()
          ..restore();
      }
    }
    final picture = recorder.endRecording();
    final sheet = ArtCost.snapshot(
      () => picture.toImageSync(sheetW.toInt(), (y + shelf).ceil()),
    );
    picture.dispose();
    return _FlareSprites._(
      sheet,
      ui.ImageShader(
        sheet,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
        filterQuality: FilterQuality.low,
      ),
      rects,
      w,
      h,
    );
  }

  void dispose() {
    shader.dispose();
    sheet.dispose();
  }
}

class _FlarePainter extends CustomPainter {
  _FlarePainter(this.sim, Listenable frame, this.k) : super(repaint: frame);

  final _FlareSim sim;

  /// The script's canvas pixels per logical pixel.
  final double k;

  static Color _rgba(List<int> c, double a) =>
      Color.fromRGBO(c[0], c[1], c[2], a.clamp(0.0, 1.0));

  static double _falloff(double xNorm) {
    final d = (xNorm - 0.5).abs() * 2;
    return 1 - math.pow(d, 1.6) * 0.55;
  }

  /// The scene's shapes at alpha 1, in the order [_paint] walks them: each
  /// streak, then its core when it has one, then the bokeh.
  List<_Shape> _shapes(double h) {
    final add = Paint()..blendMode = BlendMode.plus;
    final shapes = <_Shape>[];
    for (final s in sim.streaks) {
      final sh = h * s.heightFrac;
      shapes.add(
        _Shape(Size(s.width, sh), (canvas) {
          canvas.drawRect(
            Rect.fromLTWH(0, 0, s.width, sh),
            add
              ..shader = ui.Gradient.linear(
                Offset.zero,
                Offset(0, sh),
                [
                  const Color(0x00000000),
                  _rgba(s.color, 0.45),
                  _rgba(s.color, 1),
                  _rgba(s.color, 0.45),
                  const Color(0x00000000),
                ],
                const [0, 0.18, 0.5, 0.82, 1],
              ),
          );
        }),
      );
      final coreColor = s.coreColor;
      if (coreColor != null) {
        final coreW = math.min(s.width * 0.18, 12.0);
        shapes.add(
          _Shape(Size(coreW, sh), (canvas) {
            canvas.drawRect(
              Rect.fromLTWH(0, 0, coreW, sh),
              add
                ..shader = ui.Gradient.linear(
                  Offset.zero,
                  Offset(0, sh),
                  [
                    const Color(0x00000000),
                    _rgba(coreColor, 0.55),
                    _rgba(coreColor, 1),
                    _rgba(coreColor, 0.55),
                    const Color(0x00000000),
                  ],
                  const [0, 0.20, 0.5, 0.80, 1],
                ),
            );
          }),
        );
      }
    }
    for (final b in sim.bokeh) {
      shapes.add(
        _Shape(Size.square(b.size * 2), (canvas) {
          final center = Offset(b.size, b.size);
          canvas.drawCircle(
            center,
            b.size,
            add
              ..shader = ui.Gradient.radial(
                center,
                b.size,
                [_rgba(b.color, 1), _rgba(b.color, 0.40), _rgba(b.color, 0)],
                const [0, 0.45, 1],
              ),
          );
        }),
      );
    }
    return shapes;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final watch = Stopwatch()..start();
    _paint(canvas, size);
    ArtCost.paint(watch);
  }

  void _paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    // The canvas fills itself black before the bloom. Once running, the
    // black comes with the widest blur's region instead, one full screen
    // pass fewer.
    if (!sim.started) {
      canvas.drawRect(screen, Paint()..color = const Color(0xFF000000));
      return;
    }
    final w = size.width * k;
    final h = size.height * k;
    var sprites = sim.sprites;
    if (sprites == null || sprites.w != w || sprites.h != h) {
      sprites?.dispose();
      sprites = sim.sprites = _FlareSprites.build(_shapes(h), w, h);
    }
    // The three blurs are added at these strengths, which follow the audio.
    final weights = [
      0.48 + sim.energyLevel * 0.28,
      0.62 + sim.smoothLevel * 0.20,
      0.70,
    ];
    // Each tier's sprites are added up in their own region of one small
    // offscreen image, at the tier's scale, then that region is stretched
    // over the screen. Added up at full size, their overlapping margins
    // were more pixels than low end GPUs fill in a frame.
    final regions = <Rect>[];
    var top = 0.0;
    for (final (_, scale) in _tiers) {
      final r = Rect.fromLTWH(
        0,
        top,
        math.max(1, (w * scale).ceil()).toDouble(),
        math.max(1, (h * scale).ceil()).toDouble(),
      );
      regions.add(r);
      top = r.bottom + 2;
    }
    final positions = [for (final _ in _tiers) <double>[]];
    final coords = [for (final _ in _tiers) <double>[]];
    final colors = [for (final _ in _tiers) <int>[]];
    // Adds shape [index] at [alpha], its box centered on (cx, cy) in
    // canvas pixels and stretched vertically by [stretch], once per tier.
    void quads(int index, double alpha, double cx, double cy, double stretch) {
      final rects = sprites!.rects[index];
      for (var t = 0; t < _tiers.length; t++) {
        final a = (alpha * weights[t]).clamp(0.0, 1.0);
        if (a < 0.002) continue;
        final (_, scale) = _tiers[t];
        final r = rects[t];
        final region = regions[t];
        final x = region.left + cx * scale;
        final y = region.top + cy * scale;
        final halfW = r.width / 2;
        final halfH = r.height / 2 * stretch;
        final l = x - halfW, rt = x + halfW, tp = y - halfH, b = y + halfH;
        positions[t].addAll([l, tp, rt, tp, rt, b, l, tp, rt, b, l, b]);
        coords[t].addAll([
          r.left, r.top, r.right, r.top, r.right, r.bottom, //
          r.left, r.top, r.right, r.bottom, r.left, r.bottom,
        ]);
        final color = Color.fromRGBO(255, 255, 255, a).toARGB32();
        for (var v = 0; v < 6; v++) {
          colors[t].add(color);
        }
      }
    }

    final t = sim.time;
    final level = sim.smoothLevel;
    var index = 0;
    for (final s in sim.streaks) {
      final twinkle =
          math.sin(t * s.twinkleRate + s.twinklePhase) * 0.30 + 0.70;
      final audio = s.audioReactive ? level * 0.62 : 0.0;
      final cx = (((s.x + sim.drift * s.driftScale) % 1) + 1) % 1 * w;
      final falloff = _falloff(cx / w);
      final alpha = math.min(1.0, (s.alpha * twinkle + audio) * falloff);
      final cy = h * (0.5 + s.yOff);
      final stretch = 1 + level * 0.10;
      if (alpha >= 0.005) quads(index, alpha, cx, cy, stretch);
      index++;
      if (s.coreColor != null) {
        final coreA = math.min(1.0, s.coreAlpha * twinkle + audio * 0.6);
        // The core is drawn only with its streak, at the streak's height.
        if (alpha >= 0.005) quads(index, coreA, cx, cy, stretch);
        index++;
      }
    }
    for (final b in sim.bokeh) {
      final twinkle =
          math.sin(t * b.twinkleRate + b.twinklePhase) * 0.35 + 0.65;
      final audio = b.audioReactive ? level * 0.42 : 0.0;
      final cx = (((b.x + sim.drift * b.driftScale) % 1) + 1) % 1 * w;
      final alpha = math.min(
        1.0,
        (b.alpha * twinkle + audio) * _falloff(cx / w),
      );
      if (alpha >= 0.005) quads(index, alpha, cx, b.y * h, 1);
      index++;
    }
    final recorder = ui.PictureRecorder();
    final offscreen = Canvas(recorder);
    offscreen.drawRect(regions[0], Paint()..color = const Color(0xFF000000));
    final add = Paint()
      ..blendMode = BlendMode.plus
      ..shader = sprites.shader;
    for (var t = 0; t < _tiers.length; t++) {
      if (positions[t].isEmpty) continue;
      final vertices = ui.Vertices.raw(
        VertexMode.triangles,
        Float32List.fromList(positions[t]),
        textureCoordinates: Float32List.fromList(coords[t]),
        colors: Int32List.fromList(colors[t]),
      );
      offscreen
        ..save()
        ..clipRect(regions[t])
        ..drawVertices(vertices, BlendMode.modulate, add)
        ..restore();
      vertices.dispose();
    }
    final picture = recorder.endRecording();
    final atlas = ArtCost.snapshot(
      () => picture.toImageSync(regions[2].width.toInt(), top.ceil()),
    );
    picture.dispose();
    for (var t = 0; t < regions.length; t++) {
      canvas.drawImageRect(
        atlas,
        regions[t],
        screen,
        Paint()
          ..filterQuality = FilterQuality.low
          ..blendMode = t == 0 ? BlendMode.src : BlendMode.plus,
      );
    }
    atlas.dispose();
  }

  @override
  bool shouldRepaint(_FlarePainter old) => old.sim != sim || old.k != k;
}
