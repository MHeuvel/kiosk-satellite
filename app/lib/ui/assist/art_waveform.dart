import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'assist_art.dart';

/// The Waveform skin's background, ported line for line from its script
/// (waveform.js): seven sine-composite ribbons across a band 55% of the
/// screen tall, each smoothing the audio level at its own pace, a glow
/// bloomed twice, the cores in three feather groups, and drifting specks.
/// It steps every frame, where the original steps every 33 ms, with its per
/// step easing scaled to match; the blurs run as GPU layer filters in place
/// of the original's half-size canvas.
class WaveformArt extends StatefulWidget {
  const WaveformArt({
    super.key,
    required this.dark,
    required this.mode,
    required this.reactive,
    required this.level,
  });

  final bool dark;
  final ArtMode mode;
  final bool reactive;
  final ValueListenable<double> level;

  @override
  State<WaveformArt> createState() => _WaveformArtState();
}

class _WaveformArtState extends State<WaveformArt>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _sim = _WaveSim();
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
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // The bar's classes decide the level: the analyser's while listening
    // or speaking (only running with the reactive bar), 0.35 thinking.
    final raw = switch (widget.mode) {
      ArtMode.thinking => 0.35,
      ArtMode.idle => 0.0,
      _ => widget.reactive ? widget.level.value.clamp(0.0, 1.0) : 0.0,
    };
    final watch = Stopwatch()..start();
    _sim.step(dt, raw, widget.dark);
    ArtCost.step(watch);
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The script's canvas caps the pixel ratio at 1.5, and its filter
    // blurs are in those canvas pixels.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final k = math.min(dpr, 1.5);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _WavePainter(_sim, _frame, k, dpr),
      ),
    );
  }
}

class _Strand {
  const _Strand(
    this.rgb,
    this.alpha,
    this.lineW,
    this.speed,
    this.freqs,
    this.weights,
    this.phase,
    this.ampScale,
  );

  final List<int> rgb;
  final double alpha;
  final double lineW;
  final double speed;
  final List<double> freqs;
  final List<double> weights;
  final double phase;
  final double ampScale;
}

class _Dynamics {
  const _Dynamics(
    this.smoothUp,
    this.smoothDown,
    this.speedReact,
    this.alphaReact,
    this.harmonicGain,
  );

  final double smoothUp;
  final double smoothDown;
  final double speedReact;
  final double alphaReact;
  final double harmonicGain;
}

// The theme strand colors are the skin's --wf-strand-N values, which the
// script reads over its own tables.
const _strandsDark = [
  _Strand(
    [30, 10, 140],
    0.08,
    16,
    0.4,
    [1.2, 2.0, 5.0],
    [0.55, 0.30, 0.15],
    0,
    1.3,
  ),
  _Strand(
    [70, 40, 200],
    0.13,
    10,
    0.55,
    [1.5, 3.0, 6.0],
    [0.50, 0.30, 0.20],
    0.8,
    1.2,
  ),
  _Strand(
    [120, 60, 255],
    0.23,
    5,
    0.7,
    [2.0, 3.5, 7.0],
    [0.45, 0.35, 0.20],
    1.6,
    1.1,
  ),
  _Strand(
    [30, 160, 255],
    0.18,
    6,
    0.65,
    [1.8, 4.2, 8.0],
    [0.40, 0.35, 0.25],
    2.8,
    1.15,
  ),
  _Strand(
    [160, 80, 255],
    0.38,
    3.5,
    0.85,
    [2.2, 4.0, 6.5],
    [0.45, 0.30, 0.25],
    0.4,
    1.0,
  ),
  _Strand(
    [140, 170, 255],
    0.62,
    2,
    0.75,
    [1.6, 3.2, 5.5],
    [0.40, 0.35, 0.25],
    2.0,
    0.9,
  ),
  _Strand(
    [200, 210, 255],
    0.90,
    1.2,
    0.7,
    [2.0, 3.0, 5.0],
    [0.45, 0.30, 0.25],
    0.3,
    0.8,
  ),
];

