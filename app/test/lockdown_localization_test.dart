import 'package:kiosk_satellite/ui/settings_search.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/managers/kiosk/kiosk_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:kiosk_satellite/ui/lockdown_shield.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Spanish extends UiStringsEn {
  @override
  String get lockdownScreenLocked => 'La pantalla está bloqueada';
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
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'translated Lockdown search guidance retains its native permission route',
    () {
      final entries = buildSettingsSearchIndex(
        [('Kiosk', 'Kiosk Mode', 'Exit gesture')],
        kioskTextFor: (text) => text == 'Lockdown Mode'
            ? 'Modo de bloqueo'
            : text.startsWith('Remote-only touch shield.')
            ? 'Configura el bloqueo desde la administración remota.'
            : text,
      );
      final result = entries.singleWhere(
        (entry) =>
            entry.title == 'Modo de bloqueo' &&
            entry.anchorId == 'x:kiosk_permissions',
      );
      expect(result.category, 'Kiosk');
      expect(result.anchorId, 'x:kiosk_permissions');
      expect(
        result.description,
        'Configura el bloqueo desde la administración remota.',
      );
      expect(result.englishAlias, contains('Remote-only touch shield.'));
    },
  );
  testWidgets(
    'shield keeps swallowing touches and its notice follows language',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final language = ValueNotifier(const Locale('es'));
      addTearDown(language.dispose);
      var touches = 0;
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: language,
          builder: (_, locale, _) => MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              _Delegate(),
              ...appLocalizationsDelegates,
            ],
            home: Scaffold(
              body: Stack(
                children: [
                  Center(
                    child: ElevatedButton(
                      onPressed: () => touches++,
                      child: const Text('Underlying action'),
                    ),
                  ),
                  const LockdownShield(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(tester.getCenter(find.text('Underlying action')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('La pantalla está bloqueada'), findsOneWidget);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      language.value = const Locale('en');
      await tester.pump();
      expect(find.text('Screen is locked'), findsOneWidget);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      await tester.tapAt(tester.getCenter(find.text('Underlying action')));
      expect(touches, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'language updates native text without reapplying protections or gestures',
    () async {
      SharedPreferences.setMockInitialValues({
        'ks.ui.language': 'en',
        'ks.lockdown.enabled': true,
        'ks.lockdown.exit_gesture': 'taps7hold',
        'ks.kiosk.pin': '0078',
      });
      final bus = EventBus();
      final log = Logger();
      final commands = CommandRegistry(log);
      final settings = SettingsManager(bus, commands, log);
      await settings.init();
      const channel = MethodChannel('kiosk_satellite/kiosk_lock');
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'hasOverlayPermission' ? true : null;
      });
      final kiosk = KioskManager(bus, commands, log, settings)
        ..pushFlags = true;
      addTearDown(() async {
        await kiosk.dispose();
        await settings.dispose();
        await bus.dispose();
        await log.dispose();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });
      await kiosk.init();
      await commands.execute('resumeKioskAfterInstall', const {});
      final before = Map<String, dynamic>.from(
        calls.lastWhere((c) => c.method == 'apply').arguments as Map,
      );
      expect(before['lockShield'], true);
      expect(
        before.remove('lockShieldText'),
        UiStringsEn().lockdownScreenLocked,
      );
      calls.clear();
      await settings.set(defs.uiLanguage, 'es');
      await Future<void>.delayed(Duration.zero);
      expect(calls.map((c) => c.method), ['lockShieldText']);
      expect(calls.single.arguments, {
        'text': lookupUiStrings(const Locale('es')).lockdownScreenLocked,
      });
      expect(settings.get(defs.lockdownEnabled), true);
      expect(settings.get(defs.lockdownExitGesture), 'taps7hold');
      expect(settings.get(defs.kioskPin), '0078');
      await commands.execute('resumeKioskAfterInstall', const {});
      final after = Map<String, dynamic>.from(
        calls.lastWhere((c) => c.method == 'apply').arguments as Map,
      );
      expect(
        after.remove('lockShieldText'),
        lookupUiStrings(const Locale('es')).lockdownScreenLocked,
      );
      expect(after, before);
      calls.clear();
      await kiosk.dispose();
      await settings.set(defs.uiLanguage, 'en');
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
    },
  );
}
