import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/managers/dlna/dlna_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/ui/dlna_media_overlay.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
// The platform interface belongs to the video_player dependency.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _Messages extends UiStringsEn {
  @override
  String get dlnaCannotDecode => 'TEST decoder failed';
  @override
  String get dlnaCannotRead => 'TEST file failed';
  @override
  String get dlnaCannotPlay => 'TEST playback failed';
  @override
  String get dlnaSeeLogs => 'TEST log guidance';
  @override
  String get dlnaLoading => 'TEST loading';
  @override
  String get dlnaStop => 'TEST stop';
  @override
  String get dlnaPortInvalid => 'TEST invalid port';
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

class _Video extends VideoPlayerPlatform {
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return Stream.error(
      PlatformException(code: 'VideoError', message: failure),
    );
  }

  @override
  Future<void> dispose(int playerId) async {}
  String failure = 'Source error';
  int creates = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    creates++;
    return creates;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppContainer container;
  late ValueNotifier<Locale> language;
  late _Video video;
  late VideoPlayerPlatform originalVideo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = AppContainer();
    await container.settings.init();
    language = ValueNotifier(const Locale('es'));
    originalVideo = VideoPlayerPlatform.instance;
    video = _Video();
    VideoPlayerPlatform.instance = video;
  });
  tearDown(() async {
    VideoPlayerPlatform.instance = originalVideo;
    language.dispose();
    await container.settings.dispose();
  });
  Widget localized(Widget child) => ValueListenableBuilder<Locale>(
    valueListenable: language,
    builder: (context, locale, _) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: const [_Delegate(), ...appLocalizationsDelegates],
      home: Scaffold(body: child),
    ),
  );

  testWidgets(
    'pending title survives language changes and stop dismisses media',
    (tester) async {
      const item = DlnaMedia(
        uri: 'http://example.test/media',
        kind: 'audio',
        metadata: '<title>{name}</title>',
        title: 'Loading media',
      );
      container.dlna.media.value = item;
      container.dlna.pending.value = true;
      await tester.pumpWidget(
        localized(DlnaMediaOverlay(container: container)),
      );
      expect(find.text('Loading media'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .semanticsLabel,
        'TEST loading',
      );
      language.value = const Locale('en');
      await tester.pump();
      await tester.pump();
      expect(find.text('Loading media'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .semanticsLabel,
        'Loading media',
      );
      expect(container.dlna.media.value, same(item));
      expect(container.dlna.pending.value, isTrue);
      expect(video.creates, 0);
      await tester.tap(find.text('Loading media'));
      await tester.pump();
      expect(container.dlna.media.value, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final sample in [
    ('Source error', 'TEST file failed', 'This file could not be read.'),
    (
      'MediaCodecVideoRenderer error',
      'TEST decoder failed',
      'This device cannot decode this video.',
    ),
    (
      'Network timeout',
      'TEST playback failed',
      'This media could not be played.',
    ),
  ]) {
    testWidgets('failure changes language without restarting ${sample.$1}', (
      tester,
    ) async {
      video.failure = sample.$1;
      const item = DlnaMedia(
        uri: 'http://example.test/video',
        kind: 'video',
        metadata: 'original',
      );
      container.dlna.media.value = item;
      container.dlna.transportState.value = 'PLAYING';
      await tester.pumpWidget(
        localized(DlnaMediaOverlay(container: container)),
      );
      await tester.pump();
      // Stream cancellation completes outside the widget test clock.
      // Decoder failures make a second attempt using a platform view.
      for (
        var attempt = 0;
        attempt < 4 && find.text(sample.$2).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(find.text(sample.$2), findsOneWidget);
      expect(find.text('TEST log guidance'), findsOneWidget);
      final attempts = video.creates;
      for (final locale in ['en', 'es']) {
        language.value = Locale(locale);
        await tester.pump();
        await tester.pump();
        expect(
          find.text(locale == 'en' ? sample.$3 : sample.$2),
          findsOneWidget,
        );
        expect(video.creates, attempts);
        expect(container.dlna.media.value, same(item));
        expect(container.dlna.transportState.value, 'PLAYING');
      }
      await tester.pump(const Duration(seconds: 6));
      expect(container.dlna.media.value, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('port validation is translated and saves canonical text', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(
        SettingTile(container: container, def: defs.dlnaPort, onChanged: () {}),
      ),
    );
    await tester.tap(find.text('Server port'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '80');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('TEST invalid port'), findsOneWidget);
    expect(container.settings.get(defs.dlnaPort), '');
    await tester.enterText(find.byType(TextField), '2456');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(container.settings.get(defs.dlnaPort), '2456');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
