import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/managers/home_assistant/ha_tts.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/voice/ha_socket.dart';
import 'package:kiosk_satellite/ui/intercom_settings.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers websocket commands from a table instead of Home Assistant.
class _FakeSocket extends HaSocket {
  _FakeSocket(this.answers) : super(baseUrl: () => '', token: () => '');

  final Object? Function(Map<String, Object?> command) answers;
  final sent = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Future<Object?> request(
    Map<String, Object?> command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    sent.add(command);
    return answers(command);
  }

  @override
  Future<void> close() async => closed = true;
}

void main() {
  group('pickTtsLanguage', () {
    test('matches language and country across spellings', () {
      expect(pickTtsLanguage(['en_GB', 'en_US'], 'en', 'US'), 'en_US');
      expect(pickTtsLanguage(['en-gb', 'en-us'], 'en-GB', 'US'), 'en-gb');
      expect(pickTtsLanguage(['de', 'en'], 'en', 'US'), 'en');
    });

    test('falls back to any region, then to nothing', () {
      expect(pickTtsLanguage(['en_GB', 'en_US'], 'en', 'EC'), 'en_US');
      expect(pickTtsLanguage(['es_AR', 'es_ES'], 'es', 'EC'), 'es_ES');
      expect(pickTtsLanguage(['es_AR', 'es_MX'], 'es', 'EC'), 'es_AR');
      expect(pickTtsLanguage(['de', 'fr'], 'en', 'US'), '');
      expect(pickTtsLanguage(['en'], '', ''), '');
    });
  });

  test('the tts_get_url body carries only what is set', () {
    expect(ttsRequestBody(engine: 'tts.piper', message: 'Hi'), {
      'engine_id': 'tts.piper',
      'message': 'Hi',
    });
    expect(
      ttsRequestBody(
        engine: 'tts.piper',
        message: 'Hi',
        language: ' en_US ',
        voice: 'en_US-amy-low',
      ),
      {
        'engine_id': 'tts.piper',
        'message': 'Hi',
        'language': 'en_US',
        'options': {'voice': 'en_US-amy-low'},
      },
    );
  });

  group('haSpeak', () {
    test('a voice Home Assistant fails with is retried without it', () async {
      final bodies = <Map<String, Object?>>[];
      final audio = await haSpeak(
        base: 'http://ha.local:8123',
        token: 'tkn',
        engine: 'tts.piper',
        message: 'Wake up',
        language: 'en_US',
        voice: 'gone',
        client: () => MockClient((req) async {
          if (req.url.path == '/api/tts_get_url') {
            final body = jsonDecode(req.body) as Map<String, Object?>;
            bodies.add(body);
            return http.Response(
              jsonEncode({
                'url': body.containsKey('options')
                    ? 'http://ha.local:8123/api/tts_proxy/bad.mp3'
                    : 'http://ha.local:8123/api/tts_proxy/good.mp3',
              }),
              200,
            );
          }
          return req.url.path.endsWith('good.mp3')
              ? http.Response.bytes([1, 2], 200)
              : http.Response('', 500);
        }),
      );
      expect(audio, [1, 2]);
      expect(bodies, [
        {
          'engine_id': 'tts.piper',
          'message': 'Wake up',
          'language': 'en_US',
          'options': {'voice': 'gone'},
        },
        {'engine_id': 'tts.piper', 'message': 'Wake up'},
      ]);
    });

    test('First available sends no language or voice', () async {
      final bodies = <Object?>[];
      await haSpeak(
        base: 'http://ha.local:8123',
        token: 'tkn',
        engine: '',
        message: 'Wake up',
        language: 'en_US',
        voice: 'amy',
        client: () => MockClient((req) async {
          if (req.url.path == '/api/states') {
            return http.Response(
              jsonEncode([
                {'entity_id': 'tts.piper'},
              ]),
              200,
            );
          }
          if (req.url.path == '/api/tts_get_url') {
            bodies.add(jsonDecode(req.body));
            return http.Response('', 500);
          }
          return http.Response('', 404);
        }),
      );
      expect(bodies, [
        {'engine_id': 'tts.piper', 'message': 'Wake up'},
      ]);
    });
  });

  group('haTtsVoices', () {
    Object? answers(Map<String, Object?> c) => switch (c['type']) {
      'tts/engine/get' => {
        'provider': {
          'engine_id': 'tts.piper',
          'supported_languages': ['en_GB', 'en_US', 'es_AR'],
        },
      },
      'get_config' => {'language': 'en', 'country': 'US'},
      'tts/engine/voices' => {
        'voices': c['language'] == 'en_US'
            ? [
                {'voice_id': 'en_US-amy-low', 'name': 'amy (low)'},
              ]
            : null,
      },
      _ => null,
    };

    test('lists voices for Home Assistant\'s language by default', () async {
      final socket = _FakeSocket(answers);
      final voices = await haTtsVoices(
        base: 'http://ha.local:8123',
        token: 'tkn',
        engine: 'tts.piper',
        socket: (_, _) => socket,
      );
      expect(voices!.languages, ['en_GB', 'en_US', 'es_AR']);
      expect(voices.language, 'en_US');
      expect(voices.voices, [
        {'voice_id': 'en_US-amy-low', 'name': 'amy (low)'},
      ]);
      expect(socket.closed, isTrue);
    });

    test('a picked language skips the config, no voices is empty', () async {
      final socket = _FakeSocket(answers);
      final voices = await haTtsVoices(
        base: 'http://ha.local:8123',
        token: 'tkn',
        engine: 'tts.piper',
        language: 'es_AR',
        socket: (_, _) => socket,
      );
      expect(voices!.language, 'es_AR');
      expect(voices.voices, isEmpty);
      expect(socket.sent.map((c) => c['type']), isNot(contains('get_config')));
    });

    test('an unreachable Home Assistant answers null', () async {
      final voices = await haTtsVoices(
        base: 'http://ha.local:8123',
        token: 'tkn',
        engine: 'tts.piper',
        socket: (_, _) => _FakeSocket((_) => throw StateError('down')),
      );
      expect(voices, isNull);
    });
  });

  group('device rows', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late AppContainer c;
    late List<Map<String, Object?>> voiceCalls;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'ks.esphome.enabled': true,
        'ks.announcements.enabled': true,
        'ks.announcements.tts_engine': 'tts.piper',
      });
      c = AppContainer();
      await c.settings.init();
      voiceCalls = [];
      c.commands
        ..register(
          Command(
            name: 'ttsVoices',
            description: '',
            handler: (p) async {
              voiceCalls.add(Map.of(p));
              final language = '${p['language']}'.isEmpty
                  ? 'en_US'
                  : '${p['language']}';
              return CommandResult.ok({
                'languages': ['en_US', 'es_AR'],
                'language': language,
                'voices': language == 'en_US'
                    ? [
                        {'voice_id': 'en_US-amy-low', 'name': 'amy (low)'},
                        {'voice_id': 'en_US-joe-medium', 'name': 'joe'},
                      ]
                    : [
                        {'voice_id': 'es_AR-daniela-high', 'name': 'daniela'},
                      ],
              });
            },
          ),
        )
        ..register(
          Command(
            name: 'announcementTtsEngines',
            description: '',
            handler: (_) async => const CommandResult.ok([
              {'entity_id': 'tts.piper', 'name': 'Piper'},
              {'entity_id': 'tts.cloud', 'name': 'Cloud'},
            ]),
          ),
        );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('kiosk_satellite/device_details'),
            (call) async => call.method == 'languageNames'
                ? {
                    'en_US': 'English (United States)',
                    'es_AR': 'Spanish (Argentina)',
                  }
                : null,
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('kiosk_satellite/device_details'),
            null,
          );
      await c.settings.dispose();
      await c.bus.dispose();
      await c.log.dispose();
    });

    Widget app(Widget child) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    Widget row(defs.SettingDef<String> def) => TtsVoiceRow(
      container: c,
      def: def,
      engineDef: defs.announcementsTtsEngine,
      languageDef: defs.announcementsTtsLanguage,
      voiceDef: defs.announcementsTtsVoice,
    );

    testWidgets('a voice is picked from the engine list', (tester) async {
      await tester.pumpWidget(app(row(defs.announcementsTtsVoice)));
      await tester.pumpAndSettle();
      expect(voiceCalls, isEmpty, reason: 'Default needs no lookup');
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
      expect(voiceCalls.last, {'engine': 'tts.piper', 'language': ''});
      // The id the announce action takes, under each name.
      expect(find.text('en_US-joe-medium'), findsOneWidget);
      await tester.tap(find.text('joe'));
      await tester.pumpAndSettle();
      expect(c.settings.get(defs.announcementsTtsVoice), 'en_US-joe-medium');
      expect(find.text('joe'), findsOneWidget);
    });

    testWidgets('a new language drops a voice it does not list', (
      tester,
    ) async {
      await c.settings.set(defs.announcementsTtsVoice, 'en_US-amy-low');
      await tester.pumpWidget(app(row(defs.announcementsTtsLanguage)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
      expect(find.text('English (United States)'), findsOneWidget);
      expect(find.text('en_US'), findsOneWidget);
      await tester.tap(find.text('Spanish (Argentina)'));
      await tester.pumpAndSettle();
      expect(c.settings.get(defs.announcementsTtsLanguage), 'es_AR');
      expect(c.settings.get(defs.announcementsTtsVoice), '');
      expect(find.text('Spanish (Argentina)'), findsOneWidget);
    });

    testWidgets('a new engine clears the language and voice', (tester) async {
      await c.settings.set(defs.announcementsTtsLanguage, 'en_US');
      await c.settings.set(defs.announcementsTtsVoice, 'en_US-amy-low');
      await tester.pumpWidget(app(AnnouncementTtsEngineRow(container: c)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Piper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cloud'));
      await tester.pumpAndSettle();
      expect(c.settings.get(defs.announcementsTtsEngine), 'tts.cloud');
      expect(c.settings.get(defs.announcementsTtsLanguage), '');
      expect(c.settings.get(defs.announcementsTtsVoice), '');
    });

    testWidgets('the rows show only under an engine picked by name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget page() => MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        home: SubpageSettingsScreen(
          container: c,
          category: 'ESPHome',
          subpage: 'Announcements',
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.byType(TtsVoiceRow), findsNWidgets(2));
      expect(
        find.textContaining(RegExp('^text to speech\$', caseSensitive: false)),
        findsOneWidget,
      );
      await c.settings.set(defs.announcementsTtsEngine, '');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.byType(TtsVoiceRow), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
