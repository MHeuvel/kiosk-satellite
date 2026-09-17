import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/update/update_manager.dart';
import 'package:kiosk_satellite/ui/kiosk_drawer.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:kiosk_satellite/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Test wording exercises localization even before draft catalogs are approved.
class MenuMessages extends UiStringsEn {
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
