import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _ForwardNative =
    Void Function(Pointer<Int16>, Pointer<Int16>, Pointer<Int16>);
typedef _Forward =
    void Function(Pointer<Int16>, Pointer<Int16>, Pointer<Int16>);

/// Fixed-point 512-point real FFT with the Dart frontend's exact coefficients.
final class NativeMicroFft implements Finalizable {
  NativeMicroFft._(this._forward, this._storage);

  static final _finalizer = NativeFinalizer(calloc.nativeFree);
  static final DynamicLibrary? _library = _load();

  static DynamicLibrary? _load() {
    if (!Platform.isAndroid) return null;
    try {
      return DynamicLibrary.open('libkiosk_wake_fft.so');
    } catch (_) {
      return null;
    }
  }

  static NativeMicroFft? tryCreate(
    Int16List cosine,
    Int16List sine,
    Int16List realCosine,
    Int16List realSine, {
    DynamicLibrary? library,
  }) {
    final lib = library ?? _library;
    if (lib == null ||
        cosine.length != 256 ||
        sine.length != 256 ||
        realCosine.length != 128 ||
        realSine.length != 128) {
      return null;
    }
    final _Forward forward;
    try {
      forward = lib.lookupFunction<_ForwardNative, _Forward>('ks_mww_fft');
    } catch (_) {
      return null;
    }
    final storage = calloc<Int16>(2306);
    try {
      final fft = NativeMicroFft._(forward, storage);
      final tables = fft._tables.asTypedList(768);
      tables.setAll(0, cosine);
      tables.setAll(256, sine);
      tables.setAll(512, realCosine);
      tables.setAll(640, realSine);
      _finalizer.attach(fft, storage.cast(), detach: fft);
      return fft;
    } catch (_) {
      calloc.free(storage);
      rethrow;
    }
  }

  final _Forward _forward;
  final Pointer<Int16> _storage;
  Pointer<Int16> get _tables => _storage + 1026;
  Pointer<Int16> get _scratch => _storage + 1794;
  late final _input = _storage.asTypedList(512);
  late final _real = (_storage + 512).asTypedList(257);
  late final _imaginary = (_storage + 769).asTypedList(257);
  bool _released = false;

  void forward(Int16List input, Int16List real, Int16List imaginary) {
    if (_released) throw StateError('FFT released');
    if (input.length != 512 || real.length != 257 || imaginary.length != 257) {
      throw ArgumentError('FFT requires 512 samples and 257 output bins');
    }
    _input.setAll(0, input);
    _forward(_storage, _tables, _scratch);
    real.setAll(0, _real);
    imaginary.setAll(0, _imaginary);
  }

  void release() {
    if (_released) return;
    _released = true;
    _finalizer.detach(this);
    calloc.free(_storage);
  }
}
