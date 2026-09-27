import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'assist_view.dart';

/// The ESPHome voice assistant events (api.proto VoiceAssistantEvent).
abstract final class VaEvent {
  static const error = 0;
  static const runStart = 1;
  static const runEnd = 2;
  static const sttStart = 3;
  static const sttEnd = 4;
  static const intentStart = 5;
  static const intentEnd = 6;
  static const ttsStart = 7;
  static const ttsEnd = 8;
  static const sttVadStart = 11;
  static const sttVadEnd = 12;
  static const intentProgress = 100;
}

/// Asks Home Assistant for pipelines and feeds them, over the kiosk's
/// ESPHome device.
abstract class VoiceLinkPort {
  /// Start a pipeline (named by [wakeWordPhrase] for pipeline 2 and the
  /// cross-satellite dedupe), or stop the running one. False when Home
  /// Assistant is not subscribed.
  Future<bool> request({required bool start, String wakeWordPhrase = ''});

  Future<bool> audio(Uint8List pcm);

  /// An announcement or spoken answer finished playing: the satellite goes
  /// back to idle in Home Assistant.
  Future<bool> finished();
}

/// The microphone: the wake word engine's capture, pre-roll first.
abstract class VoiceMicPort {
  Future<bool> open(void Function(Uint8List pcm, bool preRoll) onChunk);
  Future<void> close();
}

/// Playback through the kiosk's own player at the Assistant volume.
abstract class VoicePlayerPort {
  /// Plays [url] (streamed while Home Assistant still synthesizes it); the
  /// sound's id, or null when it could not start.
  Future<String?> play(String url);

  /// Plays a voice chime ('wake', 'done', 'error', 'announce'); its id and
  /// duration in seconds, or null.
  Future<(String, double)?> chime(String kind);

  Future<void> stop(String id);
}

/// The settings a turn reads, fresh each time.
class VoiceSessionOptions {
  const VoiceSessionOptions({
    this.seamless = false,
    this.wakeSound = true,
    this.followupDelayMs = 0,
    this.followupChime = false,
    this.answerLingerSeconds = 0,
    this.resultsLingerSeconds = 30,
    this.announcementLingerSeconds = 5,
    this.stopWord = false,
  });

  final bool seamless;
  final bool wakeSound;
  final int followupDelayMs;
  final bool followupChime;
  final int answerLingerSeconds;
  final int resultsLingerSeconds;
  final int announcementLingerSeconds;
  final bool stopWord;
}

/// An announcement from Home Assistant (assist_satellite.announce,
/// start_conversation and ask_question all arrive as one).
class VoiceAnnouncement {
  const VoiceAnnouncement({
    required this.mediaId,
    required this.text,
    required this.preannounceMediaId,
    required this.startConversation,
  });

  final String mediaId;
  final String text;
  final String preannounceMediaId;
  final bool startConversation;
}

enum _Phase {
  idle,
  starting,
  listening,
  thinking,
  speaking,
  announcing,
  followup,
  showing,
}

