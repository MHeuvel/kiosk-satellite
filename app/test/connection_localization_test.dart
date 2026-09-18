import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/ui/offline_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Spanish extends UiStringsEn {
  @override
  String get offlineDashboard => 'Panel de control no disponible';
  @override
  String get offlineNetwork => 'Sin conexión de red';
  @override
  String get offlinePageHelp => 'No se pudo cargar la página.';
  @override
  String get offlineNetworkHelp =>
      'El panel de control volverá cuando se restablezca la conexión de red.';
  @override
  String get offlineLost => 'Se perdió la conexión de red';
  @override
  String get offlineRestored => 'Se restableció la conexión de red';
  @override
  String get commonRetry => 'Reintentar';
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
  final loads = <String>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ks.browser.start_url': 'http://ha.example/KeepCase?view=1',
    });
    c = AppContainer();
    await c.settings.init();
    language = ValueNotifier(const Locale('es'));
    loads.clear();
    c.browser.urlMapper = (url) {
      loads.add(url);
      return url;
    };
  });
  tearDown(() async {
    language.dispose();
    await c.browser.dispose();
    await c.settings.dispose();
    await c.bus.dispose();
    await c.log.dispose();
  });
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: language,
        builder: (context, locale, _) => MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: const [
            _Delegate(),
            ...appLocalizationsDelegates,
          ],
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'offline notice follows network and language without changing retries',
    (tester) async {
      c.browser.loadFailed.value = true;
      c.browser.lastErrorDescription = 'net::ERR_NAME_NOT_RESOLVED <detail>';
      c.device.networkUp.value = false;
      await show(tester, OfflineNotice(container: c));
      expect(find.text('Sin conexión de red'), findsOneWidget);
      expect(find.text('net::ERR_NAME_NOT_RESOLVED <detail>'), findsOneWidget);
      expect(tester.takeException(), isNull);
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('No network connection'), findsOneWidget);
      c.device.networkUp.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Dashboard unavailable'), findsOneWidget);
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      expect(find.text('Panel de control no disponible'), findsOneWidget);
      expect(loads, isEmpty);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(loads, ['http://ha.example/KeepCase?view=1']);
      c.browser.loadFailed.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Panel de control no disponible'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('network toast keeps its recovery timer across locale changes', (
    tester,
  ) async {
    c.device.networkUp.value = false;
    await show(tester, NetworkToast(container: c));
    expect(find.text('Se perdió la conexión de red'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byType(AnimatedSlide),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );
    c.device.networkUp.value = true;
    await tester.pump();
    expect(find.text('Se restableció la conexión de red'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    language.value = const Locale('en');
    await tester.pump();
    await tester.pump();
    expect(find.text('Network connection restored'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
    c.device.networkUp.value = false;
    await tester.pump();
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(find.text('Network connection lost'), findsOneWidget);
    expect(loads, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
