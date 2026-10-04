import 'dart:typed_data';

/// Streaming linear resampler for mono PCM16, little endian. The microphone
/// captures at 16 kHz and a realtime model takes 24 kHz. Linear
/// interpolation is enough for speech on its way up: there is nothing above
/// 8 kHz to alias. The last sample of each chunk is carried into the next,
/// so chunk edges interpolate as if the stream were whole.
class PcmResampler {
  PcmResampler({required this.from, required this.to})
    : assert(from > 0 && to > 0);

  final int from;
  final int to;

  /// Where the next output sample falls, in input samples, counted from
  /// the carried sample.
  double _pos = 0;
  int? _last;

  Uint8List convert(Uint8List pcm) {
    if (from == to) return pcm;
    final n = pcm.length ~/ 2;
    if (n == 0) return Uint8List(0);
    final input = ByteData.sublistView(pcm);
    // With a carried sample it stands at index 0 and the chunk at 1..n.
    final prev = _last;
    final offset = prev == null ? 0 : 1;
    final total = n + offset;
    int sample(int i) => offset == 1 && i == 0
        ? prev!
        : input.getInt16((i - offset) * 2, Endian.little);

    final step = from / to;
    final last = total - 1;
    final count = _pos > last ? 0 : ((last - _pos) / step).floor() + 1;
    final out = Uint8List(count * 2);
    final view = ByteData.sublistView(out);
    var pos = _pos;
    for (var k = 0; k < count; k++) {
      final i = pos.floor();
      final frac = pos - i;
      final a = sample(i);
      final b = i < last ? sample(i + 1) : a;
      view.setInt16(
        k * 2,
        (a + (b - a) * frac).round().clamp(-32768, 32767),
        Endian.little,
      );
      pos += step;
    }
    _last = sample(last);
    _pos = pos - last;
    return out;
  }

  void reset() {
    _pos = 0;
    _last = null;
  }
}
