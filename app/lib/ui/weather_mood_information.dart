import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../app_container.dart';
import '../core/locale_dates.dart';
import '../l10n/messages.dart';
import '../managers/settings/definitions.dart' as defs;
import 'clock_faces.dart';
import 'digital_clock_face.dart';
import 'glance_row.dart';
import 'weather_readings.dart';

const _textShadows = [
  Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 4),
];

Color _color(String value) {
  final parts = value.split(',').map(int.tryParse).toList();
  if (parts.length != 3 || parts.any((v) => v == null)) {
    return const Color(0xFFFAFAFA);
  }
  return Color.fromARGB(
    255,
    parts[0]!.clamp(0, 255),
    parts[1]!.clamp(0, 255),
    parts[2]!.clamp(0, 255),
  );
}

class WeatherMoodReadings {
  String condition = '';
  final attributes = <String, Object?>{};
  bool get available =>
      condition.isNotEmpty &&
      condition != 'unknown' &&
      condition != 'unavailable';

  void update(Map<String, Object?> state) {
    final value = state['state'];
    if (value is String) condition = value;
    final attrs = state['attributes'];
    if (attrs is Map) attributes.addAll(attrs.map((k, v) => MapEntry('$k', v)));
  }

  num? number(String key) {
    final value = attributes[key];
    return value is num && value.isFinite ? value : null;
  }

  String reading(num value, String unitKey) {
    final unit = '${attributes[unitKey] ?? ''}';
    return unit.isEmpty ? '${value.round()}' : '${value.round()} $unit';
  }

  String? temperature({required bool feelsLike}) =>
      WeatherTemperatureReading.fromAttributes(
        attributes,
        feelsLike: false,
        feelsLikeOnly: feelsLike,
      )?.primary;
}

/// Static text repaints independently of the animated GPU background.
class WeatherMoodInformation extends StatefulWidget {
  const WeatherMoodInformation({
    super.key,
    required this.container,
    required this.readings,
    this.translations = const {},
  });
  final AppContainer container;
  final WeatherMoodReadings readings;
  final Map<String, String> translations;

  @override
  State<WeatherMoodInformation> createState() => _WeatherMoodInformationState();
}

