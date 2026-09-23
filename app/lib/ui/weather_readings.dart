import 'package:flutter/material.dart';
import '../l10n/messages.dart';

/// Shared temperature selection for the weather widget and Weather Mood bar.
class WeatherTemperatureReading {
  const WeatherTemperatureReading(
    this.primary, {
    this.apparent,
    this.apparentOnly = false,
  });

  final String primary;
  final String? apparent;
  final bool apparentOnly;

  static WeatherTemperatureReading? fromAttributes(
    Map<String, Object?> attributes, {
    required bool feelsLike,
    required bool feelsLikeOnly,
  }) {
    num? number(String key) {
      final value = attributes[key];
      return value is num && value.isFinite ? value : null;
    }

    String degrees(num value) =>
        '${value.round()}${attributes['temperature_unit'] ?? '°'}';
    final actual = number('temperature');
    final apparent = number('apparent_temperature');
    if (apparent != null && (feelsLikeOnly || (feelsLike && actual == null))) {
      return WeatherTemperatureReading(degrees(apparent), apparentOnly: true);
    }
    if (actual == null) return null;
    return WeatherTemperatureReading(
      degrees(actual),
      apparent: feelsLike && apparent != null ? degrees(apparent) : null,
    );
  }
}

class WeatherTemperature extends StatelessWidget {
  const WeatherTemperature({
    super.key,
    required this.reading,
    required this.primaryStyle,
    required this.secondaryStyle,
    this.alignment = CrossAxisAlignment.start,
  });

  final WeatherTemperatureReading reading;
  final TextStyle primaryStyle;
  final TextStyle secondaryStyle;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final secondary = reading.apparentOnly
        ? strings.screensaverOverlayFeelsLike
        : reading.apparent != null
        ? strings.screensaverWeatherFeelsLikeValue(reading.apparent!)
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text(reading.primary, style: primaryStyle),
        if (secondary != null) ...[
          const SizedBox(height: 2),
          Text(secondary, style: secondaryStyle),
        ],
      ],
    );
  }
}

/// Monochrome Material glyphs for the conditions, tinted with the widget
/// color exactly like the text.
IconData weatherConditionIcon(String condition) => switch (condition) {
  'clear-night' => Icons.nights_stay,
  'cloudy' => Icons.cloud,
  'exceptional' => Icons.storm,
  'fog' => Icons.foggy,
  'hail' => Icons.grain,
  'lightning' => Icons.bolt,
  'lightning-rainy' => Icons.thunderstorm,
  'partlycloudy' => Icons.wb_cloudy,
  'pouring' => Icons.umbrella,
  'rainy' => Icons.umbrella,
  'snowy' => Icons.ac_unit,
  'snowy-rainy' => Icons.ac_unit,
  'sunny' => Icons.wb_sunny,
  'windy' || 'windy-variant' => Icons.air,
  _ => Icons.cloud,
};

String weatherMoodConditionText(BuildContext context, String condition) {
  final strings = l10n(context);
  return switch (condition) {
    'sunny' || 'clear-night' => strings.screensaverWeatherPreviewSunny,
    'partlycloudy' => strings.screensaverWeatherPreviewPartlycloudy,
    'cloudy' => strings.screensaverWeatherPreviewCloudy,
    'rainy' => strings.screensaverWeatherPreviewRainy,
    'pouring' => strings.screensaverWeatherPreviewPouring,
    'snowy' => strings.screensaverWeatherPreviewSnowy,
    'snowy-rainy' => strings.screensaverWeatherPreviewSnowyRainy,
    'fog' => strings.screensaverWeatherPreviewFog,
    'hail' => strings.screensaverWeatherPreviewHail,
    'lightning' => strings.screensaverWeatherPreviewLightning,
    'lightning-rainy' => strings.screensaverWeatherPreviewLightningRainy,
    'windy' => strings.screensaverWeatherPreviewWindy,
    'windy-variant' => strings.screensaverWeatherPreviewWindyVariant,
    _ => strings.screensaverWeatherPreviewExceptional,
  };
}
