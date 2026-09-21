import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _ForwardNative =
    Void Function(
      Int32,
      Pointer<Double>,
      Pointer<Double>,
      Pointer<Double>,
      Pointer<Double>,
      Pointer<Uint32>,
    );
typedef _Forward =
    void Function(
      int,
      Pointer<Double>,
      Pointer<Double>,
      Pointer<Double>,
      Pointer<Double>,
      Pointer<Uint32>,
    );

/// The same radix-2 FFT as the Dart frontend, with reusable native storage.
final class NativeFft implements Finalizable {
  NativeFft._(this._forward, this._n, this._storage);

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

  /// A supplied library lets tests exercise the native path on the host.
  /// Missing libraries retain the Dart implementation on other platforms.
  static NativeFft? tryCreate(
    Float64List cosine,
    Float64List sine,
    Uint32List reverse, {
    DynamicLibrary? library,
  }) {
    final lib = library ?? _library;
    if (lib == null) return null;
    final n = cosine.length;
    if (n < 2 ||
        n > 4096 ||
        (n & (n - 1)) != 0 ||
        sine.length != n ||
        reverse.length != n) {
      return null;
    }
    final _Forward forward;
    try {
      forward = lib.lookupFunction<_ForwardNative, _Forward>('ks_wake_fft');
    } catch (_) {
      return null;
    }
    final storage = calloc<Uint8>(n * 36);
    try {
      final fft = NativeFft._(forward, n, storage);
      fft._cosine.asTypedList(n).setAll(0, cosine);
      fft._sine.asTypedList(n).setAll(0, sine);
      fft._reverse.asTypedList(n).setAll(0, reverse);
      _finalizer.attach(fft, storage.cast(), detach: fft);
      return fft;
    } catch (_) {
      calloc.free(storage);
      rethrow;
    }
  }

  final _Forward _forward;
  final int _n;
  final Pointer<Uint8> _storage;
  bool _released = false;
  Pointer<Double> get _real => _storage.cast();
  Pointer<Double> get _imaginary => (_storage + _n * 8).cast();
  Pointer<Double> get _cosine => (_storage + _n * 16).cast();
  Pointer<Double> get _sine => (_storage + _n * 24).cast();
  Pointer<Uint32> get _reverse => (_storage + _n * 32).cast();
  late final _realView = _real.asTypedList(_n);
  late final _imaginaryView = _imaginary.asTypedList(_n);

  void forward(Float64List real, Float64List imaginary) {
    if (_released) throw StateError('FFT released');
    if (real.length != _n || imaginary.length != _n) {
      throw ArgumentError('FFT input length must be $_n');
    }
    _realView.setAll(0, real);
    _imaginaryView.setAll(0, imaginary);
    _forward(_n, _real, _imaginary, _cosine, _sine, _reverse);
    real.setAll(0, _realView);
    imaginary.setAll(0, _imaginaryView);
  }

  void release() {
    if (_released) return;
    _released = true;
    _finalizer.detach(this);
    calloc.free(_storage);
  }
}
