import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'assist_art.dart';
import 'assist_skins.dart';

/// The Voice Only skin's indicator: the Kiosk Satellite mark, white with
/// its teal outline, filling its box, its four bars stretching and
/// shrinking about their middle with the voice. Drawn from the mark's
/// geometry (assets/branding/mark.svg), so it stays sharp at any size.
class LogoArt extends StatefulWidget {
  const LogoArt({
    super.key,
    required this.mode,
    required this.reactive,
    required this.level,
    required this.clock,
    this.fade,
  });

  final ArtMode mode;

  /// Listening or speaking with the reactive bar on: the bars follow
  /// [level]. Otherwise they run the mode's own animation.
  final bool reactive;
  final ValueListenable<double> level;
  final ArtClock clock;

  /// 1 down to 0 as a docked conversation ends: the mark fades with it.
  final ValueListenable<double>? fade;

  @override
  State<LogoArt> createState() => _LogoArtState();
}

class _LogoArtState extends State<LogoArt> {
  /// Each bar's height as drawn, eased toward its target every frame so a
  /// change of mode glides instead of jumping.
  final _heights = List<double>.of(_LogoPainter.rest);
  double _last = -1;

  /// The loudest recent level while listening and while speaking, each
  /// decaying: the microphone's level is boosted and curved, playback's
  /// is near linear and runs well below it, so each is scaled against its
  /// own peak to move the bars as far.
  double _micPeak = 0;
  double _playPeak = 0;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: Size.infinite, painter: _LogoPainter(this)),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.state)
    : super(
        repaint: Listenable.merge([
          state.widget.level,
          state.widget.clock,
          state.widget.fade,
        ]),
      );

  final _LogoArtState state;
  LogoArt get w => state.widget;

  /// The mark's artboard, its outline included.
  static const _artboard = Size(924.44, 959.55);

  /// The house, from the mark's SVG: a rounded pentagon.
  static final _house = Path()
    ..moveTo(390.16, 50.75)
    ..cubicTo(432.57, 17.86, 491.87, 17.86, 534.28, 50.75)
    ..lineTo(847.17, 275.46)
    ..cubicTo(879.11, 297.31, 898.26, 333.47, 898.37, 372.17)
    ..lineTo(898.37, 815.9)
    ..cubicTo(898.37, 880.83, 845.73, 933.47, 780.8, 933.47)
    ..lineTo(143.64, 933.47)
    ..cubicTo(78.71, 933.47, 26.07, 880.83, 26.07, 815.9)
    ..lineTo(26.07, 372.17)
    ..cubicTo(26.18, 333.47, 45.33, 297.3, 77.27, 275.46)
    ..close();

  static const _outline = Color(0xFF5DA3A6);
  static const _outlineWidth = 52.15;

  /// The bars' left edges, width and the line they center on.
  static const _lefts = [242.25, 361.72, 481.19, 600.65];
  static const _width = 81.54;
  static const _center = 596.88;

  /// The mark's own bar heights, and how far they reach: the tallest
  /// stays clear of the house's bottom edge.
  static const rest = [252.21, 208.53, 403.85, 214.23];
  static const _max = 500.0;

  /// Silent, the bars sit at this share of the mark's heights.
  static const _quiet = 0.55;

  /// Each bar's own wobble (Hz and phase), so a loud voice moves them as
  /// an equalizer rather than in step.
  static const _rates = [2.3, 3.1, 1.7, 2.7];
  static const _phases = [0.0, 1.9, 3.7, 5.3];

  /// The thinking indicator's swing (ThinkingDots' logo bars), as scales
  /// of the mark's heights.
  static const _lows = [0.6, 0.7, 0.45, 0.7];
  static const _highs = [1.85, 2.5, 1.0, 2.4];
  static const _delays = [0.0, -0.22, -0.45, -0.67];

  /// The level against its source's recent peak: a peak decays to half in
  /// about two seconds, and the gain stops at 4x so room noise stays low.
  double _scaled(double dt) {
    final l = w.level.value.clamp(0.0, 1.0);
    final decay = math.exp(-0.35 * dt);
    final speaking = w.mode == ArtMode.speaking;
    final peak = math.max(
      l,
      (speaking ? state._playPeak : state._micPeak) * decay,
    );
    if (speaking) {
      state._playPeak = peak;
    } else {
      state._micPeak = peak;
    }
    return (l * math.min(4.0, 0.9 / math.max(peak, 0.1))).clamp(0.0, 1.0);
  }

  double _target(int i, double t, double l) {
    switch (w.mode) {
      case ArtMode.idle:
        return rest[i];
      case ArtMode.thinking:
        return rest[i] *
            keyframes(t, 0.9, [
              (0, _lows[i]),
              (0.5, _highs[i]),
              (1, _lows[i]),
            ], delay: _delays[i]);
      case ArtMode.listening || ArtMode.speaking when w.reactive:
        final wobble =
            0.6 + 0.4 * math.sin(2 * math.pi * _rates[i] * t + _phases[i]);
        // A slow breath keeps the mark alive while the room is quiet.
        final breath = 0.04 * (1 + math.sin(2 * math.pi * t / 2.4 + i * 0.8));
        final e = (breath + l * wobble * 1.3).clamp(0.0, 1.0);
        final low = rest[i] * _quiet;
        return low + (_max - low) * e;
      case ArtMode.speaking:
        return rest[i] *
            keyframes(t, 1.2, [
              (0, _lows[i]),
              (0.5, _highs[i]),
              (1, _lows[i]),
            ], delay: _delays[i] * 4 / 3);
      case ArtMode.listening:
        // Breathing about the mark's own shape.
        return rest[i] *
            keyframes(t, 2.4, const [
              (0, 0.8),
              (0.5, 1.05),
              (1, 0.8),
            ], delay: -0.3 * i);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = w.clock.seconds;
    final dt = state._last < 0 ? 1.0 : (t - state._last).clamp(0.0, 0.1);
    state._last = t;
    final l = w.reactive ? _scaled(dt) : 0.0;
    // About 40 ms to most of a step: on top of the level's own glide,
    // quick enough to keep up with speech.
    final ease = 1 - math.exp(-25 * dt);
    final heights = state._heights;
    for (var i = 0; i < 4; i++) {
      heights[i] += (_target(i, t, l).clamp(_width, _max) - heights[i]) * ease;
    }
    final scale = math.min(
      size.width / _artboard.width,
      size.height / _artboard.height,
    );
    if (scale <= 0) return;
    final alpha = w.fade == null
        ? 1.0
        : 0.35 + 0.65 * w.fade!.value.clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(
      (size.width - _artboard.width * scale) / 2,
      (size.height - _artboard.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawPath(
      _house,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.drawPath(
      _house,
      Paint()
        ..color = _outline.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _outlineWidth
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < 4; i++) {
      final h = heights[i];
      canvas.drawRRect(
        RRect.fromLTRBR(
          _lefts[i],
          _center - h / 2,
          _lefts[i] + _width,
          _center + h / 2,
          const Radius.circular(_width / 2),
        ),
        Paint()..color = kioskSatelliteColors[i].withValues(alpha: alpha),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => true;
}