const _strandsLight = [
  _Strand(
    [20, 0, 100],
    0.10,
    16,
    0.4,
    [1.2, 2.0, 5.0],
    [0.55, 0.30, 0.15],
    0,
    1.3,
  ),
  _Strand(
    [50, 20, 160],
    0.16,
    10,
    0.55,
    [1.5, 3.0, 6.0],
    [0.50, 0.30, 0.20],
    0.8,
    1.2,
  ),
  _Strand(
    [80, 30, 200],
    0.30,
    5,
    0.7,
    [2.0, 3.5, 7.0],
    [0.45, 0.35, 0.20],
    1.6,
    1.1,
  ),
  _Strand(
    [0, 100, 210],
    0.25,
    6,
    0.65,
    [1.8, 4.2, 8.0],
    [0.40, 0.35, 0.25],
    2.8,
    1.15,
  ),
  _Strand(
    [120, 40, 200],
    0.45,
    3.5,
    0.85,
    [2.2, 4.0, 6.5],
    [0.45, 0.30, 0.25],
    0.4,
    1.0,
  ),
  _Strand(
    [60, 50, 180],
    0.65,
    2,
    0.75,
    [1.6, 3.2, 5.5],
    [0.40, 0.35, 0.25],
    2.0,
    0.9,
  ),
  _Strand(
    [40, 30, 140],
    0.90,
    1.2,
    0.7,
    [2.0, 3.0, 5.0],
    [0.45, 0.30, 0.25],
    0.3,
    0.8,
  ),
];

/// The --wf-strand-N overrides from the skin's theme blocks, which the
/// script applies over the tables above.
const _cssDark = [
  [30, 10, 140],
  [70, 40, 200],
  [120, 60, 255],
  [30, 160, 255],
  [160, 80, 255],
  [140, 170, 255],
  [200, 210, 255],
];
const _cssLight = [
  [20, 0, 100],
  [50, 20, 160],
  [80, 30, 200],
  [0, 100, 210],
  [120, 40, 200],
  [60, 50, 180],
  [40, 30, 140],
];

const _dynamics = [
  _Dynamics(0.08, 0.035, 1.5, 0.30, 0),
  _Dynamics(0.10, 0.045, 2.0, 0.40, 0.02),
  _Dynamics(0.13, 0.055, 2.5, 0.50, 0.04),
  _Dynamics(0.16, 0.065, 3.0, 0.55, 0.06),
  _Dynamics(0.20, 0.080, 3.5, 0.65, 0.08),
  _Dynamics(0.25, 0.100, 4.0, 0.75, 0.12),
  _Dynamics(0.32, 0.130, 5.0, 0.90, 0.15),
];

class _Particle {
  _Particle({
    required this.sa,
    required this.sb,
    required this.blend,
    required this.n,
    required this.speed,
    required this.yOff,
    required this.yDrift,
    required this.fadeIn,
    required this.decay,
    required this.color,
    required this.size,
    required this.baseAlpha,
  });

  final int sa;
  final int sb;
  final double blend;
  double n;
  final double speed;
  double yOff;
  final double yDrift;
  double age = 0;

  /// The vertical wander so far, in pixels.
  double drift = 0;
  final double fadeIn;
  double life = 1;
  final double decay;
  final List<int> color;
  final double size;
  final double baseAlpha;
}

const _pts = 280;
const _strandCount = 7;

/// The script's per-frame state. The shape is computed in unit space
/// (x 0..1, y relative to the band's center in units of its height) so
/// the painter can scale it to any band.
/// sin and cos of nPi c at every point, nPi running 0 to pi across.
class _Wave {
  _Wave(double c) : sin = Float64List(_pts + 1), cos = Float64List(_pts + 1) {
    for (var i = 0; i <= _pts; i++) {
      final a = i / _pts * math.pi * c;
      sin[i] = math.sin(a);
      cos[i] = math.cos(a);
    }
  }

  final Float64List sin;
  final Float64List cos;
}

final _waves = <double, _Wave>{};
_Wave _wave(double c) => _waves.putIfAbsent(c, () => _Wave(c));
final _w14 = _wave(14);
final _w22 = _wave(22);
final _w34 = _wave(34);
final _w15 = _wave(1.5);
final _w28 = _wave(2.8);
final _w23 = _wave(2.3);

/// sin(nPi)^2.4 at every point: the ribbons' taper to the edges.
final Float64List _envelope = Float64List.fromList([
  for (var i = 0; i <= _pts; i++)
    math.pow(math.sin(i / _pts * math.pi), 2.4).toDouble(),
]);

class _WaveSim {
  final _levels = Float64List(_strandCount);
  final _energy = Float64List(_strandCount);
  final _phase = Float64List(_strandCount);
  final centerY = List.generate(_strandCount, (_) => Float64List(_pts + 1));
  final halfW = List.generate(_strandCount, (_) => Float64List(_pts + 1));
  final coreAlpha = Float64List(_strandCount);
  final particles = <_Particle>[];
  final _random = math.Random();
  bool dark = true;
  double rawLevel = 0;
  double dt = 0;
  bool started = false;

