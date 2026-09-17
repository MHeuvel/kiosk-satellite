import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/managers/js_api/js_api_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/ui/kiosk_screen.dart';
import 'package:kiosk_satellite/ui/kiosk_drawer.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Messages extends UiStringsEn {
  @override
  String get kioskPinTitle => 'TEST PIN prompt';
  @override
  String get kioskWrongPin => 'TEST wrong PIN';
  @override
  String get kioskUnlock => 'TEST unlock';
  @override
  String get kioskWaiting => 'TEST waiting for Android';
  @override
  String get kioskHeld => 'TEST home role held';
  @override
  String get kioskRecovered => 'TEST recovered previous launcher';
  @override
  String get kioskFireOs => 'TEST unsupported Fire OS';
  @override
  String get kioskSetDefault => 'TEST acquire home';
  @override
  String get kioskOpenHomeSettings => 'TEST home settings';
}

class _Delegate extends LocalizationsDelegate<UiStrings> {
  const _Delegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<UiStrings> load(Locale locale) => SynchronousFuture(
    locale.languageCode == 'es' ? _Messages() : UiStringsEn(),
  );
  @override
  bool shouldReload(_Delegate old) => false;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late AppContainer c;
  late ValueNotifier<Locale> language;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ks.kiosk.enabled': true,
      'ks.kiosk.pin': '0078',
    });
    c = AppContainer();
    await c.settings.init();
    language = ValueNotifier(const Locale('es'));
  });
  tearDown(() async {
    language.dispose();
    await c.settings.dispose();
    await c.bus.dispose();
    await c.log.dispose();
  });
  Widget localized(Widget child) => ValueListenableBuilder<Locale>(
    valueListenable: language,
    builder: (context, locale, _) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: const [_Delegate(), ...appLocalizationsDelegates],
      navigatorObservers: [kioskRouteObserver],
      home: child,
    ),
  );
  testWidgets(
    'PIN stays required across language changes and preserves leading zeros',
    (tester) async {
      c.device.appVersion = 'test';
      c.jsApi = JsApiManager(c.bus, c.commands, c.log, 'test');
      final attached = Completer<bool>();
      const channel = MethodChannel('kiosk_satellite/background');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'isActivityAttached' ? attached.future : null,
      );
      const lock = MethodChannel('kiosk_satellite/kiosk_lock');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        lock,
        (_) async => null,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        attached.complete(true);
        await tester.pumpAndSettle();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        binding.defaultBinaryMessenger.setMockMethodCallHandler(lock, null);
      });
      await tester.pumpWidget(localized(KioskScreen(container: c)));
      c.bus.publish(const KioskExitGesture());
      await tester.pumpAndSettle();
      expect(find.text('TEST PIN prompt'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '78');
      await tester.tap(find.text('TEST unlock'));
      await tester.pumpAndSettle();
      expect(find.text('TEST wrong PIN'), findsOneWidget);
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('Wrong PIN'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '78',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), '0078');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester.widget<KioskDrawer>(find.byType(KioskDrawer)).restricted,
        isFalse,
      );
      expect(c.settings.get(defs.kioskPin), '0078');
      expect(c.settings.get(defs.kioskEnabled), isTrue);
    },
  );
  testWidgets(
    'home status follows role updates and language without acquiring the role',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var status = <String, Object?>{
        'supported': true,
        'enabled': true,
        'held': false,
        'roleDenials': 0,
      };
      var acquired = 0;
      c.commands.register(
        Command(
          name: 'homeLauncherStatus',
          description: 'Fixture',
          handler: (_) async => CommandResult.ok(status),
        ),
      );
      c.commands.register(
        Command(
          name: 'acquireHomeRole',
          description: 'Fixture',
          handler: (_) async {
            acquired++;
            return const CommandResult.ok();
          },
        ),
      );
      await tester.pumpWidget(
        localized(
          CategorySettingsScreen(
            container: c,
            title: 'Home Launcher',
            category: 'Home',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TEST waiting for Android'), findsOneWidget);
      await tester.tap(find.text('TEST acquire home'));
      await tester.pumpAndSettle();
      expect(acquired, 1);
      status = {...status, 'roleDenials': 2};
      c.bus.publish(const HomeRoleChanged(held: false));
      await tester.pumpAndSettle();
      expect(find.text('TEST home settings'), findsOneWidget);
      status = {...status, 'held': true};
      c.bus.publish(const HomeRoleChanged(held: true));
      await tester.pumpAndSettle();
      expect(find.text('TEST home role held'), findsOneWidget);
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Kiosk Satellite is the home screen. The kiosk starts at boot and every home press returns to it.',
        ),
        findsOneWidget,
      );
      expect(acquired, 1);
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      status = {
        ...status,
        'enabled': false,
        'held': false,
        'storedFuseReason': 'original-reason',
      };
      c.bus.publish(const HomeRoleChanged(held: false));
      await tester.pumpAndSettle();
      expect(find.text('TEST recovered previous launcher'), findsOneWidget);
      status = {'supported': false, 'reason': 'fireos'};
      c.bus.publish(const HomeRoleChanged(held: false));
      await tester.pumpAndSettle();
      expect(find.text('TEST unsupported Fire OS'), findsOneWidget);
      expect(acquired, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
