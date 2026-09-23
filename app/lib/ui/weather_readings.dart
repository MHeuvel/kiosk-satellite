import 'package:flutter/material.dart';
import '../l10n/messages.dart';

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
