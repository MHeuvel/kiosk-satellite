import 'dart:async';

import 'package:flutter/services.dart';

/// The Dart side of the intercom's playback sink: a streaming AudioTrack
/// on the communication route (IntercomAudio.kt), so the platform echo
/// canceller sees the far voice as its reference and the near microphone
/// does not carry it back.
///
/// The bridge is a plain method channel: [start] opens the track at the
/// intercom's format (16 kHz mono PCM16, what the microphone hub delivers
/// on the other kiosk), [write] hands it one chunk, [setVolume] moves the
/// intercom fader live and [stop] releases the track and the route.
/// Replaced in tests through [invoker].
class IntercomAudio {
  IntercomAudio();

  static const _channel = MethodChannel('kiosk_satellite/intercom_audio');

  /// How the platform is reached. Tests swap it.
  Future<Object?> Function(String method, [Object? args]) invoker =
      (method, [args]) => _channel.invokeMethod<Object?>(method, args);

  bool _open = false;

  bool get open => _open;

  /// Opens the track. [volume] is the linear base gain, 0..1. False when
  /// the platform could not (no bridge in tests, a track that failed).
  Future<bool> start({required double volume}) async {
    try {
      final ok = await invoker('start', {'volume': volume});
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

  Future<void> stopRing() async {
    try {
      await invoker('stopRing');
    } catch (_) {}
  }

  /// Whether the platform has an echo canceller for the microphone route.
  /// Without one a hands free call feeds the far voice straight back, so
  /// the manager forces push to talk.
  Future<bool> echoCancellerAvailable() async {
    try {
      return await invoker('aecAvailable') == true;
    } catch (_) {
      return false;
    }
  }
}
