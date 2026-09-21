import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/l10n/messages.dart';
import 'package:kiosk_satellite/ui/intercom_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Messages extends UiStringsEn {
  @override
  String get intercomCall => 'TEST call';
  @override
  String get intercomAnswer => 'TEST answer';
  @override
  String get intercomRinging => 'TEST ringing';
  @override
  String get intercomHoldTalk => 'TEST hold';
  @override
  String get intercomHoldHelp => 'TEST release to listen';
  @override
  String get intercomMute => 'TEST mute';
  @override
  String get intercomReady => 'TEST ready';
  @override
  String get intercomBusy => 'TEST busy';
  @override
  String get intercomAnnouncement => 'TEST announcement';
  @override
  String get intercomPlaying => 'TEST playing';
  @override
  String get intercomKeyLength => 'TEST key too short';
  @override
  String get intercomAnnounceAll => 'TEST announce all';
  @override
  String intercomHearsYou(String name) => '$name TEST hears';
  @override
  String intercomManyReady(String count) => '$count TEST ready kiosks';
}

class _LongMessages extends _Messages {
  @override
  String get intercomHoldTalk => 'Mantén pulsado para hablar';
  @override
  String get intercomRegenerate => 'Generar de nuevo';
  @override
  String get commonCancel => 'Cancelar';
  @override
  String get commonSave => 'Guardar';
}

