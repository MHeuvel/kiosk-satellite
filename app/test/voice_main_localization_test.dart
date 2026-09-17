import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:kiosk_satellite/ui/settings_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Spanish extends UiStringsEn {
  @override
  String get voiceAssigned => 'Satélite asignado';
  @override
  String get voiceEngine => 'Motor';
  @override
  String get voiceStart => 'Iniciar';
  @override
  String get deviceRunning => 'En ejecución';
  @override
  String get deviceStopped => 'Detenido';
  @override
  String get cameraStreamsStop => 'Detener';
  @override
  String get voicePipeline1 => 'Canal de Assist 1';
  @override
  String get voiceVad => 'Detección del fin del habla';
  @override
  String get voiceVadDefault => 'Predeterminado';
  @override
  String get voiceVadRelaxed => 'Relajado';
  @override
  String get voiceAutoStart => 'Inicio automático';
  @override
  String get voiceMicMissing =>
      'Sin este permiso no se escucha la palabra de activación.';
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
  late Map<String, dynamic> snapshot;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'ks.wake_word.background': true});
    c = AppContainer();
    await c.settings.init();
    language = ValueNotifier(const Locale('es'));
    calls = [];
    snapshot = {
      'satellite': 'assist_satellite.original',
      'satellites': [
        {'entity_id': 'assist_satellite.original', 'name': 'Disabled'},
        {
          'entity_id': 'assist_satellite.other',
          'name': '<b>Original satellite</b>',
        },
      ],
      'version': '9.8.7-raw',
      'browser': {
        'engine': {'running': false, 'canStart': true},
        'config': {
          'auto_start': true,
          'debug': false,
          'disable_muted_microphone_warning': false,
        },
        'skins': <dynamic>[],
      },
      'entities': {
        'pipeline': {
          'entity_id': 'select.raw_pipeline',
          'available': true,
          'state': 'Default',
          'options': ['Default', '<b>Original pipeline</b>'],
        },
        'vad_sensitivity': {
          'entity_id': 'select.raw_vad',
          'available': true,
          'state': 'default',
          'options': ['default', 'relaxed', 'aggressive'],
        },
      },
    };
    for (final name in [
      'vsControls',
      'vsEngine',
      'haCallService',
      'vsSetSatellite',
      'vsSetBrowserSettings',
    ]) {
      c.commands.register(
        Command(
          name: name,
          description: '',
          handler: (params) async {
            calls.add((name, Map.of(params)));
            if (name == 'vsEngine') {
              snapshot['browser']['engine']['running'] =
                  params['action'] == 'start';
            }
            if (name == 'vsSetSatellite') {
              snapshot['satellite'] = params['entity_id'];
            }
            if (name == 'haCallService') {
              for (final entity in (snapshot['entities'] as Map).values) {
                if (entity['entity_id'] == params['entity_id']) {
                  entity['state'] = (params['data'] as Map)['option'];
                }
              }
            }
            return CommandResult.ok(
              name == 'vsControls' ? jsonDecode(jsonEncode(snapshot)) : null,
            );
          },
        ),
      );
    }
  });
  tearDown(() async {
    language.dispose();
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
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets(
    'live controls follow language without changing names or writes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(VsControlsSection(container: c)));
      await tester.pumpAndSettle();
      expect(find.text('Satélite asignado'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Predeterminado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final reads = calls.length;
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('Assigned satellite'), findsOneWidget);
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      expect(calls.length, reads);
      await tester.tap(find.text('Predeterminado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Relajado').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(calls.lastWhere((c) => c.$1 == 'haCallService').$2, {
        'domain': 'select',
        'service': 'select_option',
        'entity_id': 'select.raw_vad',
        'data': {'option': 'relaxed'},
      });
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('<b>Original pipeline</b>').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(calls.lastWhere((c) => c.$1 == 'haCallService').$2, {
        'domain': 'select',
        'service': 'select_option',
        'entity_id': 'select.raw_pipeline',
        'data': {'option': '<b>Original pipeline</b>'},
      });
      await tester.tap(find.text('Iniciar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(calls.lastWhere((c) => c.$1 == 'vsEngine').$2, {
        'action': 'start',
      });
      expect(find.text('En ejecución'), findsOneWidget);
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Satélite asignado'), findsOneWidget);
      expect(find.text('<b>Original pipeline</b>'), findsOneWidget);
      expect(find.text('Relajado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'translated search retains English aliases and Voice Satellite destinations',
    () {
      final entries = buildSettingsSearchIndex(
        [('Voice Satellite', 'Voice Satellite', 'Wake word')],
        voiceTextFor: (text) =>
            text == 'Assigned satellite' ? 'Satélite asignado' : text,
      );
      for (final query in ['Satélite asignado', 'Assigned satellite']) {
        final match = searchSettings(query, entries, ['Voice Satellite']).first;
        expect(match.title, 'Satélite asignado');
        expect(match.category, 'Voice Satellite');
        expect(match.anchorId, 'x:assigned_satellite');
      }
    },
  );
  testWidgets('permission guidance follows language at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(SystemPermissionsTile(container: c)));
    await tester.pumpAndSettle();
    expect(
      find.text('Sin este permiso no se escucha la palabra de activación.'),
      findsOneWidget,
    );
    language.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(
      find.text('Without this nothing is listening for the wake word.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
