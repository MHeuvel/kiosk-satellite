import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'assist_skins.dart';

/// What the bar shows: the skins animate differently while listening,
/// thinking and speaking (their .listening, .processing and .speaking).
enum ArtMode { listening, thinking, speaking, idle }

/// A keyframe animation's value at [t] seconds: [frames] are (offset 0..1,
/// value) pairs, each segment eased by [curve], as CSS applies a timing
/// function per keyframe interval. [delay] is the animation-delay.
double keyframes(
  double t,
  double duration,
  List<(double, double)> frames, {
  Curve curve = Curves.easeInOut,
  double delay = 0,
}) {
  final local = t - delay;
  if (local < 0) return frames.first.$2;
  final p = (local / duration) % 1.0;
  for (var i = 0; i < frames.length - 1; i++) {
    final (a, va) = frames[i];
    final (b, vb) = frames[i + 1];
    if (p >= a && p <= b) {
      final f = b == a ? 1.0 : curve.transform((p - a) / (b - a));
      return va + (vb - va) * f;
    }
  }
  return frames.last.$2;
}

/// CSS spreads unstopped colors evenly; dart:ui wants the stops spelled out.
List<double> evenStops(int n) => [for (var i = 0; i < n; i++) i / (n - 1)];

/// The skins' scripts step every 33 ms and tune their per step easing to
/// that. The native art steps every frame, so it scales those rates by the
/// frame's share of a script step: the same motion at any frame rate.
const scriptStep = 1 / 30;

/// A per step easing [rate] over [dt] seconds.
double easeOver(double rate, double dt) =>
    1 - math.pow(1 - rate, dt / scriptStep).toDouble();

/// The Gaussian's cumulative distribution (Abramowitz and Stegun 7.1.26
/// for erf, good to 1.5e-7).
double gaussianCdf(double x) {
  final z = x / math.sqrt2;
  final t = 1 / (1 + 0.3275911 * z.abs());
  final y =
      1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                      0.284496736) *
                  t +
              0.254829592) *
          t *
          math.exp(-z * z);
  return 0.5 * (1 + (z >= 0 ? y : -y));
}

/// Blurred edges drawn exactly and cheaply. A Gaussian-blurred straight
/// edge is the Gaussian's CDF across it, so a blurred frame, box shadow
/// or inset shadow along a rectangle is four gradient strips carrying
/// that profile, instead of blurring a screen-sized path every frame
/// (which Impeller, having no raster cache, would redo each frame).
class EdgeGlow {
  EdgeGlow._();

  static const _stops = 24;

