import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/wake_word/vsww/log_mel.dart';
import 'package:kiosk_satellite/managers/wake_word/vsww/manifest.dart';

void main() {
  late Directory directory;
  late DynamicLibrary library;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kiosk-native-log-mel-');
    final path = '${directory.path}/libkiosk_wake_fft.so';
    final result = await Process.run('g++', [
      '-shared',
      '-fPIC',
      '-O3',
      '-fno-fast-math',
      '-ffp-contract=off',
      'android/app/src/main/cpp/wake_fft.cpp',
      'android/app/src/main/cpp/log_mel.cpp',
      '-o',
      path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    library = DynamicLibrary.open(path);
  });
  tearDownAll(() => directory.delete(recursive: true));

  test(
    'native features match Dart bit for bit across signals and window shifts',
    () {
      for (final fftSize in [256, 512, 1024]) {
        final config = VswwFeatureConfig(
          sampleRate: 16000,
          nFft: fftSize,
          nMels: 40,
          fMin: 80,
          fMax: 7600,
          logFloor: 1e-6,
          frameSamples: fftSize == 256 ? 200 : 400,
          hopSamples: 160,
          windowSamples: fftSize == 256 ? 20520 : 20800,
          frames: 128,
        );
        final reference = LogMelExtractor(config, useNative: false);
        final native = LogMelExtractor(config, nativeLibrary: library);
        expect(native.usesNative, isTrue);
        final random = math.Random(53);
        final audio = Float32List(config.windowSamples);
        for (var signal = 0; signal < 6; signal++) {
          for (var frame = 0; frame < 8; frame++) {
            final shift = [0, 160, 1280, 1279, 20800, 2560, 1280, 160][frame];
            if (shift < audio.length) {
              audio.setRange(0, audio.length - shift, audio, shift);
            }
            for (
              var i = math.max(0, audio.length - shift);
              i < audio.length;
              i++
            ) {
              audio[i] = switch (signal) {
                0 => 0,
                1 => (random.nextDouble() * 2 - 1) * 0.0001,
                2 => math.sin(i * 0.017) * 0.3 + math.sin(i * 0.031) * 0.2,
                3 => i.isEven ? 1.0 : -1.0,
                4 => i % 400 == 0 ? 1 : 0,
                _ => random.nextDouble() * 2 - 1,
              };
            }
            final expected = reference.extract(
              audio,
              newSamples: frame == 0 ? -1 : shift,
            );
            final actual = native.extract(
              audio,
              newSamples: frame == 0 ? -1 : shift,
            );
            expect(
              actual.buffer.asUint8List(),
              expected.buffer.asUint8List(),
              reason: 'FFT $fftSize, signal $signal, shift $shift',
            );
          }
        }
        native.dispose();
        native.dispose();
        reference.dispose();
        expect(() => native.extract(audio), throwsStateError);
      }
    },
  );

  test('missing symbol falls back to Dart', () {
    const config = VswwFeatureConfig(
      sampleRate: 16000,
      nFft: 512,
      nMels: 40,
      fMin: 80,
      fMax: 7600,
      logFloor: 1e-6,
      frameSamples: 400,
      hopSamples: 160,
      windowSamples: 20800,
      frames: 128,
    );
    final extractor = LogMelExtractor(
      config,
      nativeLibrary: DynamicLibrary.process(),
    );
    expect(extractor.usesNative, isFalse);
    expect(extractor.extract(Float32List(20800)), hasLength(5120));
    extractor.dispose();
  });

  test('ring windows match the unrolled window in both paths', () {
    const config = VswwFeatureConfig(
      sampleRate: 16000,
      nFft: 512,
      nMels: 40,
      fMin: 80,
      fMax: 7600,
      logFloor: 1e-6,
      frameSamples: 400,
      hopSamples: 160,
      windowSamples: 20800,
      frames: 128,
    );
    final n = config.windowSamples;
    final unrolled = LogMelExtractor(config, useNative: false);
    final dartRing = LogMelExtractor(config, useNative: false);
    final nativeRing = LogMelExtractor(config, nativeLibrary: library);
    expect(nativeRing.usesNative, isTrue);
    final random = math.Random(91);
    final ring = Float32List(n);
    final window = Float32List(n);
    var head = 0;
    for (var chunk = 0; chunk < 40; chunk++) {
      // Chunks of 1280 walk the head through every hop phase of the ring.
      for (var i = 0; i < 1280; i++) {
        ring[head] = chunk % 5 == 0
            ? 0
            : (random.nextDouble() * 2 - 1) * (chunk.isEven ? 1 : 0.001);
        head = (head + 1) % n;
      }
      window.setRange(0, n - head, ring, head);
      window.setRange(n - head, n, ring, 0);
      final newSamples = chunk == 0 ? -1 : 1280;
      final expected = unrolled.extract(window, newSamples: newSamples);
      final dart = dartRing.extractRing(ring, head, newSamples: newSamples);
      final native = nativeRing.extractRing(ring, head, newSamples: newSamples);
      expect(
        dart.buffer.asUint8List(),
        expected.buffer.asUint8List(),
        reason: 'Dart ring, chunk $chunk',
      );
      expect(
        native.buffer.asUint8List(),
        expected.buffer.asUint8List(),
        reason: 'native ring, chunk $chunk',
      );

      var sum = 0.0;
      for (var i = 0; i < n; i++) {
        sum += window[i] * window[i];
      }
      expect(dartRing.sumSquares(ring, head), sum, reason: 'chunk $chunk');
      expect(nativeRing.sumSquares(ring, head), sum, reason: 'chunk $chunk');
    }
    unrolled.dispose();
    dartRing.dispose();
    nativeRing.dispose();
  });
}
