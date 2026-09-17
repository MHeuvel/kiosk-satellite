import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/l10n/messages.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/ui/intercom_settings.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Spanish extends UiStringsEn {
  @override
  String get esphomeBluetooth => 'Proxy Bluetooth';
  @override
  String get esphomeIdentityUnknown => 'Dispositivo desconocido';
  @override
  String esphomeIdentityVendor(String vendor) => 'Dispositivo $vendor';
  @override
  String get esphomeRotating => '(dirección variable)';
  @override
  String get esphomeNotificationTest => 'Notificación de prueba';
  @override
  String get esphomeNotificationBody => 'Así se ve y suena una notificación.';
  @override
  String get esphomeTtsFirst => 'Primero disponible';
  @override
  String get settingAnnouncementsTtsEngineTitle => 'Motor de texto a voz';
  @override
  String get esphomeCoordinates => 'Últimas coordenadas';
  @override
  String get esphomeLocationWaiting => 'Esperando la primera posición.';
  @override
  String esphomeLocationError(String error) => 'GPS no disponible: $error';
  @override
  String esphomeSlots(String count) => 'Hasta $count dispositivos.';
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
  late AppContainer c;
  late ValueNotifier<Locale> language;
  late List<(String, Map<String, Object?>)> calls;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ks.esphome.enabled': true,
      'ks.esphome.entities': true,
      'ks.esphome.node_name': 'original-node',
      'ks.btproxy.enabled': true,
      'ks.btproxy.connections': true,
      'ks.location.enabled': true,
    });
    c = AppContainer();
    await c.settings.init();
    language = ValueNotifier(const Locale('es'));
    calls = [];
    for (final name in [
      'bluetoothAdapterOn',
      'esphomeStatus',
      'btProxyNearby',
      'announcementTtsEngines',
      'showNotification',
    ]) {
      c.commands.register(
        Command(
          name: name,
          description: '',
          handler: (params) async {
            calls.add((name, Map.of(params)));
            return CommandResult.ok(switch (name) {
              'bluetoothAdapterOn' => {'on': true},
              'esphomeStatus' => {'connectionSlots': 3},
              'btProxyNearby' => {
                'devices': [
                  {
                    'identity': 'Unknown device',
                    'name': 'Unknown device',
                    'mac': 'AA:BB:CC:DD:EE:01',
                    'rssi': -50,
                    'last_seen': DateTime.now().toIso8601String(),
                  },
                  {
                    'identity': 'Unknown device',
                    'rotating': true,
                    'mac': 'AA:BB:CC:DD:EE:02',
                    'rssi': -80,
                    'last_seen': DateTime.now().toIso8601String(),
                  },
                ],
              },
              'announcementTtsEngines' => [
                {'entity_id': 'tts.original', 'name': 'First available'},
                {'entity_id': 'tts.raw', 'name': '<b>Original engine</b>'},
              ],
              _ => null,
            });
          },
        ),
      );
    }
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('kiosk_satellite/bluetooth_proxy'),
      (_) async => {'supported': true},
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('kiosk_satellite/location'),
      (_) async => {'supported': true},
    );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('kiosk_satellite/bluetooth_proxy'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('kiosk_satellite/location'),
          null,
        );
    language.dispose();
    await c.location.dispose();
    await c.settings.dispose();
    await c.bus.dispose();
    await c.log.dispose();
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
  Widget page(String subpage) => SubpageSettingsScreen(
    container: c,
    category: 'ESPHome',
    subpage: subpage,
  );

  testWidgets(
    'Bluetooth keeps actual names and addresses while class labels follow locale',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(page('Bluetooth Proxy')));
      await tester.pumpAndSettle();
      expect(find.text('Proxy Bluetooth'), findsOneWidget);
      expect(find.text('Unknown device', findRichText: true), findsOneWidget);
      expect(
        find.text(
          'Dispositivo desconocido  (dirección variable)',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Hasta 3 dispositivos.'), findsOneWidget);
      final before = calls.where((call) => call.$1 == 'btProxyNearby').length;
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(
        find.text('Unknown device  (rotating address)', findRichText: true),
        findsOneWidget,
      );
      expect(calls.where((call) => call.$1 == 'btProxyNearby').length, before);
      expect(c.settings.get(defs.btproxyEnabled), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'test notification uses translated sample text and original command fields',
    (tester) async {
      await tester.pumpWidget(app(page('Notifications')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('esphome.original_node_notification'),
        findsOneWidget,
      );
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      final sent = calls.lastWhere((call) => call.$1 == 'showNotification').$2;
      expect(sent, {
        'title': 'Notificación de prueba',
        'message': 'Así se ve y suena una notificación.',
        'type': 'info',
        'icon': 'mdi:bell-ring',
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'open announcement engine picker follows locale without translating engine names',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(Scaffold(body: AnnouncementTtsEngineRow(container: c))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Primero disponible'));
      await tester.pumpAndSettle();
      expect(find.text('First available'), findsOneWidget);
      final reads = calls
          .where((call) => call.$1 == 'announcementTtsEngines')
          .length;
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Text to speech engine'),
        ),
        findsOneWidget,
      );
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.$1 == 'announcementTtsEngines').length,
        reads,
      );
      await tester.tap(find.text('<b>Original engine</b>'));
      await tester.pumpAndSettle();
      expect(c.settings.get(defs.announcementsTtsEngine), 'tts.raw');
      expect(find.text('<b>Original engine</b>'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'GPS status resolves in the current language without altering its error detail',
    (tester) async {
      await tester.pumpWidget(app(page('GPS Sensor')));
      await tester.pumpAndSettle();
      expect(find.text('Últimas coordenadas'), findsOneWidget);
      expect(find.text('Esperando la primera posición.'), findsOneWidget);
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('Last coordinates'), findsOneWidget);
      expect(c.settings.get(defs.locationEnabled), isTrue);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) =>
                  Text(esphomeError(context, 'GPS unavailable: <b>RAW</b>')),
            ),
          ),
        ),
      );
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      expect(find.text('GPS no disponible: <b>RAW</b>'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
