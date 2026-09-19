import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Chimes page and all five selectors use shipped catalogs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppContainer();
    await c.settings.init();
    final calls = <String>[];
    for (final name in ['previewVoiceChime', 'stopSound']) {
      c.commands.register(
        Command(
          name: name,
          description: '',
          handler: (p) async {
            calls.add('$name:${p['kind'] ?? p['id']}');
            return const CommandResult.ok();
          },
        ),
      );
    }
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final language in ['en', 'es']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: UiStrings.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: SubpageSettingsScreen(
            container: c,
            category: 'Voice Satellite',
            subpage: 'Chimes',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'en' ? 'Chimes' : 'Sonidos'),
        findsOneWidget,
      );
      for (final title
          in language == 'en'
              ? [
                  'Wake sound',
                  'Done sound',
                  'Error sound',
                  'Timer sound',
                  'Announcement sound',
                ]
              : [
                  'Sonido de activación',
                  'Sonido de finalización',
                  'Sonido de error',
                  'Sonido del temporizador',
                  'Sonido de anuncio',
                ]) {
        expect(find.text(title), findsOneWidget);
      }
      final preview = find.text(
        language == 'en' ? 'Preview on kiosk' : 'Reproducir en el kiosco',
      );
      expect(preview, findsNWidgets(5));
      await tester.tap(preview.first);
      await tester.pump();
      expect(calls.last, 'previewVoiceChime:wake');
      for (final setting in voiceChimeSettings.values) {
        expect(setting.titleMessageId, isNotNull);
        expect(setting.descriptionMessageId, isNotNull);
        expect(setting.perDevice, isTrue);
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await c.settings.dispose();
    await c.bus.dispose();
    await c.log.dispose();
  });
}
