import 'dart:async';

import 'package:flutter/services.dart';

/// The Dart side of the intercom's playback sink: a streaming AudioTrack
/// played as media with a reference for the software echo canceller.
///
/// The bridge is a plain method channel: [start] opens the track at the
/// intercom's format (16 kHz mono PCM16, what the microphone hub delivers
/// on the other kiosk), [write] hands it one chunk, [setVolume] moves the
/// intercom fader live and [stop] releases the track and the route.
/// Replaced in tests through [invoker].
class IntercomAudio {
  IntercomAudio();

  static const _channel = MethodChannel('kiosk_satellite/intercom_audio');

  /// Chunks ride their own channel, which the platform serves on a
  /// background queue: through the main thread a busy UI held them back,
  /// they reached the track in bursts and the excess was dropped.
  static const _data = MethodChannel('kiosk_satellite/intercom_audio_data');

  /// How the platform is reached. Tests swap it.
  Future<Object?> Function(String method, [Object? args]) invoker =
      (method, [args]) => (method == 'write' ? _data : _channel)
          .invokeMethod<Object?>(method, args);

  bool _open = false;

  bool get open => _open;

  /// Opens the track. [volume] is the linear base gain, 0..1. False when
  /// the platform could not (no bridge in tests, a track that failed).
  Future<bool> start({required double volume, bool handsFree = false}) async {
    try {
      final ok = await invoker('start', {
        'volume': volume,
        'handsFree': handsFree,
      });
      _open = ok == true;
    } on MissingPluginException {
      _open = false;
    } catch (_) {
      _open = false;
    }
    return _open;
  }

  /// One chunk of PCM16 mono 16 kHz. Fire and forget: a chunk the track
  /// could not take is dropped, the next one lands on time.
  void write(Uint8List pcm) {
    if (!_open) return;
    unawaited(invoker('write', pcm).catchError((_) => null));
  }

  /// Select the echo canceller tuning for a hands free two-way call.
  Future<void> setHandsFree(bool enabled) async {
    if (!_open) return;
    try {
      await invoker('setHandsFree', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    if (!_open) return;
    try {
      await invoker('setVolume', {'volume': volume});
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!_open) return;
    _open = false;
    try {
      await invoker('stop');
    } catch (_) {}
  }

  /// The built-in ring, synthesized natively: a double burst of the
  /// classic 440 and 480 Hz telephone ring, or one short burst. [volume]
  /// is the notification volume, 0..1, applied as is like the chime.
  Future<String?> ring({required double volume, bool short = false}) async {
    try {
      await invoker('ring', {'volume': volume, 'short': short});
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// The built-in announcement chime, two soft bell notes, synthesized
  /// natively. [volume] as for the ring.
  /// The built-in announcement chime as 16 kHz mono PCM16, played ahead
  /// of the words on the same track. Null when the platform could not.
  Future<Uint8List?> chimePcm() async {
    try {
      final out = await invoker('chimePcm');
      return out is Uint8List ? out : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> stopRing() async {
    try {
      await invoker('stopRing');
    } catch (_) {}
  }

  /// Decodes an audio file (MP3, WAV, OGG, whatever the platform decodes)
  /// to 16 kHz mono PCM16, for an announcement from Home Assistant. Null
  /// when the platform could not.
  Future<Uint8List?> decode(Uint8List bytes) async {
    try {
      final out = await invoker('decode', bytes);
      return out is Uint8List ? out : null;
    } catch (_) {
      return null;
    }
  }
}
