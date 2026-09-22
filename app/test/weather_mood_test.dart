import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/screensaver/screensaver_widgets.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:kiosk_satellite/ui/screensaver_view.dart';
import 'package:kiosk_satellite/ui/weather_mood_screensaver.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in {
    'en': 'Select a weather entity in Settings > Screensaver > Weather Mood.',
    'es':
        'Selecciona una entidad meteorológica en Ajustes > Salvapantallas > Ambiente meteorológico.',
    'de':
        'Wähle eine Wetterentität unter Einstellungen > Bildschirmschoner > Wetterstimmung aus.',
    'fr':
        'Sélectionnez une entité météo dans Paramètres > Économiseur d’écran > Ambiance météo.',
  }.entries) {
    testWidgets(
      'unset entity shows a black prompt without overlays in ${language.key}',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'ks.screensaver.widgets':
              '[{"type":"clock","position":"top_left","config":{}}]',
          'ks.screensaver.glance_enabled': true,
        });
        final container = AppContainer();
        await container.settings.init();
        container.screensaver.activeView.value = 'weather_mood';
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language.key),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: Scaffold(
              body: Stack(children: [ScreensaverOverlay(container: container)]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(language.value), findsOneWidget);
        expect(find.byType(InAppWebView), findsNothing);
        expect(find.byType(WeatherWidgetOverlay), findsNothing);
        expect(find.byType(ClockWidgetOverlay), findsNothing);
        final background = tester.widget<ColoredBox>(
          find
              .ancestor(
                of: find.text(language.value),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(background.color, Colors.black);
        await container.settings.setFromJson(
          defs.screensaverWeatherEntity.key,
          '  ',
        );
        await tester.pumpAndSettle();
        expect(find.text(language.value), findsOneWidget);
        expect(find.byType(InAppWebView), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  test('sun state overrides local time and missing sun uses 6 AM to 6 PM', () {
    expect(weatherMoodNight('above_horizon', DateTime(2026, 9, 21, 23)), false);
    expect(weatherMoodNight('below_horizon', DateTime(2026, 9, 21, 12)), true);
    for (final sun in [null, 'unknown', 'unavailable']) {
      expect(weatherMoodNight(sun, DateTime(2026, 9, 21, 5, 59)), true);
      expect(weatherMoodNight(sun, DateTime(2026, 9, 21, 6)), false);
      expect(weatherMoodNight(sun, DateTime(2026, 9, 21, 17, 59)), false);
      expect(weatherMoodNight(sun, DateTime(2026, 9, 21, 18)), true);
    }
  });

  test('Weather Mood supports every widget type', () {
    expect(screensaverWidgetAllowedOnMode('weather', 'weather_mood'), true);
    for (final type in ['clock', 'battery', 'entity']) {
      expect(screensaverWidgetAllowedOnMode(type, 'weather_mood'), true);
    }
    expect(screensaverWidgetAllowedOnMode('weather', 'clock'), true);
  });

  test(
    'settings persist and scheduled Weather Mood carries overlays',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = AppContainer();
      await container.settings.init();
      final settings = container.settings;
      expect(settings.visible(defs.screensaverWeatherEntity), false);
      await settings.setFromJson(defs.screensaverMode.key, 'weather_mood');
      expect(settings.visible(defs.screensaverWeatherEntity), true);
      await settings.setFromJson(
        defs.screensaverWeatherEntity.key,
        'weather.home',
      );
      await settings.setFromJson(defs.screensaverWeatherLightning.key, false);
      await settings.setFromJson(defs.screensaverScheduleEnabled.key, true);
      await settings.setFromJson(
        defs.screensaverSchedule.key,
        '[{"at":"00:00","mode":"weather_mood","widgets":true,"glance":true}]',
      );
      await container.screensaver.start();
      await pumpEventQueue();
      expect(container.screensaver.activeView.value, 'weather_mood');
      expect(container.screensaver.scheduleWidgets.value, true);
      expect(container.screensaver.scheduleGlance.value, true);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString('ks.screensaver.weather_entity'),
        'weather.home',
      );
      expect(preferences.getBool('ks.screensaver.weather_lightning'), false);
      await container.screensaver.stop();
    },
  );

  testWidgets('mode picker lists weather entities by name and saves the ID', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = AppContainer();
    await container.settings.init();
    container.commands.register(
      Command(
        name: 'haSearchEntities',
        description: 'Test entity search',
        handler: (params) async {
          expect(params['query'], 'weather.');
          return const CommandResult.ok([
            {'entity_id': 'weather.home', 'name': 'Garden weather'},
            {
              'entity_id': 'sensor.weather_temperature',
              'name': 'Excluded sensor',
            },
          ]);
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingTile(
            container: container,
            def: defs.screensaverWeatherEntity,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Weather entity'));
    await tester.pumpAndSettle();
    expect(find.text('Garden weather'), findsOneWidget);
    expect(find.text('Excluded sensor'), findsNothing);
    await tester.tap(find.text('Garden weather'));
    await tester.pumpAndSettle();
    expect(
      container.settings.get(defs.screensaverWeatherEntity),
      'weather.home',
    );
  });
}
