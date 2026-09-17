/// Stored camera sizes use sensor coordinates. Rotation happens during capture.
(int, int)? parseCameraResolution(String value) {
  final match = RegExp(
    r'^([1-9][0-9]{0,4})x([1-9][0-9]{0,4})$',
  ).firstMatch(value);
  if (match == null) return null;
  return (int.parse(match[1]!), int.parse(match[2]!));
}

bool isCameraStreamResolution(String value) =>
    const ['480', '720', '1080'].contains(value) ||
    parseCameraResolution(value) != null;

/// Old video tiers map to standard video sizes before hardware selection.
(int, int) cameraStreamResolution(String value) =>
    parseCameraResolution(value) ??
    switch (value) {
      '720' => (1280, 720),
      '1080' => (1920, 1080),
      _ => (640, 480),
    };

/// Keep exact sizes and choose the closest pixel count for migrated settings.
/// On a tie, prefer the smaller frame to avoid increasing capture work.
String closestCameraResolution(String value, List<String> supported) {
  if (supported.isEmpty || supported.contains(value)) return value;
  final (width, height) = cameraStreamResolution(value);
  final target = width * height;
  final sizes = supported
      .where((s) => parseCameraResolution(s) != null)
      .toList();
  int area(String size) {
    final (w, h) = parseCameraResolution(size)!;
    return w * h;
  }

  sizes.sort((a, b) {
    final distance = (area(a) - target).abs().compareTo(
      (area(b) - target).abs(),
    );
    if (distance != 0) return distance;
    final pixels = area(a).compareTo(area(b));
    return pixels != 0 ? pixels : a.compareTo(b);
  });
  return sizes.isEmpty ? value : sizes.first;
}

String cameraResolutionLabel(String value) => value.replaceAll('x', ' × ');

/// CameraX capture combinations intersected with H.264 encoder capabilities.
class CameraStreamingCapabilities {
  CameraStreamingCapabilities.fromJson(Map<Object?, Object?> json)
    : withAnalysis = _sizes(json['withAnalysis']),
      withoutAnalysis = _sizes(json['withoutAnalysis']),
      encoderRejected = _sizes(json['encoderRejected']),
      captureRejected = _sizes(json['captureRejected']);

  final List<String> withAnalysis;
  final List<String> withoutAnalysis;
  final List<String> encoderRejected;
  final List<String> captureRejected;

  static List<String> _sizes(Object? value) {
    if (value is! List) throw const FormatException('Missing streaming sizes');
    return value
        .whereType<String>()
        .where((size) => parseCameraResolution(size) != null)
        .toSet()
        .toList();
  }

  List<String> sizes(bool analysis) =>
      analysis ? withAnalysis : withoutAnalysis;

  String notice(bool analysis) {
    final extra = withoutAnalysis.where((size) => !withAnalysis.contains(size));
    final parts = <String>[
      'Only sizes supported by the camera and H.264 encoder at the current streaming settings are listed.',
      if (analysis && extra.isNotEmpty)
        'Turn off Motion analysis while streaming to also use ${extra.map(cameraResolutionLabel).join(', ')}.',
      if (!analysis)
        'Motion detection, face detection and hand gestures pause while viewers are connected. Snapshots use video frames at the streaming resolution.',
      if (encoderRejected.isNotEmpty)
        encoderRejected.length <= 4
            ? 'The encoder cannot use ${encoderRejected.map(cameraResolutionLabel).join(', ')} at these settings.'
            : '${encoderRejected.length} camera sizes are excluded because the encoder cannot use them at these settings.',
      if (captureRejected.isNotEmpty)
        'Other camera sizes are unavailable in the current capture setup.',
    ];
    return parts.join(' ');
  }
}