/// One voice satellite's turns, run against Home Assistant's ESPHome
/// assist satellite. A port of Voice Satellite's session choreography onto
/// the ESPHome events: the wake chime after the cross-satellite dedupe
/// window, the microphone muted through the chime, the answer played from
/// the URL Home Assistant sends, follow-ups when the assistant asks back,
/// the stop word and cancel, expected and unexpected errors.
///
/// Every await re-checks a generation counter. Anything that ends or
/// replaces a turn advances it, so nothing of the old turn keeps running.
class VoiceSession {
  VoiceSession({
    required this.link,
    required this.mic,
    required this.player,
    required this.options,
    required this.onView,
    required this.onLevel,
    required this.onBusy,
    required this.onStopArmed,
    required this.onError,
    this.onIntentEnd,
    this.onIdle,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final VoiceLinkPort link;
  final VoiceMicPort mic;
  final VoicePlayerPort player;
  final VoiceSessionOptions Function() options;
  final void Function(AssistView view) onView;
  final void Function(double level) onLevel;

  /// A turn or an announcement started (true) or ended (false), with what
  /// kind it is: 'voice' or 'announcement'.
  final void Function(bool busy, String reason) onBusy;
  final void Function(bool armed) onStopArmed;

  /// Something to tell the user. Expected errors never reach here.
  final void Function(String code, String message) onError;

  /// The intent ended: the conversation id, for the chat log.
  final void Function(String conversationId)? onIntentEnd;

  /// The session went idle: the wake word may listen again.
  final void Function()? onIdle;
  final DateTime Function() _now;

  // Voice Satellite's timings.
  static const dedupeWindow = Duration(milliseconds: 250);
  static const chimeDrain = Duration(milliseconds: 250);
  static const vadWatchdog = Duration(seconds: 60);
  static const playbackSafety = Duration(seconds: 120);
  static const stopWordArmDelay = Duration(milliseconds: 250);
  static const noMediaAnnouncement = Duration(seconds: 3);

  /// Errors that are part of normal use: nothing said, another satellite
  /// answered, a timeout. They end the turn quietly.
  static const expectedErrors = {
    'timeout',
    'wake-word-timeout',
    'stt-no-text-recognized',
    'duplicate_wake_up_detected',
    'no_wake_word',
  };

  static const _preannounceDefault = '/api/assist_satellite/static/';

  _Phase _phase = _Phase.idle;
  int _gen = 0;
  AssistView _view = AssistView.hidden;

  // The microphone.
  bool _micOpen = false;
  bool _sending = false;
  final _held = <Uint8List>[];
  int _heldBytes = 0;

  // The run.
  String _phrase = '';
  DateTime? _wokeAt;
  bool _runActive = false;
  String _streamUrl = '';
  bool _answerStarted = false;

  /// How the answer's playback went: null while none finished yet.
  bool? _answerPlayed;
  bool _continue = false;

  /// Someone opened a result: the overlay stays until it is dismissed.
  bool _kept = false;
  bool _hasResults = false;

  // Playback.
  String? _playId;
  Completer<bool>? _playDone;
  Timer? _watchdog;
  Timer? _linger;

  bool get busy => _phase != _Phase.idle;
  AssistView get view => _view;

  void _show(AssistView view) {
    _view = view;
    onView(view);
  }

  // ── wake ───────────────────────────────────────────────────────────────

  /// The wake word fired ([phrase] names it), or a turn was asked for
  /// without one (empty: the vs_wake action).
  Future<void> wake(String phrase) async {
    if (_phase == _Phase.announcing) {
      ++_gen;
      await _abandon();
    } else if (busy) {
      return;
    }
    final gen = ++_gen;
    _resetRun();
    _phrase = phrase;
    _wokeAt = _now();
    _phase = _Phase.starting;
    onBusy(true, 'voice');
    _show(const AssistView(phase: AssistPhase.listening, reactive: false));
    final seamless = options().seamless;
    await _startRun(gen, chime: !seamless, keepPreRoll: seamless);
  }

  /// Opens the microphone, asks Home Assistant for a pipeline and, past the
  /// chime, starts streaming.
  Future<void> _startRun(
    int gen, {
    required bool chime,
    required bool keepPreRoll,
  }) async {
    final opened = await mic.open((pcm, preRoll) => _onChunk(gen, pcm));
    if (gen != _gen) {
      if (opened) await mic.close();
      return;
    }
    _micOpen = opened;
    if (!opened) {
      onError('microphone', 'The microphone is not available.');
      await _finish(gen, sound: 'error');
      return;
    }
    _runActive = true;
    final asked = await link.request(start: true, wakeWordPhrase: _phrase);
    if (gen != _gen) return;
    if (!asked) {
      _runActive = false;
      onError(
        'not-connected',
        'Home Assistant is not connected to this kiosk.',
      );
      await _finish(gen, sound: 'error');
      return;
    }
    if (!chime) {
      _startSending(keepHeld: keepPreRoll);
      _show(_view.copyWith(reactive: true));
      return;
    }
    // The dedupe window: when another satellite heard the same wake word,
    // Home Assistant answers within it and this one plays no chime at all.
    await Future<void>.delayed(dedupeWindow);
    if (gen != _gen) return;
    if (options().wakeSound) {
      final played = await player.chime('wake');
      if (gen != _gen) return;
      if (played != null) {
        await Future<void>.delayed(
          Duration(milliseconds: (played.$2 * 1000).round()) + chimeDrain,
        );
        if (gen != _gen) return;
      }
    }
    // The chime is not part of the command: drop what was heard over it.
    _startSending(keepHeld: false);
    _show(_view.copyWith(reactive: true));
  }

  void _onChunk(int gen, Uint8List pcm) {
    if (gen != _gen) return;
    onLevel(speechLevel(pcm));
    if (_sending) {
      unawaited(link.audio(pcm));
      return;
    }
    _held.add(pcm);
    _heldBytes += pcm.length;
    // Three seconds at most: more than the pre-roll and a chime.
    while (_heldBytes > 96000 && _held.isNotEmpty) {
      _heldBytes -= _held.removeAt(0).length;
    }
  }

  void _startSending({required bool keepHeld}) {
    if (keepHeld) {
      for (final pcm in _held) {
        unawaited(link.audio(pcm));
      }
    }
    _held.clear();
    _heldBytes = 0;
    _sending = true;
  }

  Future<void> _closeMic() async {
    _sending = false;
    _held.clear();
    _heldBytes = 0;
    if (!_micOpen) return;
    _micOpen = false;
    await mic.close();
  }

  /// The bar's level from one chunk of 16 kHz PCM16: mean amplitude with
  /// the gain and curve Voice Satellite's analyser uses for the microphone.
  static double speechLevel(Uint8List pcm) {
    final samples = pcm.length ~/ 2;
    if (samples == 0) return 0;
    final data = ByteData.sublistView(pcm);
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      sum += data.getInt16(i * 2, Endian.little).abs();
    }
    final mean = sum / samples / 32768.0;
    final level = math.pow(mean * 7.5, 0.6).toDouble();
    return level < 0.06 ? 0 : level.clamp(0.0, 1.0);
  }

  // ── Home Assistant's side ──────────────────────────────────────────────

  /// Home Assistant's answer to the pipeline request.
  Future<void> onResponse({required bool error}) async {
    if (!error || !_runActive) return;
    final gen = _gen;
    _runActive = false;
    onError('refused', 'Home Assistant could not start the assistant.');
    await _finish(gen, sound: 'error');
  }

  Future<void> onEvent(int type, Map<String, String> data) async {
    if (!_runActive) return;
    final gen = _gen;
    switch (type) {
      case VaEvent.runStart:
        // A streaming text to speech engine hands the answer's URL here,
        // before the answer exists; it plays when the intent says so.
        _streamUrl = data['url'] ?? '';
      case VaEvent.sttStart:
        _phase = _Phase.listening;
        _armWatchdog(gen);
      case VaEvent.sttVadStart:
        _armWatchdog(gen);
      case VaEvent.sttVadEnd:
        await _closeMic();
      case VaEvent.sttEnd:
        _cancelWatchdog();
        await _closeMic();
        if (gen != _gen) return;
        _phase = _Phase.thinking;
        _show(
          _view.copyWith(
            phase: AssistPhase.thinking,
            command: data['text'] ?? '',
            reactive: false,
          ),
        );
      case VaEvent.intentStart:
        _phase = _Phase.thinking;
        if (_view.phase != AssistPhase.thinking) {
          _show(_view.copyWith(phase: AssistPhase.thinking, reactive: false));
        }
      case VaEvent.intentProgress:
        if (data['tts_start_streaming'] == '1' && _streamUrl.isNotEmpty) {
          unawaited(_playAnswer(gen, _streamUrl));
        }
      case VaEvent.intentEnd:
        _continue = data['continue_conversation'] == '1';
        final conversation = data['conversation_id'] ?? '';
        if (conversation.isNotEmpty) onIntentEnd?.call(conversation);
      case VaEvent.ttsStart:
        _phase = _Phase.speaking;
        _show(
          _view.copyWith(
            phase: AssistPhase.speaking,
            answer: data['text'] ?? '',
            streaming: false,
            reactive: true,
          ),
        );
      case VaEvent.ttsEnd:
        final url = data['url'] ?? '';
        if (url.isNotEmpty) unawaited(_playAnswer(gen, url));
      case VaEvent.runEnd:
        _cancelWatchdog();
        _runActive = false;
        await _closeMic();
        if (gen != _gen) return;
        // Still speaking: the end of the playback takes the turn from here.
        if (_answerStarted && _answerPlayed == null) return;
        await _afterAnswer(gen, played: _answerPlayed ?? false);
      case VaEvent.error:
        await _onError(gen, data['code'] ?? '', data['message'] ?? '');
    }
  }

  Future<void> _onError(int gen, String code, String message) async {
    _cancelWatchdog();
    _runActive = false;
    await _closeMic();
    if (expectedErrors.contains(code)) {
      // A satellite that lost the dedupe stays silent: the user already
      // heard the winner's chime.
      final duplicate = code == 'duplicate_wake_up_detected';
      await _finish(gen, sound: duplicate ? null : 'done');
      return;
    }
    onError(code, message);
    await _finish(gen, sound: 'error');
  }

  void _armWatchdog(int gen) {
    _cancelWatchdog();
    _watchdog = Timer(vadWatchdog, () {
      if (gen == _gen) unawaited(cancel());
    });
  }

  void _cancelWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  // ── the answer ─────────────────────────────────────────────────────────

  Future<void> _playAnswer(int gen, String url) async {
    if (_answerStarted) return;
    _answerStarted = true;
    _phase = _Phase.speaking;
    final ok = await _play(gen, url, armStopWord: true);
    if (gen != _gen) return;
    _answerPlayed = ok;
    await link.finished();
    if (gen != _gen) return;
    // A streamed answer can end before Home Assistant ends the run: the
    // run's end picks the turn up then.
    if (!_runActive) await _afterAnswer(gen, played: ok);
  }

  /// Plays [url] to its end. False when it could not play or failed.
  Future<bool> _play(int gen, String url, {bool armStopWord = false}) async {
    final id = await player.play(url);
    if (gen != _gen) {
      if (id != null) await player.stop(id);
      return false;
    }
    if (id == null) return false;
    return _awaitSound(gen, id, armStopWord: armStopWord);
  }

  Future<bool> _awaitSound(
    int gen,
    String id, {
    bool armStopWord = false,
    Duration safety = playbackSafety,
  }) async {
    final done = Completer<bool>();
    _playId = id;
    _playDone = done;
    _position = null;
    _length = null;
    Timer? arm;
    if (armStopWord && options().stopWord) {
      arm = Timer(stopWordArmDelay, () {
        if (gen == _gen && _playId == id) onStopArmed(true);
      });
    }
    final guard = Timer(safety, () {
      if (!done.isCompleted) done.complete(false);
    });
    final ok = await done.future;
    arm?.cancel();
    guard.cancel();
    if (_playId == id) {
      _playId = null;
      _playDone = null;
      if (armStopWord) onStopArmed(false);
    }
    return ok;
  }

  /// A sound finished (or failed); from the player's ended events.
  void onSoundEnded(String id, {String? error}) {
    if (id != _playId) return;
    final done = _playDone;
    if (done != null && !done.isCompleted) done.complete(error == null);
  }

  /// The playback level of the sound playing now, for the bar.
  void onSoundLevel(String id, double level) {
    if (id == _playId) onLevel(level);
  }

  /// Where the sound playing now was, and when that was reported.
  Duration? _position;
  Duration? _length;
  DateTime? _positionAt;

  /// The player's report of where the sound playing now is.
  void onSoundProgress(String id, Duration position, Duration? duration) {
    if (id != _playId) return;
    _position = position;
    _length = duration;
    _positionAt = _now();
  }

  /// Seconds into the sound playing now and its length, while both are
  /// known: carried forward from the player's last report.
  ({double elapsed, double duration})? get playback {
    final position = _position;
    final length = _length;
    final at = _positionAt;
    if (_playId == null || position == null || length == null || at == null) {
      return null;
    }
    var elapsed = position + _now().difference(at);
    if (elapsed > length) elapsed = length;
    return (
      elapsed: elapsed.inMicroseconds / 1e6,
      duration: length.inMicroseconds / 1e6,
    );
  }

  Future<void> _afterAnswer(int gen, {required bool played}) async {
    if (gen != _gen) return;
    if (_continue && played) {
      await _followUp(gen);
      return;
    }
    await _finish(gen, sound: 'done', linger: true);
  }

  /// The assistant asked something back: listen again in the same
  /// conversation, the chat kept on screen.
  Future<void> _followUp(int gen) async {
    _phase = _Phase.followup;
    final opts = options();
    if (opts.followupDelayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: opts.followupDelayMs));
      if (gen != _gen) return;
    }
    // The same wake word keeps the same pipeline, except inside Home
    // Assistant's two-second window, where it would read as a duplicate.
    final woke = _wokeAt;
    if (woke != null && _now().difference(woke) < const Duration(seconds: 3)) {
      _phrase = '';
    }
    _resetRun(keepConversation: true);
    // The turn that just ended stays on screen above the next one, whose
    // lines start empty. A result panel stays until a turn brings another.
    final turn = _view.turn;
    _show(
      AssistView(
        phase: AssistPhase.listening,
        earlier: [..._view.earlier, if (!turn.isEmpty) turn],
        results: _view.results,
        reactive: false,
      ),
    );
    await _startRun(
      gen,
      chime: opts.followupChime && opts.wakeSound,
      keepPreRoll: false,
    );
  }

  // ── announcements ──────────────────────────────────────────────────────

  /// Plays an announcement, then listens when a reply is expected
  /// (start_conversation, ask_question).
  Future<void> announce(VoiceAnnouncement announcement) async {
    if (busy) {
      ++_gen;
      await _abandon();
    }
    final gen = ++_gen;
    _resetRun();
    _phase = _Phase.announcing;
    onBusy(true, 'announcement');
    _show(
      AssistView(phase: AssistPhase.announcement, answer: announcement.text),
    );
    final pre = announcement.preannounceMediaId;
    if (pre.isNotEmpty) {
      // Home Assistant's own preannounce sound is the kiosk's announcement
      // chime, so the Chimes page decides what it sounds like.
      if (pre.contains(_preannounceDefault)) {
        final chime = await player.chime('announce');
        if (gen != _gen) return;
        if (chime != null) {
          await _awaitSound(
            gen,
            chime.$1,
            safety: Duration(milliseconds: (chime.$2 * 1000).round() + 3000),
          );
        }
      } else {
        await _play(gen, pre);
      }
      if (gen != _gen) return;
    }
    if (announcement.mediaId.isNotEmpty) {
      await _play(gen, announcement.mediaId, armStopWord: true);
    } else {
      await Future<void>.delayed(noMediaAnnouncement);
    }
    if (gen != _gen) return;
    await link.finished();
    if (gen != _gen) return;
    if (announcement.startConversation) {
      _phrase = '';
      _wokeAt = _now();
      _phase = _Phase.starting;
      onBusy(true, 'voice');
      _show(
        AssistView(
          phase: AssistPhase.listening,
          answer: announcement.text,
          reactive: false,
        ),
      );
      await _startRun(gen, chime: options().wakeSound, keepPreRoll: false);
      return;
    }
    await _finish(
      gen,
      sound: 'done',
      lingerSeconds: options().announcementLingerSeconds,
    );
  }

  // ── vs_show ────────────────────────────────────────────────────────────

  /// A prompt from the vs_show action, which the manager sends to the
  /// assistant as typed text; the overlay shows it as the command. Returns
  /// the turn's generation, or null while another turn is on screen.
  int? beginShow(String prompt) {
    if (busy) return null;
    final gen = ++_gen;
    _resetRun();
    _phase = _Phase.showing;
    onBusy(true, 'show');
    _show(
      AssistView(phase: AssistPhase.thinking, command: prompt, reactive: false),
    );
    if (options().wakeSound) unawaited(player.chime('wake'));
    return gen;
  }

  /// The show's answer so far: it streams in word by word, [streaming]
  /// until the assistant is done with it.
  void showAnswer(int gen, String text, {bool streaming = true}) {
    if (gen != _gen || text.isEmpty) return;
    _show(
      _view.copyWith(
        phase: AssistPhase.speaking,
        answer: text,
        streaming: streaming,
        reactive: false,
      ),
    );
  }

  /// Speaks the show's answer, to its end.
  Future<void> showSpeak(int gen, String url) async {
    if (gen != _gen) return;
    await _play(gen, url, armStopWord: true);
  }

  /// The show's run is over: the answer stays for [seconds], or until it
  /// is dismissed at 0.
  Future<void> endShow(int gen, {required int seconds, bool failed = false}) {
    if (gen == _gen && _view.streaming) {
      _show(_view.copyWith(streaming: false));
    }
    if (failed) return _finish(gen, sound: 'error');
    if (gen == _gen && seconds <= 0) _kept = true;
    return _finish(gen, lingerSeconds: seconds > 0 ? seconds : null);
  }

  // ── results (from the chat log) ────────────────────────────────────────

  /// Tool lines and results read from the conversation's chat log.
  void showResults({
    List<String> tools = const [],
    List<AssistResult> results = const [],
  }) {
    if (!_view.visible) return;
    if (results.isNotEmpty) _hasResults = true;
    // A turn without results leaves the last turn's panel up, as Voice
    // Satellite's panel stays until another replaces it.
    _show(
      _view.copyWith(tools: tools, results: results.isEmpty ? null : results),
    );
  }

  /// Someone is looking at a result (opened an image or a video): the
  /// overlay stays until it is dismissed. With [silence] (a video) the
  /// spoken answer stops and the turn asks nothing back.
  void holdResults({bool silence = false}) {
    if (!_view.visible) return;
    _kept = true;
    _linger?.cancel();
    if (!silence) return;
    _continue = false;
    final id = _playId;
    if (id == null) return;
    final done = _playDone;
    if (done != null && !done.isCompleted) done.complete(true);
    unawaited(player.stop(id));
  }

  // ── ending ─────────────────────────────────────────────────────────────

  /// Double tap, the stop word, or the watchdog: end whatever is going on,
  /// with the done chime.
  Future<void> cancel() async {
    if (!busy) return;
    _kept = false;
    final gen = ++_gen;
    await _abandon();
    await _finish(gen, sound: 'done');
  }

  /// Stops the pipeline, the sound and the microphone. The caller has
  /// already advanced the generation.
  Future<void> _abandon() async {
    final speaking = _phase == _Phase.speaking || _phase == _Phase.announcing;
    if (_runActive) {
      _runActive = false;
      unawaited(link.request(start: false));
    }
    final id = _playId;
    final done = _playDone;
    _playId = null;
    _playDone = null;
    if (done != null && !done.isCompleted) done.complete(false);
    if (id != null) {
      await player.stop(id);
      onStopArmed(false);
    }
    // Home Assistant waits for the end of what it sent to play.
    if (speaking) await link.finished();
    await _closeMic();
    _cancelWatchdog();
  }

  Future<void> _finish(
    int gen, {
    String? sound,
    bool linger = false,
    int? lingerSeconds,
  }) async {
    if (gen != _gen) return;
    _cancelWatchdog();
    _runActive = false;
    await _closeMic();
    if (gen != _gen) return;
    final opts = options();
    if (sound != null && (sound == 'error' || opts.wakeSound)) {
      await player.chime(sound);
      if (gen != _gen) return;
    }
    // How long the overlay stays: 0 hides it now, null keeps it until it
    // is dismissed (results with Keep results on screen at 0).
    int? keep = 0;
    if (_kept) {
      keep = null;
    } else if (lingerSeconds != null) {
      keep = lingerSeconds;
    } else if (linger && _hasResults) {
      keep = opts.resultsLingerSeconds == 0 ? null : opts.resultsLingerSeconds;
    } else if (linger) {
      keep = opts.answerLingerSeconds;
    }
    // The turn is over: whatever of it is still waiting (a start inside the
    // dedupe window, a chime) must not carry on.
    final ended = ++_gen;
    _phase = _Phase.idle;
    onBusy(false, '');
    onIdle?.call();
    _linger?.cancel();
    if (keep == 0) {
      _show(AssistView.hidden);
    } else if (keep != null) {
      _linger = Timer(Duration(seconds: keep), () {
        if (ended == _gen) _show(AssistView.hidden);
      });
    }
  }

  /// A double tap: ends a turn, or takes a lingering overlay down.
  void dismiss() {
    if (busy) {
      unawaited(cancel());
      return;
    }
    if (!_view.visible) return;
    _linger?.cancel();
    _kept = false;
    _gen++;
    _show(AssistView.hidden);
  }

  void _resetRun({bool keepConversation = false}) {
    _linger?.cancel();
    _cancelWatchdog();
    if (!keepConversation) {
      _phrase = '';
      _hasResults = false;
      _kept = false;
    }
    _runActive = false;
    _streamUrl = '';
    _answerStarted = false;
    _answerPlayed = null;
    _continue = false;
  }

  /// Everything off, for shutdown or a runtime switch.
  Future<void> dispose() async {
    ++_gen;
    await _abandon();
    _linger?.cancel();
    if (_phase != _Phase.idle) {
      _phase = _Phase.idle;
      onBusy(false, '');
    }
    _show(AssistView.hidden);
  }
}
