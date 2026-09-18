import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/ui/setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Spanish extends UiStringsEn {
  @override
  String get settingUiLanguageTitle => 'Idioma';
  @override
  String get setupWelcome => 'Bienvenido';
  @override
  String get setupPermissionLead => 'Android solicitará estos permisos.';
  @override
  String get setupNotificationListening => 'Notificación mientras escucha';
  @override
  String get setupOverlayBoot => 'Volver a abrir y arrancar con el dispositivo';
  @override
  String get setupOverlayCrash => 'Volver a abrir después de un fallo';

  @override
  String get setupVoiceSkipped => 'No instalado, omitido';
  @override
  String get setupChooseDashboard => 'Elige un panel de control';
  @override
  String get haChangeView => 'Cambiar vista';
  @override
  String get haChooseView => 'Elige una vista';
  @override
  String get setupVoiceDetected => 'Voice Satellite detectado';
  @override
  String get setupApplyRecommended => 'Aplicar todos los ajustes recomendados';
  @override
  String get setupNativeWakeWord =>
      'Detección nativa de palabras de activación';
  @override
  String get setupPullRefresh => 'Deslizar hacia abajo para actualizar';
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
  var batteryUnrestricted = true;
  var overlay = true;
  var overlayRequestable = true;
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

  testWidgets(
    'Welcome language persists immediately and retains unsaved fields',
    (tester) async {
      await boot();
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final locale = ValueNotifier(const Locale('en'));
      final sub = container.bus.on<SettingChanged>().listen((event) {
        if (event.key == defs.uiLanguage.key) {
          locale.value = appLocaleForLanguage(event.value as String);
        }
      });
      addTearDown(sub.cancel);
      addTearDown(locale.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (_, value, _) => MaterialApp(
            locale: value,
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              _Delegate(),
              ...appLocalizationsDelegates,
            ],
            home: SetupScreen(container: container),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'My unsaved kiosk');
      await tester.enterText(fields.at(1), 'Unsaved-password');
      final picker = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español').last);
      await tester.pumpAndSettle();
      expect(find.text('Idioma'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('Bienvenido'), findsOneWidget);
      expect(container.settings.get(defs.uiLanguage), 'es');
      expect(
        tester.widget<TextField>(fields.at(0)).controller!.text,
        'My unsaved kiosk',
      );
      expect(
        tester.widget<TextField>(fields.at(1)).controller!.text,
        'Unsaved-password',
      );
      expect(container.settings.get(defs.startUrl), isEmpty);
      expect(container.settings.get(defs.remotePassword), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final integrationPresent in [true, false]) {
    testWidgets(
      'setup selections preserve values with integration: $integrationPresent',
      (tester) async {
        await boot();
        final oldOverrides = HttpOverrides.current;
        HttpOverrides.global = null;
        addTearDown(() => HttpOverrides.global = oldOverrides);
        final calls = <Map<String, dynamic>>[];
        final server = await tester.runAsync(
          () => HttpServer.bind('127.0.0.1', 0),
        );
        final sockets = <WebSocket>[];
        server!.listen((request) async {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            final socket = await WebSocketTransformer.upgrade(request);
            sockets.add(socket);
            socket.add(jsonEncode({'type': 'auth_required'}));
            socket.listen((raw) {
              final msg = jsonDecode(raw as String) as Map<String, dynamic>;
              if (msg['type'] == 'auth') {
                socket.add(jsonEncode({'type': 'auth_ok'}));
                return;
              }
              calls.add(msg);
              final result = switch (msg['type']) {
                'lovelace/dashboards/list' => [
                  {
                    'url_path': 'raw-dashboard',
                    'title': 'Original dashboard',
                    'mode': 'storage',
                  },
                ],
                'lovelace/config' => {
                  'views': [
                    {'title': 'Original first view', 'path': 'first'},
                    {'title': 'Original second view', 'path': 'second'},
                  ],
                },
                'config/entity_registry/list' => [
                  {
                    'platform': 'voice_satellite',
                    'entity_id': 'assist_satellite.first',
                    'name': 'Original first satellite',
                  },
                  {
                    'platform': 'voice_satellite',
                    'entity_id': 'assist_satellite.second',
                    'name': 'Original second satellite',
                  },
                ],
                _ => <Object?>[],
              };
              socket.add(
                jsonEncode({
                  'id': msg['id'],
                  'type': 'result',
                  'success': true,
                  'result': result,
                }),
              );
            });
          } else {
            request.response.statusCode =
                request.method == 'HEAD' && !integrationPresent ? 404 : 200;
            request.response.write('{}');
            await request.response.close();
          }
        });
        addTearDown(
          () => tester.runAsync(() async {
            for (final socket in sockets) {
              unawaited(socket.close());
            }
            await server.close(force: true);
          }),
        );
        final language = ValueNotifier(const Locale('es'));
        addTearDown(language.dispose);
        tester.view.physicalSize = const Size(1000, 1600);
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
        Future<void> settle() async {
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 30));
          }
        }

        await settle();
        await tester.tap(find.byType(SwitchListTile));
        await tester.tap(find.text('Next'));
        await settle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'http://127.0.0.1:${server.port}');
        await tester.enterText(fields.at(1), 'original-token');
        await tester.tap(find.text('Validate & continue'));
        await settle();
        expect(find.text('Elige un panel de control'), findsOneWidget);
        await tester.tap(find.text('Original dashboard'));
        await settle();
        await tester.tap(find.text('Cambiar vista'));
        await settle();
        expect(find.text('Elige una vista'), findsOneWidget);
        language.value = const Locale('en');
        await settle();
        expect(find.text('Choose a view'), findsOneWidget);
        language.value = const Locale('es');
        await settle();
        await tester.tap(find.text('Original second view'));
        await settle();
        expect(find.text('raw-dashboard/second'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await settle();
        if (!integrationPresent) {
          expect(find.text('No instalado, omitido'), findsOneWidget);
          expect(
            find.text('Android solicitará estos permisos.'),
            findsOneWidget,
          );
          expect(
            find.text('Volver a abrir después de un fallo'),
            findsOneWidget,
          );
          expect(find.text('Voice Satellite detectado'), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await settle();
          return;
        }
        expect(find.text('Voice Satellite detectado'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await settle();
        expect(find.text('Notificación mientras escucha'), findsOneWidget);
        expect(
          find.text('Volver a abrir y arrancar con el dispositivo'),
          findsOneWidget,
        );
        language.value = const Locale('en');
        await settle();
        language.value = const Locale('es');
        await settle();
        expect(find.text('Notificación mientras escucha'), findsOneWidget);
        await tester.tap(find.text('Back'));
        await settle();
        await tester.tap(find.text('Original second satellite'));
        final master = find.widgetWithText(
          SwitchListTile,
          'Aplicar todos los ajustes recomendados',
        );
        await tester.ensureVisible(master);
        await tester.tap(master);
        await settle();
        final pull = find.widgetWithText(
          SwitchListTile,
          'Deslizar hacia abajo para actualizar',
        );
        await tester.ensureVisible(pull);
        await tester.tap(pull);
        await settle();
        expect(tester.widget<SwitchListTile>(pull).value, isTrue);
        final reads = calls.length;
        language.value = const Locale('en');
        await settle();
        language.value = const Locale('es');
        await settle();
        expect(tester.widget<SwitchListTile>(pull).value, isTrue);
        expect(tester.widget<SwitchListTile>(master).value, isFalse);
        expect(
          tester
              .widget<SwitchListTile>(
                find.widgetWithText(
                  SwitchListTile,
                  'Detección nativa de palabras de activación',
                ),
              )
              .onChanged,
          isNull,
        );
        expect(calls.length, reads);
        final satellite = find.widgetWithText(
          ListTile,
          'Original second satellite',
        );
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: satellite, matching: find.byType(Icon)),
              )
              .icon,
          Icons.radio_button_checked,
        );
        tester.view.physicalSize = const Size(390, 1000);
        await settle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await settle();
      },
    );
  }
}
