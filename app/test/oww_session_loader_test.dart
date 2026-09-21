import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:kiosk_satellite/managers/wake_word/oww/oww_session_loader.dart';

class _Options implements OrtSessionOptions {
  _Options({this.providerAvailable = true, this.providerError});
  final bool providerAvailable;
  final Object? providerError;
  int? intraThreads;
  int? interThreads;
  int appendCalls = 0;
  int releases = 0;
  @override
  void setIntraOpNumThreads(int value) => intraThreads = value;
  @override
  void setInterOpNumThreads(int value) => interThreads = value;
  @override
  bool appendXnnpackProvider() {
    appendCalls++;
    if (providerError != null) throw providerError!;
    return providerAvailable;
  }

  @override
  void release() => releases++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements OrtSession {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('XNNPACK keeps one thread and releases session options', () {
    final options = _Options();
    final session = _Session();
    final bytes = Uint8List.fromList([1, 2, 3]);
    final loader = OwwSessionLoader(
      optionsFactory: () => options,
      sessionFactory: (model, configuration) {
        expect(identical(model, bytes), isTrue);
        expect(identical(configuration, options), isTrue);
        expect(options.intraThreads, 1);
        expect(options.interThreads, 1);
        expect(options.appendCalls, 1);
        expect(options.releases, 0);
        return session;
      },
      onFallback: (_) => fail('XNNPACK should load'),
    );
    expect(identical(loader.load(bytes), session), isTrue);
    expect(options.releases, 1);
  });

  for (final failure in [
    'provider exception',
    'provider unavailable',
    'session failure',
  ]) {
    test('$failure retries with fresh CPU options after cleanup', () {
      final primary = _Options(
        providerError: failure == 'provider exception'
            ? StateError('unsupported')
            : null,
        providerAvailable: failure != 'provider unavailable',
      );
      final fallback = _Options();
      final session = _Session();
      final bytes = Uint8List.fromList([1]);
      var optionCalls = 0;
      final errors = <Object>[];
      final loader = OwwSessionLoader(
        optionsFactory: () {
          if (optionCalls++ == 0) return primary;
          expect(primary.releases, 1);
          return fallback;
        },
        sessionFactory: (model, options) {
          expect(identical(model, bytes), isTrue);
          if (identical(options, primary)) throw StateError('partition failed');
          expect(fallback.appendCalls, 0);
          expect(fallback.intraThreads, 1);
          expect(fallback.interThreads, 1);
          return session;
        },
        onFallback: errors.add,
      );
      expect(identical(loader.load(bytes), session), isTrue);
      expect(optionCalls, 2);
      expect(primary.releases, 1);
      expect(fallback.releases, 1);
      expect(errors, hasLength(1));
    });
  }

  test('CPU failure propagates after both options objects are released', () {
    final options = [_Options(), _Options()];
    final failure = StateError('invalid model');
    var calls = 0;
    final loader = OwwSessionLoader(
      optionsFactory: () => options[calls++],
      sessionFactory: (_, _) => throw failure,
    );
    expect(() => loader.load(Uint8List(0)), throwsA(same(failure)));
    expect(calls, 2);
    expect(options.map((o) => o.releases), [1, 1]);
  });
}
