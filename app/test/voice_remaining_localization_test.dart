import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:kiosk_satellite/ui/wake_word_tester.dart';
import 'package:kiosk_satellite/managers/wake_word/wake_word_manager.dart';
import 'package:kiosk_satellite/managers/wake_word/engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class _Spanish extends UiStringsEn {
  @override
  String get voiceWakeEngine => 'Motor de palabras de activación';
  @override
  String get voiceWake1 => 'Palabra de activación 1';
  @override
  String get voiceVerySensitive => 'Muy sensible';
  @override
  String get voiceSkin => 'Estilo';
  @override
  String get voiceTheme => 'Modo del tema';
  @override
  String get deviceThemeDark => 'Oscuro';
  @override
  String get voiceTester => 'Prueba de palabras de activación';
  @override
  String get voiceHits => 'Detecciones';
  @override
  String get voiceLogHit => 'DETECCIÓN';
  @override
  String get voiceLogNear => 'casi';
  @override
  String get voiceLogScore => 'puntuación';
  @override
  String voiceStopWordNamed(String word) => '$word (palabra de detención)';
  @override
  String voiceCacheCleared(String count) =>
      'Se borraron $count archivos. Descargando de nuevo.';

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
        'config': <String, dynamic>{
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
    snapshot['browser']['config'].addAll({
      'skin': 'default',
      'theme_mode': 'auto',
      'reactive_bar': true,
      'reactive_bar_update_interval_ms': 33,
      'text_scale': 100,
    });
    snapshot['browser']['skins'] = [
      {'value': 'default', 'label': 'Default'},
      {'value': 'raw', 'label': '<b>Original skin</b>'},
    ];
    snapshot['entities'].addAll({
      'wake_word_detection': {
        'entity_id': 'select.engine',
        'available': true,
        'state': 'On Device (vsWakeWord)',
        'options': ['On Device (vsWakeWord)', 'Home Assistant', 'Disabled'],
      },
      'wake_word_model': {
        'entity_id': 'select.model',
        'available': true,
        'state': 'Very sensitive',
        'options': ['Very sensitive', '<b>Original word</b>'],
      },
      'wake_word_sensitivity': {
        'entity_id': 'select.sensitivity',
        'available': true,
        'state': 'Slightly sensitive',
        'options': ['Slightly sensitive', 'Very sensitive'],
      },
    });
    for (final name in [
      'vsControls',
      'clearWakeWordModels',
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
              name == 'vsControls'
                  ? jsonDecode(jsonEncode(snapshot))
                  : name == 'clearWakeWordModels'
                  ? {'removed': 4}
                  : null,
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
    'wake choices translate while model names and wire values stay original',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(VsControlsSection(container: c, subpage: 'Wake Word')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Motor de palabras de activación'), findsOneWidget);
      expect(find.text('Very sensitive'), findsOneWidget);
      await tester.tap(find.text('Slightly sensitive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Muy sensible').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(calls.lastWhere((c) => c.$1 == 'haCallService').$2, {
        'domain': 'select',
        'service': 'select_option',
        'entity_id': 'select.sensitivity',
        'data': {'option': 'Very sensitive'},
      });
      final before = calls.length;
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      expect(calls.length, before);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Muy sensible'), findsOneWidget);
      expect(find.text('Very sensitive'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('appearance sends original theme and skin values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(VsControlsSection(container: c, subpage: 'Appearance')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estilo'), findsOneWidget);
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro').last);
    await tester.pumpAndSettle();
    expect(calls.lastWhere((c) => c.$1 == 'vsSetBrowserSettings').$2, {
      'settings': {'theme_mode': 'dark'},
    });
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('<b>Original skin</b>').last);
    await tester.pumpAndSettle();
    expect(calls.lastWhere((c) => c.$1 == 'vsSetBrowserSettings').$2, {
      'settings': {'skin': 'raw'},
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('cache result follows language without clearing again', (
    tester,
  ) async {
    await tester.pumpWidget(app(ClearModelCacheTile(container: c)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(
      find.text('Se borraron 4 archivos. Descargando de nuevo.'),
      findsOneWidget,
    );
    language.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(find.text('Files cleared: 4. Downloading again.'), findsOneWidget);
    expect(calls.where((c) => c.$1 == 'clearWakeWordModels').length, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('tester fits the current Spanish catalog on a narrow display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final manager = _TesterManager(c);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('en'), Locale('es')],
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(
          body: WakeWordTesterTile(container: _TesterContainer(manager)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await manager.samples.close();
  });
  testWidgets('open tester keeps samples and selected word across languages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final manager = _TesterManager(c);
    String clipboard = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      app(WakeWordTesterTile(container: _TesterContainer(manager))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open tester'));
    await tester.pumpAndSettle();
    expect(find.text('Prueba de palabras de activación'), findsOneWidget);
    expect(manager.starts, 1);
    manager.samples.add({
      'id': 'original',
      'score': 0.9,
      'fired': true,
      'decoded': '<b>RAW</b>',
      'editDistance': 1,
      'chunkLatencyUs': 3000,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(
      find.textContaining('DETECCIÓN', findRichText: true),
      findsOneWidget,
    );
    language.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'HIT  score 0.900  [<b>RAW</b>]  ed 1',
        findRichText: true,
      ),
      findsOneWidget,
    );
    language.value = const Locale('es');
    await tester.pumpAndSettle();
    expect(manager.starts, 1);
    expect(manager.stops, 0);
    await tester.ensureVisible(find.text('Copy'));
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(clipboard, contains('DETECCIÓN  puntuación 0.900  [<b>RAW</b>]'));
    await tester.ensureVisible(find.text('Very sensitive'));
    await tester.tap(find.text('Very sensitive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop (palabra de detención)').last);
    await tester.pumpAndSettle();
    manager.samples.add({'id': 'original', 'score': 0.9, 'fired': true});
    manager.samples.add({
      'id': 'stop',
      'score': 0.42,
      'nearMiss': true,
      'decoded': 'raw phonemes',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    language.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(find.text('Stop (stop word)'), findsOneWidget);
    expect(
      find.textContaining(
        'near  score 0.420  decoded=[raw phonemes]',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('HIT  score', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('Close'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(manager.stops, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await manager.samples.close();
  });
}

class _TesterContainer implements AppContainer {
  _TesterContainer(this.wakeWord);
  @override
  final WakeWordManager wakeWord;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TesterManager extends WakeWordManager {
  _TesterManager(AppContainer c) : super(c.bus, c.commands, c.log, c.settings);
  final samples = StreamController<Map<String, Object?>>.broadcast();
  int starts = 0;
  int stops = 0;
  @override
  Stream<Map<String, Object?>> get telemetry => samples.stream;
  @override
  WakeWordConfig get config => const WakeWordConfig(
    engine: WakeWordEngineType.vsWakeWord,
    models: [
      WakeWordModelRef(
        id: 'original',
        wakeWord: 'Very sensitive',
        manifestUrl: 'http://ha/model',
      ),
    ],
    stopModel: WakeWordModelRef(
      id: 'stop',
      wakeWord: 'Stop',
      manifestUrl: 'http://ha/stop',
    ),
  );
  @override
  void startTest() {
    starts++;
  }

  @override
  void stopTest() {
    stops++;
  }
}
