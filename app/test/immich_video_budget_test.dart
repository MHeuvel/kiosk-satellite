import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/screensaver/immich_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The video player buffers fifty seconds of a stream into the Java heap,
/// which on an Echo Show is 80 MB in all: a video whose buffering would not
/// fit is skipped instead of played, judged by the stream's real size.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding answers every HTTP request with a 400 and no body;
  // the manager test wants the loopback server it started.
  setUpAll(() => HttpOverrides.global = null);
  const mb = 1024 * 1024;

  test('the listing duration reads as seconds', () {
    expect(immichDurationSeconds('0:00:20.896'), closeTo(20.896, 0.001));
    expect(immichDurationSeconds('0:02:05.000'), 125);
    expect(immichDurationSeconds('1:00:00.000'), 3600);
    expect(immichDurationSeconds('00:30'), 30);
    // Immich 3 sends milliseconds as a number.
    expect(immichDurationSeconds(20896), closeTo(20.896, 0.001));
    expect(immichDurationSeconds(0), isNull);
    expect(immichDurationSeconds(''), isNull);
    expect(immichDurationSeconds(null), isNull);
    expect(immichDurationSeconds('soon'), isNull);
    expect(immichDurationSeconds('0:00:00.000'), isNull);
  });

  test('a short video buffers whole, a long one its first fifty seconds', () {
    expect(immichVideoBufferBytes(14 * mb, 21), 14 * mb);
    expect(immichVideoBufferBytes(100 * mb, 200), 25 * mb);
    // No length known: assume it all comes at once.
    expect(immichVideoBufferBytes(60 * mb, null), 60 * mb);
  });

  test('forty percent of the heap is the budget, a quarter of a small one', () {
    expect(immichVideoBudget(80 * mb), 20 * mb);
    expect(immichVideoBudget(128 * mb), closeTo(51.2 * mb, 1));
    expect(immichVideoBudget(512 * mb), closeTo(204.8 * mb, 1));
    expect(
      immichVideoFits(bytes: 14 * mb, durationSeconds: 21, heapMax: 80 * mb),
      isTrue,
    );
    expect(
      immichVideoFits(bytes: 60 * mb, durationSeconds: 40, heapMax: 80 * mb),
      isFalse,
    );
    // The same video on a 512 MB phone.
    expect(
      immichVideoFits(bytes: 60 * mb, durationSeconds: 40, heapMax: 512 * mb),
      isTrue,
    );
    // A two minute 4K clip on an Echo Show: 50 s of it is 50 MB.
    expect(
      immichVideoFits(bytes: 120 * mb, durationSeconds: 120, heapMax: 80 * mb),
      isFalse,
    );
  });

  group('the manager asks the server for the stream size', () {
    late HttpServer server;
    late ImmichManager immich;
    final sizes = <String, int?>{};
    final heads = <String>[];
    var honorsRange = true;

    setUp(() async {
      heads.clear();
      honorsRange = true;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final path = request.uri.path;
        final response = request.response;
        if (path.endsWith('/video/playback')) {
          heads.add(path);
          final id = path.split('/')[3];
          final size = sizes[id];
          response.headers.contentType = ContentType('video', 'mp4');
          if (size == null) {
            // A server that states no size streams chunked.
            response.write('x');
          } else if (honorsRange && request.headers.value('range') != null) {
            response.statusCode = 206;
            response.headers.set('content-range', 'bytes 0-0/$size');
            response.headers.contentLength = 1;
            response.write('x');
          } else {
            response.headers.contentLength = size;
            response.write('x' * size);
          }
        } else {
          response.statusCode = 404;
        }
        await response.close();
      });
      SharedPreferences.setMockInitialValues({
        'ks.screensaver.immich_url': 'http://127.0.0.1:${server.port}',
        'ks.screensaver.immich_api_key': 'test-key',
        'ks.screensaver.immich_cache': false,
      });
      final bus = EventBus();
      final log = Logger();
      final settings = SettingsManager(bus, CommandRegistry(log), log);
      await settings.init();
      immich = ImmichManager(bus, CommandRegistry(log), log, settings);
      immich.javaHeapMaxOverride = 80 * mb;
    });

    tearDown(() => server.close(force: true));

    test('fits, does not fit, and unknown size plays', () async {
      sizes['small'] = 14 * mb;
      sizes['big'] = 60 * mb;
      sizes['unsized'] = null;
      expect(
        await immich.videoFits(
          const ImmichAsset(id: 'small', isVideo: true, durationSeconds: 21),
        ),
        isTrue,
      );
      expect(
        await immich.videoFits(
          const ImmichAsset(id: 'big', isVideo: true, durationSeconds: 40),
        ),
        isFalse,
      );
      expect(
        await immich.videoFits(
          const ImmichAsset(id: 'unsized', isVideo: true, durationSeconds: 40),
        ),
        isTrue,
      );
    });

    test('a verdict is asked for once per video', () async {
      sizes['big'] = 60 * mb;
      const asset = ImmichAsset(id: 'big', isVideo: true, durationSeconds: 40);
      expect(await immich.videoFits(asset), isFalse);
      expect(await immich.videoFits(asset), isFalse);
      expect(heads, hasLength(1));
    });

    test('a server that ignores the range still states its length', () async {
      honorsRange = false;
      sizes['big'] = 60 * mb;
      expect(
        await immich.videoFits(
          const ImmichAsset(id: 'big', isVideo: true, durationSeconds: 40),
        ),
        isFalse,
      );
    });

    test('the Content-Range total is read, and only a real one', () {
      expect(immichContentRangeTotal('bytes 0-0/7567107'), 7567107);
      expect(immichContentRangeTotal('bytes 0-0/*'), isNull);
      expect(immichContentRangeTotal(null), isNull);
      expect(immichContentRangeTotal('bytes 0-0/0'), isNull);
    });

    test('with no heap figure every video plays', () async {
      immich.javaHeapMaxOverride = null;
      sizes['big'] = 60 * mb;
      // Off Android the platform channel answers nothing.
      expect(
        await immich.videoFits(
          const ImmichAsset(id: 'big', isVideo: true, durationSeconds: 40),
        ),
        isTrue,
      );
      expect(heads, isEmpty);
    });
  });
}
