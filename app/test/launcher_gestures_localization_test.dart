import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/l10n/gesture_messages.dart';
import 'package:kiosk_satellite/managers/gestures/gesture_mappings.dart';
import 'package:kiosk_satellite/managers/motion/motion_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/ui/gesture_settings.dart';
import 'package:kiosk_satellite/ui/hand_gesture_tester.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Messages extends UiStringsEn {
  @override
  String get gestureEdit => 'TEST edit gesture';
  @override
  String get gestureUrl => 'TEST open URL';
  @override
  String get gestureUrlError => 'TEST invalid URL';
  @override
  String get gestureNoHand => 'TEST no hand';
  @override
  String get gestureTester => 'TEST hand tester';
  @override
  String gestureOpen(String value) => 'TEST open $value';
  @override
  String gestureDescribeCornerHold(String corner, String seconds) =>
      'TEST hold $corner $seconds';
  @override
  String gestureDescribeOneFinger(String count) => 'TEST show $count finger';
  @override
  String get gestureCameraClose => 'TEST close camera';
  @override
  String get launcherNoneHelp => 'TEST select apps';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppContainer c;
  late ValueNotifier<Locale> language;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'ks.launcher.enabled': true});
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
      home: child,
    ),
  );
  testWidgets(
    'gesture editor keeps URL input and validation across language changes',
    (tester) async {
      tester.view.physicalSize = const Size(650, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await c.settings.setFromJson(
        defs.gestureMappings.key,
        jsonEncode([
          {
            'id': 'original-id',
            'trigger': {'type': 'corner_hold', 'corner': 'br', 'holdMs': 1750},
            'action': {'type': 'url', 'url': 'https://example.com/Original'},
          },
        ]),
      );
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: SingleChildScrollView(
              child: GestureSettingsPanel(container: c),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST open https://example.com/Original'));
      await tester.pumpAndSettle();
      expect(find.text('TEST edit gesture'), findsOneWidget);
      await tester.tap(
        find.text('TEST open https://example.com/Original').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST open URL'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'invalid');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('TEST invalid URL'), findsOneWidget);
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('Enter a full http(s) URL.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'invalid',
      );
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/KeepCase?Value=ABC',
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = decodeGestureMappings(
        c.settings.get(defs.gestureMappings),
      ).single;
      expect(saved.id, 'original-id');
      expect(saved.trigger, {
        'type': 'corner_hold',
        'corner': 'br',
        'holdMs': 1750,
      });
      expect(saved.action, {
        'type': 'url',
        'url': 'https://example.com/KeepCase?Value=ABC',
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'app picker preserves Android package names and labels across locales',
    (tester) async {
      tester.view.physicalSize = const Size(650, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      c.commands.register(
        Command(
          name: 'installedApps',
          description: 'test fixture',
          handler: (_) async => CommandResult.ok([
            {'package': 'com.example.Raw', 'label': 'Original App'},
          ]),
        ),
      );
      await tester.pumpWidget(
        localized(
          CategorySettingsScreen(
            container: c,
            category: 'Launcher',
            title: 'App Launcher',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST select apps'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Original App'));
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(find.text('com.example.Raw'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(jsonDecode(c.settings.get(defs.launcherApps)), [
        {'package': 'com.example.Raw', 'label': 'Original App'},
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'hand tester follows locale without replacing readings or mappings',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final reading = ValueNotifier<HandTestReading?>(null);
      addTearDown(reading.dispose);
      final mappings = decodeGestureMappings(
        '[{"id":"hand","trigger":{"type":"fingers","fingers":1},"action":{"type":"camera_view","mode":"hide"}}]',
      );
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: HandGestureTesterDialog(reading: reading, mappings: mappings),
          ),
        ),
      );
      expect(find.text('TEST no hand'), findsOneWidget);
      reading.value = const HandTestReading(
        hands: 1,
        fingers: 1,
        fingersUp: [false, true, false, false, false],
      );
      await tester.pumpAndSettle();
      expect(find.text('TEST show 1 finger'), findsOneWidget);
      expect(find.text('Triggers: TEST close camera'), findsOneWidget);
      final held = reading.value;
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('Show 1 finger'), findsOneWidget);
      expect(reading.value, same(held));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'structured descriptions preserve provider text and do not mutate action data',
    (tester) async {
      final action = <String, Object?>{
        'type': 'plugin_action',
        'pluginName': 'Open',
        'title': 'My CASE',
        'pluginId': 'p',
        'command': 'Raw',
      };
      final before = jsonEncode(action);
      await tester.pumpWidget(
        localized(
          Builder(
            builder: (context) {
              expect(localizedGestureAction(context, action), 'Open: My CASE');
              expect(
                localizedGestureOutcome(context, action, ok: true),
                'Ran Open: My CASE',
              );
              expect(
                localizedGestureAction(context, {
                  'type': 'open_uri',
                  'uri': 'myapp://Raw/Value',
                }),
                'TEST open myapp://Raw/Value',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(jsonEncode(action), before);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('translated gesture and hand dialogs fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final strings = lookupUiStrings(const Locale('es'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: GestureSettingsPanel(container: c),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.gestureAdd));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.gestureFingerHold).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    final reading = ValueNotifier<HandTestReading?>(null);
    addTearDown(reading.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(
          body: HandGestureTesterDialog(reading: reading, mappings: const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
