import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/ui/setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Picker extends FilePicker {
  String? content;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    expect(type, FileType.custom);
    expect(allowedExtensions, ['json']);
    expect(withData, isTrue);
    if (content == null) return null;
    final bytes = Uint8List.fromList(utf8.encode(content!));
    return FilePickerResult([
      PlatformFile(name: 'backup.json', size: bytes.length, bytes: bytes),
    ]);
  }
}

class _Spanish extends UiStringsEn {
  @override
  String get setupBackupSettings => 'La copia no contiene ajustes.';
  @override
  String get setupServiceHelp =>
      'Mantiene activa la aplicación con la pantalla apagada.';
  @override
  String get deviceBattery => 'Batería sin restricciones';
  @override
  String get deviceOverlay => 'Mostrar sobre otras aplicaciones';
  @override
  String get setupBatteryMissing => 'Android puede pausar la aplicación.';
  @override
  String get deviceBatteryHeld => 'Permite ejecutar en segundo plano.';
  @override
  String get commonGrant => 'Conceder';
  @override
  String get setupNotBackup => 'El archivo no es una copia de seguridad';
  @override
  String get setupInvalidBackupHelp => 'Exporta un archivo JSON válido.';
  @override
  String get deviceImportFailed => 'No se pudo importar';
  @override
  String get setupBackupNoDashboard => 'La copia no tiene un panel de control';
  @override
  String get setupBackupNoDashboardHelp =>
      'Continúa para elegir un panel de control.';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppContainer container;
  var batteryUnrestricted = false;
  var overlay = false;
  var overlayRequestable = false;
  final permissionCalls = <String>[];
  Future<void> boot() async {
    SharedPreferences.setMockInitialValues({});
    container = AppContainer();
    await container.settings.init();
    // The native service, answering as a running one.
    const channel = MethodChannel('kiosk_satellite/background');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'serviceStatus':
              return <String, Object?>{
                'running': true,
                'foreground': true,
                'types': ['specialUse'],
                'uptimeMs': 5000,
              };
            case 'requestBatteryUnrestricted':
              permissionCalls.add(call.method);
              batteryUnrestricted = true;
              return null;
            case 'isBatteryUnrestricted':
              return batteryUnrestricted;
            case 'canBringToFront':
              return overlay;
            case 'canRequestBringToFront':
              return overlayRequestable;
            case 'canRequestBatteryUnrestricted':
              return true;
            case 'hasAllFilesAccess':
            case 'hasUsageAccess':
              return true;
          }
          return null;
        });
    // permission_handler's channel: everything granted, services on.
    const perms = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(perms, (call) async {
          if (call.method == 'checkServiceStatus') return 1;
          if (call.method == 'checkPermissionStatus') return 1;
          return null;
        });
    const brightness = MethodChannel('kiosk_satellite/brightness');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(brightness, (call) async => true);
    // device_info_plus (the Android version check behind the Bluetooth
    // rows): an unmocked channel hangs a widget test rather than throwing,
    // so answer with the failure the read already treats as "not Android".
    const info = MethodChannel('dev.fluttercommunity.plus/device_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          info,
          (call) async => throw PlatformException(code: 'test'),
        );
    addTearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(perms, null);
      messenger.setMockMethodCallHandler(brightness, null);
      messenger.setMockMethodCallHandler(info, null);
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ValueNotifier<Locale>> show(WidgetTester tester) async {
    await boot();
    final language = ValueNotifier(const Locale('es'));
    addTearDown(language.dispose);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: language,
        builder: (context, locale, _) => MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: const [
            _Delegate(),
            ...appLocalizationsDelegates,
          ],
          home: SetupScreen(container: container),
        ),
      ),
    );
    await settle(tester);
    return language;
  }

  testWidgets('translated service grants preserve requests and ADB commands', (
    tester,
  ) async {
    final language = await show(tester);
    final battery = find.widgetWithText(ListTile, 'Batería sin restricciones');
    expect(
      find.text('Mantiene activa la aplicación con la pantalla apagada.'),
      findsOneWidget,
    );
    expect(find.text('Android puede pausar la aplicación.'), findsOneWidget);
    expect(
      find.textContaining(
        'adb shell appops set me.jxl.kiosk_satellite SYSTEM_ALERT_WINDOW allow',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Mostrar sobre otras aplicaciones'),
        matching: find.byType(TextButton),
      ),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: battery, matching: find.text('Conceder')),
    );
    await settle(tester);
    expect(permissionCalls, ['requestBatteryUnrestricted']);
    expect(find.text('Permite ejecutar en segundo plano.'), findsOneWidget);
    language.value = const Locale('en');
    await settle(tester);
    language.value = const Locale('es');
    await settle(tester);
    expect(find.text('Permite ejecutar en segundo plano.'), findsOneWidget);
    expect(permissionCalls, ['requestBatteryUnrestricted']);
    tester.view.physicalSize = const Size(390, 1000);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
  testWidgets(
    'translated restore errors preserve identity options and backup data',
    (tester) async {
      final picker = _Picker();
      FilePicker.platform = picker;
      await show(tester);
      await container.settings.set(defs.deviceName, 'Local kiosk');
      await container.settings.set(
        defs.haSatelliteEntity,
        'assist_satellite.local',
      );
      Future<void> upload(String? content) async {
        picker.content = content;
        await tester.tap(find.text('Import'));
        await settle(tester);
      }

      await upload(null);
      expect(container.settings.get(defs.deviceName), 'Local kiosk');
      expect(container.settings.get(defs.remotePassword), '');
      await upload('{broken');
      expect(
        find.text('El archivo no es una copia de seguridad'),
        findsOneWidget,
      );
      expect(find.text('Exporta un archivo JSON válido.'), findsOneWidget);
      expect(container.settings.get(defs.deviceName), 'Local kiosk');
      expect(container.settings.get(defs.remotePassword), '');
      final config = {
        'kind': 'kiosk-satellite-config',
        'settings': {
          'device.name': 'Original kiosk',
          'remote.password': 'fixture-backup-password',
          'ha.satellite_entity': 'assist_satellite.original',
        },
      };
      await upload(jsonEncode(config));
      final dialog = find.byType(AlertDialog);
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Cancel')),
      );
      await settle(tester);
      expect(container.settings.get(defs.deviceName), 'Local kiosk');
      expect(container.settings.get(defs.remotePassword), '');
      await upload(jsonEncode(config));
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Import')),
      );
      await settle(tester);
      expect(container.settings.get(defs.deviceName), 'Local kiosk');
      expect(
        container.settings.get(defs.haSatelliteEntity),
        'assist_satellite.local',
      );
      expect(
        container.settings.get(defs.remotePassword),
        'fixture-backup-password',
      );
      expect(
        find.text('La copia no tiene un panel de control'),
        findsOneWidget,
      );
      await upload(jsonEncode(config));
      final replace = find.descendant(
        of: dialog,
        matching: find.textContaining('Original kiosk'),
      );
      await tester.ensureVisible(replace);
      await settle(tester);
      await tester.tap(replace);
      await settle(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await settle(tester);
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Import')),
      );
      await settle(tester);
      expect(container.settings.get(defs.deviceName), 'Original kiosk');
      expect(
        container.settings.get(defs.haSatelliteEntity),
        'assist_satellite.local',
      );
      await upload(jsonEncode({'kind': 'kiosk-satellite-config'}));
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Import')),
      );
      await settle(tester);
      expect(find.text('No se pudo importar'), findsOneWidget);
      expect(find.text('La copia no contiene ajustes.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );
}
