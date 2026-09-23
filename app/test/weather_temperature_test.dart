import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/ui/weather_readings.dart';

void main() {
  WeatherTemperatureReading? reading({
    Object? actual = 29,
    Object? apparent = 33,
    String unit = '°C',
    bool enabled = true,
    bool only = false,
  }) => WeatherTemperatureReading.fromAttributes(
    {
      'temperature': actual,
      'apparent_temperature': apparent,
      'temperature_unit': unit,
    },
    feelsLike: enabled,
    feelsLikeOnly: only,
  );

  test('actual and apparent temperatures stay separate with their units', () {
    expect(reading()!.primary, '29°C');
    expect(reading()!.apparent, '33°C');
    expect(reading(enabled: false)!.apparent, isNull);
    expect(reading(apparent: 29)!.apparent, '29°C');
    expect(reading(actual: -4.7, apparent: -9.2, unit: '°F')!.primary, '-5°F');
    expect(reading(actual: -4.7, apparent: -9.2, unit: '°F')!.apparent, '-9°F');
  });

  test('missing and invalid readings fall back without misleading labels', () {
    for (final absent in [null, 'unknown', double.nan, double.infinity]) {
      final value = reading(apparent: absent, only: true)!;
      expect(value.primary, '29°C');
      expect(value.apparentOnly, false);
      expect(value.apparent, isNull);
      expect(reading(actual: absent, apparent: absent), isNull);
      expect(reading(actual: absent, enabled: false), isNull);
    }
    expect(reading(actual: null)!.primary, '33°C');
    expect(reading(actual: null)!.apparentOnly, true);
  });

  for (final locale in ['en', 'es', 'de', 'fr']) {
    testWidgets(
      'labeled temperatures in $locale preserve alignment and styles',
      (tester) async {
        final strings = lookupUiStrings(Locale(locale));
        for (final only in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              home: Scaffold(
                body: WeatherTemperature(
                  reading: reading(only: only)!,
                  alignment: CrossAxisAlignment.end,
                  primaryStyle: const TextStyle(
                    fontSize: 50,
                    color: Colors.white,
                  ),
                  secondaryStyle: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final main = find.text(only ? '33°C' : '29°C');
          final secondary = find.text(
            only
                ? strings.screensaverOverlayFeelsLike
                : strings.screensaverWeatherFeelsLikeValue('33°C'),
          );
          expect(main, findsOneWidget);
          expect(secondary, findsOneWidget);
          expect(
            tester.getTopLeft(secondary).dy,
            greaterThan(tester.getBottomLeft(main).dy),
          );
          expect(tester.getTopRight(main).dx, tester.getTopRight(secondary).dx);
          expect(tester.widget<Text>(main).style!.fontSize, 50);
          expect(tester.widget<Text>(secondary).style!.fontSize, 20);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
