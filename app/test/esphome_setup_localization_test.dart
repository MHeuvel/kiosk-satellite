import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/ui/esphome_entity_picker.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:kiosk_satellite/ui/settings_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Spanish extends UiStringsEn {
  @override
  String get settingEsphomeExcludedEntitiesTitle => 'Entidades excluidas';
  @override
  String get esphomeEntitySearch => 'Buscar entidades';
  @override
  String get esphomeEntityUnavailable => 'No disponible actualmente';
  @override
  String get esphomeEntityLoadFailed => 'No se pudieron cargar las entidades.';
  @override
  String get esphomeTypeControl => 'Control traducido';
  @override
  String get esphomeAdvanced => 'Configuración avanzada';
  @override
  String esphomeMacManual(String mac) =>
      'Se está usando $mac, introducida abajo.';
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
  late AppContainer container;
  late ValueNotifier<Locale> language;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ks.esphome.enabled': true,
      'ks.esphome.entities': true,
      'ks.esphome.excluded_entities': '["missing.id"]',
      'ks.esphome.real_mac': true,
      'ks.esphome.mac_override': '80:30:49:CD:D6:5F',
    });
    container = AppContainer();
    await container.settings.init();
    language = ValueNotifier(const Locale('es'));
  });
  tearDown(() async {
    language.dispose();
    await container.settings.dispose();
    await container.bus.dispose();
    await container.log.dispose();
  });
  Widget app(Widget child) => ValueListenableBuilder<Locale>(
    valueListenable: language,
    builder: (_, locale, _) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: const [_Delegate(), ...appLocalizationsDelegates],
      home: child,
    ),
  );
  Widget picker() => Scaffold(
    body: EspHomeExcludedEntitiesRow(
      settings: container.settings,
      commands: container.commands,
      onChanged: () {},
    ),
  );
  test(
    'translated ESPHome search preserves English aliases and destinations',
    () {
      final index = buildSettingsSearchIndex(
        [('ESPHome', 'ESPHome', 'Home Assistant')],
        esphomeTextFor: (text) => switch (text) {
          'Advanced settings' => 'Configuración avanzada',
          'Real or spoofed Wi-Fi MAC address' =>
            'Dirección MAC real o personalizada',
          _ => text,
        },
      );
      for (final query in [
        'configuración avanzada',
        'Advanced settings',
        'personalizada',
      ]) {
        final match = searchSettings(query, index, [
          'ESPHome',
        ]).singleWhere((entry) => entry.anchorId == 'sub:Advanced settings');
        expect(match.category, 'ESPHome');
        expect(match.title, 'Configuración avanzada');
        expect(match.isPage, isTrue);
      }
    },
  );
  testWidgets(
    'entity draft and raw names survive language changes during loading and selection',
    (tester) async {
      final pending = Completer<CommandResult>();
      var reads = 0;
      container.commands.register(
        Command(
          name: 'getEspHomeEntities',
          description: '',
          handler: (_) {
            reads++;
            return pending.future;
          },
        ),
      );
      await tester.pumpWidget(app(picker()));
      await tester.tap(find.text('Entidades excluidas'));
      await tester.pump();
      language.value = const Locale('en');
      await tester.pump();
      pending.complete(
        const CommandResult.ok([
          {
            'objectId': 'raw.entity',
            'name': 'Control',
            'categoryLabel': 'Control',
            'type': 'light',
          },
          {
            'objectId': 'raw.battery',
            'name': '<b>Battery name</b>',
            'categoryLabel': 'Diagnostics',
            'type': 'sensor',
          },
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Currently unavailable'), findsOneWidget);
      await tester.tap(find.text('Control'));
      await tester.enterText(find.byType(TextField), 'raw.entity');
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      expect(find.text('Control'), findsOneWidget);
      expect(find.text('Control traducido · light'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        true,
      );
      expect(find.text('raw.entity'), findsOneWidget);
      expect(reads, 1);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        defs.decodeEspHomeExcludedEntities(
          container.settings.get(defs.esphomeExcludedEntities),
        ),
        {'missing.id', 'raw.entity'},
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'failed picker follows language and cancel preserves exclusions',
    (tester) async {
      container.commands.register(
        Command(
          name: 'getEspHomeEntities',
          description: '',
          handler: (_) async => const CommandResult.fail('RAW failure'),
        ),
      );
      await tester.pumpWidget(app(picker()));
      await tester.tap(find.text('Entidades excluidas'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudieron cargar las entidades.'), findsOneWidget);
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load entities. Close the picker and try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        container.settings.get(defs.esphomeExcludedEntities),
        '["missing.id"]',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Advanced settings keeps manual identity and route when language changes',
    (tester) async {
      const deviceChannel = MethodChannel('kiosk_satellite/device_details');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        deviceChannel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          deviceChannel,
          null,
        ),
      );
      expect(container.settings.get(defs.esphomeRealMac), isTrue);
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          SubpageSettingsScreen(
            container: container,
            category: 'ESPHome',
            subpage: 'Advanced settings',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Configuración avanzada'), findsOneWidget);
      expect(
        find.text('Se está usando 80:30:49:CD:D6:5F, introducida abajo.'),
        findsOneWidget,
      );
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('Advanced settings'), findsOneWidget);
      expect(
        find.text('Reporting 80:30:49:CD:D6:5F, entered below.'),
        findsOneWidget,
      );
      expect(
        container.settings.get(defs.esphomeMacOverride),
        '80:30:49:CD:D6:5F',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
