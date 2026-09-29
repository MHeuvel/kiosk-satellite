import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_container.dart';
import '../core/events.dart';
import '../l10n/messages.dart';
import '../managers/screen/adaptive_brightness.dart';
import '../managers/settings/definitions.dart';
import 'kit.dart';
import 'theme.dart';
import 'toast.dart';

/// Under the chart. Shared wording with the remote admin, which carries
/// its own copy (brightness_curve.js).
const _curveHint =
    'Drag a point, or tap it to type exact values. The Screen light in '
    'Home Assistant moves the top point and the curve follows.';

/// The adaptive brightness curve as one editor (issue #742): a chart of
/// screen brightness over the room's light on a log scale, four points to
/// drag, the live reading marked on it, and a chip per point that opens a
/// dialog for exact values. Mirrored on the remote (brightness_curve.js).
class BrightnessCurveEditor extends StatefulWidget {
  const BrightnessCurveEditor({super.key, required this.container});

  final AppContainer container;

  @override
  State<BrightnessCurveEditor> createState() => _BrightnessCurveEditorState();
}

/// The settings the curve is drawn from.
final _curveKeys = {
  adaptiveMinBrightness.key,
  adaptiveMaxBrightness.key,
  adaptiveDarkLux.key,
  adaptiveBrightLux.key,
  adaptivePoint2Position.key,
  adaptivePoint2Level.key,
  adaptivePoint3Position.key,
  adaptivePoint3Level.key,
};

