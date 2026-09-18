import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
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
  String get setupBackupObject => 'La copia debe contener un objeto JSON.';
  @override
  String get setupBackupKind =>
      'Este archivo no es una configuración de Kiosk Satellite.';
  @override
  String get setupBackupSettings => 'La copia no contiene ajustes.';
}

class _Delegate extends LocalizationsDelegate<UiStrings> {
  const _Delegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<UiStrings> load(Locale locale) => SynchronousFuture(_Spanish());
  @override
  bool shouldReload(_Delegate old) => false;
}

void main() {
  for (final entry in <(Object?, String)>[
    (null, 'La copia debe contener un objeto JSON.'),
    ({}, 'Este archivo no es una configuración de Kiosk Satellite.'),
    ({'kind': 'kiosk-satellite-config'}, 'La copia no contiene ajustes.'),
    (
      {'kind': 'kiosk-satellite-config', 'settings': []},
      'La copia no contiene ajustes.',
    ),
  ]) {
    testWidgets(
      'Settings import rejects ${jsonEncode(entry.$1)} in Spanish without changing settings',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final container = AppContainer();
        await container.settings.init();
        await container.settings.set(defs.deviceName, 'Original kiosk');
        await container.settings.set(defs.remotePassword, 'Original password');
        final picker = _Picker()..content = jsonEncode(entry.$1);
        FilePicker.platform = picker;
        addTearDown(() async {
          FilePicker.platform = _Picker();
          await container.settings.dispose();
          await container.bus.dispose();
          await container.log.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              _Delegate(),
              ...appLocalizationsDelegates,
            ],
            home: CategorySettingsScreen(
              container: container,
              title: 'Device',
              category: 'Device',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.text('Import configuration');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Import'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.$2), findsOneWidget);
        expect(container.settings.get(defs.deviceName), 'Original kiosk');
        expect(
          container.settings.get(defs.remotePassword),
          'Original password',
        );
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
