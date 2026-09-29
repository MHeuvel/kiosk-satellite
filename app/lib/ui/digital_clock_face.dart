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
  });

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

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        time,
        style: TextStyle(
          fontFamily: fontFamily,
          color: color,
          fontSize: clockSize,
          fontWeight: weight,
          fontVariations: clockFontVariations(opticalSize, weight),
          letterSpacing: clockSize * .02,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1,
          shadows: shadows,
        ),
      ),
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
}
