import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/wake_word/mww/micro_frontend.dart';
import 'package:kiosk_satellite/managers/wake_word/mww/native_micro_frontend.dart';

void main() {
  late Directory directory;
  late DynamicLibrary library;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kiosk-micro-frontend-');
    final path = '${directory.path}/libmicro_frontend.so';
    final result = await Process.run('g++', [
      '-std=c++17',
      '-shared',
      '-fPIC',
      '-O3',
      '-fsanitize=undefined',
      '-fno-sanitize-recover=all',
      'android/app/src/main/cpp/micro_fft.cpp',
      'android/app/src/main/cpp/micro_frontend.cpp',
      '-o',
      path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    library = DynamicLibrary.open(path);
  });
  tearDownAll(() => directory.delete(recursive: true));

  test('native features match the existing JS reference fixture exactly', () {
    final golden =
        jsonDecode(
              File(
                'test/fixtures/micro_frontend_golden.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final native = MicroFrontend(nativeLibrary: library);
    addTearDown(native.dispose);
    expect(native.usesNative, isTrue);
    var seed = 12345;
    final input = Int16List(golden['meta']['samples'] as int);
    for (var i = 0; i < input.length; i++) {
      seed = (seed * 1103515245 + 12345) & 0xffffffff;
      input[i] = (seed % 65536) - 32768;
    }
    expect(native.feedPcm16(input), golden['frames']);
  });

  test(
    'native and Dart features match through signals, fragments and resets',
    () {
      final reference = MicroFrontend(useNative: false);
      final native = MicroFrontend(nativeLibrary: library);
      final second = MicroFrontend(nativeLibrary: library);
      expect(native.usesNative, isTrue);
      addTearDown(reference.dispose);
      addTearDown(native.dispose);
      addTearDown(second.dispose);
      final random = math.Random(731);
      var offset = 0;
      for (var signal = 0; signal < 12; signal++) {
        reference.reset();
        native.reset();
        second.reset();
        for (var chunk = 0; chunk < 40; chunk++) {
          final size = [
            0,
            1,
            159,
            160,
            161,
            479,
            480,
            481,
            1280,
            8192,
          ][chunk % 10];
          final pcm = Int16List(size);
          for (var i = 0; i < size; i++, offset++) {
            pcm[i] = switch (signal) {
              0 => 0,
              1 => -32768,
              2 => 32767,
              3 => offset.isEven ? 32767 : -32768,
              4 => random.nextInt(3) - 1,
              5 => random.nextInt(256) - 128,
              6 => (math.sin(offset * 0.037) * 28000).round(),
              7 => offset % 97 == 0 ? -32768 : 0,
              8 => ((offset % 512) * 128) - 32768,
              // Loud and quiet spells move the noise estimate both ways.
              10 =>
                (offset ~/ 3000).isEven
                    ? random.nextInt(65536) - 32768
                    : random.nextInt(64) - 32,
              11 => (math.sin(offset * offset * 1e-7) * 20000).round(),
              _ => random.nextInt(65536) - 32768,
            };
          }
          final expected = reference.feedPcm16(pcm);
          final actual = native.feedPcm16(pcm);
          // Interleave another instance to check that native scratch is not shared.
          final alternate = second.feed([
            for (final value in pcm) value / 32768.0,
          ]);
          expect(actual.length, expected.length);
          expect(alternate.length, expected.length);
          for (var i = 0; i < expected.length; i++) {
            expect(
              actual[i].buffer.asUint8List(),
              expected[i].buffer.asUint8List(),
              reason: 'signal $signal, chunk $chunk, frame $i',
            );
            expect(
              alternate[i].buffer.asUint8List(),
              expected[i].buffer.asUint8List(),
            );
          }
          if (chunk == 17) {
            reference.reset();
            native.reset();
            second.reset();
          }
        }
      }
    },
  );

  test('missing symbol uses Dart and released native state is guarded', () {
    final fallback = MicroFrontend(nativeLibrary: DynamicLibrary.process());
    addTearDown(fallback.dispose);
    expect(fallback.usesNative, isFalse);
    expect(fallback.feedPcm16(Int16List(480)), hasLength(1));

    final native = MicroFrontend(nativeLibrary: library);
    expect(native.feedPcm16(Int16List(480)), hasLength(1));
    native.dispose();
    native.dispose();
    expect(() => native.feedPcm16(Int16List(480)), throwsStateError);

    final tables = sharedTables();
    final fb = tables.filterbank;
    NativeMicroFrontend? create(Int16List fftTables, Int16List widths) =>
        NativeMicroFrontend.tryCreate(
          window: tables.windowCoefficients,
          channelFrequencyStarts: fb.channelFrequencyStarts,
          channelWeightStarts: fb.channelWeightStarts,
          channelWidths: widths,
          weights: fb.weights,
          unweights: fb.unweights,
          fftTables: fftTables,
          gainLut: tables.gainLut,
          logLut: kLogLut,
          evenSmoothing: kNoiseReductionEvenSmoothing,
          oddSmoothing: kNoiseReductionOddSmoothing,
          minSignal: kNoiseReductionMinSignal,
          featureSize: kFeatureSize,
          stepSize: kStepSize,
          library: library,
        );
    expect(create(Int16List(767), fb.channelWidths), isNull);
    // A channel reaching past the spectrum is refused, not read out of bounds.
    final wide = Int16List.fromList(fb.channelWidths)..[40] = 300;
    expect(create(Int16List(768), wide), isNull);
  });
}