  /// A strip across one side: [profile] maps the distance outward from
  /// [edge] (negative inside) to an alpha, sampled from [from] to [to].
  static void _side(
    Canvas canvas,
    Rect box,
    int side,
    Color color,
    double from,
    double to,
    double Function(double) profile, {
    Path? clip,
  }) {
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= _stops; i++) {
      final f = i / _stops;
      final d = from + (to - from) * f;
      colors.add(color.withValues(alpha: color.a * profile(d).clamp(0.0, 1.0)));
      stops.add(f);
    }
    // The strip runs the whole side, from `from` to `to` across it.
    final (Rect strip, Offset a, Offset b) = switch (side) {
      0 => (
        Rect.fromLTRB(
          box.left - to,
          box.top - to,
          box.right + to,
          box.top - from,
        ),
        Offset(0, box.top - from),
        Offset(0, box.top - to),
      ),
      1 => (
        Rect.fromLTRB(
          box.right + from,
          box.top - to,
          box.right + to,
          box.bottom + to,
        ),
        Offset(box.right + from, 0),
        Offset(box.right + to, 0),
      ),
      2 => (
        Rect.fromLTRB(
          box.left - to,
          box.bottom + from,
          box.right + to,
          box.bottom + to,
        ),
        Offset(0, box.bottom + from),
        Offset(0, box.bottom + to),
      ),
      _ => (
        Rect.fromLTRB(
          box.left - to,
          box.top - to,
          box.left - from,
          box.bottom + to,
        ),
        Offset(box.left - from, 0),
        Offset(box.left - to, 0),
      ),
    };
    if (clip != null) {
      canvas.save();
      canvas.clipPath(clip);
    }
    canvas.drawRect(
      strip,
      Paint()..shader = ui.Gradient.linear(a, b, colors, stops),
    );
    if (clip != null) canvas.restore();
  }

  /// The side's mitered quarter of the ring between [box] grown by
  /// [out] and shrunk by [inn], so the four strips meet without overlap.
  static Path _miter(Rect box, int side, double out, double inn) {
    final o = box.inflate(out);
    final i = box.deflate(inn);
    final (List<Offset> pts) = switch (side) {
      0 => [o.topLeft, o.topRight, i.topRight, i.topLeft],
      1 => [o.topRight, o.bottomRight, i.bottomRight, i.topRight],
      2 => [o.bottomRight, o.bottomLeft, i.bottomLeft, i.bottomRight],
      _ => [o.bottomLeft, o.topLeft, i.topLeft, i.bottomLeft],
    };
    return Path()..addPolygon(pts, true);
  }

  /// A frame of [width] centered on [box]'s edges, blurred by [sigma]
  /// (CSS drop-shadow of a border or border-image frame).
  static void frame(
    Canvas canvas,
    Rect box,
    double width,
    Color color,
    double sigma,
  ) {
    final reach = width / 2 + 3 * sigma;
    double coverage(double d) => sigma <= 0
        ? (d.abs() <= width / 2 ? 1 : 0)
        : gaussianCdf((width / 2 - d) / sigma) -
              gaussianCdf((-width / 2 - d) / sigma);
    for (var side = 0; side < 4; side++) {
      _side(
        canvas,
        box,
        side,
        color,
        -reach,
        reach,
        coverage,
        clip: _miter(box, side, reach, reach),
      );
    }
  }

  /// box-shadow: inset 0 0 [blur] [spread] of [box]. The four strips
  /// overlap in the corners, where they compound as the shadow does.
  static void inset(
    Canvas canvas,
    Rect box,
    Color color,
    double blur, {
    double spread = 0,
  }) {
    final sigma = blur / 2;
    final reach = spread + 3 * sigma + 1;
    canvas.save();
    canvas.clipRect(box);
    for (var side = 0; side < 4; side++) {
      _side(
        canvas,
        box,
        side,
        color,
        -reach,
        0,
        (d) => sigma <= 0
            ? (-d < spread ? 1 : 0)
            : 1 - gaussianCdf((-d - spread) / sigma),
      );
    }
    canvas.restore();
  }

  /// box-shadow: 0 0 [blur] outside [box].
  static void outer(Canvas canvas, Rect box, Color color, double blur) {
    final sigma = blur / 2;
    final reach = 3 * sigma + 1;
    for (var side = 0; side < 4; side++) {
      _side(
        canvas,
        box,
        side,
        color,
        0,
        reach,
        (d) => 1 - gaussianCdf(d / sigma),
        clip: _miter(box, side, reach, 0),
      );
    }
  }
}

/// Fills the ring between [outer] and [outer] shrunk by [width] as four
/// rectangles: the same pixels as an even-odd path, without the
/// full-screen stencil pass Impeller spends on one every frame.
void drawRing(Canvas canvas, Rect outer, double width, Paint paint) {
  final inner = outer.deflate(width);
  canvas
    ..drawRect(
      Rect.fromLTRB(outer.left, outer.top, outer.right, inner.top),
      paint,
    )
    ..drawRect(
      Rect.fromLTRB(outer.left, inner.bottom, outer.right, outer.bottom),
      paint,
    )
    ..drawRect(
      Rect.fromLTRB(outer.left, inner.top, inner.left, inner.bottom),
      paint,
    )
    ..drawRect(
      Rect.fromLTRB(inner.right, inner.top, outer.right, inner.bottom),
      paint,
    );
}

/// What the canvas skins spend per step on the UI thread, for the
/// overlay's frame stats in voiceStatus: the simulation and the drawing.
class ArtCost {
  ArtCost._();
  static double stepMs = 0;
  static double paintMs = 0;

