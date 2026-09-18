import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/l10n/fleet_messages.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/managers/fleet/fleet_sync_manager.dart';
import 'package:kiosk_satellite/ui/fleet_settings.dart';
import 'package:kiosk_satellite/ui/plugin_readings.dart';

class _Messages extends UiStringsEn {
  @override
  String get fleetDefault => 'TEST default';
  @override
  String get fleetUpdatesOnly => 'TEST updates';
  @override
  String get fleetCategories => 'TEST categories';
  @override
  String get pluginOn => 'TEST on';
  @override
  String get mediaOff => 'TEST off';
  @override
  String fleetSendingPercent(String percent) => 'TEST sending $percent';
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
  late ValueNotifier<Locale> language;
  setUp(() => language = ValueNotifier(const Locale('es')));
  tearDown(() => language.dispose());
  Widget app(Widget child) => ValueListenableBuilder<Locale>(
    valueListenable: language,
    builder: (_, locale, _) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: const [_Delegate(), ...appLocalizationsDelegates],
      home: Scaffold(body: child),
    ),
  );
  testWidgets(
    'profile picker follows language while keeping canonical selection',
    (tester) async {
      String? selected;
      const custom = SyncProfile(
        id: 'custom-id',
        name: 'Default',
        categories: {},
      );
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showProfilePicker(
                  context,
                  who: 'Raw NAME',
                  profiles: [
                    SyncProfile.initial,
                    SyncProfile.updatesOnly,
                    custom,
                  ],
                  selected: 'default',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('TEST default'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      await tester.tap(find.text('TEST updates'));
      await tester.pumpAndSettle();
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('Updates only'), findsOneWidget);
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      expect(find.text('TEST updates'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(selected, 'updates-only');
      expect(custom.name, 'Default');
    },
  );
  testWidgets('category choices retain raw keys across a language change', (
    tester,
  ) async {
    Set<String>? selected;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await showCategoriesDialog(
                context,
                categories: [
                  {
                    'id': 'Camera',
                    'title': 'Camera',
                    'note': 'the device camera',
                  },
                ],
                picked: {},
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('TEST categories'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    language.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      true,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(selected, {'Camera'});
  });
  testWidgets(
    'fleet status localizes known progress and preserves unknown details',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(fleetStatusText(context, 'Sending 42%'), 'TEST sending 42');
      expect(
        fleetStatusText(context, 'Unknown <host> CASE'),
        'Unknown <host> CASE',
      );
      expect(
        fleetProfileName(
          context,
          const SyncProfile(id: 'custom', name: 'Updates only', categories: {}),
        ),
        'Updates only',
      );
    },
  );
  testWidgets(
    'plugin readings translate booleans without translating text values',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          const SingleChildScrollView(
            child: PluginReadings(
              readings: [
                {
                  'type': 'binary_sensor',
                  'key': 'flag',
                  'name': 'Raw NAME',
                  'state': true,
                },
                {
                  'type': 'text_sensor',
                  'key': 'text',
                  'name': 'Raw text',
                  'state': 'On',
                },
                {
                  'type': 'sensor',
                  'key': 'number',
                  'name': 'Raw number',
                  'state': 12.5,
                  'accuracyDecimals': 1,
                  'unit': 'RAW',
                },
              ],
            ),
          ),
        ),
      );
      expect(find.text('TEST on', findRichText: true), findsOneWidget);
      expect(find.text('On', findRichText: true), findsOneWidget);
      expect(find.text('12.5 RAW', findRichText: true), findsOneWidget);
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('On', findRichText: true), findsNWidgets(2));
      expect(find.text('Raw NAME'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('fleet status updates fit a narrow screen and retain names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final container = AppContainer();
    await container.settings.init();
    container.commands.register(
      Command(
        name: 'fleetStatus',
        description: 'fixture',
        handler: (_) async => const CommandResult.ok({
          'enabled': true,
          'leader': true,
          'profiles': [],
          'followers': [
            {
              'id': 'raw-id',
              'name': 'Original NAME',
              'address': '192.0.2.5',
              'version': '1.0',
              'profile': 'default',
              'phase': 'updating',
              'status': 'Sending 25%',
              'tone': 'muted',
            },
          ],
        }),
      ),
    );
    await tester.pumpWidget(
      app(
        SingleChildScrollView(child: FleetSettingsPanel(container: container)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TEST sending 25'), findsOneWidget);
    expect(find.text('Original NAME'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await container.settings.dispose();
    await container.bus.dispose();
    await container.log.dispose();
  });

  testWidgets(
    'Add by IP works with no discovered kiosks and preserves the chosen profile',
    (tester) async {
      language.value = const Locale('en');
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final container = AppContainer();
      await container.settings.init();
      final calls = <(String, Map<String, Object?>)>[];
      for (final name in [
        'fleetStatus',
        'fleetCandidates',
        'fleetLookup',
        'fleetInvite',
      ]) {
        container.commands.register(
          Command(
            name: name,
            description: 'fixture',
            handler: (params) async {
              calls.add((name, params));
              if (name == 'fleetStatus') {
                return CommandResult.ok({
                  'enabled': true,
                  'leader': true,
                  'followers': [],
                  'profiles': [
                    SyncProfile.initial.toJson(),
                    SyncProfile.updatesOnly.toJson(),
                  ],
                });
              }
              if (name == 'fleetCandidates') return const CommandResult.ok([]);
              if (name == 'fleetLookup') {
                if (params['address'] == '') {
                  return const CommandResult.fail('Enter a valid IP address.');
                }
                return const CommandResult.ok({
                  'id': 'bed',
                  'name': 'Bedroom',
                  'address': '192.168.1.80',
                  'port': 2345,
                  'manual': true,
                });
              }
              return const CommandResult.ok(true);
            },
          ),
        );
      }
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: FleetSettingsPanel(container: container),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add by IP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find kiosk'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid IP address.'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).first, '192.168.1.80');
      await tester.enterText(find.byType(TextField).last, '2345');
      await tester.tap(find.text('Find kiosk'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.$1 == 'fleetInvite'), isEmpty);
      expect(find.text('Sync to Bedroom'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(RadioListTile<String>, 'Updates only'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send invitation'));
      await tester.pumpAndSettle();
      expect(calls.singleWhere((c) => c.$1 == 'fleetInvite').$2, {
        'id': 'bed',
        'profile': 'updates-only',
        'address': '192.168.1.80',
        'port': 2345,
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await container.settings.dispose();
      await container.bus.dispose();
      await container.log.dispose();
    },
  );
}