  List<List<int>> get colors => dark ? _cssDark : _cssLight;

  void step(double dt, double raw, bool dark) {
    this.dt = dt;
    this.dark = dark;
    rawLevel = raw;
    started = true;
    final strands = dark ? _strandsDark : _strandsLight;
    // maxAmp and maxDisp in units of the band's height.
    const maxAmp = 0.32;
    const idleBase = 0.42;
    const maxDisp = 0.42;
    for (var si = 0; si < _strandCount; si++) {
      final s = strands[si];
      final d = _dynamics[si];
      final ampRate = raw > _levels[si] ? d.smoothUp : d.smoothDown;
      _levels[si] += (raw - _levels[si]) * easeOver(ampRate, dt);
      final level = _levels[si];
      final engRate = raw > _energy[si] ? 0.25 : 0.12;
      _energy[si] += (raw - _energy[si]) * easeOver(engRate, dt);
      final energy = _energy[si];
      _phase[si] += dt * s.speed * (1 + energy * d.speedReact);
      final phase = _phase[si];
      final waveAmp = maxAmp * (idleBase + level * (1 - idleBase)) * s.ampScale;
      coreAlpha[si] = math.min(1, s.alpha * (1 + level * d.alphaReact));
      final hGain = d.harmonicGain * energy;
      final halfBase = s.lineW * 0.5;
      final active = energy > 0.01;
      final ys = centerY[si];
      final ws = halfW[si];
      // The script's sines, sin(nPi c + b), each as sin(nPi c) cos b +
      // cos(nPi c) sin b: the first factors are fixed per point and tabled,
      // so a step takes the sines of each strand's b only.
      final w0 = _wave(s.freqs[0] * 2);
      final w1 = _wave(s.freqs[1] * 2);
      final w2 = _wave(s.freqs[2] * 2);
      final c0 = math.cos(phase + s.phase) * s.weights[0];
      final s0 = math.sin(phase + s.phase) * s.weights[0];
      final c1 = math.cos(phase * 1.6 + s.phase + 1.1) * s.weights[1];
      final s1 = math.sin(phase * 1.6 + s.phase + 1.1) * s.weights[1];
      final c2 = math.cos(phase * 2.2 + s.phase + 2.2) * s.weights[2];
      final s2 = math.sin(phase * 2.2 + s.phase + 2.2) * s.weights[2];
      final c14 = math.cos(phase * 2.8 + s.phase * 1.7) * 0.06;
      final s14 = math.sin(phase * 2.8 + s.phase * 1.7) * 0.06;
      final harmonics = hGain > 0.001;
      final c22 = math.cos(phase * 3.5 + s.phase * 2.3) * hGain;
      final s22 = math.sin(phase * 3.5 + s.phase * 2.3) * hGain;
      final c34 = math.cos(phase * 4.2 + s.phase * 0.7) * hGain * 0.5;
      final s34 = math.sin(phase * 4.2 + s.phase * 0.7) * hGain * 0.5;
      final c15 = math.cos(phase * 1.1 + si * 0.7) * 0.7;
      final s15 = math.sin(phase * 1.1 + si * 0.7) * 0.7;
      final c28 = math.cos(phase * 0.65 + si * 1.3) * 0.5;
      final s28 = math.sin(phase * 0.65 + si * 1.3) * 0.5;
      final c23 = math.cos(phase * 0.8 + si * 1.5) * 0.6;
      final s23 = math.sin(phase * 0.8 + si * 1.5) * 0.6;
      for (var i = 0; i <= _pts; i++) {
        var wave =
            w0.sin[i] * c0 +
            w0.cos[i] * s0 +
            w1.sin[i] * c1 +
            w1.cos[i] * s1 +
            w2.sin[i] * c2 +
            w2.cos[i] * s2 +
            _w14.sin[i] * c14 +
            _w14.cos[i] * s14;
        if (harmonics) {
          wave +=
              _w22.sin[i] * c22 +
              _w22.cos[i] * s22 +
              _w34.sin[i] * c34 +
              _w34.cos[i] * s34;
        }
        var env = _envelope[i];
        if (active) {
          env *= math.max(
            0,
            1 +
                energy *
                    (_w15.sin[i] * c15 +
                        _w15.cos[i] * s15 +
                        _w28.sin[i] * c28 +
                        _w28.cos[i] * s28),
          );
        }
        final waveVal = wave * env;
        final raw = waveVal * waveAmp;
        ys[i] = maxDisp * _tanh(raw / maxDisp);
        final displacement = waveVal.abs();
        final thickMod = active
            ? math.max(
                0.4,
                1 + energy * (_w23.sin[i] * c23 + _w23.cos[i] * s23),
              )
            : 1.0;
        // Ribbon half widths stay in pixels, as in the script.
        ws[i] = math.max(
          0.3,
          halfBase * (0.25 + 0.75 * displacement) * thickMod,
        );
      }
    }
    _stepParticles(dt, raw, strands);
  }

