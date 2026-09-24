import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _CreateNative =
    Pointer<Void> Function(
      Pointer<Int16>,
      Pointer<Int16>,
      Pointer<Int16>,
      Pointer<Int16>,
      Pointer<Int16>,
      Pointer<Int16>,
      Int32,
      Pointer<Int16>,
      Pointer<Int16>,
      Int32,
      Pointer<Int32>,
      Int32,
      Int32,
      Int32,
      Int32,
    );
typedef _Create =
    Pointer<Void> Function(
      Pointer<Int16>,
      Pointer<Int16>,
      Pointer<Int16>,
      Pointer<Int16>,
      Pointer<Int16>,
      Pointer<Int16>,
      int,
      Pointer<Int16>,
      Pointer<Int16>,
      int,
      Pointer<Int32>,
      int,
      int,
      int,
      int,
    );
typedef _FeedNative = Int32 Function(Pointer<Void>, Int32);
typedef _Feed = int Function(Pointer<Void>, int);
typedef _StateNative = Void Function(Pointer<Void>);
typedef _State = void Function(Pointer<Void>);

/// The microWakeWord frontend after PCM16 input, in native code: window, FFT,
/// filterbank, noise reduction, PCAN and log scale. Built from the Dart
/// frontend's own tables and bit-exact with it.
///
/// The native state owns fixed batch buffers (one 80 ms chunk in, its rows
/// out), so one finalizer frees everything and a chunk costs two small copies.
final class NativeMicroFrontend implements Finalizable {
  NativeMicroFrontend._(
    this._state,
    this._feed,
    this._reset,
    this._free,
    this._finalizer,
    this._featureSize,
    this._batch,
    this._pcm,
    this._rowsOut,
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

  /// Null when the library, a symbol or the table layout does not fit: the
  /// caller keeps the Dart frontend.
  static NativeMicroFrontend? tryCreate({
    required Int16List window,
    required Int16List channelFrequencyStarts,
    required Int16List channelWeightStarts,
    required Int16List channelWidths,
    required Int16List weights,
    required Int16List unweights,
    required Int16List fftTables,
    required Int16List gainLut,
    required List<int> logLut,
    required int evenSmoothing,
    required int oddSmoothing,
    required int minSignal,
    required int featureSize,
    required int stepSize,
    DynamicLibrary? library,
  }) {
    final lib = library ?? _library;
    if (lib == null || fftTables.length != 768) return null;
    final _Create create;
    final _Feed feed;
    final _State reset;
    final Pointer<NativeFunction<_StateNative>> free;
    final Pointer<Int16> Function(Pointer<Void>) pcmOf;
    final Pointer<Float> Function(Pointer<Void>) rowsOf;
    final int batch;
    try {
      create = lib.lookupFunction<_CreateNative, _Create>(
        'ks_mww_frontend_create',
      );
      feed = lib.lookupFunction<_FeedNative, _Feed>(
        'ks_mww_frontend_feed',
        isLeaf: true,
      );
      reset = lib.lookupFunction<_StateNative, _State>(
        'ks_mww_frontend_reset',
        isLeaf: true,
      );
      free = lib.lookup<NativeFunction<_StateNative>>('ks_mww_frontend_free');
      pcmOf = lib
          .lookupFunction<
            Pointer<Int16> Function(Pointer<Void>),
            Pointer<Int16> Function(Pointer<Void>)
          >('ks_mww_frontend_pcm');
      rowsOf = lib
          .lookupFunction<
            Pointer<Float> Function(Pointer<Void>),
            Pointer<Float> Function(Pointer<Void>)
          >('ks_mww_frontend_rows');
      batch = lib.lookupFunction<Int32 Function(), int Function()>(
        'ks_mww_frontend_batch',
      )();
    } catch (_) {
      return null;
    }
    final state = using((arena) {
      Pointer<Int16> copy16(Int16List data) {
        final p = arena<Int16>(data.isEmpty ? 1 : data.length);
        p.asTypedList(data.length).setAll(0, data);
        return p;
      }

      final log = arena<Int32>(logLut.length);
      log.asTypedList(logLut.length).setAll(0, logLut);
      return create(
        copy16(window),
        copy16(channelFrequencyStarts),
        copy16(channelWeightStarts),
        copy16(channelWidths),
        copy16(weights),
        copy16(unweights),
        weights.length,
        copy16(fftTables),
        copy16(gainLut),
        gainLut.length,
        log,
        logLut.length,
        evenSmoothing,
        oddSmoothing,
        minSignal,
      );
    });
    if (state == nullptr) return null;
    final finalizer = _finalizers.putIfAbsent(
      free.address,
      () => NativeFinalizer(free),
    );
    final native = NativeMicroFrontend._(
      state,
      feed,
      reset,
      free.asFunction<_State>(),
      finalizer,
      featureSize,
      batch,
      pcmOf(state).asTypedList(batch),
      rowsOf(state).asTypedList((batch ~/ stepSize + 1) * featureSize),
    );
    finalizer.attach(native, state, detach: native);
    return native;
  }

  final Pointer<Void> _state;
  final _Feed _feed;
  final _State _reset;
  final _State _free;
  final NativeFinalizer _finalizer;
  final int _featureSize;
  final int _batch;
  final Int16List _pcm;
  final Float32List _rowsOut;
  bool _released = false;

  /// Dart-owned rows handed out by [feed], grown to the most one call made.
  final List<Float32List> _rows = [];
  final List<Float32List> _results = [];

  /// Feed PCM16 and return one feature row per completed 10 ms step. The list
  /// and its rows are reused by the next call.
  List<Float32List> feed(Int16List pcm) {
    if (_released) throw StateError('frontend released');
    _results.clear();
    for (var offset = 0; offset < pcm.length; offset += _batch) {
      final end = offset + _batch < pcm.length ? offset + _batch : pcm.length;
      _pcm.setRange(0, end - offset, pcm, offset);
      final frames = _feed(_state, end - offset);
      for (var f = 0; f < frames; f++) {
        if (_results.length == _rows.length) {
          _rows.add(Float32List(_featureSize));
        }
        final row = _rows[_results.length];
        row.setRange(0, _featureSize, _rowsOut, f * _featureSize);
        _results.add(row);
      }
    }
    return _results;
  }

  void reset() {
    if (_released) throw StateError('frontend released');
    _reset(_state);
  }

  void release() {
    if (_released) return;
    _released = true;
    _finalizer.detach(this);
    _free(_state);
  }
}