  /// Of those, the time in Picture.toImageSync, summed per step.
  static double snapshotMs = 0;
  static final _snap = Stopwatch();
  static T snapshot<T>(T Function() f) {
    _snap.start();
    try {
      return f();
    } finally {
      _snap.stop();
    }
  }

  static void endStep() {
    snapshotMs = snapshotMs * 0.8 + _snap.elapsedMicroseconds / 1000 * 0.2;
    _snap.reset();
  }

  static void step(Stopwatch s) {
    stepMs = stepMs * 0.8 + s.elapsedMicroseconds / 1000 * 0.2;
    endStep();
  }

  static void paint(Stopwatch s) =>
      paintMs = paintMs * 0.8 + s.elapsedMicroseconds / 1000 * 0.2;
}

/// A seconds clock for CSS-style animations, shared by the layers of one
/// overlay so their phases stay locked like the skins' shared start times.
class ArtClock extends ChangeNotifier {
  ArtClock(TickerProvider vsync, {bool running = true}) {
    _ticker = vsync.createTicker((elapsed) {
      seconds = elapsed.inMicroseconds / 1e6;
      notifyListeners();
    });
    this.running = running;
  }

  /// A clock stopped at [seconds], for still pictures (the skin picker).
  ArtClock.still([this.seconds = 1.2]);

  Ticker? _ticker;
  double seconds = 0;

