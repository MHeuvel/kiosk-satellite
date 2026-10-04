import 'dart:async';

import 'package:flutter/services.dart';

import 'pcm_resampler.dart';

/// Where a realtime session's voice plays: a streaming track on the
/// communication route (RealtimeAudio.kt), so the echo canceller hears it.
abstract class RealtimePlayerPort {
  /// Opens the track for PCM16 mono at [sampleRate]. False when it could
  /// not.
  Future<bool> start(int sampleRate);

  /// One chunk, queued behind the rest. Never dropped.
  void write(Uint8List pcm);

  /// Drops everything not yet played. The frames played so far.
  Future<int> flush();

  /// The frames played so far.
  Future<int> played();

  Future<void> stop();
}

class NativeRealtimePlayer implements RealtimePlayerPort {
  static const _channel = MethodChannel('kiosk_satellite/realtime_audio');

  bool _open = false;

  /// The model's rate, and the rate the track plays at when the platform
  /// picked another: the voice is resampled on the way in, and frame
  /// counts converted on the way back.
  int _rate = 24000;
  int _trackRate = 24000;
  PcmResampler? _resampler;

  @override
  Future<bool> start(int sampleRate) async {
    _rate = sampleRate;
    try {
      final rate = await _channel.invokeMethod<num>('start', {
        'sampleRate': sampleRate,
      });
      _trackRate = rate?.toInt() ?? 0;
      _open = _trackRate > 0;
    } catch (_) {
      _open = false;
    }
    _resampler = _open && _trackRate != _rate
        ? PcmResampler(from: _rate, to: _trackRate)
        : null;
    return _open;
  }

  int _toModel(num frames) => (frames * _rate / _trackRate).round();

  @override
  void write(Uint8List pcm) {
    if (!_open) return;
    final out = _resampler?.convert(pcm) ?? pcm;
    unawaited(
      _channel.invokeMethod<void>('write', out).catchError((Object _) {}),
    );
  }

  @override
  Future<int> flush() async {
    if (!_open) return 0;
    try {
      _resampler?.reset();
      return _toModel(await _channel.invokeMethod<num>('flush') ?? 0);
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<int> played() async {
    if (!_open) return 0;
    try {
      final status = await _channel.invokeMapMethod<String, Object?>('status');
      return _toModel((status?['played'] as num?) ?? 0);
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> stop() async {
    if (!_open) return;
    _open = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
