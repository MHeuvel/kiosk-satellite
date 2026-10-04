import 'dart:math';

import 'package:flutter/material.dart';

import 'clock_faces.dart';

/// Shared digital face for the Clock and Weather Mood screensavers.
class DigitalClockFace extends StatelessWidget {
  const DigitalClockFace({
    super.key,
    required this.time,
    required this.date,
    required this.color,
    required this.clockSize,
    required this.dateSize,
    required this.fontFamily,
    required this.weight,
    this.opticalSize,
    this.shadows = const [],
    this.dateShadows,
    this.dateWeight = FontWeight.w400,
    this.dateGapFactor = .1,
    this.dateOpacity = .65,
    this.vertical = false,
  });

  /// The size of the digits for a [size] screen, before any scale. Flat,
  /// min(20vw, 30vh), the basis Voice Satellite uses. Stacked (issue #767),
  /// a pair of digits is a fraction of the flat line's width, so the cap
  /// moves to the height the [lines] of digits share.
  static double sizeFor(Size size, {bool vertical = false, int lines = 2}) =>
      vertical
      ? min(size.width * .5, size.height * .62 / lines)
      : min(size.width * .20, size.height * .30);

  /// The size of the date for a [size] screen, before any scale. Stacked,
  /// the flat face's date reads tiny under digits that tall, so it follows
  /// the digits instead, capped by the width so a long date still fits on
  /// one line.
  static double dateSizeFor(
    Size size, {
    bool vertical = false,
    int lines = 2,
  }) => vertical
      ? min(sizeFor(size, vertical: true, lines: lines) * .15, size.width * .07)
      : min(size.width * .05, size.height * .07);

  /// How many lines of digits a stacked face draws: hours and minutes,
  /// and seconds when shown.
  static int linesFor({required bool seconds}) => seconds ? 3 : 2;

  final String time;
  final String? date, fontFamily;
  final Color color;
  final double clockSize, dateSize;
  final double dateGapFactor, dateOpacity;
  final FontWeight weight;
  final double? opticalSize;
  final List<Shadow> shadows;

  /// The date's own shadows, for a shadow sized to its text. Null uses
  /// [shadows].
  final List<Shadow>? dateShadows;

  /// The date's weight, regular unless a backdrop calls for more.
  final FontWeight dateWeight;

  /// Whether each part of [time] takes a line of its own, hours over
  /// minutes (issue #767). AM or PM drops to a small line under them.
  final bool vertical;

  TextStyle _digits(double fontSize) => TextStyle(
    fontFamily: fontFamily,
    color: color,
    fontSize: fontSize,
    fontWeight: weight,
    fontVariations: clockFontVariations(opticalSize, weight),
    letterSpacing: fontSize * .02,
    fontFeatures: const [FontFeature.tabularFigures()],
    height: 1,
    shadows: shadows,
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!vertical) Text(time, style: _digits(clockSize)) else ..._stacked(),
      if (date != null) ...[
        SizedBox(height: clockSize * dateGapFactor),
        Text(
          date!,
          style: TextStyle(
            fontFamily: fontFamily,
            color: color.withValues(alpha: dateOpacity),
            fontSize: dateSize,
            fontWeight: dateWeight,
            shadows: dateShadows ?? shadows,
          ),
        ),
      ],
    ],
  );

  /// The time split at its colons, a line per part, with the AM or PM
  /// that follows the digits at the date's size under them. The lines sit
  /// a little closer than a line height: the digits' empty ascent and
  /// descent would otherwise open a gap wider than the flat face's colon.
  List<Widget> _stacked() {
    final space = time.indexOf(' ');
    final digits = space < 0 ? time : time.substring(0, space);
    final meridiem = space < 0 ? null : time.substring(space + 1);
    // The hour takes two digits like the lines under it, 05 over 38, so
    // the stack stays a block rather than a lone 5 over a pair.
    final parts = digits.split(':');
    parts[0] = parts[0].padLeft(2, '0');
    return [
      Text(
        parts.join('\n'),
        textAlign: TextAlign.center,
        style: _digits(clockSize).copyWith(height: .92),
      ),
      if (meridiem != null) ...[
        SizedBox(height: clockSize * .04),
        Text(
          meridiem,
          style: _digits(dateSize).copyWith(shadows: dateShadows ?? shadows),
        ),
      ],
    ];
  }
}
