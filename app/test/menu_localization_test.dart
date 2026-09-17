import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/managers/camera/models.dart';
import 'package:kiosk_satellite/ui/camera_views_picker.dart';
import 'package:kiosk_satellite/ui/glance_entity_picker.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/update/update_manager.dart';
import 'package:kiosk_satellite/ui/kiosk_drawer.dart';
import 'package:kiosk_satellite/ui/kit.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:kiosk_satellite/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Test wording exercises localization even before draft catalogs are approved.
class MenuMessages extends UiStringsEn {
  @override
  String get settingScreensaverEnabledTitle => 'TEST screensaver';
  @override
  String get screensaverCameraRequired => 'TEST camera required';
  @override
  String get screensaverDetectionNoProximity => 'TEST no proximity sensor';
  @override
  String get screensaverDetectionProximityPage => 'TEST proximity page';
  @override
  String get screensaverDetectionPermissions => 'TEST permissions';
  @override
  String get screensaverDetectionGrantHelp => 'TEST ADB instructions';
  @override
  String get screensaverDetectionOff => 'TEST detection off';
  @override
  String get screensaverOverlaySmallClock => 'TEST small clock';
  @override
  String get screensaverOverlayCorner => 'TEST corner';
  @override
  String get screensaverOverlayValue => 'TEST displayed value';
  @override
  String get screensaverOverlayState => 'TEST state';
  @override
  String get screensaverOverlayName => 'TEST name';
  @override
  String get commonChoose => 'TEST choose';
  @override
  String get screensaverMediaRoot => 'TEST media root';
  @override
  String get screensaverMediaAvailable => 'TEST available';
  @override
  String get settingScreensaverCameraViewsTitle => 'TEST camera views';
  @override
  String get screensaverModeBlack => 'TEST black mode';
  @override
  String get screensaverFontBlack => 'TEST heavy font';
  @override
  String get screensaverOn => 'TEST on';
  @override
  String get screensaverNowPlaying => 'TEST now playing';
  @override
  String get commonSave => 'TEST save';
  @override
  String get screenAudioReversePortrait => 'TEST reverse portrait';
  @override
  String get settingAdaptiveBrightnessTitle => 'TEST adaptive';
  @override
  String get screenAudioNoSensor => 'TEST no sensor';
  @override
  String get settingHaHoldModeTitle => 'TEST hold page';
  @override
  String get settingHaHoldModeDescription => 'TEST hold explanation';
  @override
  String get haNever => 'TEST never';
  @override
  String get haValidateConnection => 'TEST validate';
  @override
  String get haNotConfigured => 'TEST missing credentials';
  @override
  String get haVibrationLight => 'TEST gentle vibration';
  @override
  String get deviceAnalyticsPage => 'TEST analytics page';
  @override
  String get deviceAnalyticsIntro => 'TEST analytics introduction';
  @override
  String get deviceThemeDark => 'TEST dark';
  @override
  String get deviceThemeLight => 'TEST light';
  @override
  String get deviceThemeSystem => 'TEST system';
  @override
  String get commonSettings => 'Configuración';
  @override
  String get commonCancel => 'Cancelar';
  @override
  String get settingsSearchHint => 'Buscar configuración';
  @override
  String get settingsSearchClear => 'Borrar búsqueda';
  @override
  String get settingsMenuLogs => 'Registros';
  @override
  String get settingsMenuLogsSummary => 'Registro de la aplicación';
  @override
  String settingsSearchEmpty(String query) => 'Sin resultados: $query';
  @override
  String get drawerHoldOn => 'Activar modo de pausa';
  @override
  String get drawerHoldOff => 'Desactivar modo de pausa';
  @override
  String get drawerHoldActive => 'Pausa activa';
  @override
  String get drawerExitApplication => 'Salir de la aplicación';
  @override
  String get drawerExitConfirm => '¿Cerrar la aplicación?';
  @override
  String drawerPluginAction(String pluginName, String actionTitle) =>
      '$actionTitle ($pluginName)';
  @override
  String drawerUpdateInstall(String version) => 'Instalar versión $version';
}

class MenuDelegate extends LocalizationsDelegate<UiStrings> {
  const MenuDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<UiStrings> load(Locale locale) => SynchronousFuture(MenuMessages());
  @override
  bool shouldReload(MenuDelegate old) => false;
}

