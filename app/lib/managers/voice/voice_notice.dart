/// A problem the native voice satellite puts on screen, ranked as Voice
/// Satellite's toasts rank theirs: an error stays until it is closed (or
/// the problem clears), a warning 8 seconds, a notice 4.
library;

enum VoiceSeverity { error, warning, notice }

class VoiceNotice {
  const VoiceNotice({
    required this.id,
    required this.severity,
    required this.category,
    required this.message,
  });

  /// The same for every notice of one kind, so a repeat refreshes it and
  /// the problem clearing takes it down.
  final String id;
  final VoiceSeverity severity;

  /// Where it comes from: "Connection", "Wake word", "Pipeline "Home"".
  final String category;
  final String message;
}
