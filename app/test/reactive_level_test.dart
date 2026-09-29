import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/voice/reactive_level.dart';

/// 80 ms of 16 kHz PCM16: a tone at [amplitude] of full scale.
Uint8List _tone(double amplitude, {double hz = 800}) {
  final data = ByteData(1280 * 2);
  for (var i = 0; i < 1280; i++) {
    final x = amplitude * math.sin(2 * math.pi * hz * i / 16000);
    data.setInt16(i * 2, (x * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('playback runs at Voice Satellite\'s native gain', () {
    final levels = ReactiveLevel();
    expect(levels.playback(0), 0);
    expect(levels.playback(0.1), closeTo(0.22, 1e-9));
    expect(levels.playback(0.8), 1);
  });

  test('an 80 ms chunk moves the bar four times', () {
    final levels = ReactiveLevel();
    for (var i = 0; i < 20; i++) {
      expect(levels.micSlices(_tone(0.002)), [0, 0, 0, 0]);
    }
    final speech = levels.micSlices(_tone(0.2));
    expect(speech, hasLength(4));
    expect(speech.every((level) => level > 0.5), isTrue);
  });

  test('a quiet room stays dark and speech lights the bar', () {
    final levels = ReactiveLevel();
    for (var i = 0; i < 20; i++) {
      expect(levels.mic(_tone(0.002)), 0, reason: 'room noise');
    }
    final speech = levels.mic(_tone(0.2));
    expect(speech, greaterThan(0.5));
    expect(speech, lessThanOrEqualTo(1));
  });

  test('a capture 30 dB down still moves the bar', () {
    final levels = ReactiveLevel();
    for (var i = 0; i < 20; i++) {
      levels.mic(_tone(0.0002));
    }
    // What the absolute mapping alone would leave dark.
    expect(levels.mic(_tone(0.006)), greaterThan(0.3));
  });
}