class _Delegate extends LocalizationsDelegate<UiStrings> {
  const _Delegate({this.long = false});
  final bool long;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<UiStrings> load(Locale locale) => SynchronousFuture(
    locale.languageCode == 'es'
        ? (long ? _LongMessages() : _Messages())
        : UiStringsEn(),
  );
  @override
  bool shouldReload(_Delegate old) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppContainer c;
  late ValueNotifier<Locale> language;
  late List<(String, Map<String, Object?>)> commands;
  late Map<String, Object?> status;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    c = AppContainer();
    await c.settings.init();
    language = ValueNotifier(const Locale('es'));
    commands = [];
    status = {
      'enabled': true,
      'available': true,
      'state': 'idle',
      'kiosks': [
        {
          'id': 'original-id',
          'name': 'Ready',
          'address': '192.0.2.1',
          'version': 'test',
          'status': 'ready',
          'statusText': 'Ready',
        },
        {
          'id': 'second-id',
          'name': 'Call',
          'address': '192.0.2.2',
          'version': 'test',
          'status': 'ready',
          'statusText': 'Ready',
        },
      ],
    };
    c.commands.register(
      Command(
        name: 'intercomStatus',
        description: 'Fixture',
        handler: (_) async => CommandResult.ok(status),
      ),
    );
    for (final name in [
      'intercomCall',
      'intercomAnswer',
      'intercomTalk',
      'intercomMute',
      'intercomHangup',
      'intercomBroadcast',
      'intercomDismiss',
    ]) {
      c.commands.register(
        Command(
          name: name,
          description: 'Fixture',
          handler: (params) async {
            commands.add((name, Map.of(params)));
            return const CommandResult.ok();
          },
        ),
      );
    }
  });
  tearDown(() async {
    language.dispose();
    await c.settings.dispose();
  });
  Widget localized(Widget body, {bool long = false}) =>
      ValueListenableBuilder<Locale>(
        valueListenable: language,
        builder: (context, locale, _) => MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: [
            _Delegate(long: long),
            ...appLocalizationsDelegates,
          ],
          home: Scaffold(body: body),
        ),
      );
  Future<void> emit(
    WidgetTester tester,
    String state, {
    String mode = 'ptt',
    bool automated = false,
    String message = '',
  }) async {
    c.bus.publish(
      IntercomStateChanged({
        ...status,
        'state': state,
        'talkMode': mode,
        'micGranted': true,
        'call': {
          'id': 'call-id',
          'kind': 'call',
          'peer': {'id': 'original-id', 'name': 'Call'},
          'since': DateTime.now().millisecondsSinceEpoch,
          'automated': automated,
          'outgoing': false,
          'message': message,
        },
      }),
    );
    await tester.pump();
  }

  testWidgets('calls keep peer names and commands while language changes', (
    tester,
  ) async {
    await tester.pumpWidget(localized(IntercomCallOverlay(container: c)));
    await emit(tester, 'ringing');
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('TEST ringing'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.call));
    await tester.pump();
    expect(commands.single.$1, 'intercomAnswer');
    expect(commands.single.$2, <String, Object?>{});
    await emit(tester, 'in_call');
    final press = await tester.startGesture(
      tester.getCenter(find.text('TEST hold')),
    );
    await tester.pump();
    expect(commands.last.$1, 'intercomTalk');
    expect(commands.last.$2, {'on': true});
    expect(find.text('Call TEST hears'), findsOneWidget);
    final before = commands.length;
    language.value = const Locale('en');
    await tester.pump();
    await tester.pump();
    expect(find.text('Hold to talk'), findsOneWidget);
    expect(find.text('Call hears you'), findsOneWidget);
    expect(commands.length, before);
    await press.up();
    await tester.pump();
    expect(commands.last.$1, 'intercomTalk');
    expect(commands.last.$2, {'on': false});
    await emit(tester, 'in_call', mode: 'handsfree');
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    expect(commands.last.$1, 'intercomMute');
    expect(commands.last.$2, {'on': true});
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('roster translates status but preserves names and call IDs', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(IntercomSettingsPanel(container: c, cards: const [])),
    );
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('TEST ready'), findsNWidgets(2));
    await tester.tap(find.text('TEST call').first);
    await tester.pump();
    expect(commands.single.$1, 'intercomCall');
    expect(commands.single.$2, {'id': 'original-id'});
    language.value = const Locale('en');
    await tester.pump();
    await tester.pump();
    expect(find.text('TEST ready'), findsNothing);
    expect(find.text('Ready'), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('call picker preserves names and broadcast action', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(Stack(children: [IntercomRosterOverlay(container: c)])),
    );
    c.intercom.rosterVisible.value = true;
    await tester.pumpAndSettle();
    c.bus.publish(IntercomStateChanged(status));
    await tester.pumpAndSettle();
    expect(find.text('2 TEST ready kiosks'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(find.text('TEST announce all'));
    await tester.pumpAndSettle();
    expect(commands.single.$1, 'intercomBroadcast');
    expect(commands.single.$2, <String, Object?>{});
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'announcement text bypasses translations and language does not hang up',
    (tester) async {
      await tester.pumpWidget(localized(AnnouncementOverlay(container: c)));
      await emit(tester, 'listening', automated: true, message: 'Announcement');
      expect(find.text('Announcement'), findsOneWidget);
      expect(find.text('TEST playing'), findsOneWidget);
      language.value = const Locale('en');
      await tester.pump();
      await tester.pump();
      expect(find.text('Announcement'), findsOneWidget);
      expect(find.text('Playing'), findsOneWidget);
      expect(commands, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('key validation stays open and key payload is unchanged', (
    tester,
  ) async {
    c.commands.register(
      Command(
        name: 'intercomSetKey',
        description: 'Fixture',
        handler: (params) async {
          commands.add(('intercomSetKey', Map.of(params)));
          return params['key'] == 'short'
              ? const CommandResult.fail('a key is at least 16 characters')
              : const CommandResult.ok();
        },
      ),
    );
    await tester.pumpWidget(
      localized(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showIntercomKeyDialog(context, c),
            child: const Text('Open key'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'short');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('TEST key too short'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    const key = ' user-Key-<b>{name}-123456 ';
    await tester.enterText(find.byType(TextField), key);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(commands.last.$1, 'intercomSetKey');
    expect(commands.last.$2, {'key': key});
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('broadcast error translates status without parsing kiosk names', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(
        Builder(
          builder: (context) {
            final status = {
              'call': {
                'targets': [
                  {'name': 'Ready, kitchen: busy', 'status': 'busy'},
                ],
              },
            };
            return Text(
              intercomError(
                context,
                'Ready, kitchen: busy: busy',
                status: status,
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('Ready, kitchen: busy: TEST busy'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('long Spanish controls fit a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      localized(IntercomCallOverlay(container: c), long: true),
    );
    await emit(tester, 'in_call');
    expect(find.text('Mantén pulsado para hablar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      localized(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showIntercomKeyDialog(context, c),
            child: const Text('Open key'),
          ),
        ),
        long: true,
      ),
    );
    await tester.tap(find.text('Open key'));
    await tester.pumpAndSettle();
    expect(find.text('Generar de nuevo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
