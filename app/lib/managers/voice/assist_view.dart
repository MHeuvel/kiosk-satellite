/// What the assist overlay shows, as one immutable snapshot the native voice
/// satellite publishes and the overlay draws. Kept free of Flutter so the
/// session can be tested without widgets.
library;

enum AssistPhase {
  /// Nothing on screen.
  hidden,

  /// Listening for the command: the bar follows the voice.
  listening,

  /// The command is in; the assistant is working on it.
  thinking,

  /// The answer is on screen (and usually being spoken).
  speaking,

  /// An announcement from Home Assistant, centered.
  announcement,
}

/// One result a turn produced: weather, a stock quote, images, videos.
/// [kind] names the panel, [data] is the tool result as Home Assistant sent
/// it (see results.dart for the shapes each panel reads).
class AssistResult {
  const AssistResult(this.kind, this.data);
  final String kind;
  final Map<String, Object?> data;
}

/// A finished turn of the conversation, kept on screen above the turns
/// after it, as Voice Satellite keeps every line of a conversation.
class AssistTurn {
  const AssistTurn({
    this.command = '',
    this.tools = const [],
    this.answer = '',
  });

  final String command;
  final List<String> tools;
  final String answer;

  bool get isEmpty => command.isEmpty && tools.isEmpty && answer.isEmpty;
}

class AssistView {
  const AssistView({
    this.phase = AssistPhase.hidden,
    this.earlier = const [],
    this.command = '',
    this.answer = '',
    this.streaming = false,
    this.tools = const [],
    this.results = const [],
    this.reactive = true,
    this.docked = false,
    this.lingering = false,
  });

  static const hidden = AssistView();

  final AssistPhase phase;

  /// The conversation's earlier turns, oldest first. The lines below
  /// ([command], [tools], [answer]) are the turn in progress.
  final List<AssistTurn> earlier;

  /// What the user said (speech to text), or the prompt of a show.
  final String command;

  /// The assistant's answer, or the announcement's text.
  final String answer;

  /// Whether [answer] is still arriving (a vs_show streams it in).
  final bool streaming;

  /// One line per action the assistant took ("Turn on").
  final List<String> tools;

  final List<AssistResult> results;

  /// Whether the bar follows the audio level right now. Off while the wake
  /// chime plays and while the assistant thinks.
  final bool reactive;

  /// A realtime conversation: the bar along the edge and a small caption,
  /// with the screen under it visible and usable.
  final bool docked;

  /// The turn is over and its answer or results stay on screen. Nothing
  /// listens or speaks, so the skin's bar is down.
  final bool lingering;

  bool get visible => phase != AssistPhase.hidden;

  /// The turn in progress, as it would be kept once the next one starts.
  AssistTurn get turn =>
      AssistTurn(command: command, tools: tools, answer: answer);

  AssistView copyWith({
    AssistPhase? phase,
    List<AssistTurn>? earlier,
    String? command,
    String? answer,
    bool? streaming,
    List<String>? tools,
    List<AssistResult>? results,
    bool? reactive,
    bool? docked,
    bool? lingering,
  }) => AssistView(
    phase: phase ?? this.phase,
    earlier: earlier ?? this.earlier,
    command: command ?? this.command,
    answer: answer ?? this.answer,
    streaming: streaming ?? this.streaming,
    tools: tools ?? this.tools,
    results: results ?? this.results,
    reactive: reactive ?? this.reactive,
    docked: docked ?? this.docked,
    lingering: lingering ?? this.lingering,
  );
}

/// The turn in Home Assistant's assist_satellite states (idle, listening,
/// processing, responding), for the Voice Satellite sensor. [busy] is
/// whether a turn or a conversation runs: a preview or an answer left on
/// screen after its turn reads idle.
String satelliteState(AssistView view, {required bool busy}) {
  if (!busy || view.lingering) return 'idle';
  return switch (view.phase) {
    AssistPhase.hidden => 'idle',
    AssistPhase.listening => 'listening',
    AssistPhase.thinking => 'processing',
    AssistPhase.speaking || AssistPhase.announcement => 'responding',
  };
}

/// Voice Satellite's estimate of how long [text] takes to say, in seconds:
/// 2.8 words a second, 0.7 more per number, three at least.
double estimateSpeechSeconds(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  final words = trimmed.split(RegExp(r'\s+')).length;
  final numbers = RegExp(r'\d[\d,.]*%?').allMatches(text).length;
  final seconds = words / 2.8 + numbers * 0.7;
  return seconds < 3 ? 3 : seconds;
}