class _BrightnessCurveEditorState extends State<BrightnessCurveEditor>
    with TickerProviderStateMixin {
  StreamSubscription<SettingChanged>? _settingsSub;
  StreamSubscription<LightLevelChanged>? _luxSub;

  /// The curve as the settings hold it, and the one on screen, which
  /// eases toward it when something else moves it (Home Assistant's
  /// Screen light turning Maximum brightness).
  late List<CurvePoint> _target;
  late List<CurvePoint> _from;
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..addListener(() => setState(() {}));

  /// The live reading, eased the same way.
  double? _lux;
  double? _luxFrom;
  late final AnimationController _luxMove = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..addListener(() => setState(() {}));

  /// A drag in progress: the point, the curve being shaped, the chart's
  /// range frozen so the axis does not slide under the finger, and how
  /// far the finger has gone (a press that never moves is a tap).
  int? _active;
  List<CurvePoint>? _drag;
  _Domain? _dragDomain;
  double _travel = 0;

  /// Where the finger landed relative to the point's center, kept through
  /// the drag so the point does not jump under it.
  Offset _grab = Offset.zero;

  /// Writing the drag's result: the settings arrive one at a time and the
  /// halfway states are not worth drawing.
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _target = _fromSettings();
    _from = _target;
    _morph.value = 1;
    _lux = widget.container.device.lightLux;
    _luxMove.value = 1;
    _settingsSub = widget.container.bus.on<SettingChanged>().listen((e) {
      if (!_curveKeys.contains(e.key) || _committing || !mounted) return;
      _retarget();
    });
    _luxSub = widget.container.bus.on<LightLevelChanged>().listen((e) {
      if (!mounted) return;
      _luxFrom = _shownLux;
      _lux = e.lux;
      _luxMove.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _luxSub?.cancel();
    _morph.dispose();
    _luxMove.dispose();
    super.dispose();
  }

  List<CurvePoint> _fromSettings() {
    final s = widget.container.settings;
    return AdaptiveCurve.fromSettings(
      minLevel: s.get(adaptiveMinBrightness).toDouble(),
      maxLevel: s.get(adaptiveMaxBrightness).toDouble(),
      darkLux: s.get(adaptiveDarkLux).toDouble(),
      brightLux: s.get(adaptiveBrightLux).toDouble(),
      point2Position: s.get(adaptivePoint2Position).toDouble(),
      point2Level: s.get(adaptivePoint2Level).toDouble(),
      point3Position: s.get(adaptivePoint3Position).toDouble(),
      point3Level: s.get(adaptivePoint3Level).toDouble(),
    ).points;
  }

  void _retarget({bool animate = true}) {
    final next = _fromSettings();
    setState(() {
      _from = animate ? _shown : next;
      _target = next;
    });
    if (animate) {
      _morph.forward(from: 0);
    } else {
      _morph.value = 1;
    }
  }

  /// The curve on screen: the drag's while one is going, else the eased
  /// one. Light levels ease on the log scale, like the axis.
  List<CurvePoint> get _shown {
    final drag = _drag;
    if (drag != null) return drag;
    final t = Curves.easeOutCubic.transform(_morph.value);
    if (t >= 1) return _target;
    return [
      for (var i = 0; i < _target.length; i++)
        (
          lux: math.exp(
            _lerp(math.log(_from[i].lux), math.log(_target[i].lux), t),
          ),
          level: _lerp(_from[i].level, _target[i].level, t),
        ),
    ];
  }

  double? get _shownLux {
    final to = _lux;
    final from = _luxFrom;
    if (to == null || from == null || _luxMove.value >= 1) return to;
    final t = Curves.easeOutCubic.transform(_luxMove.value);
    return math.exp(
      _lerp(math.log(math.max(from, 0.01)), math.log(math.max(to, 0.01)), t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  // ── Dragging ─────────────────────────────────────────────────────────

  void _dragStart(Offset local, _Geometry g) {
    final points = _shown;
    final index = g.hit(points, local);
    if (index == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _active = index;
      _drag = List.of(points);
      _dragDomain = g.domain;
      _travel = 0;
      _grab = g.at(points[index]) - local;
    });
  }

  void _dragUpdate(Offset local, Offset delta, _Geometry g) {
    final index = _active;
    final drag = _drag;
    if (index == null || drag == null) return;
    _travel += delta.distance;
    if (_travel < kTouchSlop) return;
    final at = local + _grab;
    final moved = _clampPoint(drag, index, (
      lux: _snapLux(g.luxAt(at.dx)),
      level: _snapLevel(g.levelAt(at.dy)),
    ), g.domain);
    if (moved == drag[index]) return;
    // A fresh list, so the painter sees the change.
    setState(() => _drag = [...drag]..[index] = moved);
  }

  Future<void> _dragEnd() async {
    final index = _active;
    final drag = _drag;
    if (index == null || drag == null) return;
    final tapped = _travel < kTouchSlop;
    if (tapped) {
      setState(() {
        _active = null;
        _drag = null;
        _dragDomain = null;
      });
      await _editPoint(index);
      return;
    }
    await _commit(drag);
    if (!mounted) return;
    setState(() {
      _active = null;
      _drag = null;
      _dragDomain = null;
    });
  }

  /// Write a whole curve. The settings are checked together (Minimum and
  /// Maximum, Dark room and Bright room may pass each other in one move),
  /// then stored; only what changed is written. Returns why it was
  /// refused, or null.
  Future<String?> _commit(List<CurvePoint> p) async {
    final values = curveSettings(p);
    final settings = widget.container.settings;
    final batch = {for (final e in values.entries) e.key.key: e.value};
    for (final e in values.entries) {
      final message = settings.validate(e.key, e.value, batch: batch);
      if (message != null) {
        _retarget(animate: false);
        return message;
      }
    }
    _committing = true;
    try {
      for (final e in values.entries) {
        if (settings.get(e.key) != e.value) await settings.set(e.key, e.value);
      }
    } finally {
      _committing = false;
    }
    if (mounted) _retarget(animate: false);
    return null;
  }

  // ── Typed values ─────────────────────────────────────────────────────

  Future<void> _editPoint(int index) async {
    final points = List.of(_target);
    final saved = await showDialog<CurvePoint>(
      context: context,
      builder: (context) => _PointDialog(
        index: index,
        point: points[index],
        bounds: _bounds(points, index, null, gap: 1),
      ),
    );
    if (saved == null || !mounted) return;
    points[index] = saved;
    final refused = await _commit(points);
    if (refused != null && mounted) {
      showToast(
        context,
        title: screenAudioText(context, 'Brightness curve'),
        message: refused,
        kind: ToastKind.error,
      );
    }
  }

  // ── Layout ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final lux = _shownLux;
    final domain = _dragDomain ?? _Domain.around(_target);
    final tight = tightPane(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Ks.inset, 18, Ks.inset, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final g = _Geometry(
                Size(constraints.maxWidth, tight ? 210 : 250),
                domain,
              );
              return RawGestureDetector(
                gestures: {
                  _PointDragRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _PointDragRecognizer
                      >(
                        () => _PointDragRecognizer(
                          hit: (at) => g.hit(_shown, at),
                        ),
                        (r) => r
                          ..hit = ((at) => g.hit(_shown, at))
                          ..dragStartBehavior = DragStartBehavior.down
                          ..onStart = ((d) => _dragStart(d.localPosition, g))
                          ..onUpdate = ((d) {
                            _dragUpdate(d.localPosition, d.delta, g);
                          })
                          ..onEnd = ((_) => _dragEnd())
                          ..onCancel = (() => _dragEnd()),
                      ),
                },
                child: CustomPaint(
                  size: g.size,
                  painter: _CurvePainter(
                    points: shown,
                    geometry: g,
                    lux: lux,
                    active: _active,
                    theme: Theme.of(context),
                    luxLabel: lux == null
                        ? null
                        : '${l10n(context).screenAudioLux(formatCurveLux(lux))}'
                              ' · ${(AdaptiveCurve(shown).levelAt(lux) * 100).round()}%',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            spacing: 8,
            children: [
              for (var i = 0; i < shown.length; i++)
                Expanded(
                  child: _PointChip(
                    lux: l10n(
                      context,
                    ).screenAudioLux(formatCurveLux(shown[i].lux)),
                    level: '${(shown[i].level * 100).round()}%',
                    active: _active == i,
                    onTap: () => _editPoint(i),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          HintRow(screenAudioText(context, _curveHint), inset: false),
        ],
      ),
    );
  }
}

typedef _Bounds = ({
  double luxLo,
  double luxHi,
  double levelLo,
  double levelHi,
});

/// One point's exact values: its light level and its brightness, each
/// checked against the neighbors before the dialog closes.
class _PointDialog extends StatefulWidget {
  const _PointDialog({
    required this.index,
    required this.point,
    required this.bounds,
  });

  final int index;
  final CurvePoint point;
  final _Bounds bounds;

  @override
  State<_PointDialog> createState() => _PointDialogState();
}

class _PointDialogState extends State<_PointDialog> {
  late final _lux = TextEditingController(
    text: formatCurveLux(widget.point.lux),
  );
  late final _level = TextEditingController(
    text: '${(widget.point.level * 100).round()}',
  );
  String? _luxError;
  String? _levelError;

  @override
  void dispose() {
    _lux.dispose();
    _level.dispose();
    super.dispose();
  }

  void _save() {
    final b = widget.bounds;
    final lux = num.tryParse(_lux.text.trim().replaceAll(',', '.'));
    final level = num.tryParse(_level.text.trim());
    final luxOk = lux != null && lux > b.luxLo && lux < b.luxHi;
    final levelOk =
        level != null &&
        level / 100 >= b.levelLo - 1e-9 &&
        level / 100 <= b.levelHi + 1e-9;
    setState(() {
      _luxError = luxOk
          ? null
          : l10n(context).screenAudioCurveLuxRange(
              formatCurveLux(b.luxLo),
              formatCurveLux(b.luxHi),
            );
      _levelError = levelOk
          ? null
          : l10n(context).screenAudioCurveLevelRange(
              '${(b.levelLo * 100).round()}',
              '${(b.levelHi * 100).round()}',
            );
    });
    if (!luxOk || !levelOk) return;
    Navigator.pop(context, (lux: lux.toDouble(), level: level.round() / 100));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n(context).screenAudioCurvePoint('${widget.index + 1}')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            TextField(
              controller: _lux,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (_luxError != null) setState(() => _luxError = null);
              },
              decoration: InputDecoration(
                labelText: screenAudioText(context, 'Light level (lx)'),
                errorText: _luxError,
                errorMaxLines: 2,
              ),
            ),
            TextField(
              controller: _level,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_levelError != null) setState(() => _levelError = null);
              },
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: screenAudioText(context, 'Brightness (%)'),
                errorText: _levelError,
                errorMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n(context).commonCancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(deviceText(context, 'Save')),
        ),
      ],
    );
  }
}

/// The settings a curve writes: the ends as they are, the middle points as
/// shares of the span between them (see [adaptivePoint2Position]).
Map<SettingDef<num>, num> curveSettings(List<CurvePoint> p) {
  num level(double v) => (v * 100).round() / 100;
  num lux(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toInt() : r;
  }

  num share(double v) => double.parse(v.toStringAsFixed(6));
  final min = level(p[0].level);
  final max = level(p[3].level);
  final dark = lux(p[0].lux);
  final bright = lux(p[3].lux);
  return {
    adaptiveMinBrightness: min,
    adaptiveMaxBrightness: max,
    adaptiveDarkLux: dark,
    adaptiveBrightLux: bright,
    adaptivePoint2Position: share(
      AdaptiveCurve.positionFor(p[1].lux, dark.toDouble(), bright.toDouble()),
    ),
    adaptivePoint2Level: share(
      AdaptiveCurve.shareFor(p[1].level, min.toDouble(), max.toDouble()),
    ),
    adaptivePoint3Position: share(
      AdaptiveCurve.positionFor(p[2].lux, dark.toDouble(), bright.toDouble()),
    ),
    adaptivePoint3Level: share(
      AdaptiveCurve.shareFor(p[2].level, min.toDouble(), max.toDouble()),
    ),
  };
}

/// A light level for a label: one decimal at most, none when whole.
String formatCurveLux(double lux) {
  final r = (lux * 10).round() / 10;
  return r == r.roundToDouble() ? '${r.toInt()}' : r.toStringAsFixed(1);
}

/// A dragged light level lands on two significant figures (4.7, 12, 470),
/// which is as fine as a finger on a log scale can aim.
double _snapLux(double lux) {
  if (lux <= 0) return 0.1;
  final magnitude = math.pow(10, (math.log(lux) / math.ln10).floor() - 1);
  final snapped = (lux / magnitude).round() * magnitude;
  return math.max(0.1, (snapped * 10).round() / 10);
}

double _snapLevel(double level) => (level * 100).round() / 100;

/// Where a point may go: between its neighbors in light (a drag keeps a
/// little room, a typed value only has to differ) and between their
/// brightness. The ends also keep Minimum under Maximum.
_Bounds _bounds(
  List<CurvePoint> p,
  int i,
  _Domain? domain, {
  double gap = 1.12,
}) {
  final last = p.length - 1;
  var levelLo = i == 0 ? 0.0 : p[i - 1].level;
  var levelHi = i == last ? 1.0 : p[i + 1].level;
  if (i == 0) levelHi = math.min(levelHi, p[last].level - 0.01);
  if (i == last) levelLo = math.max(levelLo, p[0].level + 0.01);
  return (
    luxLo: i == 0 ? (domain?.lo ?? 0) : p[i - 1].lux * gap,
    luxHi: i == last ? (domain?.hi ?? 200000) : p[i + 1].lux / gap,
    levelLo: levelLo,
    levelHi: levelHi,
  );
}

CurvePoint _clampPoint(
  List<CurvePoint> p,
  int i,
  CurvePoint want,
  _Domain domain,
) {
  final b = _bounds(p, i, domain);
  final lux = b.luxLo <= b.luxHi ? want.lux.clamp(b.luxLo, b.luxHi) : p[i].lux;
  final level = b.levelLo <= b.levelHi
      ? want.level.clamp(b.levelLo, b.levelHi)
      : p[i].level;
  return (lux: lux.toDouble(), level: level.toDouble());
}

/// The chart's light range: whole decades around the curve's ends, from
/// 1 lx or lower, with room past the ends to drag. A sensor that calls a
/// lit room 30 lx gets a chart to 100, not a wide empty stretch to 1000.
/// The live reading has no say: a dark room's sensor flapping between 0
/// and 1 lx would redraw the axis on every sample. A reading outside the
/// range sits on the chart's edge.
class _Domain {
  const _Domain(this.lo, this.hi);

  factory _Domain.around(List<CurvePoint> p) {
    var lo = math.min(1.0, p.first.lux / 2);
    final hi = math.max(10.0, p.last.lux * 2);
    lo = math.max(lo, 0.01);
    // A hair of slack so a whole decade (log 1000 is 2.9999999999999996
    // in float) stays that decade.
    double decade(double v, bool up) {
      final e = math.log(v) / math.ln10;
      return math
          .pow(10, up ? (e - 1e-9).ceil() : (e + 1e-9).floor())
          .toDouble();
    }

    return _Domain(decade(lo, false), decade(hi, true));
  }

  final double lo;
  final double hi;
}

/// Chart coordinates: the plot area inside the axis labels, light on a log
/// scale across, brightness up.
class _Geometry {
  _Geometry(this.size, this.domain);

  final Size size;
  final _Domain domain;

  static const left = 40.0;
  static const right = 10.0;
  static const top = 14.0;
  static const bottom = 26.0;

  /// How close a press has to land to take a point.
  static const reach = 30.0;

  Rect get plot =>
      Rect.fromLTRB(left, top, size.width - right, size.height - bottom);

  double get _logLo => math.log(domain.lo);
  double get _logHi => math.log(domain.hi);

  double x(double lux) {
    final l = math.log(lux.clamp(domain.lo, domain.hi));
    return plot.left + (l - _logLo) / (_logHi - _logLo) * plot.width;
  }

  double y(double level) => plot.bottom - level.clamp(0.0, 1.0) * plot.height;

  Offset at(CurvePoint p) => Offset(x(p.lux), y(p.level));

  double luxAt(double dx) {
    final t = ((dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return math.exp(_logLo + t * (_logHi - _logLo));
  }

  double levelAt(double dy) =>
      ((plot.bottom - dy) / plot.height).clamp(0.0, 1.0);

  int? hit(List<CurvePoint> points, Offset at) {
    int? best;
    var bestDistance = reach;
    for (var i = 0; i < points.length; i++) {
      final d = (this.at(points[i]) - at).distance;
      if (d <= bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }
}

/// A pan that claims the pointer at once when it lands on a point, so the
/// page does not scroll under a drag, and never enters the arena when it
/// lands anywhere else, so the page still scrolls from the chart.
class _PointDragRecognizer extends PanGestureRecognizer {
  _PointDragRecognizer({required this.hit});

  int? Function(Offset local) hit;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      hit(event.localPosition) != null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.points,
    required this.geometry,
    required this.lux,
    required this.active,
    required this.theme,
    required this.luxLabel,
  });

  final List<CurvePoint> points;
  final _Geometry geometry;
  final double? lux;
  final int? active;
  final ThemeData theme;
  final String? luxLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final scheme = theme.colorScheme;
    final g = geometry;
    final plot = g.plot;
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: 11,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    // Brightness gridlines every quarter, labeled at 0, 50 and 100.
    for (var q = 0; q <= 4; q++) {
      final y = g.y(q / 4);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      if (q.isEven) {
        _text(
          canvas,
          '${q * 25}%',
          labelStyle,
          Offset(plot.left - 8, y),
          align: _Align.right,
        );
      }
    }
    // A line per decade of light, labeled under the axis.
    final first = (math.log(g.domain.lo) / math.ln10).round();
    final last = (math.log(g.domain.hi) / math.ln10).round();
    for (var e = first; e <= last; e++) {
      final x = g.x(math.pow(10, e).toDouble());
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      _text(
        canvas,
        _decadeLabel(e),
        labelStyle,
        Offset(x, plot.bottom + 6),
        align: e == first
            ? _Align.left
            : e == last
            ? _Align.rightEdge
            : _Align.center,
      );
    }

    // The curve, flat before the first point and after the last.
    final curve = AdaptiveCurve(points);
    final path = Path();
    const step = 2.0;
    for (var x = plot.left; x <= plot.right + 0.01; x += step) {
      final y = g.y(curve.levelAt(g.luxAt(x)));
      if (x == plot.left) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(plot.right, plot.bottom)
      ..lineTo(plot.left, plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primary.withValues(alpha: 0.26),
            scheme.primary.withValues(alpha: 0.02),
          ],
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = scheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // The room right now: a dashed line at the reading, a dot where it
    // meets the curve and the pair of numbers above.
    final now = lux;
    if (now != null) {
      final x = g.x(math.max(now, g.domain.lo));
      final y = g.y(curve.levelAt(now));
      final dash = Paint()
        ..color = scheme.tertiary.withValues(alpha: 0.8)
        ..strokeWidth = 1.5;
      for (var d = plot.top; d < plot.bottom; d += 7) {
        canvas.drawLine(
          Offset(x, d),
          Offset(x, math.min(d + 3.5, plot.bottom)),
          dash,
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        9,
        Paint()..color = scheme.tertiary.withValues(alpha: 0.22),
      );
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = scheme.tertiary);
      final label = luxLabel;
      if (label != null) _pill(canvas, label, x, plot, scheme);
    }

    // The points: open rings, the one under the finger filled and haloed.
    for (var i = 0; i < points.length; i++) {
      final c = g.at(points[i]);
      if (i == active) {
        canvas.drawCircle(
          c,
          20,
          Paint()..color = scheme.primary.withValues(alpha: 0.16),
        );
        canvas.drawCircle(c, 9, Paint()..color = scheme.primary);
        canvas.drawCircle(
          c,
          9,
          Paint()
            ..color = scheme.surface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      } else {
        canvas.drawCircle(c, 7.5, Paint()..color = scheme.surface);
        canvas.drawCircle(
          c,
          7.5,
          Paint()
            ..color = scheme.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  void _pill(Canvas canvas, String text, double x, Rect plot, ColorScheme s) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: theme.textTheme.labelSmall!.copyWith(
          color: s.onTertiaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = painter.width + 14;
    const h = 20.0;
    final left = (x - w / 2).clamp(plot.left, plot.right - w);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, plot.top - 4, w, h),
      const Radius.circular(h / 2),
    );
    canvas.drawRRect(rect, Paint()..color = s.tertiaryContainer);
    painter.paint(
      canvas,
      Offset(left + 7, plot.top - 4 + (h - painter.height) / 2),
    );
  }

  static String _decadeLabel(int e) => switch (e) {
    < 0 => (math.pow(10, e)).toStringAsFixed(-e),
    < 3 => '${math.pow(10, e).toInt()}',
    < 6 => '${math.pow(10, e - 3).toInt()}k',
    _ => '${math.pow(10, e - 6).toInt()}M',
  };

  void _text(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset at, {
    _Align align = _Align.center,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      _Align.left => at.dx,
      _Align.center => at.dx - painter.width / 2,
      _Align.right => at.dx - painter.width,
      _Align.rightEdge => at.dx - painter.width,
    };
    // A left or right label sits centered on its line vertically; one
    // under the axis hangs from it.
    final dy = align == _Align.right ? at.dy - painter.height / 2 : at.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.points != points ||
      old.lux != lux ||
      old.active != active ||
      old.theme != theme ||
      old.luxLabel != luxLabel ||
      old.geometry.size != geometry.size ||
      old.geometry.domain.lo != geometry.domain.lo ||
      old.geometry.domain.hi != geometry.domain.hi;
}

enum _Align { left, center, right, rightEdge }

/// One point's values under the chart: its light level over its
/// brightness, in the control box surface. Tapping opens the dialog.
class _PointChip extends StatelessWidget {
  const _PointChip({
    required this.lux,
    required this.level,
    required this.active,
    required this.onTap,
  });

  final String lux;
  final String level;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(Ks.radiusControl);
    const figures = [FontFeature.tabularFigures()];
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: active
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            border: Border.all(
              color: active ? scheme.primary : scheme.outlineVariant,
            ),
            borderRadius: radius,
          ),
          child: Column(
            children: [
              Text(
                lux,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: figures,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                level,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: figures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
