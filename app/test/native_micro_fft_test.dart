import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/wake_word/mww/micro_frontend.dart';
import 'package:kiosk_satellite/managers/wake_word/mww/native_micro_fft.dart';

void main() {
  late Directory directory;
  late DynamicLibrary library;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kiosk-micro-fft-');
    final path = '${directory.path}/libmicro_fft.so';
    final result = await Process.run('g++', [
      '-std=c++17',
      '-shared',
      '-fPIC',
      '-O3',
      '-fsanitize=undefined',
      '-fno-sanitize-recover=all',
      'android/app/src/main/cpp/micro_fft.cpp',
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
    final native = MicroFrontend(fftLibrary: library);
    addTearDown(native.dispose);
    expect(native.usesNativeFft, isTrue);
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
      final reference = MicroFrontend(useNativeFft: false);
      final native = MicroFrontend(fftLibrary: library);
      final second = MicroFrontend(fftLibrary: library);
      addTearDown(reference.dispose);
      addTearDown(native.dispose);
      addTearDown(second.dispose);
      final random = math.Random(731);
      var offset = 0;
      for (var signal = 0; signal < 10; signal++) {
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

  test('missing symbol uses Dart and native storage guards invalid access', () {
    final fallback = MicroFrontend(fftLibrary: DynamicLibrary.process());
    addTearDown(fallback.dispose);
    expect(fallback.usesNativeFft, isFalse);
    expect(fallback.feedPcm16(Int16List(480)), hasLength(1));
    final plan = sharedTables().fftPlan;
    final native = NativeMicroFft.tryCreate(
      plan.twCos,
      plan.twSin,
      plan.stCos,
      plan.stSin,
      library: library,
    )!;
    expect(
      () => native.forward(Int16List(511), Int16List(257), Int16List(257)),
      throwsArgumentError,
    );
    native.release();
    native.release();
    expect(
      () => native.forward(Int16List(512), Int16List(257), Int16List(257)),
      throwsStateError,
    );
    expect(
      NativeMicroFft.tryCreate(
        Int16List(1),
        plan.twSin,
        plan.stCos,
        plan.stSin,
        library: library,
      ),
      isNull,
    );
  });
}
