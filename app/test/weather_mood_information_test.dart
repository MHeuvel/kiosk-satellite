import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/glance/glance_manager.dart';
import 'package:kiosk_satellite/ui/digital_clock_face.dart';
import 'package:kiosk_satellite/ui/glance_row.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:kiosk_satellite/ui/weather_mood_information.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<AppContainer> container([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues({
      'ks.screensaver.mode': 'weather_mood',
      ...values,
    });
    final c = AppContainer();
    await c.settings.init();
    return c;
  }

  test(
    'Weather Mood clock preserves clock defaults and localized controls',
    () {
      for (final (mood, clock) in [
        (defs.screensaverWeatherClockFont, defs.screensaverClockFont),
        (
          defs.screensaverWeatherClockFontWeight,
          defs.screensaverClockFontWeight,
        ),
        (defs.screensaverWeatherClock24h, defs.screensaverClock24h),
        (defs.screensaverWeatherClockDate, defs.screensaverClockDate),
        (defs.screensaverWeatherClockScale, defs.screensaverClockScale),
        (defs.screensaverWeatherClockColor, defs.screensaverClockColor),
      ]) {
        expect(mood.defaultValue, clock.defaultValue);
        expect(mood.titleMessageId, clock.titleMessageId);
        expect(mood.descriptionMessageId, clock.descriptionMessageId);
        expect(mood.options, clock.options);
        expect(mood.optionMessageIds, clock.optionMessageIds);
      }
      expect(defs.screensaverWeatherClock.defaultValue, false);
      expect(defs.screensaverWeatherBar.defaultValue, false);
      expect(defs.screensaverWeatherClockShadow.defaultValue, true);
    },
  );
  test(
    'readings merge HA diffs and retain units with absent apparent temperatures',
    () {
      final r = WeatherMoodReadings();
      expect(r.available, false);
      r.update({
        'state': 'sunny',
        'attributes': {
          'temperature': 22.2,
          'temperature_unit': '°C',
          'wind_speed': 12.2,
          'wind_speed_unit': 'km/h',
        },
      });
      r.update({
        'attributes': {'apparent_temperature': 24.7},
      });
      expect(
        r.temperature(feelsLike: true, feelsLikeOnly: false),
        '22°C / 25°C',
      );
      expect(r.temperature(feelsLike: true, feelsLikeOnly: true), '25°C');
      r.update({
        'attributes': {'apparent_temperature': 22.4},
      });
      expect(r.temperature(feelsLike: true, feelsLikeOnly: false), '22°C');
      r.update({
        'attributes': {'apparent_temperature': null, 'visibility': double.nan},
      });
      expect(r.temperature(feelsLike: true, feelsLikeOnly: true), '22°C');
      expect(r.number('visibility'), isNull);
      expect(r.reading(r.number('wind_speed')!, 'wind_speed_unit'), '12 km/h');
      r.update({'state': 'unavailable'});
      expect(r.available, false);
    },
  );
  for (final language in ['en', 'es', 'de', 'fr']) {
    testWidgets('clock and bar controls reveal and save in $language', (
      tester,
    ) async {
      final c = await container();
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final strings = lookupUiStrings(Locale(language));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: SubpageSettingsScreen(
            container: c,
            category: 'Screensaver',
            subpage: 'Weather Mood screensaver',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(strings.settingScreensaverWeatherBlurTitle),
        findsOneWidget,
      );
      expect(
        find.text(strings.settingScreensaverClockScaleTitle),
        findsNothing,
      );
      expect(
        find.text(strings.settingScreensaverWeatherBarScaleTitle),
        findsNothing,
      );
      await tester.tap(find.text(strings.settingScreensaverWeatherClockTitle));
      await tester.pumpAndSettle();
      expect(
        find.text(strings.settingScreensaverClockScaleTitle),
        findsOneWidget,
      );
      expect(
        find.text(strings.settingScreensaverClockFontTitle),
        findsOneWidget,
      );
      expect(
        find.text(strings.settingScreensaverWidgetTextShadowTitle),
        findsOneWidget,
      );
      await tester.tap(find.text(strings.settingScreensaverClock24hTitle));
      await tester.pumpAndSettle();
      expect(c.settings.get(defs.screensaverWeatherClock24h), true);
      expect(c.settings.get(defs.screensaverClock24h), false);
      await tester.tap(find.text(strings.settingScreensaverWeatherBarTitle));
      await tester.pumpAndSettle();
      expect(
        find.text(strings.settingScreensaverWeatherBarScaleTitle),
        findsOneWidget,
      );
      expect(
        find.text(strings.settingScreensaverWidgetTextShadowTitle),
        findsNWidgets(2),
      );
      await tester.tap(find.text(strings.settingScreensaverWeatherClockTitle));
      await tester.pumpAndSettle();
      expect(
        find.text(strings.settingScreensaverClockScaleTitle),
        findsNothing,
      );
      expect(
        find.text(strings.settingScreensaverWeatherBarScaleTitle),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'overlays fit landscape, portrait and large text and update live',
    (tester) async {
      final c = await container({
        'ks.screensaver.weather_clock': true,
        'ks.screensaver.weather_bar': true,
        'ks.screensaver.weather_bar_location': 'Home',
        'ks.screensaver.weather_bar_feels_like': true,
        'ks.screensaver.glance_enabled': true,
      });
      c.glance.entities.value = const [
        GlanceEntity(
          entityId: 'sensor.room',
          name: 'Living room',
          state: '23',
          unit: '°C',
        ),
      ];
      final readings = WeatherMoodReadings()
        ..update({
          'state': 'partlycloudy',
          'attributes': {
            'temperature': 26.4,
            'apparent_temperature': 29.2,
            'temperature_unit': '°C',
            'humidity': 72,
            'wind_speed': 12.3,
            'wind_speed_unit': 'km/h',
            'visibility': 10,
            'visibility_unit': 'km',
          },
        });
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader(
        'Rubik',
      )..addFont(rootBundle.load('assets/fonts/Rubik.ttf'))).load();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      Future<void> show(Size size, double scale, String locale) async {
        tester.view.physicalSize = size;
        await c.settings.set(defs.screensaverWeatherBarScale, scale);
        await c.settings.set(
          defs.screensaverWeatherClockScale,
          scale == 200 ? 300 : 100,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: RepaintBoundary(
              key: key,
              child: Material(
                color: const Color(0xFF33485F),
                child: WeatherMoodInformation(container: c, readings: readings),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$size, $scale, $locale',
        );
        expect(find.byType(DigitalClockFace), findsOneWidget);
        expect(find.text('26°C / 29°C'), findsOneWidget);
        expect(
          find.text(
            lookupUiStrings(
              Locale(locale),
            ).screensaverWeatherPreviewPartlycloudy,
          ),
          findsOneWidget,
        );
        expect(
          tester
              .getRect(find.byType(DigitalClockFace))
              .overlaps(tester.getRect(find.byType(WeatherMoodBar))),
          false,
        );
        expect(
          tester.getBottomLeft(find.byType(GlanceRow)).dy,
          lessThan(tester.getTopLeft(find.byType(WeatherMoodBar)).dy),
        );
        final directory = Platform.environment['WEATHER_MOOD_REVIEW_DIR'];
        if (directory != null) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$directory/${size.width.toInt()}-${scale.toInt()}-$locale.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      for (final size in [
        const Size(1280, 800),
        const Size(720, 480),
        const Size(360, 800),
      ]) {
        await show(size, 100, 'en');
        await show(size, 200, 'de');
        final face = tester.widget<DigitalClockFace>(
          find.byType(DigitalClockFace),
        );
        expect(face.date, isNotNull);
        expect(face.dateGapFactor, .015);
        expect(face.dateOpacity, 1);
        expect(face.shadows, isNotEmpty);
      }
      await c.settings.set(defs.screensaverWeatherClockDate, false);
      await c.settings.set(defs.screensaverWeatherClock24h, true);
      await c.settings.set(defs.screensaverWeatherClockShadow, false);
      await c.settings.set(defs.screensaverWeatherBarHumidity, false);
      readings.update({
        'attributes': {'wind_speed': null, 'visibility': null},
      });
      await show(const Size(1280, 800), 100, 'fr');
      expect(find.text('72%'), findsNothing);
      expect(find.text('12 km/h'), findsNothing);
      final face = tester.widget<DigitalClockFace>(
        find.byType(DigitalClockFace),
      );
      expect(face.date, isNull);
      expect(face.shadows, isEmpty);
      expect(face.time, matches(RegExp(r'^\d{2}:\d{2}$')));
      readings.update({'state': 'unavailable'});
      await tester.pumpWidget(
        MaterialApp(
          home: WeatherMoodInformation(container: c, readings: readings),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WeatherMoodBar), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
