import 'package:flutter/services.dart';

/// Dart side of the native 16 kHz mono PCM16 microphone stream (Android
/// `MicRecorder`, EventChannel `kiosk_satellite/mic`).
///
/// Listening starts capture; cancelling the subscription stops it and releases
/// the mic. Each event is a chunk of little-endian 16-bit PCM bytes.
class NativeMic {
  static const _channel = EventChannel('kiosk_satellite/mic');

  /// The user's capture device as an AudioRouting selector
  /// ("type|address|name", empty = Android routes). Set by AudioRoutingManager
  /// at startup and on setting changes; read when a stream opens, so it must
  /// be current before the engine (re)starts.
  static String deviceSelector = '';

  /// The capture tuning from Microphone settings, set alongside
  /// [deviceSelector] and read at the same moment: the platform applies all
  /// of it when the session opens, so changing any of them needs a restart.
  static String source = 'voice_communication';
  static bool echoCancellation = true;
  static num gainDb = 0;
  static bool agc = false;
  static bool noiseSuppression = false;

  /// 1-based channel of a multichannel microphone to capture; 0 lets the
  /// platform downmix (which averages every channel together).
  static num channel = 0;

  /// 'auto' asks for 16 kHz mono and lets the platform convert; 'hardware'
  /// opens 48 kHz stereo, the only format some sound cards record in, and
  /// the native side converts. Either way this stream is 16 kHz mono.
  static String captureFormat = 'auto';

  /// Where the capture's warnings go (a format that failed, a read that
  /// stalled), so they reach the app log and not only logcat. Set by
  /// AudioRoutingManager with the other capture settings.
  static void Function(String warning)? onWarning;

  Stream<Uint8List> stream() => _channel
      .receiveBroadcastStream({
        if (deviceSelector.isNotEmpty) 'device': deviceSelector,
        'source': source,
        'aec': echoCancellation,
        'gainDb': gainDb,
        'agc': agc,
        'noiseSuppression': noiseSuppression,
        'channel': channel,
        'format': captureFormat,
      })
      // Besides PCM the platform sends the capture's warnings (a format
      // that failed, a read that stalled), so they reach the app log.
      .where((e) {
        if (e is! Map) return true;
        final warning = e['warning'];
        if (warning is String) onWarning?.call(warning);
        return false;
      })
      .map((e) => e as Uint8List);
}