class _WeatherMoodInformationState extends State<WeatherMoodInformation> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    _now = DateTime.now();
    _timer = Timer(
      Duration(milliseconds: 60000 - _now.second * 1000 - _now.millisecond),
      () {
        if (!mounted) return;
        setState(() {
          if (widget.container.settings.get(defs.screensaverPixelShift)) {
            final random = math.Random();
            _offset = Offset(
              random.nextDouble() * 20 - 10,
              random.nextDouble() * 20 - 10,
            );
          } else {
            _offset = Offset.zero;
          }
          _tick();
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _clock(Size size, bool glance) {
    final s = widget.container.settings;
    if (!s.get(defs.screensaverWeatherClock)) return const SizedBox.expand();
    final use24h = s.get(defs.screensaverWeatherClock24h);
    final hour = use24h
        ? _now.hour
        : (_now.hour % 12 == 0 ? 12 : _now.hour % 12);
    final hours = use24h ? '$hour'.padLeft(2, '0') : '$hour';
    final time =
        '$hours:${'${_now.minute}'.padLeft(2, '0')}${use24h
            ? ''
            : _now.hour < 12
            ? ' AM'
            : ' PM'}';
    final font = s.get(defs.screensaverWeatherClockFont);
    final scale =
        (s.get(defs.screensaverWeatherClockScale) / 100).clamp(.5, 3.0) *
        (glance ? .72 : 1);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Transform.translate(
          offset: _offset,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: DigitalClockFace(
              time: time,
              dateGapFactor: .015,
              dateOpacity: 1,
              date: s.get(defs.screensaverWeatherClockDate)
                  ? fullDate(_now)
                  : null,
              color: _color(s.get(defs.screensaverWeatherClockColor)),
              clockSize: math.min(size.width * .20, size.height * .30) * scale,
              dateSize: math.min(size.width * .05, size.height * .07) * scale,
              fontFamily: clockFontFamily(font),
              weight:
                  clockWeightOverride(
                    s.get(defs.screensaverWeatherClockFontWeight),
                  ) ??
                  clockFontWeight(font),
              opticalSize: clockOpticalSize(font),
              shadows: s.get(defs.screensaverWeatherClockShadow)
                  ? _textShadows
                  : const [],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.container;
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<bool?>(
          valueListenable: c.screensaver.scheduleGlance,
          builder: (context, scheduled, _) => ValueListenableBuilder(
            valueListenable: c.glance.entities,
            builder: (context, entities, _) {
              final glance =
                  (scheduled ??
                      c.settings.get(defs.screensaverGlanceEnabled)) &&
                  entities.isNotEmpty;
              return Column(
                children: [
                  Expanded(child: _clock(size, glance)),
                  if (glance)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            c.settings.get(defs.screensaverWeatherBar) &&
                                widget.readings.available
                            ? 24
                            : size.height * .06,
                      ),
                      child: GlanceRow(
                        container: c,
                        scale: math.min(1.0, size.height / 480).clamp(.75, 1.0),
                      ),
                    ),
                  if (c.settings.get(defs.screensaverWeatherBar) &&
                      widget.readings.available)
                    WeatherMoodBar(
                      container: c,
                      readings: widget.readings,
                      translations: widget.translations,
                      offset: _offset,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Weather readings as chips floating over the scene: a large chip with
/// the conditions and temperature at the bottom left and one small chip
/// per reading at the bottom right. Translucent dark pills with a faint
/// edge read against every sky, from bright day to dusk to night, and
/// match the At a Glance pills.
class WeatherMoodBar extends StatelessWidget {
  const WeatherMoodBar({
    super.key,
    required this.container,
    required this.readings,
    this.translations = const {},
    this.offset = Offset.zero,
  });
  final AppContainer container;
  final WeatherMoodReadings readings;
  final Map<String, String> translations;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final s = container.settings, size = MediaQuery.sizeOf(context);
    final scale = (s.get(defs.screensaverWeatherBarScale) / 100).clamp(.5, 2.0);
    final color = _color(s.get(defs.screensaverWeatherBarColor));
    final shadows = s.get(defs.screensaverWeatherBarShadow)
        ? _textShadows
        : const <Shadow>[];
    final opacity = (s.get(defs.screensaverWeatherBarOpacity) / 100).clamp(
      0.0,
      1.0,
    );
    // The fill follows Background opacity. The edge and icon circles fade
    // with it, so a fully transparent chip leaves only its text.
    final fill = const Color(0xFF1C1C1E).withValues(alpha: opacity);
    // Light catching the top of the glass: a faint sheen that fades out
    // toward the bottom of each chip.
    final sheen = Color.alphaBlend(
      Colors.white.withValues(alpha: .12 * (opacity / .5).clamp(0.0, 1.0)),
      fill,
    );
    final edge = Colors.white.withValues(alpha: .16 * opacity);
    final circle = Colors.white.withValues(
      alpha: .14 * (opacity / .7).clamp(0.0, 1.0),
    );
    TextStyle style(
      double fontSize, {
      FontWeight weight = FontWeight.w400,
      double alpha = 1,
    }) => TextStyle(
      fontFamily: 'Rubik',
      fontSize: fontSize * scale,
      color: color.withValues(alpha: alpha),
      fontWeight: weight,
      shadows: shadows,
      height: 1.2,
    );
    // A StadiumBorder keeps the radius at half the chip's own height; an
    // oversized corner radius once froze Impeller's raster thread.
    Widget chip(Widget child, EdgeInsets padding) {
      final glass = Container(
        padding: padding * scale,
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sheen, fill],
            stops: const [0, .6],
          ),
          shape: StadiumBorder(side: BorderSide(color: edge)),
        ),
        child: child,
      );
      if (opacity <= 0) return glass;
      // Without backdrop shaders the tinted chip stands alone: a blurred
      // copy of the scene behind every chip costs the legacy renderer a
      // backdrop read and blur per chip on every frame.
      return _GlassChip(
        tint: opacity,
        fallback: glass,
        child: Padding(padding: padding * scale, child: child),
      );
    }

    Widget disc(double diameter, Widget icon) => Container(
      width: diameter * scale,
      height: diameter * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
      child: icon,
    );
    Widget metric(String title, String value, IconData icon) => chip(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          disc(
            40,
            Icon(icon, color: color, size: 22 * scale, shadows: shadows),
          ),
          SizedBox(width: 10 * scale),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  screensaverText(context, title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style(13, alpha: .8),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style(17, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      const EdgeInsets.fromLTRB(6, 6, 18, 6),
    );
    final metrics = <Widget>[
      if (s.get(defs.screensaverWeatherBarHumidity) &&
          readings.number('humidity') != null)
        metric(
          'Humidity',
          '${readings.number('humidity')!.round()}%',
          Icons.water_drop_outlined,
        ),
      if (s.get(defs.screensaverWeatherBarWind) &&
          readings.number('wind_speed') != null)
        metric(
          'Wind speed',
          readings.reading(readings.number('wind_speed')!, 'wind_speed_unit'),
          Icons.air,
        ),
      if (s.get(defs.screensaverWeatherBarVisibility) &&
          readings.number('visibility') != null)
        metric(
          'Visibility',
          readings.reading(readings.number('visibility')!, 'visibility_unit'),
          Icons.visibility_outlined,
        ),
    ];
    final location = s.get(defs.screensaverWeatherBarLocation).trim();
    final condition =
        translations[readings.condition] ??
        weatherMoodConditionText(context, readings.condition);
    final temperature = readings.temperature(
      feelsLike: s.get(defs.screensaverWeatherBarFeelsLike),
    );
    final forecast = s.get(defs.screensaverWeatherBarForecast);
    // The same height and type as the reading chips, so every chip in
    // the row matches. The temperature takes the value size and the
    // location and conditions stack beside it like a reading's title.
    final main = chip(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Holds the chip at the reading chips' height without an icon.
          SizedBox(height: 40 * scale),
          if (forecast)
            disc(
              40,
              WeatherConditionIcon(
                readings.condition,
                size: 24 * scale,
                color: color,
                shadows: shadows,
              ),
            ),
          if (temperature != null) ...[
            SizedBox(width: (forecast ? 10 : 6) * scale),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  temperature,
                  style: style(24, weight: FontWeight.w600),
                ),
              ),
            ),
          ],
          if (location.isNotEmpty || forecast) ...[
            SizedBox(width: 12 * scale),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (location.isNotEmpty)
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style(13, alpha: .8),
                    ),
                  if (forecast)
                    Text(
                      condition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style(17, weight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
      const EdgeInsets.fromLTRB(6, 6, 18, 6),
    );
    final gap = 12 * scale;
    // One row when the chips' real widths fit: conditions at the left and
    // readings at the right. Otherwise the readings stack above the main
    // chip and wrap as needed.
    final content = Padding(
      padding: EdgeInsets.fromLTRB(12 * scale, 0, 12 * scale, 12 * scale),
      child: Transform.translate(
        offset: offset,
        // A lone conditions chip sits centered; with readings it anchors
        // the bottom left.
        child: metrics.isEmpty
            ? Center(child: main)
            : OverflowBar(
                spacing: gap * 2,
                overflowSpacing: gap,
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.start,
                overflowDirection: VerticalDirection.up,
                children: [
                  main,
                  Wrap(spacing: gap, runSpacing: gap, children: metrics),
                ],
              ),
      ),
    );
    // The chips take their natural height, so the clock above keeps all
    // the room they leave. They shrink only when many wrapped readings on a
    // small screen would take more than a third of it.
    // The width the chips actually get. Under a UI scale exemption the
    // MediaQuery size is the scaled one, not the space laid out here.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : size.width;
        return _ReportHeight(
          key: const ValueKey('weather-mood-bar'),
          onHeight: (height) =>
              container.screensaver.weatherChipsHeight.value = height,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: size.height * width / size.width * .38,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: BackdropGroup(
                child: SizedBox(width: width, child: content),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reports its child's laid-out height after the frame, for layouts that
/// depend on it elsewhere.
class _ReportHeight extends SingleChildRenderObjectWidget {
  const _ReportHeight({super.key, required this.onHeight, super.child});
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportHeight renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderReportHeight extends RenderProxyBox {
  _RenderReportHeight(this.onHeight);
  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // Listeners rebuild other widgets, which cannot happen mid-layout.
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }

  @override
  void detach() {
    if (_reported != null) {
      _reported = null;
      SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(0));
    }
    super.detach();
  }
}

/// The glass shader, on renderers that can run it as a backdrop filter.
final Future<ui.FragmentProgram?> _glassProgram =
    ui.ImageFilter.isShaderFilterSupported
    ? ui.FragmentProgram.fromAsset(
        'shaders/weather_mood_glass.frag',
      ).then<ui.FragmentProgram?>((program) => program, onError: (_) => null)
    : Future.value(null);

/// A chip of clear glass over the scene: the backdrop refracts at the
/// rounded edge under a bright rim. Renderers without backdrop shaders, and
/// the moments before the shader loads, show [fallback] instead.
class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.tint,
    required this.fallback,
    required this.child,
  });
  final double tint;
  final Widget fallback;
  final Widget child;

  @override
  Widget build(BuildContext context) => FutureBuilder<ui.FragmentProgram?>(
    future: _glassProgram,
    builder: (context, snapshot) {
      final program = snapshot.data;
      if (program == null) return fallback;
      return ClipPath(
        clipper: const ShapeBorderClipper(shape: StadiumBorder()),
        // One read of the scene behind serves every chip in the group.
        child: _GlassBackdrop(
          program: program,
          tint: tint,
          backdropKey: BackdropGroup.of(context)?.backdropKey,
          child: child,
        ),
      );
    },
  );
}

class _GlassBackdrop extends SingleChildRenderObjectWidget {
  const _GlassBackdrop({
    required this.program,
    required this.tint,
    required this.backdropKey,
    super.child,
  });
  final ui.FragmentProgram program;
  final double tint;
  final BackdropKey? backdropKey;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassBackdrop(program.fragmentShader(), tint, backdropKey);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGlassBackdrop renderObject,
  ) => renderObject
    ..tint = tint
    ..backdropKey = backdropKey;
}

/// Paints its child over the glass. The shader needs the chip's place on
/// screen, which is only known once it paints.
class _RenderGlassBackdrop extends RenderProxyBox {
  _RenderGlassBackdrop(this._shader, this._tint, this._backdropKey);
  final ui.FragmentShader _shader;
  double _tint;
  BackdropKey? _backdropKey;

  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  set tint(double value) {
    if (value == _tint) return;
    _tint = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    // The backdrop is in the view's device pixels. The root view's own
    // ratio applies here: the MediaQuery ratio below a UI scale exemption
    // differs from it.
    RenderObject root = this;
    while (root.parent != null) {
      root = root.parent!;
    }
    final ratio = root is RenderView
        ? root.configuration.devicePixelRatio
        : 1.0;
    final rect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    _shader
      ..setFloat(2, rect.left * ratio)
      ..setFloat(3, rect.top * ratio)
      ..setFloat(4, rect.width * ratio)
      ..setFloat(5, rect.height * ratio)
      ..setFloat(6, _tint)
      ..setFloat(7, rect.height / size.height * ratio);
    final layer = (this.layer as BackdropFilterLayer?) ?? BackdropFilterLayer();
    layer
      ..filter = ui.ImageFilter.shader(_shader)
      ..backdropKey = _backdropKey;
    this.layer = layer;
    context.pushLayer(layer, super.paint, offset);
  }

  @override
  void dispose() {
    _shader.dispose();
    super.dispose();
  }
}
