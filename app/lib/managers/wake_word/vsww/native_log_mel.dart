import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _CreateNative =
    Pointer<Void> Function(
      Int32,
      Int32,
      Int32,
      Int32,
      Int32,
      Int32,
      Double,
      Pointer<Float>,
      Pointer<Int32>,
      Pointer<Int32>,
      Pointer<Float>,
      Pointer<Double>,
      Pointer<Double>,
      Pointer<Uint32>,
    );
typedef _Create =
    Pointer<Void> Function(
      int,
      int,
      int,
      int,
      int,
      int,
      double,
      Pointer<Float>,
      Pointer<Int32>,
      Pointer<Int32>,
      Pointer<Float>,
      Pointer<Double>,
      Pointer<Double>,
      Pointer<Uint32>,
    );
typedef _BufferNative = Pointer<Float> Function(Pointer<Void>);
typedef _FramesNative = Void Function(Pointer<Void>, Int32, Int32);
typedef _Frames = void Function(Pointer<Void>, int, int);
typedef _SumSquaresNative = Double Function(Pointer<Void>, Int32);
typedef _SumSquares = double Function(Pointer<Void>, int);
typedef _FreeNative = Void Function(Pointer<Void>);

/// The log-mel frame math of [LogMelExtractor] in native code.
///
/// The plan owns the audio ring and the feature rows; Dart reads and writes
/// them through [ring] and [features], so a chunk costs one copy into the ring
/// and no per-frame traffic. Same tables, same operations in the same order, so
/// the features match the Dart path bit for bit.
final class NativeLogMel implements Finalizable {
  NativeLogMel._(
    this._plan,
    this._frames,
    this._sumSquares,
    this._finalizer,
    this._free,
    this.ring,
    this.features,
  );

  static final DynamicLibrary? _library = _load();

  static DynamicLibrary? _load() {
    if (!Platform.isAndroid) return null;
    try {
      return DynamicLibrary.open('libkiosk_wake_fft.so');
    } catch (_) {
      return null;
    }
  }

  /// One finalizer per loaded library's free function, kept alive here.
  static final _finalizers = <int, NativeFinalizer>{};

  /// A supplied library lets tests exercise the native path on the host.
  /// Null when the library or its symbols are missing: the caller keeps its
  /// Dart implementation.
  static NativeLogMel? tryCreate({
    required int windowSamples,
    required int frameSamples,
    required int hopSamples,
    required int nFft,
    required int frames,
    required int nMels,
    required double logFloor,
    required Float32List window,
    required Int32List filterLo,
    required Int32List filterHi,
    required Float32List filterCoefficients,
    required Float64List cosine,
    required Float64List sine,
    required Uint32List reverse,
    DynamicLibrary? library,
  }) {
    final lib = library ?? _library;
    if (lib == null) return null;
    final _Create create;
    final _Frames framesFn;
    final _SumSquares sumSquares;
    final Pointer<Float> Function(Pointer<Void>) ringOf, featuresOf;
    final Pointer<NativeFunction<_FreeNative>> free;
    try {
      create = lib.lookupFunction<_CreateNative, _Create>('ks_vsww_create');
      framesFn = lib.lookupFunction<_FramesNative, _Frames>(
        'ks_vsww_frames',
        isLeaf: true,
      );
      sumSquares = lib.lookupFunction<_SumSquaresNative, _SumSquares>(
        'ks_vsww_sum_squares',
        isLeaf: true,
      );
      ringOf = lib.lookupFunction<_BufferNative, _BufferNative>('ks_vsww_ring');
      featuresOf = lib.lookupFunction<_BufferNative, _BufferNative>(
        'ks_vsww_features',
      );
      free = lib.lookup<NativeFunction<_FreeNative>>('ks_vsww_free');
    } catch (_) {
      return null;
    }
    final plan = using((arena) {
      Pointer<T> copy<T extends NativeType>(TypedData data) {
        final bytes = data.lengthInBytes;
        final p = arena<Uint8>(bytes == 0 ? 1 : bytes);
        p
            .asTypedList(bytes)
            .setAll(0, data.buffer.asUint8List(data.offsetInBytes, bytes));
        return p.cast();
      }

      return create(
        windowSamples,
        frameSamples,
        hopSamples,
        nFft,
        frames,
        nMels,
        logFloor,
        copy<Float>(window),
        copy<Int32>(filterLo),
        copy<Int32>(filterHi),
        copy<Float>(filterCoefficients),
        copy<Double>(cosine),
        copy<Double>(sine),
        copy<Uint32>(reverse),
      );
    });
    if (plan == nullptr) return null;
    final finalizer = _finalizers.putIfAbsent(
      free.address,
      () => NativeFinalizer(free),
    );
    final native = NativeLogMel._(
      plan,
      framesFn,
      sumSquares,
      finalizer,
      free.asFunction<void Function(Pointer<Void>)>(),
      ringOf(plan).asTypedList(windowSamples),
      featuresOf(plan).asTypedList(frames * nMels),
    );
    finalizer.attach(native, plan, detach: native);
    return native;
  }

  final Pointer<Void> _plan;
  final _Frames _frames;
  final _SumSquares _sumSquares;
  final NativeFinalizer _finalizer;
  final void Function(Pointer<Void>) _free;
  bool _released = false;

  /// The audio window the frames are computed from, as a ring. Invalid after
  /// [release].
  final Float32List ring;

  /// Feature rows, frame-major. Invalid after [release].
  final Float32List features;

  /// Compute rows [first, frames) of [features] from the window that starts
  /// at `ring[head]` and wraps at the ring's end.
  void frames(int head, int first) {
    if (_released) throw StateError('log-mel released');
    _frames(_plan, head, first);
  }

  /// Sum of squares over the same window, in window order.
  double sumSquares(int head) {
    if (_released) throw StateError('log-mel released');
    return _sumSquares(_plan, head);
  }

  void release() {
    if (_released) return;
    _released = true;
    _finalizer.detach(this);
    _free(_plan);
  }
}
