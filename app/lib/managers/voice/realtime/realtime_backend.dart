/// The seam between a realtime voice session and whatever runs the model.
///
/// The session owns the device side: the microphone, the echo canceller's
/// route, playback, barge-in and the overlay. A backend owns the model side:
/// the connection, the conversation and the tools. Today the one backend
/// talks to the provider directly (OpenAI's realtime protocol, which xAI
/// follows). When Home Assistant's pipeline engines can run audio-to-audio
/// models, a backend over the ESPHome satellite takes its place and the
/// session does not change. That is why tools stay inside the backend: with
/// Home Assistant they run in Home Assistant, and the session only shows
/// that they ran.
library;

import 'dart:typed_data';

/// What a backend can do, read before the session starts streaming.
class RealtimeCapabilities {
  const RealtimeCapabilities({
    this.inputRate = 24000,
    this.outputRate = 24000,
    this.serverBargeIn = true,
    this.clientTurns = false,
  });

  /// The microphone audio it takes, PCM16 mono at this rate.
  final int inputRate;

  /// The voice it sends back, PCM16 mono at this rate.
  final int outputRate;

  /// The backend hears the user start talking over an answer and says so
  /// ([RealtimeSpeechStarted]). False leaves barge-in to the stop word.
  final bool serverBargeIn;

  /// Speech heard neither stops an answer nor gets a reply on its own: the
  /// session decides each turn ([RealtimeBackend.userTurn]) and stops the
  /// answer itself ([RealtimeBackend.interrupted]). A faint echo of the
  /// answer the provider takes for speech then does nothing. Without it,
  /// the provider hears nothing over an answer until the session decides
  /// the user is talking over it.
  final bool clientTurns;
}

/// Why and how the session started.
class RealtimeStart {
  const RealtimeStart({this.wakeWord = '', this.language = ''});

  /// The wake word that started it, empty for a manual wake.
  final String wakeWord;

  /// The kiosk's language, a hint for transcription.
  final String language;
}

sealed class RealtimeEvent {
  const RealtimeEvent();
}

/// The connection is up and the model is listening.
class RealtimeReady extends RealtimeEvent {
  const RealtimeReady();
}

/// A piece of the answer's audio. [itemId] names the answer it belongs to,
/// which is what an interruption refers back to.
class RealtimeAudio extends RealtimeEvent {
  const RealtimeAudio(this.itemId, this.pcm);
  final String itemId;
  final Uint8List pcm;
}

/// The user started talking. While an answer plays, this is a barge-in.
class RealtimeSpeechStarted extends RealtimeEvent {
  const RealtimeSpeechStarted();
}

class RealtimeSpeechStopped extends RealtimeEvent {
  const RealtimeSpeechStopped();
}

/// What the user said, once transcribed. [complete] is false while the
/// transcript is still growing.
class RealtimeUserText extends RealtimeEvent {
  const RealtimeUserText(this.text, {this.complete = true});
  final String text;
  final bool complete;
}

/// The answer's words so far, as the model speaks them.
class RealtimeAnswerText extends RealtimeEvent {
  const RealtimeAnswerText(this.text, {this.complete = false});
  final String text;
  final bool complete;
}

/// The model called a tool. [done] is false while it runs.
class RealtimeToolActivity extends RealtimeEvent {
  const RealtimeToolActivity(
    this.name, {
    this.done = false,
    this.error = false,
  });
  final String name;
  final bool done;
  final bool error;
}

/// The model started an answer.
class RealtimeResponseStarted extends RealtimeEvent {
  const RealtimeResponseStarted();
}

/// The model finished generating an answer. It may still be playing.
class RealtimeResponseDone extends RealtimeEvent {
  const RealtimeResponseDone();
}

/// The model decided the conversation is over (the user said goodbye).
/// The session ends once the answer finishes playing.
class RealtimeEndRequested extends RealtimeEvent {
  const RealtimeEndRequested();
}

/// The backend is gone. [error] says why when it was not asked to go.
class RealtimeClosed extends RealtimeEvent {
  const RealtimeClosed({this.error});
  final String? error;
}

/// A problem worth telling the user that does not end the session.
class RealtimeWarning extends RealtimeEvent {
  const RealtimeWarning(this.message);
  final String message;
}

abstract class RealtimeBackend {
  RealtimeCapabilities get capabilities;

  /// Everything the model side reports, in order. One listener.
  Stream<RealtimeEvent> get events;

  /// Connects and configures the conversation. [RealtimeReady] or
  /// [RealtimeClosed] follows.
  Future<void> start(RealtimeStart start);

  /// Microphone audio at [RealtimeCapabilities.inputRate].
  void sendAudio(Uint8List pcm);

  /// Playback of [itemId] was cut after [playedMs]: the user talked over
  /// it, or it was stopped. The model forgets what was not heard.
  void interrupted(String itemId, int playedMs);

  /// With [RealtimeCapabilities.clientTurns]: the speech that just ended
  /// was the user ([keep], and it gets a reply) or not (it is dropped from
  /// the conversation, unanswered).
  void userTurn({required bool keep});

  /// Closes the connection. No events follow.
  Future<void> close();
}
