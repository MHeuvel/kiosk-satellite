import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_container.dart';
import '../core/locale_dates.dart';
import '../l10n/messages.dart';
import '../managers/settings/definitions.dart' as defs;
import '../managers/settings/settings_manager.dart';
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

/// Reserve the bar's space for corner widgets as well as the central clock.
double weatherMoodBarHeight(Size size, SettingsManager settings) {
  if (!settings.get(defs.screensaverWeatherBar)) return 0;
  final scale = (settings.get(defs.screensaverWeatherBarScale) / 100).clamp(
    .5,
    2.0,
  );
  final narrow = size.width < 720 * scale;
  final compact = size.width < 400 * scale;
  return math.min(
    (compact
            ? 224
            : narrow
            ? 148
            : 80) *
        scale,
    size.height * .38,
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
    final narrow = size.width < 720 * scale;
    final compact = size.width < 400 * scale;
    final width = math.max(180.0, size.width / scale - 64);
    TextStyle style(double fontSize, {FontWeight weight = FontWeight.w400}) =>
        TextStyle(
          fontFamily: 'Rubik',
          fontSize: fontSize,
          color: color,
          fontWeight: weight,
          shadows: shadows,
          height: 1.2,
        );
    Widget metric(String title, String value, IconData icon) => compact
        ? Row(
            children: [
              Icon(icon, color: color, size: 21, shadows: shadows),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  screensaverText(context, title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style(20),
                ),
              ),
              const SizedBox(width: 10),
              Text(value, style: style(23)),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                screensaverText(context, title),
                textAlign: TextAlign.center,
                style: style(20),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 21, shadows: shadows),
                  const SizedBox(width: 7),
                  Text(value, style: style(23)),
                ],
              ),
            ],
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
    final horizontalHeader = Row(
      children: [
        if (forecast) ...[
          WeatherConditionIcon(
            readings.condition,
            size: 40,
            color: color,
            shadows: shadows,
          ),
          const SizedBox(width: 16),
        ],
        if (temperature != null) ...[
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                temperature,
                style: style(42, weight: FontWeight.w300),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
        if (location.isNotEmpty || forecast)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (location.isNotEmpty)
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style(21, weight: FontWeight.w500),
                  ),
                if (forecast)
                  Text(
                    condition,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style(21),
                  ),
              ],
            ),
          ),
      ],
    );
    final header = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (forecast) ...[
                    WeatherConditionIcon(
                      readings.condition,
                      size: 40,
                      color: color,
                      shadows: shadows,
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (temperature != null)
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          temperature,
                          style: style(42, weight: FontWeight.w300),
                        ),
                      ),
                    ),
                ],
              ),
              if (location.isNotEmpty || forecast) const SizedBox(height: 8),
              if (location.isNotEmpty)
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style(21, weight: FontWeight.w500),
                ),
              if (forecast)
                Text(
                  condition,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style(21),
                ),
            ],
          )
        : horizontalHeader;
    final details = compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final metric in metrics)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: metric,
                ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < metrics.length; i++)
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : (width * .05).clamp(24.0, 64.0),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: metrics[i],
                    ),
                  ),
                ),
            ],
          );
    final opacity = (s.get(defs.screensaverWeatherBarOpacity) / 100).clamp(
      0.0,
      1.0,
    );
    return SizedBox(
      key: const ValueKey('weather-mood-bar'),
      height: weatherMoodBarHeight(size, s),
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: opacity),
          // The edge fades with the background and matches the original
          // look at the default 50%.
          border: Border(
            top: BorderSide(color: color.withValues(alpha: .20 * opacity)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
          child: Transform.translate(
            offset: offset,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: width,
                child: narrow
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          header,
                          if (metrics.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            details,
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(flex: 5, child: header),
                          if (metrics.isNotEmpty) ...[
                            const SizedBox(width: 24),
                            Expanded(flex: 6, child: details),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