  /// Ticks only while something shows it: a running ticker asks for every
  /// frame.
  set running(bool on) {
    final ticker = _ticker;
    if (ticker == null || on == ticker.isActive) return;
    on ? ticker.start() : ticker.stop();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

/// The skin's activity indicator (bar, strip or frame) over the whole
/// screen, from its CSS.
class SkinBarLayer extends StatelessWidget {
  const SkinBarLayer({
    super.key,
    required this.skin,
    required this.mode,
    required this.reactive,
    required this.level,
    required this.clock,
  });

  final AssistSkin skin;
  final ArtMode mode;

  /// The .reactive class: listening or speaking with the reactive bar on.
  final bool reactive;
  final ValueListenable<double> level;
  final ArtClock clock;

  @override
  Widget build(BuildContext context) {
    if (skin.bar is NoBar || mode == ArtMode.idle) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarPainter(skin.bar, mode, reactive, level, clock),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.bar, this.mode, this.reactive, this.level, this.clock)
    : super(repaint: Listenable.merge([level, clock]));

  final BarStyle bar;
  final ArtMode mode;
  final bool reactive;
  final ValueListenable<double> level;
  final ArtClock clock;

  double get t => clock.seconds;
  double get lvl => level.value.clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    switch (bar) {
      case final GradientBar b:
        _gradientBar(canvas, size, b);
      case AlexaStrip():
        _alexa(canvas, size);
      case SiriFrame():
        _siri(canvas, size);
      case RetroFrame():
        _retro(canvas, size);
      case NoBar():
        break;
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.bar != bar || old.mode != mode || old.reactive != reactive;

  // ── the gradient bars (Kiosk Satellite, Default, Google Home, HA) ──────

  void _gradientBar(Canvas canvas, Size size, GradientBar b) {
    final w = size.width * 0.6;
    final left = size.width * 0.2;
    final bottom = size.height - 24;
    final h = b.height;
    final duration = switch (mode) {
      ArtMode.thinking => 0.5,
      ArtMode.speaking => 2.0,
      _ => 3.0,
    };
    // The gradient is 200% of the bar and its position runs 0% to 200%:
    // it slides two bar widths (one period) left per cycle.
    final shift = -2 * w * ((t / duration) % 1.0);
    Shader shader(List<Color> colors, List<double>? stops) =>
        ui.Gradient.linear(
          Offset(left + shift, 0),
          Offset(left + shift + 2 * w, 0),
          colors,
          stops ?? evenStops(colors.length),
          TileMode.repeated,
        );
    final fill = Paint()..shader = shader(b.colors, b.stops);
    if (!reactive) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          bottom - h,
          left + w,
          bottom,
          Radius.circular(h / 2),
        ),
        fill,
      );
      return;
    }
    final l = lvl;
    // scaleY(1 + 3 level) from the bottom edge, corners and all.
    final sy = 1 + 3 * l;
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        bottom - h * sy,
        left + w,
        bottom,
        Radius.elliptical(h / 2, h / 2 * sy),
      ),
      fill,
    );
    final opacity = (2.5 * l).clamp(0.0, 1.0);
    if (opacity <= 0) return;
    // The glow box: 36 px past the bar top and bottom, scaled by
    // 0.4 + 0.6 level about its center, then by the bar's own stretch.
    final g = 0.4 + 0.6 * l;
    final c = h / 2;
    final top0 = bottom - h;
    double map(double y) => top0 + h + (c + (y - c) * g - h) * sy;
    final boxTop = map(-36);
    final boxBottom = map(h + 36);
    final box = Rect.fromLTRB(left, boxTop, left + w, boxBottom);
    canvas.saveLayer(box, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    canvas.save();
    canvas.translate(0, map(0));
    canvas.scale(1, g * sy);
    canvas.drawRect(
      Rect.fromLTRB(
        left - w,
        c - b.glowStrip / 2,
        left + 2 * w,
        c + b.glowStrip / 2,
      ),
      Paint()
        ..shader = shader(
          b.glowColors ?? b.colors,
          b.glowColors == null ? b.stops : null,
        )
        // filter: blur(12px) outside WebKit; the scale above stretches
        // the blurred strip exactly as the compositor does.
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.restore();
    canvas.drawRect(
      box,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _endsMask(box),
    );
    canvas.restore();
  }

  /// linear-gradient(90deg, transparent, #000 15%, #000 85%, transparent)
  static Shader _endsMask(Rect box) => ui.Gradient.linear(
    box.centerLeft,
    box.centerRight,
    const [
      Color(0x00000000),
      Color(0xFF000000),
      Color(0xFF000000),
      Color(0x00000000),
    ],
    const [0, 0.15, 0.85, 1],
  );

  // ── Alexa ─────────────────────────────────────────────────────────────

  static const _cyan = Color(0xFF00CAFF);
  static const _cyanLight = Color(0xFF00E5FF);

  void _alexa(Canvas canvas, Size size) {
    final w = size.width;
    final strip = RRect.fromLTRBAndCorners(
      0,
      size.height - 10,
      w,
      size.height,
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    );
    final shimmer = switch (mode) {
      ArtMode.thinking => 1.0,
      ArtMode.speaking => 4.0,
      _ => 3.0,
    };
    // background-size 200%, position 200% to -200%: two periods right.
    final f = (t / shimmer) % 1.0;
    final offset = w * (4 * f - 2);
    final gradient = ui.Gradient.linear(
      Offset(offset, 0),
      Offset(offset + 2 * w, 0),
      const [_cyan, _cyanLight, _cyan],
      const [0, 0.5, 1],
      TileMode.repeated,
    );
    // drop-shadow(0 0 r cyan a): the glow keyframes, or the static base
    // while reactive (only the shimmer runs then).
    final (radius, alpha) = reactive
        ? (12.0, 0.5)
        : switch (mode) {
            ArtMode.speaking => (
              keyframes(t, 1.5, const [(0, 10), (0.5, 18), (1, 10)]),
              keyframes(t, 1.5, const [(0, 0.5), (0.5, 0.7), (1, 0.5)]),
            ),
            ArtMode.thinking => (
              keyframes(t, 0.6, const [(0, 12), (0.5, 24), (1, 12)]),
              keyframes(t, 0.6, const [(0, 0.5), (0.5, 0.8), (1, 0.5)]),
            ),
            _ => (
              keyframes(t, 2, const [(0, 12), (0.5, 24), (1, 12)]),
              keyframes(t, 2, const [(0, 0.5), (0.5, 0.8), (1, 0.5)]),
            ),
          };
    canvas.drawRRect(
      strip,
      Paint()
        ..color = _cyan.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius / 2),
    );
    canvas.drawRRect(strip, Paint()..shader = gradient);
    if (!reactive) return;
    final l = lvl;
    final opacity = (2.5 * l).clamp(0.0, 1.0);
    if (opacity <= 0) return;
    // The glow box: 4% past each side, 36 px above and below the strip,
    // scaled by 0.4 + 0.6 level about its center; a 20 px strip in it.
    final center = size.height - 5;
    final half = (5 + 36) * (0.4 + 0.6 * l);
    final box = Rect.fromLTRB(
      -0.04 * w,
      center - half,
      1.04 * w,
      center + half,
    );
    final g = 0.4 + 0.6 * l;
    canvas.saveLayer(box, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    canvas.save();
    canvas.translate(0, center);
    canvas.scale(1, g);
    canvas.drawRect(
      Rect.fromLTRB(box.left, -10, box.right, 10),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(box.left, 0),
          Offset(box.right, 0),
          const [_cyan, _cyanLight, _cyan],
          const [0, 0.5, 1],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.restore();
    canvas.drawRect(
      box,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _endsMask(box),
    );
    canvas.restore();
  }

  // ── Siri ──────────────────────────────────────────────────────────────

  static const _violet = Color(0xFF8B5CF6);
  static const _blue = Color(0xFF3B82F6);

  void _siri(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final period = switch (mode) {
      ArtMode.thinking => 0.8,
      ArtMode.speaking => 2.0,
      _ => 4.0,
    };
    final angle = 2 * math.pi * ((t / period) % 1.0);
    // drop-shadow(0 0 6px violet .7) drop-shadow(0 0 2px blue .5); the
    // first is 4 px while processing.
    final first = mode == ArtMode.thinking ? 4.0 : 6.0;
    final line = screen.deflate(2.5);
    EdgeGlow.frame(canvas, line, 5, _violet.withValues(alpha: 0.7), first / 2);
    EdgeGlow.frame(canvas, line, 5, _blue.withValues(alpha: 0.5), 1);
    // conic-gradient(from angle, ...): CSS starts at the top, Flutter's
    // sweep at the right.
    drawRing(
      canvas,
      screen,
      5,
      Paint()
        ..shader = SweepGradient(
          colors: const [
            _violet,
            _blue,
            Color(0xFF06B6D4),
            Color(0xFFEC4899),
            _violet,
          ],
          transform: GradientRotation(angle - math.pi / 2),
        ).createShader(screen),
    );
    if (!reactive) return;
    final opacity = lvl;
    if (opacity <= 0) return;
    // ::after inset shadows (the outer ones fall off screen): blue 7 px,
    // violet 16 px over it.
    EdgeGlow.inset(canvas, screen, _blue.withValues(alpha: 0.45 * opacity), 7);
    EdgeGlow.inset(
      canvas,
      screen,
      _violet.withValues(alpha: 0.6 * opacity),
      16,
    );
  }

  // ── Retro Terminal ────────────────────────────────────────────────────

  static const _green = Color(0xFF33FF33);

  void _retro(Canvas canvas, Size size) {
    final outer = (Offset.zero & size).deflate(18);
    var opacity = 1.0;
    final double radius;
    final double alpha;
    switch (mode) {
      case ArtMode.thinking:
        // terminal-flicker 0.15s steps(2): 1, .8, .6, .8.
        final step = ((t % 0.15) / 0.0375).floor();
        opacity = const [1.0, 0.8, 0.6, 0.8][step.clamp(0, 3)];
        (radius, alpha) = (4.0, 0.4);
      case ArtMode.speaking:
        radius = keyframes(t, 1.5, const [(0, 8), (0.5, 16), (1, 8)]);
        alpha = keyframes(t, 1.5, const [(0, 0.5), (0.5, 0.7), (1, 0.5)]);
      default:
        radius = keyframes(t, 2, const [(0, 8), (0.5, 20), (1, 8)]);
        alpha = keyframes(t, 2, const [(0, 0.4), (0.5, 0.8), (1, 0.4)]);
    }
    final line = outer.deflate(1);
    EdgeGlow.frame(
      canvas,
      line,
      2,
      _green.withValues(alpha: alpha * opacity),
      radius / 2,
    );
    if (mode == ArtMode.thinking || reactive) {
      EdgeGlow.inset(
        canvas,
        outer.deflate(2),
        _green.withValues(alpha: 0.08 * opacity),
        6,
      );
    }
    drawRing(
      canvas,
      outer,
      2,
      Paint()..color = _green.withValues(alpha: opacity),
    );
    if (!reactive) return;
    final l = lvl;
    if (l <= 0) return;
    // ::after on the border box: 0 0 20px green .8 out, inset 0 0 36px
    // green .28 in, at the level's opacity.
    EdgeGlow.outer(canvas, outer, _green.withValues(alpha: 0.8 * l), 20);
    EdgeGlow.inset(canvas, outer, _green.withValues(alpha: 0.28 * l), 36);
  }
}

/// The backdrop: the skin's color at the chosen opacity over [under] (the
/// frozen, blurred screen), and for the terminal its CRT bezel, scanlines
/// and vignette. None of it moves during a turn, so with [cache] it is
/// drawn once into an image and then costs one pass a frame, where
/// Impeller would otherwise redraw every layer of it each frame.
class SkinBackdrop extends StatefulWidget {
  const SkinBackdrop({
    super.key,
    required this.skin,
    required this.color,
    this.under,
    this.cache = false,
  });

  final AssistSkin skin;
  final Color color;
  final ui.Image? under;
  final bool cache;

  @override
  State<SkinBackdrop> createState() => _SkinBackdropState();
}

class _SkinBackdropState extends State<SkinBackdrop> {
  ui.Image? _image;
  Object? _key;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _paint(Canvas canvas, Size size) {
    final under = widget.under;
    if (under != null) {
      canvas.drawImageRect(
        under,
        Rect.fromLTWH(0, 0, under.width.toDouble(), under.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low,
      );
    }
    _BackdropPainter(widget.color, widget.skin.crt).paint(canvas, size);
  }

  @override
  Widget build(BuildContext context) {
    final still = widget.cache && (widget.skin.crt || widget.under != null);
    if (!still) {
      return CustomPaint(
        size: Size.infinite,
        painter: _BackdropPainter(widget.color, widget.skin.crt),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final key = (size, dpr, widget.color, widget.skin.crt, widget.under);
        if (key != _key && size.isFinite && !size.isEmpty) {
          _key = key;
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..scale(dpr);
          _paint(canvas, size);
          final picture = recorder.endRecording();
          _image?.dispose();
          _image = picture.toImageSync(
            (size.width * dpr).round(),
            (size.height * dpr).round(),
          );
          picture.dispose();
        }
        return RawImage(image: _image, fit: BoxFit.fill);
      },
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.color, this.crt);
  final Color color;
  final bool crt;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    canvas.drawRect(screen, Paint()..color = color);
    if (!crt) return;
    // box-shadow, last listed at the bottom: the 80 px vignette spread
    // 20, then the 16, 14 and 12 px bezel rings.
    EdgeGlow.inset(canvas, screen, const Color(0xB3000000), 80, spread: 20);
    for (final (width, ring) in const [
      (16.0, Color(0xFF111111)),
      (14.0, Color(0xFF2A2A2A)),
      (12.0, Color(0xFF111111)),
    ]) {
      drawRing(canvas, screen, width, Paint()..color = ring);
    }
    final inner = screen.deflate(16);
    // ::before: scanlines, 2 px clear then 2 px at 12% black.
    canvas.drawRect(
      inner,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, inner.top),
          Offset(0, inner.top + 4),
          const [
            Color(0x00000000),
            Color(0x00000000),
            Color(0x1F000000),
            Color(0x1F000000),
          ],
          const [0, 0.5, 0.5, 1],
          TileMode.repeated,
        ),
    );
    // ::after: radial-gradient(ellipse at center, transparent 50%,
    // rgba(0,0,0,.5) 100%), the ellipse through the corners.
    canvas.save();
    canvas.translate(inner.center.dx, inner.center.dy);
    canvas.scale(1, inner.height / inner.width);
    final r = inner.width / 2 * math.sqrt2;
    canvas.drawCircle(
      Offset.zero,
      r * 1.5,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r,
          const [Color(0x00000000), Color(0x00000000), Color(0x80000000)],
          const [0, 0.5, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.color != color || old.crt != crt;
}

/// The thinking indicator, animated, or frozen beside a tool name: the
/// skin's bullets (bouncing, or blinking in the terminal) or the Kiosk
/// Satellite mark's bars.
class ThinkingDots extends StatelessWidget {
  const ThinkingDots({
    super.key,
    required this.skin,
    required this.colors,
    required this.scale,
    required this.clock,
    this.shadows = const [],
    this.idle = false,
  });

  final AssistSkin skin;
  final List<Color> colors;
  final double scale;
  final ArtClock clock;

  /// The line's inherited text-shadow (Alexa's), under the terminal's own
  /// bullet glow.
  final List<CssShadow> shadows;
  final bool idle;

  static const _even = TextHeightBehavior(
    leadingDistribution: TextLeadingDistribution.even,
  );

  @override
  Widget build(BuildContext context) {
    if (skin.dots == DotsStyle.logoBars) return _logoBars();
    final size = (idle ? skin.idleDotSize : skin.dotSize) * scale;
    if (idle) {
      // Frozen in a flex line: inline-flex spans at line-height 1.
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: skin.dotsGap,
        children: [
          for (var i = 0; i < 3; i++)
            Text(
              '•',
              style: _style(i, size, glow: false),
              textHeightBehavior: _even,
            ),
        ],
      );
    }
    // Animated, the bullets sit on a text line of the thinking size, whose
    // normal line height makes the row's height, as in the skins' block.
    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) => Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: skin.font,
            fontSize: size,
            height: skin.lineHeight,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          children: [
            const TextSpan(text: '\u200B'),
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) WidgetSpan(child: SizedBox(width: skin.dotsGap)),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _bullet(i, size),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _style(int i, double size, {required bool glow}) {
    final own = glow ? skin.dotGlow : null;
    final inherited = skin.dotGlow == null ? shadows : const <CssShadow>[];
    return TextStyle(
      fontFamily: skin.font,
      fontSize: size,
      fontVariations: fontVariationsFor(skin.font, size, FontWeight.w400),
      height: 1,
      color: colors[i % colors.length],
      shadows: own != null
          ? [own.shadow]
          : inherited.isEmpty
          ? null
          : [for (final s in inherited) s.shadow],
    );
  }

  Widget _bullet(int i, double size) {
    final t = clock.seconds;
    var dy = 0.0;
    var opacity = 1.0;
    if (skin.dots == DotsStyle.blink) {
      // step-end 1.2s: on to 50%, 0.15 after; delays 0, .4, .8.
      final p = ((t - 0.4 * i) / 1.2) % 1.0;
      opacity = p < 0.51 ? 1 : 0.15;
    } else {
      // 0%, 60%, 100% at 0; 30% at -8 px; delays 0, .2, .4.
      dy = keyframes(t, 1.4, const [
        (0, 0),
        (0.3, -8),
        (0.6, 0),
        (1, 0),
      ], delay: 0.2 * i);
    }
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Text(
          '•',
          style: _style(i, size, glow: true),
          textHeightBehavior: _even,
        ),
      ),
    );
  }

  /// The mark in a 24 px box: bars a quarter as wide as it, 12% apart, at
  /// 53, 39, 100 and 41% of its height, each swinging between its own low
  /// and high scale over 0.9 s.
  Widget _logoBars() {
    final h = 24 * scale;
    const heights = [0.53, 0.39, 1.0, 0.41];
    const lows = [0.6, 0.7, 0.45, 0.7];
    const highs = [1.85, 2.5, 1.0, 2.4];
    const delays = [0.0, -0.22, -0.45, -0.67];
    return ListenableBuilder(
      listenable: idle ? const AlwaysStoppedAnimation(0) : clock,
      builder: (context, _) => SizedBox(
        height: h,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: h * 0.12,
          children: [
            for (var i = 0; i < 4; i++)
              Transform.scale(
                scaleY: idle
                    ? 1
                    : keyframes(clock.seconds, 0.9, [
                        (0, lows[i]),
                        (0.5, highs[i]),
                        (1, lows[i]),
                      ], delay: delays[i]),
                child: Container(
                  width: h * 0.25,
                  height: h * heights[i],
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(h * 0.125),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
