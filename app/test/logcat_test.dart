import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/device/logcat.dart';

String bufferLine(
  int slot, {
  String time = '12:03:11.233',
  String priority = 'W',
  String process = '21719',
  String surface = 'MediaCodec.release',
  String queue = '54d700000031',
  String operation = 'detachBuffer',
  String state = 'FREE',
}) =>
    '09-20 $time $priority/BufferQueueProducer($process): '
    '[$surface](id:$queue,api:3,p:$process,c:$process) '
    '$operation: slot $slot is not owned by the producer (state = $state)';

Future<List<String>> compact(List<String> lines) =>
    compactLogcat(Stream.fromIterable(lines)).toList();

void main() {
  test(
    'a decoder cleanup burst retains one warning and its total count',
    () async {
      final lines = [for (var slot = 10; slot < 64; slot++) bufferLine(slot)];
      expect(await compact(lines), [
        '${lines.first} [54 similar buffer cleanup messages]',
      ]);
    },
  );

  test('temporary ImageReader cleanup groups across milliseconds', () async {
    final first = bufferLine(13, surface: 'ImageReader-1x1f22u256m2-21719-1');
    expect(
      await compact([
        first,
        bufferLine(
          14,
          surface: 'ImageReader-1x1f22u256m2-21719-1',
          time: '12:03:11.234',
        ),
      ]),
      ['$first [2 similar buffer cleanup messages]'],
    );
  });

  test('cancellation errors retain their severity and operation', () async {
    final warning = bufferLine(63);
    final error = bufferLine(6, priority: 'E', operation: 'cancelBuffer');
    expect(
      await compact([
        warning,
        error,
        bufferLine(7, priority: 'E', operation: 'cancelBuffer'),
      ]),
      [warning, '$error [2 similar buffer cleanup messages]'],
    );
  });

  test('other surfaces and non-FREE states remain verbatim', () async {
    final lines = [
      for (final surface in [
        'SurfaceView',
        'ImageReader-640x480f23m4-21719-39',
        'ImageReader-1x10f22u256m2-21719-1',
      ])
        for (var slot = 0; slot < 2; slot++) bufferLine(slot, surface: surface),
      for (final state in ['ACQUIRED', 'QUEUED', 'DEQUEUED'])
        for (var slot = 0; slot < 2; slot++) bufferLine(slot, state: state),
      '09-20 12:03:11.233 E/BufferQueueProducer(21719): '
          '[MediaCodec.release] queueBuffer: BufferQueue has been abandoned',
    ];
    expect(await compact(lines), lines);
  });

  test(
    'distinct releases and intervening diagnostics remain separate',
    () async {
      final lines = [
        bufferLine(1),
        bufferLine(2, time: '12:03:12.233'),
        bufferLine(3, time: '12:03:12.233', queue: '54d700000032'),
        bufferLine(4, time: '12:03:12.233', process: '21720'),
        '09-20 12:03:12.234 W/cr_MediaCodecBridge(21719): Codec released',
        bufferLine(5, time: '12:03:12.233', process: '21720'),
      ];
      expect(await compact(lines), lines);
    },
  );

  test('crash traces and unrelated messages survive a cleanup burst', () async {
    final crash = [
      '09-20 12:03:11.234 E/AndroidRuntime(21719): FATAL EXCEPTION: main',
      'java.lang.IllegalStateException: codec failed',
      '    at example.Player.release(Player.java:42)',
      '',
      '09-20 12:05:15.951 W/kiosk_satellite(21719): Missing inline cache',
    ];
    expect(await compact([bufferLine(1), bufferLine(2), ...crash]), [
      '${bufferLine(1)} [2 similar buffer cleanup messages]',
      ...crash,
    ]);
  });

  test('empty logs and isolated warnings remain unchanged', () async {
    expect(await compact([]), isEmpty);
    expect(await compact([bufferLine(1)]), [bufferLine(1)]);
  });
}
