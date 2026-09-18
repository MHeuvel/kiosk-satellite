import 'dart:typed_data';

/// One explicitly requested capture. Audio stays in memory until cleared.
class SoundCapture {
  SoundCapture(this.id);

  static const maxBytes = 8 * 1024 * 1024;
  final String id;
  final _audio = BytesBuilder(copy: true);
  int bytesReceived = 0;
  int? statusCode;
  String? contentType;
  String? error;
  bool httpComplete = false;
  bool playbackEnded = false;
  String? playbackError;

  bool get ready =>
      httpComplete && statusCode == 200 && error == null && _audio.length > 0;

  void add(List<int> bytes) {
    bytesReceived += bytes.length;
    if (error != null) return;
    if (bytesReceived > maxBytes) {
      discard('Capture exceeded $maxBytes bytes');
    } else {
      _audio.add(bytes);
    }
  }

  void discard(String reason) {
    error = reason;
    _audio.clear();
  }

  Uint8List get audio => _audio.toBytes();

  Map<String, Object?> get status => {
    'id': id,
    'bytesReceived': bytesReceived,
    'statusCode': statusCode,
    'contentType': contentType,
    'httpComplete': httpComplete,
    'playbackEnded': playbackEnded,
    'playbackError': playbackError,
    'ready': ready,
    'error': error,
  };
}
