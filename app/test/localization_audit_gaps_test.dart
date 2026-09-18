import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/l10n/messages.dart';
import 'package:kiosk_satellite/managers/glance/glance_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/ui/glance_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Spanish extends UiStringsEn {
  @override
  String deviceRestartFailed(String error) => 'No se pudo reiniciar: $error';
  @override
  String get deviceRestartAndroidOnly =>
      'El reinicio solo está disponible en Android.';
  @override
  String get glanceUnknown => 'Desconocido';
  @override
  String get glanceUnavailable => 'No disponible';
  @override
  String get deviceBatteryHeld =>
      'Permite ejecutar el proceso en segundo plano.';
  @override
  String get updateInvalidApk => 'El archivo no es un APK de Android.';
  @override
  String deviceInstallFailedDetail(String error) =>
      'La instalación falló: $error';
  @override
  String updateUploadSpace(String size, String required, String free) =>
      'APK $size MB, necesarios $required MB, libres $free MB';
}

class _Delegate extends LocalizationsDelegate<UiStrings> {
  const _Delegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<UiStrings> load(Locale locale) => SynchronousFuture(
    locale.languageCode == 'es' ? _Spanish() : UiStringsEn(),
  );
  @override
  bool shouldReload(_Delegate old) => false;
}

Widget app(Widget child, String language) => MaterialApp(
  locale: Locale(language),
  supportedLocales: const [Locale('en'), Locale('es')],
  localizationsDelegates: const [_Delegate(), ...appLocalizationsDelegates],
  home: Scaffold(body: child),
);
void main() {
  testWidgets('known errors translate and unknown diagnostics stay exact', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
        'es',
      ),
    );
    expect(
      deviceOperationError(
        context,
        'Install failed: Bad state: The file is not an Android APK.',
      ),
      'La instalación falló: El archivo no es un APK de Android.',
    );
    expect(
      deviceOperationError(
        context,
        'Not enough free space: the APK is 132.6 MB and the install needs about 365.2 MB, but the device has 90.1 MB free.',
      ),
      'APK 132.6 MB, necesarios 365.2 MB, libres 90.1 MB',
    );
    expect(
      deviceOperationError(context, 'restart failed: restart is Android-only'),
      'No se pudo reiniciar: El reinicio solo está disponible en Android.',
    );
    expect(
      deviceOperationError(context, 'restart failed: E_VENDOR <raw>'),
      'No se pudo reiniciar: E_VENDOR <raw>',
    );
    const detail =
        'PlatformException(E_VENDOR, <original> /data/a.apk, {code: 42}, null)';
    expect(deviceOperationError(context, detail), detail);
    expect(
      deviceOperationError(context, 'Install failed: $detail'),
      'La instalación falló: $detail',
    );
    expect(
      deviceOperationError(
        context,
        'PlatformException(install, The file is not an Android APK., null, null)',
      ),
      'PlatformException(install, El archivo no es un APK de Android., null, null)',
    );
    expect(
      launcherText(
        context,
        'Allows the process to run in the background without being paused or killed.',
      ),
      'Permite ejecutar el proceso en segundo plano.',
    );
  });
  for (final textOnly in [false, true]) {
    testWidgets(
      'Glance reserved states change locale without replacing data: $textOnly',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final c = AppContainer();
        await c.settings.init();
        await c.settings.set(defs.screensaverGlanceTextOnly, textOnly);
        final entities = [
          const GlanceEntity(
            entityId: 'sensor.a',
            name: 'Original name',
            state: 'unknown',
          ),
          const GlanceEntity(
            entityId: 'sensor.b',
            name: 'Other name',
            state: 'unavailable',
          ),
          const GlanceEntity(
            entityId: 'sensor.c',
            name: 'Temperature',
            state: '21.25',
            unit: '°C',
            precision: 1,
          ),
        ];
        c.glance.entities.value = entities;
        await tester.pumpWidget(app(GlanceRow(container: c), 'en'));
        await tester.pumpAndSettle();
        expect(find.text('Unknown'), findsOneWidget);
        await tester.pumpWidget(app(GlanceRow(container: c), 'es'));
        await tester.pumpAndSettle();
        expect(find.text('Desconocido'), findsOneWidget);
        expect(find.text('No disponible'), findsOneWidget);
        expect(find.text('Original name'), findsOneWidget);
        expect(find.text('21.3 °C'), findsOneWidget);
        expect(c.glance.entities.value, same(entities));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
