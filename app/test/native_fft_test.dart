import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/wake_word/vsww/log_mel.dart';
import 'package:kiosk_satellite/managers/wake_word/vsww/manifest.dart';
import 'package:kiosk_satellite/managers/wake_word/vsww/native_fft.dart';

void main() {
  late Directory directory;
  late DynamicLibrary library;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kiosk-native-fft-');
    final path = '${directory.path}/libkiosk_wake_fft.so';
    final result = await Process.run('g++', [
      '-shared',
      '-fPIC',
      '-O3',
      '-fno-fast-math',
      '-ffp-contract=off',
      'android/app/src/main/cpp/wake_fft.cpp',
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
        final reference = LogMelExtractor(config, useNativeFft: false);
        final native = LogMelExtractor(config, fftLibrary: library);
        expect(native.usesNativeFft, isTrue);
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
      fftLibrary: DynamicLibrary.process(),
    );
    expect(extractor.usesNativeFft, isFalse);
    expect(extractor.extract(Float32List(20800)), hasLength(5120));
    extractor.dispose();
  });

  test('native input sizes and released memory are guarded', () {
    final cosine = Float64List(512);
    final sine = Float64List(512);
    final reverse = Uint32List(512);
    final native = NativeFft.tryCreate(
      cosine,
      sine,
      reverse,
      library: library,
    )!;
    expect(
      () => native.forward(Float64List(511), Float64List(512)),
      throwsArgumentError,
    );
    native.release();
    native.release();
    expect(() => native.forward(cosine, sine), throwsStateError);
    expect(
      NativeFft.tryCreate(
        Float64List(3),
        Float64List(3),
        Uint32List(3),
        library: library,
      ),
      isNull,
    );
  });
}
