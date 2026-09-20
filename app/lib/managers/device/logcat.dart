// Android can report every unused buffer slot while WebView releases a codec.
// Group only FREE-slot messages on the codec's temporary cleanup surfaces.
// Other surfaces, buffer states and errors keep their original lines.
final _codecCleanup = RegExp(
  r'^(\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.\d+ '
  r'([WE])/BufferQueueProducer\s*\(\s*(\d+)\): '
  r'(\[(?:MediaCodec\.release|ImageReader-1x1f\d+[^\]]*)\]'
  r'\(id:[^)]+\) (?:detachBuffer|cancelBuffer): slot )'
  r'\d+( is not owned by the producer \(state = FREE\))$',
);

/// Keeps one original line and a count for each consecutive cleanup burst.
/// Matching includes the second, process, queue, operation and severity so
/// separate releases and distinct failures remain separate entries.
Stream<String> compactLogcat(Stream<String> lines) async* {
  String? first;
  String? previousKey;
  var count = 0;

  String entry() =>
      count == 1 ? first! : '$first [$count similar buffer cleanup messages]';

  await for (final line in lines) {
    final match = _codecCleanup.firstMatch(line);
    final key = match == null
        ? null
        : [for (var i = 1; i <= match.groupCount; i++) match.group(i)].join();
    if (key != null && key == previousKey) {
      count++;
      continue;
    }
    if (first != null) yield entry();
    first = null;
    previousKey = key;
    count = 0;
    if (key == null) {
      yield line;
    } else {
      first = line;
      count = 1;
    }
  }
  if (first != null) yield entry();
}
