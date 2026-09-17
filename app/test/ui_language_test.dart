import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/messages.dart';
import 'package:kiosk_satellite/main.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart';
import 'package:kiosk_satellite/ui/kit.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'language is first in User Interface and only offers bundled catalogs',
    () {
      final group = allSettings
          .where(
            (def) =>
                def.category == 'Device' && def.section == 'User Interface',
          )
          .toList();
      expect(group.first, uiLanguage);
      expect(uiLanguage.perDevice, isTrue);
      expect(uiLanguage.options, [
        ...UiStrings.supportedLocales.map((locale) => locale.toLanguageTag()),
      ]);
      expect(uiLanguage.optionLabels!['es'], 'Español');
      expect(appLocaleForLanguage('es'), const Locale('es'));
      expect(uiLanguage.defaultValue, 'en');
      expect(appLocaleForLanguage('system'), const Locale('en'));
      expect(appLocaleForLanguage('not-installed'), const Locale('en'));
    },
  );

  for (final saved in ['system', 'es']) {
    test(
      'saved language $saved migrates without overwriting an explicit choice',
      () async {
        SharedPreferences.setMockInitialValues({'ks.ui.language': saved});
        final container = AppContainer();
        try {
          await container.settings.init();
          final expected = saved == 'system' ? 'en' : saved;
          expect(container.settings.get(uiLanguage), expected);
          expect(
            (await SharedPreferences.getInstance()).getString('ks.ui.language'),
            expected,
          );
        } finally {
          await container.settings.dispose();
          await container.bus.dispose();
          await container.log.dispose();
        }
      },
    );
  }

  testWidgets(
    'selector applies live on an open route and persists remote writes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = AppContainer();
      await container.settings.init();
      tester.platformDispatcher.localesTestValue = [const Locale('ja', 'JP')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const background = MethodChannel('kiosk_satellite/background');
      messenger.setMockMethodCallHandler(background, (call) async {
        if (call.method == 'serviceStatus') {
          return <String, Object?>{
            'running': true,
            'foreground': true,
            'types': ['specialUse'],
            'uptimeMs': 5000,
          };
        }
        return true;
      });
      const info = MethodChannel('dev.fluttercommunity.plus/device_info');
      messenger.setMockMethodCallHandler(
        info,
        (call) async => throw PlatformException(code: 'test'),
      );
      addTearDown(() async {
        messenger.setMockMethodCallHandler(background, null);
        messenger.setMockMethodCallHandler(info, null);
        await container.settings.dispose();
        await container.bus.dispose();
        await container.log.dispose();
      });
      await tester.pumpWidget(KioskSatelliteApp(container: container));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      late BuildContext routeContext;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (context) {
            routeContext = context;
            return Scaffold(
              body: Column(
                children: [
                  Text(l10n(context).commonNext),
                  SettingTile(
                    container: container,
                    def: uiLanguage,
                    onChanged: () {},
                  ),
                ],
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(app.locale, const Locale('en'));
      expect(Localizations.localeOf(routeContext), const Locale('en'));
      expect(find.text('Next'), findsOneWidget);
      final row = tester.widget<DropdownRow<String>>(
        find.byType(DropdownRow<String>),
      );
      row.onChanged('es');
      await tester.pumpAndSettle();
      expect(find.text('Siguiente'), findsOneWidget);
      expect(Localizations.localeOf(routeContext), const Locale('es'));
      expect(container.settings.get(uiLanguage), 'es');
      expect(
        (await SharedPreferences.getInstance()).getString('ks.ui.language'),
        'es',
      );
      expect(
        await container.settings.setFromJson(
          'ui.language',
          'en',
          source: 'remote',
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsOneWidget);
      expect(
        await container.settings.setFromJson('ui.language', 'unavailable'),
        isFalse,
      );
      expect(container.settings.get(uiLanguage), 'en');
      expect(
        await container.settings.setFromJson('ui.language', 'system'),
        isFalse,
      );
      await tester.pumpAndSettle();
      expect(Localizations.localeOf(routeContext), const Locale('en'));
      tester.platformDispatcher.localesTestValue = [const Locale('es', 'EC')];
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsOneWidget);
      expect(Localizations.localeOf(routeContext), const Locale('en'));
      final definition = container.settings.describe().firstWhere(
        (def) => def['key'] == 'ui.language',
      );
      expect(definition['options'], ['en', 'es']);
      expect((definition['optionLabels'] as Map)['es'], 'Español');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