  static double _tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  void _stepParticles(double dt, double raw, List<_Strand> strands) {
    // The script spawns and decays per step.
    final steps = dt / scriptStep;
    final spawnChance = (0.4 + raw * 2) * steps;
    final spawnCount =
        spawnChance.floor() + (_random.nextDouble() < spawnChance % 1 ? 1 : 0);
    for (var sp = 0; sp < spawnCount && particles.length < 50; sp++) {
      final si = _random.nextInt(_strandCount);
      particles.add(
        _Particle(
          sa: _random.nextInt(_strandCount),
          sb: _random.nextInt(_strandCount),
          blend: _random.nextDouble(),
          n: 0.08 + _random.nextDouble() * 0.84,
          speed: -(0.01 + _random.nextDouble() * 0.04),
          // In units of the band height: maxAmp 0.32 times 0.6 of scatter.
          yOff: (_random.nextDouble() - 0.5) * 0.32 * 0.6,
          // Pixels per second, converted by the painter.
          yDrift: (_random.nextDouble() - 0.5) * 6,
          fadeIn: 0.6 + _random.nextDouble() * 0.8,
          decay: 0.003 + _random.nextDouble() * 0.008,
          color: colors[si],
          size: 1.5 + _random.nextDouble() * 2.5,
          baseAlpha: 0.35 + _random.nextDouble() * 0.5,
        ),
      );
    }
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.n += p.speed * dt;
      p.drift += p.yDrift * dt;
      p.age += dt;
      p.life -= p.decay * steps;
      if (p.life <= 0 || p.n < 0.02 || p.n > 0.98) particles.removeAt(i);
    }
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.sim, Listenable frame, this.k, this.dpr)
    : super(repaint: frame);

  final _WaveSim sim;

  /// The script's canvas pixels per logical pixel.
  final double k;

  /// Device pixels per logical pixel.
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    if (!sim.started) return;
    final watch = Stopwatch()..start();
    _paint(canvas, size);
    ArtCost.paint(watch);
  }

  void _paint(Canvas canvas, Size size) {
    // .vs-waveform: full width, 55% tall, centered.
    final w = size.width;
    final h = size.height * 0.55;
    final top = (size.height - h) / 2;
    final band = Rect.fromLTWH(0, top, w, h);
    final centerY = top + h / 2;
    final colors = sim.colors;
    Color core(int si) => Color.fromRGBO(
      colors[si][0],
      colors[si][1],
      colors[si][2],
      sim.coreAlpha[si],
    );
    // The canvas is its own layer, composited over the backdrop. The
    // script blurs the glow (10 and 28 px) and the feathered cores (7 and
    // 3 px) as whole canvases. Drawn here two ways that look the same,
    // since each is cheap on some devices and not others: as feathered
    // strips (cheap for the GPU, work for the CPU) or as blurred layers
    // (the reverse). The first frames time the strips and settle it for
    // the session.
    final bounds = band.inflate(60);
    final layered = _layered ?? false;
    if (layered) {
      canvas.saveLayer(bounds, Paint());
      _layeredBlurs(canvas, w, h, centerY, bounds, core);
    } else {
      // At the script's capped pixel ratio, like its canvas, stretched to
      // the screen's: on a denser screen that is half the pixels to fill.
      // The stretch is the layer's own filter, and its bounds are at the
      // smaller scale since a layer clips before its filter.
      final scale = k / dpr;
      if (scale < 0.99) {
        canvas
          ..saveLayer(
            Rect.fromLTRB(
              bounds.left * scale,
              bounds.top * scale,
              bounds.right * scale,
              bounds.bottom * scale,
            ),
            Paint()
              ..imageFilter = ui.ImageFilter.matrix(
                Matrix4.diagonal3Values(1 / scale, 1 / scale, 1).storage,
                filterQuality: FilterQuality.low,
              ),
          )
          ..scale(scale);
      } else {
        canvas.saveLayer(bounds, Paint());
      }
      _pin(canvas, bounds);
      final watch = Stopwatch()..start();
      _featheredBlurs(canvas, w, h, centerY, core);
      _timeStrips(watch.elapsedMicroseconds / 1000);
    }
    // Specks: soft sprites added over the ribbons, riding a blend of two
    // strands, all in one draw.
    final specks = sim.particles;
    if (specks.isNotEmpty) {
      final count = math.min(specks.length, _maxSpecks);
      for (var n = 0; n < count; n++) {
        final p = specks[n];
        final fadeInT = math.min(p.age / p.fadeIn, 1.0);
        final fadeOutT = math.min(p.life / 0.3, 1.0);
        final visibility = fadeInT * fadeInT * fadeOutT;
        final idx = p.n * _pts;
        final lo = idx.floor().clamp(0, _pts);
        final hi = math.min(lo + 1, _pts);
        final frac = idx - lo;
        double yOf(int s) =>
            sim.centerY[s][lo] +
            (sim.centerY[s][hi] - sim.centerY[s][lo]) * frac;
        final ya = yOf(p.sa);
        final yb = yOf(p.sb);
        final strandY = centerY + (ya + (yb - ya) * p.blend + p.yOff) * h;
        final radius = p.size * (0.4 + visibility * 0.6) * 5;
        // RSTransform: scos, ssin, tx, ty, the sprite's center at the
        // speck's.
        final scale = radius / _speckSize;
        _speckTransforms
          ..[n * 4] = scale
          ..[n * 4 + 1] = 0
          ..[n * 4 + 2] = p.n * w - _speckSize * scale
          ..[n * 4 + 3] = strandY + p.drift - _speckSize * scale;
        _speckRects
          ..[n * 4] = 0
          ..[n * 4 + 1] = 0
          ..[n * 4 + 2] = _speckSize * 2
          ..[n * 4 + 3] = _speckSize * 2;
        final a8 = (visibility * p.baseAlpha * 255).round().clamp(0, 255);
        _speckTints[n] =
            (a8 << 24 | p.color[0] << 16 | p.color[1] << 8 | p.color[2])
                .toSigned(32);
      }
      canvas.drawRawAtlas(
        _speck,
        Float32List.sublistView(_speckTransforms, 0, count * 4),
        Float32List.sublistView(_speckRects, 0, count * 4),
        Int32List.sublistView(_speckTints, 0, count),
        BlendMode.modulate,
        null,
        _speckPaint,
      );
    }
    canvas.restore();
  }

  /// Whether this device draws the blurs as layers; null until the strips
  /// have been timed.
  static bool? _layered;
  static int _timed = 0;
  static double _stripsMs = 0;

  /// Settles on layers when the strips take more than a third of a frame
  /// to build, averaged over the first 30 frames.
  static void _timeStrips(double ms) {
    if (_layered != null) return;
    _stripsMs += ms;
    if (++_timed == 30) _layered = _stripsMs / _timed > 6;
  }

  /// Each blur as a strip whose rows of vertices carry the blurred
  /// ribbon's cross section, the difference of two Gaussian edges, in
  /// their alpha: no offscreen layers or blur passes. The script's canvas
  /// pixels are 1/k logical pixels.
  void _featheredBlurs(
    Canvas canvas,
    double w,
    double h,
    double centerY,
    Color Function(int) core,
  ) {
    void feathered(int si, double sigma, Color color, {bool add = false}) {
      final strip = _feather(
        sim.centerY[si],
        sim.halfW[si],
        w,
        h,
        centerY,
        sigma / k,
        color,
      );
      canvas.drawVertices(strip, BlendMode.dst, add ? _addPaint : _overPaint);
      strip.dispose();
    }

    final colors = sim.colors;
    // Glow: every ribbon at 4x its alpha, added up, blooming at 10 px and
    // again at 28 px and 0.6.
    for (var si = 0; si < _strandCount; si++) {
      final rgb = colors[si];
      final alpha = math.min(1.0, sim.coreAlpha[si] * 4);
      feathered(
        si,
        10,
        Color.fromRGBO(rgb[0], rgb[1], rgb[2], alpha),
        add: true,
      );
      feathered(
        si,
        28,
        Color.fromRGBO(rgb[0], rgb[1], rgb[2], alpha * 0.6),
        add: true,
      );
    }
    // Cores: strands 0-1 feathered 7 px, 2-4 feathered 3 px, 5-6 crisp.
    for (var si = 0; si < 2; si++) {
      feathered(si, 7, core(si));
    }
    for (var si = 2; si < 5; si++) {
      feathered(si, 3, core(si));
    }
    // The crisp ones, antialiased by a feather about as wide as a canvas
    // pixel's edge.
    for (var si = 5; si < _strandCount; si++) {
      feathered(si, 0.35, core(si));
    }
  }

  /// Each blur as a layer at a quarter (or half) of the script's canvas
  /// size, blurred there and stretched back over the screen by its own
  /// filter, as the script blurs a half size canvas. The layer opens after
  /// the scale so the blur is in logical pixels: Impeller shrinks a layer's
  /// blur by any scale applied inside it.
  void _layeredBlurs(
    Canvas canvas,
    double w,
    double h,
    double centerY,
    Rect bounds,
    Color Function(int) core,
  ) {
    // Each ribbon as a triangle strip along its top and bottom edges; the
    // two crisp strands are drawn sharp as antialiased paths.
    final strips = [
      for (var si = 0; si < _strandCount; si++) _strip(si, w, h, centerY),
    ];
    void layer(
      double size,
      double sigma,
      void Function(Canvas) draw, {
      double alpha = 1,
      bool add = false,
    }) => _blurLayer(
      canvas,
      bounds,
      k * size / dpr,
      sigma,
      draw,
      alpha: alpha,
      add: add,
    );

    final colors = sim.colors;
    // Glow: every ribbon at 4x its alpha, added up, blooming at 10 px and
    // again at 28 px and 0.6.
    void glow(Canvas c) {
      for (var si = 0; si < _strandCount; si++) {
        final rgb = colors[si];
        c.drawVertices(
          strips[si],
          BlendMode.dst,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = Color.fromRGBO(
              rgb[0],
              rgb[1],
              rgb[2],
              math.min(1, sim.coreAlpha[si] * 4),
            ),
        );
      }
    }

    layer(0.25, 10, glow, add: true);
    layer(0.25, 28, glow, alpha: 0.6, add: true);
    // Cores: strands 0-1 feathered 7 px, 2-4 feathered 3 px, 5-6 crisp.
    layer(0.25, 7, (c) {
      for (var si = 0; si < 2; si++) {
        c.drawVertices(strips[si], BlendMode.dst, Paint()..color = core(si));
      }
    });
    layer(0.5, 3, (c) {
      for (var si = 2; si < 5; si++) {
        c.drawVertices(strips[si], BlendMode.dst, Paint()..color = core(si));
      }
    });
    for (var si = 5; si < _strandCount; si++) {
      canvas.drawPath(_ribbon(si, w, h, centerY), Paint()..color = core(si));
    }
    for (final strip in strips) {
      strip.dispose();
    }
  }

  /// Ribbon [si] as a triangle strip along its top and bottom edges.
  ui.Vertices _strip(int si, double w, double h, double centerY) {
    final ys = sim.centerY[si];
    final ws = sim.halfW[si];
    final points = Float32List((_pts + 1) * 4);
    for (var i = 0; i <= _pts; i++) {
      final x = w * i / _pts;
      final y = centerY + ys[i] * h;
      points[i * 4] = x;
      points[i * 4 + 1] = y - ws[i];
      points[i * 4 + 2] = x;
      points[i * 4 + 3] = y + ws[i];
    }
    return ui.Vertices.raw(VertexMode.triangleStrip, points);
  }

  /// What [draw] draws, in a layer at [scale] of the current one, blurred
  /// there by [sigma] canvas pixels (1/k logical pixels) and stretched
  /// back by its own filter. The layer opens after the scale so the blur
  /// is in logical pixels: Impeller shrinks a layer's blur by any scale
  /// applied inside it.
  void _blurLayer(
    Canvas canvas,
    Rect bounds,
    double scale,
    double sigma,
    void Function(Canvas) draw, {
    double alpha = 1,
    bool add = false,
  }) {
    canvas
      ..save()
      ..scale(scale)
      ..saveLayer(
        bounds,
        Paint()
          ..blendMode = add ? BlendMode.plus : BlendMode.srcOver
          ..color = Color.fromRGBO(0, 0, 0, alpha)
          ..imageFilter = ui.ImageFilter.compose(
            outer: ui.ImageFilter.matrix(
              Matrix4.diagonal3Values(1 / scale, 1 / scale, 1).storage,
              filterQuality: FilterQuality.low,
            ),
            inner: ui.ImageFilter.blur(
              sigmaX: sigma / k,
              sigmaY: sigma / k,
              tileMode: TileMode.decal,
            ),
          ),
      );
    draw(canvas);
    canvas
      ..restore()
      ..restore();
  }

  /// Ribbon [si] as a closed path along its top and bottom edges.
  Path _ribbon(int si, double w, double h, double centerY) {
    final ys = sim.centerY[si];
    final ws = sim.halfW[si];
    final path = Path()..moveTo(0, centerY + ys[0] * h - ws[0]);
    for (var i = 1; i <= _pts; i++) {
      path.lineTo(w * i / _pts, centerY + ys[i] * h - ws[i]);
    }
    for (var i = _pts; i >= 0; i--) {
      path.lineTo(w * i / _pts, centerY + ys[i] * h + ws[i]);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.sim != sim || old.k != k || old.dpr != dpr;
}

/// Rows of vertices across a feathered strip, from edge to edge; odd, so
/// one runs down the middle.
const _featherRows = 9;

/// The cross section of a ribbon of half width H blurred by 1 (both in
/// units of the blur): at row t of the strip, which spans H + 3 each side,
/// Phi(H - t (H + 3)) - Phi(-H - t (H + 3)). Tabled over H, since a frame
/// needs tens of thousands.
const _featherStep = 0.125;
const _featherMax = 16.0;
final Float32List _featherTable = () {
  final count = (_featherMax / _featherStep).round() + 1;
  final out = Float32List(count * _featherRows);
  for (var j = 0; j < count; j++) {
    final hw = j * _featherStep;
    for (var row = 0; row < _featherRows; row++) {
      final dy = (hw + 3) * (2 * row / (_featherRows - 1) - 1);
      out[j * _featherRows + row] =
          gaussianCdf(hw - dy) - gaussianCdf(-hw - dy);
    }
  }
  return out;
}();

/// The triangles joining the rows of a strip [columns] wide.
final _featherIndices = <int, Uint16List>{};
Uint16List _indicesFor(int columns) => _featherIndices.putIfAbsent(columns, () {
  final out = Uint16List((_featherRows - 1) * (columns - 1) * 6);
  var n = 0;
  for (var r = 0; r < _featherRows - 1; r++) {
    for (var i = 0; i < columns - 1; i++) {
      final a = r * columns + i;
      final b = a + columns;
      out
        ..[n++] = a
        ..[n++] = a + 1
        ..[n++] = b
        ..[n++] = a + 1
        ..[n++] = b + 1
        ..[n++] = b;
    }
  }
  return out;
});

/// Scratch for [_feather], reused every strip of every frame: Vertices
/// copy what they are given, and a frame builds about twenty strips.
final _center = Float64List(_pts + 1);
final _half = Float64List(_pts + 1);
final _xs = Float64List(_pts + 1);
final _weights = Float64List(64);
final _positions = Float32List(_featherRows * (_pts + 1) * 2);
final _colors = Int32List(_featherRows * (_pts + 1));

/// A ribbon (center [ys] in band heights, half widths [ws] in pixels,
/// both per point across [width]) blurred by [sigma] logical pixels, as a
/// strip of vertices whose alpha follows the blur's cross section.
///
/// The ribbon is thick vertically, as the script draws it, so where it
/// slopes the blur's cross section is wider vertically by 1/cos of the
/// slope. The blur also smooths the ribbon along its length: wiggles
/// narrower than the blur fade, so the center and width are smoothed along
/// x by the same Gaussian first, and the strip needs a column only every
/// blur or so.
ui.Vertices _feather(
  Float64List ys,
  Float64List ws,
  double width,
  double height,
  double centerY,
  double sigma,
  Color color,
) {
  final step = width / _pts;
  final spread = sigma / step;
  final stride = math.max(1, spread.round());
  final columns = (_pts / stride).ceil() + 1;
  final radius = spread < 0.5 ? 0 : math.min(31, (spread * 3).ceil());
  var total = 0.0;
  for (var d = 0; d <= radius; d++) {
    _weights[d] = math.exp(-d * d / (2 * spread * spread));
    total += d == 0 ? _weights[d] : 2 * _weights[d];
  }
  for (var c = 0; c < columns; c++) {
    final i = math.min(c * stride, _pts);
    _xs[c] = step * i;
    if (radius == 0) {
      _center[c] = ys[i];
      _half[c] = ws[i];
      continue;
    }
    var sumY = ys[i] * _weights[0], sumW = ws[i] * _weights[0];
    for (var d = 1; d <= radius; d++) {
      final weight = _weights[d];
      final l = i - d < 0 ? 0 : i - d;
      final r = i + d > _pts ? _pts : i + d;
      sumY += (ys[l] + ys[r]) * weight;
      sumW += (ws[l] + ws[r]) * weight;
    }
    _center[c] = sumY / total;
    _half[c] = sumW / total;
  }
  final rgb =
      ((color.r * 255).round() << 16) |
      ((color.g * 255).round() << 8) |
      (color.b * 255).round();
  final alpha = color.a * 255;
  final last = _featherTable.length ~/ _featherRows - 2;
  for (var c = 0; c < columns; c++) {
    final y = centerY + _center[c] * height;
    final lo = c == 0 ? 0 : c - 1;
    final hi = c == columns - 1 ? c : c + 1;
    final slope = (_center[hi] - _center[lo]) * height / (_xs[hi] - _xs[lo]);
    final cos = 1 / math.sqrt(1 + slope * slope);
    // The half width in units of the blur's vertical spread.
    final hw = _half[c] * cos / sigma;
    final extent = (hw + 3) * sigma / cos;
    final at = (hw < _featherMax ? hw : _featherMax) / _featherStep;
    final j = math.min(at.floor(), last);
    final f = at - j;
    final x = _xs[c];
    for (var row = 0; row < _featherRows; row++) {
      final k0 = _featherTable[j * _featherRows + row];
      final k1 = _featherTable[(j + 1) * _featherRows + row];
      final v = row * columns + c;
      _positions[v * 2] = x;
      _positions[v * 2 + 1] = y + extent * (2 * row / (_featherRows - 1) - 1);
      final a8 = (alpha * (k0 + (k1 - k0) * f)).round();
      _colors[v] = ((a8 < 0 ? 0 : (a8 > 255 ? 255 : a8)) << 24 | rgb).toSigned(
        32,
      );
    }
  }
  final count = _featherRows * columns;
  return ui.Vertices.raw(
    VertexMode.triangles,
    Float32List.sublistView(_positions, 0, count * 2),
    colors: Int32List.sublistView(_colors, 0, count),
    indices: _indicesFor(columns),
  );
}

/// Keeps a layer the size of [bounds] every frame: Impeller sizes a layer
/// to what is drawn in it, and a size that changes every frame (as the
/// ribbons move) means a new texture every frame instead of one from its
/// pool, 2 ms each on a Galaxy Tab S8. Two corner pixels at the least
/// alpha pin it, invisible.
void _pin(Canvas canvas, Rect bounds) {
  final paint = Paint()..color = const Color(0x01000000);
  canvas
    ..drawRect(Rect.fromLTWH(bounds.left, bounds.top, 1, 1), paint)
    ..drawRect(Rect.fromLTWH(bounds.right - 1, bounds.bottom - 1, 1, 1), paint);
}

final _addPaint = Paint()..blendMode = BlendMode.plus;
final _overPaint = Paint();

/// The specks' sprite's radius in pixels.
const _speckSize = 32.0;

/// The script keeps at most 50 specks.
const _maxSpecks = 50;
final _speckTransforms = Float32List(_maxSpecks * 4);
final _speckRects = Float32List(_maxSpecks * 4);
final _speckTints = Int32List(_maxSpecks);
final _speckPaint = Paint()
  ..blendMode = BlendMode.plus
  ..filterQuality = FilterQuality.low;

/// One speck at full alpha in white, as the script's radial gradient; each
/// is drawn from it tinted and scaled.
final ui.Image _speck = () {
  final recorder = ui.PictureRecorder();
  const center = Offset(_speckSize, _speckSize);
  Canvas(recorder).drawCircle(
    center,
    _speckSize,
    Paint()
      ..shader = ui.Gradient.radial(
        center,
        _speckSize,
        const [
          Color.fromRGBO(255, 255, 255, 0.8),
          Color.fromRGBO(255, 255, 255, 0.35),
          Color.fromRGBO(255, 255, 255, 0.1),
          Color.fromRGBO(255, 255, 255, 0),
        ],
        const [0, 0.25, 0.6, 1],
      ),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(
    (_speckSize * 2).toInt(),
    (_speckSize * 2).toInt(),
  );
  picture.dispose();
  return image;
}();