Widget localized(Widget child) => MaterialApp(
  locale: const Locale('es'),
  supportedLocales: appSupportedLocales,
  localizationsDelegates: const [MenuDelegate(), ...appLocalizationsDelegates],
  theme: buildTheme(Brightness.light),
  home: child,
);

Future<AppContainer> containerFor(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  final container = AppContainer();
  await container.settings.init();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await container.settings.dispose();
    await container.bus.dispose();
    await container.log.dispose();
    tester.view.reset();
  });
  return container;
}

void main() {
  testWidgets(
    'translated detection pages preserve unavailable hardware gates',
    (tester) async {
      final container = await containerFor(tester, const Size(800, 1400));
      await container.settings.setFromJson(defs.cameraEnabled.key, false);
      await tester.pumpWidget(
        localized(
          SubpageSettingsScreen(
            container: container,
            category: 'Screensaver',
            subpage: 'Motion Detection',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TEST camera required'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byType(SwitchListTile).first)
            .onChanged,
        isNull,
      );
      const channel = MethodChannel('kiosk_satellite/proximity_sensor');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'supported': false,
          'hint': 'Not available on this device: it has no proximity sensor.',
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await container.proximity.proximitySupport();
      await tester.pumpWidget(
        localized(
          SubpageSettingsScreen(
            container: container,
            category: 'Screensaver',
            subpage: 'Proximity Detection',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TEST proximity page'), findsWidgets);
      expect(find.text('TEST no proximity sensor'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byType(SwitchListTile).first)
            .onChanged,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'translated person permission guidance preserves the page route',
    (tester) async {
      final container = await containerFor(tester, const Size(800, 1400));
      const channel = MethodChannel('kiosk_satellite/background');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => switch (call.method) {
          'personSensorSupport' => {'supported': true},
          'readLogsState' => {'granted': false, 'effective': false},
          _ => null,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        localized(
          SubpageSettingsScreen(
            container: container,
            category: 'Screensaver',
            subpage: 'Person Detection',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TEST ADB instructions'), findsOneWidget);
      expect(find.text('TEST detection off'), findsOneWidget);
      expect(
        tester
            .widget<SubpageSettingsScreen>(find.byType(SubpageSettingsScreen))
            .subpage,
        'Person Detection',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('translated widget editor preserves corner and font settings', (
    tester,
  ) async {
    final container = await containerFor(tester, const Size(800, 1600));
    final original = [
      {
        'position': 'top_right',
        'type': 'clock',
        'config': {
          'color': '1,2,3',
          'scale': 15,
          'font': 'oswald',
          'font_weight': 'black',
          'h24': true,
          'date': false,
        },
      },
    ];
    await container.settings.setFromJson(
      defs.screensaverWidgets.key,
      jsonEncode(original),
    );
    await tester.pumpWidget(
      localized(
        SubpageSettingsScreen(
          container: container,
          category: 'Screensaver',
          subpage: 'Widgets',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEST small clock'));
    await tester.pumpAndSettle();
    expect(find.text('TEST corner'), findsOneWidget);
    expect(find.text('TEST heavy font'), findsOneWidget);
    expect(find.text('Oswald'), findsOneWidget);
    await tester.tap(find.text('TEST save'));
    await tester.pumpAndSettle();
    expect(
      jsonDecode(container.settings.get(defs.screensaverWidgets)),
      original,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('translated glance editor preserves names and attribute keys', (
    tester,
  ) async {
    final container = await containerFor(tester, const Size(800, 1400));
    container.commands.register(
      Command(
        name: 'haEntityAttributes',
        description: 'Test attributes',
        handler: (_) async =>
            const CommandResult.ok({'humidity': 51, 'friendly_name': 'State'}),
      ),
    );
    List<Map<String, Object?>>? result;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context)
                    .push<List<Map<String, Object?>>>(
                      MaterialPageRoute(
                        builder: (_) => GlanceEntityPicker(
                          container: container,
                          initial: [
                            {'entity_id': 'sensor.original', 'name': 'State'},
                          ],
                        ),
                      ),
                    );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();
    expect(find.text('TEST displayed value'), findsOneWidget);
    expect(find.text('TEST state'), findsOneWidget);
    final nameField = find.descendant(
      of: find.widgetWithText(LabeledField, 'TEST name'),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField, 'My name');
    await tester.tap(find.text('TEST choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('humidity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEST save').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEST save'));
    await tester.pumpAndSettle();
    expect(result, [
      {
        'entity_id': 'sensor.original',
        'name': 'State',
        'custom_name': 'My name',
        'attribute': 'humidity',
      },
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'translated camera picker preserves supplied names and view IDs',
    (tester) async {
      final container = await containerFor(tester, const Size(800, 1200));
      await container.settings.setFromJson(
        defs.cameraConfig.key,
        const CameraConfiguration(
          cameras: [
            CameraSource(
              id: 'camera',
              name: 'Camera',
              kind: 'ha',
              entityId: 'camera.raw',
            ),
          ],
          views: [
            CameraViewConfig(
              id: 'view-raw',
              name: 'Media',
              cameraIds: ['camera'],
            ),
          ],
        ).encode(),
      );
      await container.camera.init();
      addTearDown(container.camera.dispose);
      List<String>? picked;
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  picked = await showCameraViewsPicker(
                    context,
                    container: container,
                    initial: [],
                  );
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      expect(find.text('TEST camera views'), findsOneWidget);
      expect(find.text('TEST available'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);
      expect(find.text('TEST media root'), findsNothing);
      await tester.tap(find.text('Media'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST save'));
      await tester.pumpAndSettle();
      expect(picked, ['view-raw']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'translated screensaver schedule keeps mode and override values',
    (tester) async {
      final container = await containerFor(tester, const Size(800, 1600));
      await container.settings.setFromJson(
        defs.screensaverScheduleEnabled.key,
        true,
      );
      await container.settings.setFromJson(
        defs.screensaverSchedule.key,
        '[{"at":"19:00","mode":"black","brightness":0.2,"motion":false}]',
      );
      await tester.pumpWidget(
        localized(
          SubpageSettingsScreen(
            container: container,
            category: 'Screensaver',
            subpage: 'Scheduled Screensavers',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('TEST black mode'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, '19:00'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.widgetWithText(LabeledField, 'TEST now playing'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST on').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST save'));
      await tester.pumpAndSettle();
      expect(jsonDecode(container.settings.get(defs.screensaverSchedule)), [
        {
          'at': '19:00',
          'mode': 'black',
          'brightness': 0.2,
          'motion': false,
          'now_playing': true,
        },
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Screen and Audio choices keep values and sensor gating', (
    tester,
  ) async {
    final container = await containerFor(tester, const Size(600, 1200));
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: SettingTile(
            container: container,
            def: defs.screenOrientation,
            onChanged: () {},
          ),
        ),
      ),
    );
    final row = tester.widget<DropdownRow<String>>(
      find.byType(DropdownRow<String>),
    );
    expect(
      row.options,
      contains(('reverse_portrait', 'TEST reverse portrait')),
    );
    row.onChanged('reverse_portrait');
    await tester.pump();
    expect(container.settings.get(defs.screenOrientation), 'reverse_portrait');
    container.device.hasLightSensor = false;
    await tester.pumpWidget(
      localized(
        SubpageSettingsScreen(
          container: container,
          category: 'Screen & Audio',
          subpage: 'Adaptive brightness',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('TEST no sensor'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).first,
    );
    expect(toggle.onChanged, isNull);
    expect(toggle.value, isFalse);
    expect(
      tester
          .widget<SubpageSettingsScreen>(find.byType(SubpageSettingsScreen))
          .subpage,
      'Adaptive brightness',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home Assistant validation displays a translated failure', (
    tester,
  ) async {
    final container = await containerFor(tester, const Size(600, 1200));
    await tester.pumpWidget(
      localized(
        CategorySettingsScreen(
          container: container,
          title: 'Home Assistant Setup',
          category: 'Home Assistant',
        ),
      ),
    );
    await tester.tap(find.text('TEST validate'));
    await tester.pump();
    expect(find.text('TEST missing credentials'), findsOneWidget);
    expect(container.homeAssistant.connectionOk.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home Assistant labels preserve canonical choices and routes', (
    tester,
  ) async {
    final container = await containerFor(tester, const Size(600, 1200));
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: SettingTile(
            container: container,
            def: defs.haHapticsStrength,
            onChanged: () {},
          ),
        ),
      ),
    );
    final row = tester.widget<DropdownRow<String>>(
      find.byType(DropdownRow<String>),
    );
    expect(row.options.first, ('light', 'TEST gentle vibration'));
    row.onChanged('light');
    await tester.pump();
    expect(container.settings.get(defs.haHapticsStrength), 'light');
    await tester.pumpWidget(
      localized(
        SubpageSettingsScreen(
          container: container,
          category: 'Home Assistant',
          subpage: 'Hold mode',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('TEST hold explanation'), findsOneWidget);
    expect(find.text('TEST never'), findsOneWidget);
    expect(
      tester
          .widget<SubpageSettingsScreen>(find.byType(SubpageSettingsScreen))
          .subpage,
      'Hold mode',
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [500.0, 1200.0]) {
    testWidgets('localized Settings navigation and search at width $width', (
      tester,
    ) async {
      final container = await containerFor(tester, Size(width, 1000));
      await tester.pumpWidget(localized(SettingsScreen(container: container)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Configuración'), findsOneWidget);
      final search = find.widgetWithText(TextField, 'Buscar configuración');
      for (final query in ['Registros', 'Logs']) {
        await tester.enterText(search, query);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Registro de la aplicación'), findsOneWidget);
      }
      await tester.enterText(search, 'zzzz_missing');
      await tester.pump();
      expect(find.text('Sin resultados: zzzz_missing'), findsOneWidget);
      await tester.tap(find.byTooltip('Borrar búsqueda'));
      await tester.pump();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      await tester.enterText(search, 'Registros');
      await tester.pump();
      await tester.tap(find.text('Registro de la aplicación'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Registros'), findsWidgets);
      expect(find.text('Sin resultados: zzzz_missing'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [500.0, 1200.0]) {
    testWidgets('translated Device subpages keep their route at width $width', (
      tester,
    ) async {
      final container = await containerFor(tester, Size(width, 1400));
      await tester.pumpWidget(localized(SettingsScreen(container: container)));
      await tester.pump(const Duration(milliseconds: 100));
      final search = find.widgetWithText(TextField, 'Buscar configuración');
      await tester.enterText(search, 'TEST analytics page');
      await tester.pump();
      await tester.tap(find.text('TEST analytics page').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1800));
      // Search lands on the entry, whose route name must remain English.
      await tester.ensureVisible(find.text('TEST analytics page').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('TEST analytics page').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('TEST analytics introduction'), findsOneWidget);
      if (width < 720) {
        expect(
          tester
              .widget<SubpageSettingsScreen>(find.byType(SubpageSettingsScreen))
              .subpage,
          'Kiosk Satellite Analytics',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('translated theme options persist canonical values', (
    tester,
  ) async {
    final container = await containerFor(tester, const Size(600, 1000));
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: SettingTile(
            container: container,
            def: defs.uiTheme,
            onChanged: () {},
          ),
        ),
      ),
    );
    final row = tester.widget<DropdownRow<String>>(
      find.byType(DropdownRow<String>),
    );
    expect(row.options, [
      ('dark', 'TEST dark'),
      ('light', 'TEST light'),
      ('system', 'TEST system'),
    ]);
    row.onChanged('dark');
    await tester.pump();
    expect(container.settings.get(defs.uiTheme), 'dark');
    final definition = container.settings.describe().firstWhere(
      (d) => d['key'] == 'ui.theme',
    );
    expect(definition['options'], ['dark', 'light', 'system']);
    expect((definition['optionMessageIds'] as Map)['dark'], 'deviceThemeDark');
  });

  testWidgets(
    'drawer localizes conditional actions and preserves plugin values',
    (tester) async {
      final container = await containerFor(tester, const Size(360, 2200));
      await container.settings.set(defs.haHoldMenu, true);
      container.plugins.enabled.value = true;
      container.plugins.installed.value = [
        {
          'id': 'sample',
          'name': 'Device',
          'running': true,
          'commands': [
            {'id': 'open', 'title': 'Open view'},
          ],
          'actionOptions': {
            'open': {'drawer': true},
          },
        },
      ];
      container.update.available.value = const UpdateInfo(
        version: 'test-2',
        apkUrl: '',
        notes: '',
        releaseUrl: '',
      );
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: KioskDrawer(
              container: container,
              onClose: () {},
              onSettings: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Open view (Device)'), findsOneWidget);
      expect(find.text('Instalar versión test-2'), findsOneWidget);
      expect(find.text('Activar modo de pausa'), findsOneWidget);
      await tester.tap(find.text('Activar modo de pausa'));
      await tester.pump();
      expect(container.settings.get(defs.haHoldMode), isTrue);
      expect(find.text('Desactivar modo de pausa'), findsOneWidget);
      expect(find.text('Pausa activa'), findsOneWidget);
      await tester.tap(find.text('Salir de la aplicación'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar la aplicación?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar la aplicación?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
