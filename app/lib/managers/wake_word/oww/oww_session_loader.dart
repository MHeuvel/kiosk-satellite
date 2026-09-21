import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

/// Prefer single-threaded XNNPACK and retry with CPU if session setup fails.
/// Factories allow resource cleanup and fallback tests without a native runtime.
class OwwSessionLoader {
  OwwSessionLoader({
    this.onFallback,
    this.optionsFactory = OrtSessionOptions.new,
    this.sessionFactory = OrtSession.fromBuffer,
  });

  final void Function(Object error)? onFallback;
  final OrtSessionOptions Function() optionsFactory;
  final OrtSession Function(Uint8List bytes, OrtSessionOptions options)
  sessionFactory;

  OrtSession load(Uint8List bytes) {
    try {
      return _load(bytes, xnnpack: true);
    } catch (error) {
      onFallback?.call(error);
      return _load(bytes, xnnpack: false);
    }
  }

  OrtSession _load(Uint8List bytes, {required bool xnnpack}) {
    final options = optionsFactory();
    try {
      options
        ..setIntraOpNumThreads(1)
        ..setInterOpNumThreads(1);
      if (xnnpack && !options.appendXnnpackProvider()) {
        throw StateError('XNNPACK is unavailable');
      }
      return sessionFactory(bytes, options);
    } finally {
      options.release();
    }
  }
}
