import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/audio/mic_level_monitor.dart';

Uint8List _pcm(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  final monitor = MicLevelMonitor.instance;
  final source = monitor.source;

  setUp(() => monitor.linger = Duration.zero);
  tearDown(() => monitor.source = source);

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('rms is on the engines\' 0..1 scale', () {
    expect(MicLevelMonitor.rmsOf(_pcm([0, 0, 0, 0])), 0);
    expect(MicLevelMonitor.rmsOf(_pcm([16384, -16384])), closeTo(0.5, 1e-9));
    expect(MicLevelMonitor.rmsOf(_pcm([-32768])), closeTo(1, 1e-9));
    expect(MicLevelMonitor.rmsOf(Uint8List(0)), 0);
  });

  test('rms reads a chunk that starts at an odd offset', () {
    final backing = Uint8List(5);
    final chunk = Uint8List.sublistView(backing, 1);
    ByteData.sublistView(chunk).setInt16(0, 16384, Endian.little);
    ByteData.sublistView(chunk).setInt16(2, 16384, Endian.little);
    expect(MicLevelMonitor.rmsOf(chunk), closeTo(0.5, 1e-9));
  });

  test(
    'capture opens for the first watcher and closes after the last',
    () async {
      var opens = 0;
      var closes = 0;
      late StreamController<Uint8List> capture;
      monitor.source = () {
        opens++;
        capture = StreamController<Uint8List>(onCancel: () => closes++);
        return capture.stream;
      };
      final levels = <double>[];
      final sub = monitor.levels.listen(levels.add);

      monitor.start();
      monitor.start();
      await settle();
      expect(opens, 1);

      capture.add(_pcm([16384, -16384]));
      await settle();
      expect(levels.single, closeTo(0.5, 1e-9));

      monitor.stop();
      await settle();
      expect(closes, 0, reason: 'a second watcher still holds it');
      expect(monitor.watching, isTrue);

      monitor.stop();
      await settle();
      expect(closes, 1);
      expect(monitor.watching, isFalse);

      monitor.stop();
      expect(monitor.watching, isFalse, reason: 'an extra stop is a no-op');
      await sub.cancel();
    },
  );

  test('a watcher that returns within the linger keeps the capture', () async {
    monitor.linger = const Duration(milliseconds: 50);
    var opens = 0;
    var closes = 0;
    monitor.source = () {
      opens++;
      return StreamController<Uint8List>(onCancel: () => closes++).stream;
    };
    monitor.start();
    await settle();
    monitor.stop();
    monitor.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(opens, 1);
    expect(closes, 0);
    monitor.stop();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(closes, 1);
  });

  test('a refused capture leaves the meter dark instead of throwing', () async {
    monitor.source = () => Stream<Uint8List>.error(StateError('permission'));
    final levels = <double>[];
    final sub = monitor.levels.listen(levels.add);
    monitor.start();
    await settle();
    expect(levels, isEmpty);
    monitor.stop();
    await sub.cancel();
  });
}
