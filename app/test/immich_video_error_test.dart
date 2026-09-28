import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/ui/screensaver_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A video whose decoder dies mid-playback (issue #739) used to stall the
/// Immich slideshow: the controller resets to uninitialized, so the video
/// never reaches its end, and the next build ran into the photo the video
/// slide had cleared. The error is now the cue to move on.
class _Video extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final playing = <int>{};
  var creates = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++creates;
    events[id] = StreamController<VideoEvent>();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = events[playerId]!;
    scheduleMicrotask(
      () => controller.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 30),
          size: const Size(1920, 1080),
        ),
      ),
    );
    return controller.stream;
  }

  /// A decoder failure the way the plugin reports one.
  void fail(int playerId) => events[playerId]!.addError(
    PlatformException(
      code: 'VideoError',
      message:
          'Video player had error androidx.media3.exoplayer.'
          'ExoPlaybackException: MediaCodecVideoRenderer error',
    ),
  );

  @override
  Future<void> dispose(int playerId) async {
    playing.remove(playerId);
    await events.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> play(int playerId) async => playing.add(playerId);
  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  late HttpServer server;
  late AppContainer container;
  late _Video video;
  late VideoPlayerPlatform original;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      final path = request.uri.path;
      final response = request.response;
      if (path == '/api/albums') {
        response.headers.contentType = ContentType.json;
        response.write('[]');
      } else if (path == '/api/search/metadata') {
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode({
            'assets': {
              'items': [
                {'id': 'video-1', 'type': 'VIDEO'},
                {'id': 'photo-2', 'type': 'IMAGE'},
              ],
              'nextPage': null,
            },
          }),
        );
      } else if (path.endsWith('/thumbnail')) {
        response.headers.contentType = ContentType('image', 'png');
        response.add(png);
      } else {
        response.statusCode = 404;
      }
      response.close();
    });

    SharedPreferences.setMockInitialValues({
      'ks.screensaver.immich_url': 'http://127.0.0.1:${server.port}',
      'ks.screensaver.immich_api_key': 'test-key',
      'ks.screensaver.immich_validated': true,
      'ks.screensaver.immich_shuffle': false,
      'ks.screensaver.immich_cache': false,
    });
    container = AppContainer();
    await container.settings.init();
    await container.immich.init();
    // No heap to judge against: every video plays.
    container.immich.javaHeapMaxOverride = 0;
    original = VideoPlayerPlatform.instance;
    video = _Video();
    VideoPlayerPlatform.instance = video;
  });

  tearDown(() async {
    VideoPlayerPlatform.instance = original;
    await server.close(force: true);
  });

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
    await tester.pump();
  }

  testWidgets('a video that fails mid-playback hands off to the next slide', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: ImmichScreensaver(container: container)),
      );
      await pumpUntil(tester, () => video.playing.contains(1));
      expect(find.byType(VideoPlayer), findsOneWidget);

      video.fail(1);
      await pumpUntil(tester, () => find.byType(Image).evaluate().isNotEmpty);
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsWidgets);
      expect(
        container.log.recent.any(
          (e) => e.message.startsWith('immich video stopped playing (video-1)'),
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}
