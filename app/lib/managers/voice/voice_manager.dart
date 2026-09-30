import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/command_registry.dart';
import '../../core/events.dart';
import '../../core/manager.dart';
import '../btproxy/bt_proxy_manager.dart';
import '../settings/definitions.dart' as defs;
import '../settings/settings_manager.dart';
import '../wake_word/engine.dart';
import '../wake_word/wake_word_manager.dart';
import 'assist_view.dart';
import 'chat_log.dart';
import 'custom_wake_models.dart';
import 'ha_socket.dart';
import 'migration.dart';
import 'realtime/mcp_client.dart';
import 'realtime/openai_realtime_backend.dart';
import 'realtime/realtime_backend.dart';
import 'realtime/realtime_player.dart';
import 'realtime/realtime_session.dart';
import 'realtime/realtime_tools.dart';
import 'remote_speaker.dart';
import 'voice_notice.dart';
import 'voice_session.dart';
import 'wake_catalog.dart';

/// Where Home Assistant stands with this kiosk's satellite.
class VoiceHaState {
  const VoiceHaState({
    this.subscribed = false,
    this.satelliteEntity = '',
    this.entities = const {},
    this.selectsMissing = false,
  });

  /// A Home Assistant session holds the voice assistant subscription: the
  /// kiosk is added and its satellite is live.
  final bool subscribed;

  /// The kiosk's assist_satellite entity, once found in the registry.
  final String satelliteEntity;

  /// Home Assistant's own selects on the kiosk's device, by key: pipeline,
  /// pipeline_2, vad_sensitivity, wake_word, wake_word_2.
  final Map<String, String> entities;

  /// Home Assistant has the satellite but not its Assistant and Wake word
  /// selects, and the kiosk could not reload its ESPHome entry to add them.
  final bool selectsMissing;
}

/// What a realtime provider's row on the Realtime page says.
enum RealtimeStatus { unconfigured, unvalidated, validated, failed }

/// Native Voice Satellite: the kiosk as an Assist satellite of its own,
/// through its ESPHome device. Owns the wake word config, runs the turns
/// ([VoiceSession]), plays announcements, keeps the timers and publishes
/// what the assist overlay draws.
///
/// Active only on the native runtime with Voice Satellite enabled. On the
/// dashboard runtime the Voice Satellite integration's engine in the page
/// drives the wake word manager itself, and this manager keeps its hands off.
class VoiceManager extends Manager {
  VoiceManager(
    super.bus,
    super.commands,
    super.log,
    this._settings,
    this._esphome,
    this._wakeWord,
  );

  final SettingsManager _settings;
  final BtProxyManager _esphome;
  final WakeWordManager _wakeWord;

  @override
  String get name => 'voice';

  /// What the assist overlay draws.
  final view = ValueNotifier<AssistView>(AssistView.hidden);

  /// Seconds into the answer (or announcement) playing now and its length,
  /// while the player knows both; the overlay paces a long answer's scroll
  /// to it.
  ({double elapsed, double duration})? get playback => _session.playback;

  /// The bar's audio level, 0..1.
  final level = ValueNotifier<double>(0);

  final homeAssistant = ValueNotifier<VoiceHaState>(const VoiceHaState());

  /// Problems to show as toasts.
  final notices = StreamController<VoiceNotice>.broadcast();

  /// Ids of notices whose problem has cleared, to take down.
  final clearedNotices = StreamController<String>.broadcast();

  /// The wake phrase of the last turn Home Assistant was asked for, which
  /// picks its pipeline.
  String _lastPhrase = '';

  /// The wake word engine's failure last reported, so each is shown once.
  EngineFailure? _wakeFailure;

  late final VoiceSession _session;

  /// Realtime conversations, for the wake words routed to them.
  late final RealtimeSession _realtime;

  /// How much of a realtime conversation's closing silence is left, 0..1:
  /// the docked bar drains with it. 1 while it is not counting down.
  final dockCountdown = ValueNotifier<double>(1);

  /// The last problem each realtime provider ran into: a conversation
  /// that could not connect, or tools that were missing when it saved.
  /// Cleared by a conversation that connects or a save that works.
  final _realtimeProblems =
      <RealtimeProvider, ({bool tools, String message})>{};

  /// Ticks when a provider's status may read differently, for its row.
  final realtimeStatusRevision = ValueNotifier<int>(0);
  late final HaSocket _ha = HaSocket(
    baseUrl: () => _settings.get(defs.haUrl),
    token: () => _settings.get(defs.haToken),
  );

  final _subs = <StreamSubscription<Object?>>[];

  /// The media player Voice Satellite's sounds play on, when one is set.
  late final RemoteSpeaker _speaker = RemoteSpeaker(
    ha: _ha,
    onEnded: (id, {error}) => bus.publish(SoundEnded(id: id, error: error)),
    onProgress: (id, position, length) => bus.publish(
      SoundProgress(id: id, position: position, duration: length),
    ),
    measure: _measure,
    log: (line) => log.info(name, 'speaker: $line'),
  );

  /// The media player set to play Voice Satellite's sounds, or '' for the
  /// kiosk itself.
  String get _speakerTarget => enabled
      ? _settings.get(defs.voiceTtsOutput).trim().replaceFirst('ha:', '')
      : '';

  /// Normal playback mode: no announce flag, the music put back after.
  bool get _normalPlayback =>
      _settings.get(defs.voiceTtsOutputMode) == 'normal_playback';

  /// Where a speaker gets the [kind] chime, and its length in seconds.
  Future<(String, double)?> _chimeMedia(String kind) async {
    final served = await commands.execute('voiceChimeUrl', {'kind': kind});
    final data = served.data;
    if (served.ok && data is Map) {
      return (data['url'] as String, (data['duration'] as num).toDouble());
    }
    log.warn(name, 'chime $kind not served: ${served.error}');
    return null;
  }

  /// How long the audio at [url] plays, fetched and measured on the kiosk.
  Future<double?> _measure(String url, Duration timeout) async {
    var target = url;
    if (target.startsWith('/')) {
      target =
          '${_settings.get(defs.haUrl).replaceFirst(RegExp(r'/+$'), '')}'
          '$target';
    }
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      return null;
    }
    final result = await commands.execute('soundDuration', {
      'url': target,
      'timeoutMs': timeout.inMilliseconds,
    });
    final data = result.data;
    return result.ok && data is Map
        ? (data['seconds'] as num?)?.toDouble()
        : null;
  }

  late final VoiceMigration _migration = VoiceMigration(_settings, _ha);

  /// The migration switch's steps while it runs: [{id, state}] with state
  /// todo, run, done or failed. Both wizards draw it.
  final migrationSteps = ValueNotifier<List<Map<String, String>>>(const []);
  bool _migrating = false;

  /// The custom wake words Home Assistant offered on its last request.
  List<ExternalWakeWord> _external = const [];

  /// The custom models added to the kiosk.
  late final CustomWakeModels _custom = CustomWakeModels(
    onChanged: _customChanged,
    log: (line) => log.info(name, line),
  );

  /// The wake words last offered to Home Assistant, to tell when its
  /// selects need the list again.
  String _offeredSent = '';
  Timer? _selectsTimer;

  /// The subscription following Home Assistant's selects into their
  /// settings, the entities it follows and the connection it rides.
  Future<void> Function()? _unwatchSelects;
  String _watchedSelects = '';
  int _watchedOn = -1;
  Future<void>? _watching;
  Timer? _watchTimer;

  /// The option a fleet push asked for, by select key, until Home
  /// Assistant shows it.
  final _applying = <String, String>{};

  /// The value each select's setting took from Home Assistant, so the
  /// write is not mistaken for a pick to send back there.
  final _mirrored = <String, String>{};

  /// Whether this manager configured the wake word engine (so it may release
  /// it); never on the dashboard runtime.
  bool _ownsWakeWord = false;

  /// The interaction reasons this manager has published as active.
  final _busyReasons = <String>{};

  /// Home Assistant's timers on this device, by id.
  final _timers = <String, _HaTimer>{};

  /// The timers with their alert up, by id.
  final _ringing = <String>{};

  static const timerEntity = 'native';

  Timer? _previewTimer;

  /// The preview on screen asked for the docked bubble itself.
  bool _previewDocked = false;

  /// A sample turn for Preview.
  static const _previewView = AssistView(
    phase: AssistPhase.speaking,
    command: previewCommand,
    answer: previewAnswer,
  );

  /// The preview's sample turn, which the overlay shows in the kiosk's
  /// language.
  static const previewCommand = 'What is the weather?';
  static const previewAnswer = 'Sunny and 72° right now, with a light breeze.';

  /// The overlay's frame rate while it is up, for voiceStatus: frames in
  /// the last window and their average build and raster times.
  Map<String, Object?> overlayFrames = const {};

  /// Traffic counters for voiceStatus: what went up and what came back.
  int _audioSent = 0;
  int _audioRefused = 0;
  final _eventLog = <String>[];

  bool get nativeRuntime => _settings.get(defs.voiceRuntime) == 'native';
  bool get enabled => nativeRuntime && _settings.get(defs.voiceEnabled);

  /// Voice Satellite's engine in the dashboard must not run: the native
  /// runtime owns the satellite (see kiosk_screen's suppress script).
  bool get suppressPageEngine => nativeRuntime;

  VoiceSessionOptions _options() => VoiceSessionOptions(
    seamless: _settings.get(defs.voiceSeamlessWake),
    wakeSound: _settings.get(defs.voiceWakeSound),
    followupDelayMs: _settings.get(defs.voiceFollowupDelayMs).toInt(),
    followupChime: _settings.get(defs.voiceFollowupChime),
    answerLingerSeconds: _settings.get(defs.voiceAnswerLinger).toInt(),
    resultsLingerSeconds: _settings.get(defs.voiceResultsLinger).toInt(),
    announcementLingerSeconds: _settings
        .get(defs.voiceAnnouncementLinger)
        .toInt(),
    stopWord: _settings.get(defs.voiceStopWord) && _wakeWord.stopWordAvailable,
    remoteSpeech: _settings.get(defs.voiceTtsOutput).trim().isNotEmpty,
  );

  @override
  Future<void> init() async {
    homeAssistant.addListener(_announceStatus);
    _sessionMade = true;
    _session = VoiceSession(
      link: _EspLink(
        _esphome,
        onAudio: (ok) => ok ? _audioSent++ : _audioRefused++,
        onRequest: (start, phrase, ok) {
          if (start) _lastPhrase = phrase;
          _note('request start=$start phrase=$phrase -> $ok');
        },
      ),
      mic: _WakeMic(_wakeWord),
      player: _Player(commands),
      options: _options,
      onView: _onView,
      onLevel: (value) => level.value = value,
      onBusy: _onBusy,
      onStopArmed: (armed) => unawaited(_wakeWord.setStopWordArmed(armed)),
      onError: (code, message) => unawaited(_report(code, message)),
      onIntentEnd: (conversation) => unawaited(_readChatLog(conversation)),
      onTrace: _trace,
      onIdle: _resumeWake,
    );
    _realtime = RealtimeSession(
      backend: _realtimeBackend,
      mic: _WakeMic(_wakeWord),
      player: NativeRealtimePlayer(),
      chimes: _Player(commands),
      options: _realtimeOptions,
      onView: _onView,
      onLevel: (value) => level.value = value,
      onCountdown: (left) => dockCountdown.value = left,
      onBusy: (busy, _) => _onBusy(busy, 'conversation'),
      onStopArmed: (armed) => unawaited(_wakeWord.setStopWordArmed(armed)),
      onError: (code, message) {
        if (code == 'realtime') _realtimeProblem(_activeProvider, message);
        unawaited(_report(code, message));
      },
      onWarning: (message) => unawaited(_report('realtime-warning', message)),
      onTrace: (step, {text}) {
        if (step == 'connected') _realtimeProblem(_activeProvider, null);
        _trace('realtime: $step', text: text);
      },
      onIdle: _resumeWake,
    );
    _esphome.onVoice = _onVoice;
    _esphome.onVoiceConfiguration = _configuration;
    for (final provider in RealtimeProvider.values) {
      unawaited(refreshRealtimeCatalog(provider));
    }
    homeAssistant.addListener(_watchSelects);
    // A subscription dies with its socket and nothing says so: look again
    // now and then.
    _watchTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _watchSelects(),
    );

    _intents.setMethodCallHandler(_onIntent);

    _subs
      ..add(
        bus.on<WakeWordDetected>().listen((e) {
          if (!enabled || _settings.get(defs.voiceMute)) return;
          _wakeSlot(_slotForModel(e.model), e.phrase);
        }),
      )
      ..add(bus.on<StopWordDetected>().listen((_) => _onStopWord()))
      ..add(
        bus.on<SettingChanged>().listen((e) {
          // A provider's key or endpoint moved: its model and voice lists
          // may too.
          for (final provider in RealtimeProvider.values) {
            final d = _realtimeDefs(provider);
            if (e.key != d.apiKey.key && e.key != d.endpoint.key) continue;
            _catalogTimers[provider]?.cancel();
            _catalogTimers[provider] = Timer(
              const Duration(seconds: 1),
              () => unawaited(refreshRealtimeCatalog(provider)),
            );
          }
        }),
      )
      ..add(
        bus.on<SoundEnded>().listen(
          (e) => _session.onSoundEnded(e.id, error: e.error),
        ),
      )
      ..add(
        bus.on<SoundLevel>().listen(
          (e) => _session.onSoundLevel(e.id, e.level),
        ),
      )
      // The remote admin's status rows follow Home Assistant taking or
      // dropping the satellite and the wake word starting or stopping,
      // neither of which is a settings change.
      ..add(
        bus.on<WakeWordStateChanged>().listen((_) {
          _announceStatus();
          _checkWakeFailure();
        }),
      )
      ..add(
        bus.on<SoundProgress>().listen(
          (e) => _session.onSoundProgress(e.id, e.position, e.duration),
        ),
      )
      ..add(bus.on<VoiceTimerAction>().listen(_onTimerAction))
      ..add(
        bus.on<SettingChanged>().listen((e) {
          if (e.key == defs.voiceRuntime.key ||
              e.key == defs.voiceEnabled.key ||
              e.key == defs.voiceMute.key ||
              e.key == defs.voiceWakeWordEngine.key ||
              e.key == defs.voiceWakeWords.key ||
              e.key == defs.voiceWakeWordSensitivity.key ||
              e.key == defs.voiceNoiseGate.key ||
              e.key == defs.voiceStopWord.key) {
            unawaited(_sync());
          }
          // Another engine offers other wake words.
          if (e.key == defs.voiceWakeWordEngine.key) _refreshSelects();
          if (e.key == defs.voiceRuntime.key ||
              e.key == defs.voiceEnabled.key) {
            _watchSelects();
          }
          // A pick from the fleet leader (or a backup): Home Assistant owns
          // the select, so it is set there and comes back to this kiosk the
          // way a pick made by hand does.
          for (final entry in defs.voiceHaSelectSettings.entries) {
            if (e.key != entry.value.key) continue;
            final value = '${e.value ?? ''}';
            if (_mirrored.remove(entry.key) == value) continue;
            if (_settings.importing) unawaited(_applySelect(entry.key, value));
          }
          if (e.key == defs.voiceMuteTimers.key && _ringing.isNotEmpty) {
            _pushAlert();
          }
        }),
      );

    commands
      ..register(
        Command(
          name: 'voiceStatus',
          description:
              'Native Voice Satellite state: runtime, enabled, whether Home '
              'Assistant holds the satellite, the satellite entity and the '
              'turn on screen',
          quiet: true,
          handler: (_) async => CommandResult.ok(describe()),
        ),
      )
      ..register(
        Command(
          name: 'voiceWake',
          description:
              'Start listening as if a wake word fired (slot 1 or 2), the '
              'vs_wake action',
          params: const {'slot': '1 or 2 (default 1)'},
          handler: (p) async {
            if (!enabled) {
              return const CommandResult.fail('Voice Satellite is off');
            }
            final slot = (p['slot'] as num?)?.toInt() ?? 1;
            _wakeSlot(slot, _phraseForSlot(slot));
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceCancel',
          description: 'End the voice turn or announcement on screen',
          handler: (_) async {
            dismiss();
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceRealtimeState',
          description:
              'A realtime provider\'s status as its row reads it: {status '
              '(unconfigured, unvalidated, validated or failed), error, '
              'toolsError (the error is about the tools), ready, provider}',
          params: const {'provider': 'openai or xai'},
          quiet: true,
          handler: (p) async {
            final provider = RealtimeProvider.byId('${p['provider'] ?? ''}');
            final status = realtimeStatus(provider);
            return CommandResult.ok({
              'status': status.status.name,
              if (status.error.isNotEmpty) 'error': status.error,
              if (status.tools) 'toolsError': true,
              'ready': realtimeReady(provider),
              'provider': providerName(provider),
            });
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceRealtimeSave',
          description:
              'Save & Validate a realtime provider: connects with the given '
              'settings first and stores them only when the provider takes '
              'the session: {connected, error, tools, toolsError}. A saved '
              'provider is a choice in the Assistant selects',
          params: const {
            'provider': 'openai or xai',
            'apiKey': 'optional, the key to use (left out keeps the saved one)',
            'endpoint': 'the endpoint, empty for the provider\'s own',
            'model': 'the model, empty for the provider\'s default',
            'voice': 'the voice, empty for the provider\'s default',
          },
          handler: (p) async => CommandResult.ok(
            await realtimeSave(
              RealtimeProvider.byId('${p['provider'] ?? ''}'),
              apiKey: p['apiKey'] == null ? null : '${p['apiKey']}',
              endpoint: '${p['endpoint'] ?? ''}',
              model: '${p['model'] ?? ''}',
              voice: '${p['voice'] ?? ''}',
            ),
          ),
        ),
      )
      ..register(
        Command(
          name: 'voicePreview',
          description:
              'Show the overlay with a sample answer for five seconds, in '
              'the chosen skin',
          params: const {
            'kind':
                'optional result panel to include: weather, financial, '
                'images, featured or videos',
            'data': 'optional tool result for that panel',
            'seconds': 'how long it stays (default 5)',
            'level': 'the bar level it shows, 0..1 (default 0.5)',
            'docked': 'true for the realtime conversation\'s docked bubble',
          },
          handler: (p) async {
            if (_session.busy || _realtime.busy) {
              return const CommandResult.fail('a turn is on screen');
            }
            final kind = '${p['kind'] ?? ''}';
            final data = p['data'];
            final shown = kind.isEmpty
                ? _previewView
                : _previewView.copyWith(
                    results: [
                      AssistResult(
                        kind,
                        data is Map ? data.cast<String, Object?>() : const {},
                      ),
                    ],
                  );
            final seconds = (p['seconds'] as num?)?.toInt() ?? 5;
            _previewTimer?.cancel();
            _previewDocked = p['docked'] == true;
            _onView(_previewDocked ? shown.copyWith(docked: true) : shown);
            level.value = ((p['level'] as num?)?.toDouble() ?? 0.5).clamp(
              0.0,
              1.0,
            );
            _previewTimer = Timer(Duration(seconds: seconds.clamp(1, 120)), () {
              if (view.value.answer == _previewView.answer) {
                _previewDocked = false;
                _onView(AssistView.hidden);
              }
            });
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceSpeak',
          description:
              "Play Voice Satellite's speech: on the kiosk, or on the media "
              'player set to play its sounds. Returns the id sound-ended '
              'fires with when it is over.',
          params: const {
            'url': 'the audio',
            'text': 'what it says, optional',
            'kind': 'speech (default), announcement or timer',
          },
          handler: (p) async {
            final url = '${p['url'] ?? ''}'.trim();
            if (url.isEmpty) return const CommandResult.fail('no url');
            final target = _speakerTarget;
            if (target.isEmpty) {
              return commands.execute('playSound', {
                'url': url,
                'stream': true,
              });
            }
            final id = await _speaker.play(
              target,
              url,
              normal: _normalPlayback,
              text: '${p['text'] ?? ''}',
              kind: switch (p['kind']) {
                'announcement' => RemoteSound.notification,
                'timer' => RemoteSound.timed,
                _ => RemoteSound.speech,
              },
            );
            return id == null
                ? const CommandResult.fail('the speaker could not play it')
                : CommandResult.ok({'id': id});
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceChime',
          description:
              'Play a Voice Satellite chime: on the kiosk, or on the media '
              'player set to play its sounds. Resolves {id, duration} in '
              'seconds; sound-ended fires when it is over.',
          params: const {'kind': 'wake | done | error | alert | announce'},
          handler: (p) async {
            final kind = '${p['kind'] ?? ''}';
            final target = _speakerTarget;
            if (target.isNotEmpty) {
              final chime = await _chimeMedia(kind);
              if (chime != null) {
                final (media, seconds) = chime;
                // The preannounce sound is part of the announcement, and
                // followed like it.
                final id = kind == 'announce'
                    ? await _speaker.play(
                        target,
                        media,
                        normal: _normalPlayback,
                        kind: RemoteSound.notification,
                      )
                    : await _speaker.chime(
                        target,
                        media,
                        seconds,
                        normal: _normalPlayback,
                        end: kind == 'done' || kind == 'error',
                      );
                if (id != null) {
                  return CommandResult.ok({'id': id, 'duration': seconds});
                }
              }
            }
            if (kind == 'alert') {
              return commands.execute('playTimerChime', const {});
            }
            return commands.execute('playVoiceChime', {'kind': kind});
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceStopSpeech',
          description:
              'Stop a sound voiceSpeak, voiceChime or playSound started.',
          params: const {'id': 'the sound'},
          handler: (p) async {
            final id = '${p['id'] ?? ''}';
            if (_speaker.owns(id)) {
              await _speaker.stop(id);
              return const CommandResult.ok();
            }
            return commands.execute('stopSound', {'id': id});
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceSpeakerDone',
          description:
              'Voice Satellite is done with the media player for now: in '
              'normal playback mode, what it played before comes back.',
          handler: (_) async {
            _speaker.settle();
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceHaSelects',
          description:
              "Home Assistant's selects on this kiosk's device (Assistant 1 "
              'and 2, Wake word 1 and 2, Finished speaking detection) with '
              'their state and options',
          quiet: true,
          handler: (_) async => CommandResult.ok(await haSelects()),
        ),
      )
      ..register(
        Command(
          name: 'voicePipelines',
          description:
              "Home Assistant's Assist pipelines by name, the preferred one "
              'first, for picking the Assistant before Home Assistant has '
              'this kiosk',
          quiet: true,
          handler: (_) async {
            try {
              final list = await _ha.request({
                'type': 'assist_pipeline/pipeline/list',
              });
              final pipelines = list is Map ? list['pipelines'] : null;
              final preferred = list is Map ? list['preferred_pipeline'] : null;
              return CommandResult.ok({
                'preferred': [
                  for (final p in (pipelines as List? ?? const []))
                    if (p is Map && p['id'] == preferred) '${p['name']}',
                ].firstOrNull,
                'pipelines': [
                  for (final p in pipelines ?? const [])
                    if (p is Map) '${p['name']}',
                ],
              });
            } catch (e) {
              return CommandResult.fail('$e');
            }
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceWakeWordChoices',
          description:
              'The wake words an engine offers on this kiosk, id and phrase: '
              'its bundled models and the custom ones added here',
          params: const {'engine': 'vswakeword, microwakeword or openwakeword'},
          quiet: true,
          handler: (p) async {
            final engine = voiceEngines['${p['engine'] ?? ''}'] ?? _engine;
            return CommandResult.ok([
              for (final w in offeredWakeWords(
                engine,
                external: _external,
                custom: _custom.models,
              ))
                {'id': w.id, 'phrase': w.phrase},
            ]);
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceSelectOption',
          description: "Set one of Home Assistant's selects on this kiosk",
          params: const {
            'key':
                'pipeline, pipeline_2, vad_sensitivity, wake_word, '
                'wake_word_2',
            'option': 'the option to set',
          },
          handler: (p) async {
            final key = '${p['key'] ?? ''}';
            final option = '${p['option'] ?? ''}';
            final engine = switch (key) {
              'pipeline' => defs.voiceEngine1,
              'pipeline_2' => defs.voiceEngine2,
              _ => null,
            };
            final provider = RealtimeProvider.values
                .where((p) => realtimeOption(p) == option)
                .firstOrNull;
            if (engine != null && provider != null) {
              if (!realtimeReady(provider)) {
                return const CommandResult.fail('realtime not validated');
              }
              await _settings.set(engine, provider.id);
              return const CommandResult.ok();
            }
            // A pipeline picked for a wake word on Realtime takes it back
            // to Assist.
            if (engine != null) await _settings.set(engine, 'assist');
            final ok = await selectOption(key, option);
            return ok
                ? const CommandResult.ok()
                : const CommandResult.fail('option not set');
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceShow',
          description:
              'Send a prompt to the assistant and show its answer and results '
              'on this kiosk (the vs_show action)',
          params: const {
            'prompt': 'what to ask the assistant',
            'speak': 'true to speak the answer too',
            'pipeline': '1 or 2: the assistant that answers (default 1)',
            'duration': 'seconds the answer stays, 0 until dismissed',
          },
          handler: (p) async {
            final prompt = '${p['prompt'] ?? ''}'.trim();
            if (prompt.isEmpty) return const CommandResult.fail('no prompt');
            if (!enabled || !nativeRuntime) {
              return const CommandResult.fail('Voice Satellite is off');
            }
            final gen = _session.beginShow(prompt);
            if (gen == null) {
              return const CommandResult.fail('a turn is on screen');
            }
            unawaited(
              _runShow(
                gen,
                prompt,
                speak: p['speak'] == true,
                slot: (p['pipeline'] as num?)?.toInt() == 2 ? 2 : 1,
                seconds: ((p['duration'] as num?)?.toInt() ?? 0).clamp(0, 3600),
              ),
            );
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceStartTimer',
          description:
              'Start a voice timer on this kiosk (the vs_start_timer action), '
              'through the timer intent so Home Assistant owns it',
          params: const {
            'name': 'optional timer name',
            'hours': '0..168',
            'minutes': '0..59',
            'seconds': '0..59',
          },
          handler: (p) async {
            final hours = (p['hours'] as num?)?.toInt() ?? 0;
            final minutes = (p['minutes'] as num?)?.toInt() ?? 0;
            final seconds = (p['seconds'] as num?)?.toInt() ?? 0;
            if (hours + minutes + seconds <= 0) {
              return const CommandResult.fail('the timer needs a duration');
            }
            final name = '${p['name'] ?? ''}'.trim();
            final error = await _intent('HassStartTimer', {
              if (hours > 0) 'hours': hours,
              if (minutes > 0) 'minutes': minutes,
              if (seconds > 0) 'seconds': seconds,
              if (name.isNotEmpty) 'name': name,
            });
            return error == null
                ? const CommandResult.ok()
                : CommandResult.fail(error);
          },
        ),
      );

    _registerMigrationCommands();
    _registerCustomModelCommands();
    await _custom.init();
    await _sync();
  }

  // ── custom models ──────────────────────────────────────────────────────

  void _customChanged() {
    bus.publish(const RemoteStatusChanged('wake-models'));
    unawaited(_sync());
    _refreshSelects();
  }

  String _offeredSignature() => [
    for (final w in offeredWakeWords(
      _engine,
      external: _external,
      custom: _custom.models,
    ))
      '${w.id}=${w.phrase}',
  ].join('|');

  /// Home Assistant reads the wake words for its selects only when it asks
  /// the kiosk for its configuration, which it does as the ESPHome entry
  /// sets up. When the list changed (a custom model, another engine), the
  /// entry is reloaded so the selects offer what the kiosk has now.
  void _refreshSelects() {
    _selectsTimer?.cancel();
    _selectsTimer = Timer(const Duration(seconds: 2), () {
      final satellite = homeAssistant.value.satelliteEntity;
      if (!enabled || satellite.isEmpty || _offeredSent.isEmpty) return;
      if (_offeredSignature() == _offeredSent) return;
      unawaited(_reloadEsphomeEntry(satellite));
    });
  }

  // ── Home Assistant's selects, mirrored ─────────────────────────────────

  /// Follows Home Assistant's selects on this kiosk into their settings
  /// while the native satellite runs, so a fleet leader carries its picks
  /// and a follower's own pick reads as drift.
  void _watchSelects() {
    _watching ??= _rewatchSelects().whenComplete(() => _watching = null);
  }

  Future<void> _rewatchSelects() async {
    final entities = homeAssistant.value.entities;
    final want = enabled && nativeRuntime && entities.isNotEmpty;
    final signature = want
        ? jsonEncode(SplayTreeMap<String, String>.from(entities))
        : '';
    final live =
        _unwatchSelects != null &&
        _ha.connected &&
        _ha.connections == _watchedOn;
    if (signature == _watchedSelects && (signature.isEmpty || live)) return;
    final unwatch = _unwatchSelects;
    _unwatchSelects = null;
    _watchedSelects = '';
    if (unwatch != null) await unwatch();
    if (!want) return;
    final keyOf = {for (final e in entities.entries) e.value: e.key};
    try {
      _unwatchSelects = await _ha.subscribe(
        {'type': 'subscribe_entities', 'entity_ids': keyOf.keys.toList()},
        (event) {
          // subscribe_entities: "a" carries whole states, "c" the changes.
          final added = event['a'];
          if (added is Map) {
            added.forEach((entity, raw) {
              if (raw is Map) _mirrorSelect(keyOf['$entity'], raw['s']);
            });
          }
          final changed = event['c'];
          if (changed is Map) {
            changed.forEach((entity, raw) {
              final plus = raw is Map ? raw['+'] : null;
              if (plus is Map) _mirrorSelect(keyOf['$entity'], plus['s']);
            });
          }
        },
      );
      _watchedSelects = signature;
      _watchedOn = _ha.connections;
      _applyPending();
    } catch (e) {
      log.debug(name, 'selects not followed: $e');
    }
  }

  /// Picks made before Home Assistant had this kiosk (at onboarding, or a
  /// migration then), set now that its selects are there, once.
  void _applyPending() {
    final raw = _settings.get(defs.voicePendingSelects);
    if (raw.isEmpty) return;
    unawaited(_settings.set(defs.voicePendingSelects, '', source: 'setup'));
    Object? picks;
    try {
      picks = jsonDecode(raw);
    } catch (_) {}
    if (picks is! Map) return;
    for (final entry in picks.entries) {
      final option = '${entry.value ?? ''}';
      if (option.isEmpty) continue;
      unawaited(_applySelect('${entry.key}', option, reason: 'setup'));
    }
  }

  void _mirrorSelect(String? key, Object? state) {
    final def = defs.voiceHaSelectSettings[key];
    if (def == null || state is! String) return;
    if (state.isEmpty || state == 'unavailable' || state == 'unknown') return;
    final wanted = _applying[key];
    if (wanted != null) {
      // A fleet pick on its way: the select passing through another option
      // (the wake words while an engine switch reloads them) is not drift.
      if (state != wanted) return;
      _applying.remove(key);
    }
    if (_settings.get(def) == state) return;
    _mirrored[key!] = state;
    unawaited(_settings.set(def, state, source: 'Home Assistant'));
  }

  /// A wake word that went away (its engine switched, its model deleted)
  /// leaves the kiosk listening for the ones left, or for the engine's
  /// first with none left. Home Assistant would show No wake word for it
  /// and never learn what the kiosk listens for instead, so the kiosk sets
  /// its selects to that, as a pick by hand would.
  void _reportFallback(
    List<OfferedWakeWord> offered,
    List<OfferedWakeWord> listened,
  ) {
    final stored = _activeIds();
    final ids = {for (final w in offered) w.id};
    if (listened.isEmpty || stored.every(ids.contains)) return;
    final now = [for (final w in listened) w.id];
    log.info(name, 'wake words $stored are gone, listening for $now');
    unawaited(
      _settings.set(defs.voiceWakeWords, jsonEncode(now), source: 'fallback'),
    );
    final slots = {
      'wake_word': listened.first.phrase,
      'wake_word_2': listened.length > 1 ? listened[1].phrase : 'no_wake_word',
    };
    for (final slot in slots.entries) {
      // A pick on its way from the fleet leader settles the slot itself.
      if (_applying.containsKey(slot.key)) continue;
      unawaited(_applySelect(slot.key, slot.value, reason: 'the fallback'));
    }
  }

  /// Sets Home Assistant's [key] select to [option]. The option may not be
  /// offered yet, as when the same push switched the wake word engine and
  /// Home Assistant is still reloading the list, so this tries for a
  /// minute.
  Future<void> _applySelect(
    String key,
    String option, {
    String reason = 'the fleet',
  }) async {
    if (option.isEmpty) return;
    _applying[key] = option;
    for (var attempt = 0; attempt < 20; attempt++) {
      if (attempt > 0) await Future<void>.delayed(const Duration(seconds: 3));
      if (_applying[key] != option) return;
      if (!enabled || !nativeRuntime) break;
      final entity = homeAssistant.value.entities[key];
      if (entity == null) continue;
      final state = await _migration.stateOf(entity);
      if (state?['state'] == option) {
        _applying.remove(key);
        return;
      }
      final attributes = state?['attributes'];
      final options = attributes is Map ? attributes['options'] : null;
      if (options is! List || !options.contains(option)) continue;
      if (await selectOption(key, option)) {
        log.info(name, 'set $key to $option for $reason');
        return;
      }
    }
    if (_applying[key] == option) _applying.remove(key);
    log.warn(name, 'Home Assistant did not offer $option for $key');
  }

  /// A follower whose leader syncs Voice Satellite: its custom models are
  /// the leader's, kept in step by the fleet, so they are not changed here.
  Future<bool> _modelsManaged() async {
    final r = await commands.execute('fleetStatus', const {});
    final following = r.ok && r.data is Map
        ? (r.data as Map)['following']
        : null;
    final keys = following is Map ? following['syncedKeys'] : null;
    return keys is List && keys.contains(defs.voiceWakeWordEngine.key);
  }

  String? _offeredName(Map<String, Object?> model) {
    final engine = voiceEngines[model['engine']];
    if (engine == null) return null;
    for (final w in offeredWakeWords(
      engine,
      external: _external,
      custom: _custom.models,
    )) {
      if (w.id == model['id']) return w.phrase;
    }
    return null;
  }

  static const _managedError =
      'The fleet leader manages the custom models on this kiosk.';

  void _registerCustomModelCommands() {
    CommandResult fail(Object e) =>
        CommandResult.fail(e is StateError ? e.message : '$e');
    commands
      ..register(
        Command(
          name: 'customWakeModels',
          description:
              'The custom wake word models on this kiosk, with the engine in '
              'use',
          quiet: true,
          handler: (_) async => CommandResult.ok({
            'models': [
              // Named as Home Assistant's selects offer them.
              for (final m in _custom.describe())
                {...m, 'wakeWord': _offeredName(m) ?? m['wakeWord']},
            ],
            'engine': _settings.get(defs.voiceWakeWordEngine),
            'managed': await _modelsManaged(),
          }),
        ),
      )
      ..register(
        Command(
          name: 'stageCustomWakeModel',
          description:
              'One file of a custom wake word upload, before '
              'commitCustomWakeModels checks them together.',
          params: const {'name': 'the file name', 'stream': 'the body'},
          quiet: true,
          handler: (p) async {
            final body = p['stream'];
            if (body is! Stream<List<int>>) {
              return const CommandResult.fail('no body');
            }
            if (await _modelsManaged()) {
              await body.drain<void>();
              return const CommandResult.fail(_managedError);
            }
            final name = '${p['name'] ?? ''}';
            try {
              await _custom.stage(name, body, (p['length'] as num?)?.toInt());
              return const CommandResult.ok();
            } on WakeModelError catch (e) {
              // Refused, not failed: the upload goes on with its other files
              // and the page says why this one was left out.
              return CommandResult.ok({
                'rejected': RejectedWakeFile(
                  name,
                  e.english,
                  code: e.code,
                  values: e.values,
                ).toJson(),
              });
            } catch (e) {
              return fail(e);
            }
          },
        ),
      )
      ..register(
        Command(
          name: 'addCustomWakeModelFiles',
          description:
              'Add custom wake word models from files on the device, checked '
              'together.',
          params: const {'paths': 'the files'},
          handler: (p) async {
            final paths = p['paths'];
            if (paths is! List) return const CommandResult.fail('no paths');
            if (await _modelsManaged()) {
              return const CommandResult.fail(_managedError);
            }
            final refused = <Map<String, Object?>>[];
            try {
              for (final path in paths) {
                try {
                  await _custom.stageCopy('$path');
                } on WakeModelError catch (e) {
                  refused.add(
                    RejectedWakeFile(
                      '$path'.split('/').last,
                      e.english,
                      code: e.code,
                      values: e.values,
                    ).toJson(),
                  );
                }
              }
            } catch (e) {
              await _custom.commit();
              return fail(e);
            }
            final result = await _custom.commit();
            return CommandResult.ok({
              ...result,
              'rejected': [...refused, ...(result['rejected'] as List)],
            });
          },
        ),
      )
      ..register(
        Command(
          name: 'commitCustomWakeModels',
          description:
              'Check the uploaded custom wake word files and keep the models '
              'that work.',
          handler: (_) async => CommandResult.ok(await _custom.commit()),
        ),
      )
      ..register(
        Command(
          name: 'deleteCustomWakeModel',
          description: 'Delete a custom wake word model.',
          params: const {
            'engine': 'microwakeword, openwakeword or vswakeword',
            'id': 'the model',
          },
          handler: (p) async {
            if (await _modelsManaged()) {
              return const CommandResult.fail(_managedError);
            }
            return await _custom.delete(
                  '${p['engine'] ?? ''}',
                  '${p['id'] ?? ''}',
                )
                ? const CommandResult.ok()
                : const CommandResult.fail('no such model');
          },
        ),
      )
      ..register(
        Command(
          name: 'customWakeModelsManifest',
          description:
              'Every custom wake word file with its SHA-256, for the fleet',
          quiet: true,
          handler: (_) async =>
              CommandResult.ok({'files': await _custom.manifest()}),
        ),
      )
      ..register(
        Command(
          name: 'customWakeModelPath',
          description: 'Where a custom wake word file is, for the fleet',
          params: const {'path': 'folder/name'},
          quiet: true,
          handler: (p) async {
            final file = await _custom.file('${p['path'] ?? ''}');
            return file == null
                ? const CommandResult.fail('no such file')
                : CommandResult.ok({'path': file.path});
          },
        ),
      )
      ..register(
        Command(
          name: 'receiveCustomWakeModelFile',
          description: 'A custom wake word file from the fleet leader.',
          params: const {'path': 'folder/name', 'stream': 'the body'},
          quiet: true,
          handler: (p) async {
            final body = p['stream'];
            if (body is! Stream<List<int>>) {
              return const CommandResult.fail('no body');
            }
            try {
              await _custom.receive(
                '${p['path'] ?? ''}',
                body,
                (p['length'] as num?)?.toInt(),
              );
              return const CommandResult.ok();
            } catch (e) {
              return fail(e);
            }
          },
        ),
      )
      ..register(
        Command(
          name: 'removeCustomWakeModelFile',
          description: 'Remove a custom wake word file the leader dropped.',
          params: const {'path': 'folder/name'},
          quiet: true,
          handler: (p) async {
            await _custom.remove('${p['path'] ?? ''}');
            return const CommandResult.ok();
          },
        ),
      );
  }

  // ── migration ──────────────────────────────────────────────────────────

  static const _satelliteParam =
      "the integration's assist_satellite to migrate from, else the one the "
      'dashboard assigned';

  void _pickSatellite(Map<String, Object?> params) =>
      _migration.picked = '${params['satellite'] ?? ''}'.trim();

  void _registerMigrationCommands() {
    commands
      ..register(
        Command(
          name: 'voiceMigrationCheck',
          description:
              'Before migrating from the Voice Satellite integration: Home '
              'Assistant connected, this kiosk added through ESPHome, an '
              'administrator token, the microphone allowed',
          params: const {
            'deferred':
                'true at onboarding: Home Assistant only, the kiosk '
                'is added and the microphone allowed later',
          },
          quiet: true,
          handler: (p) async => CommandResult.ok(
            await migrationCheck(deferred: p['deferred'] == true),
          ),
        ),
      )
      ..register(
        Command(
          name: 'voiceMigrationPlan',
          description:
              'What the migration carries over from the old satellite, group '
              'by group, and the values in each',
          params: const {'satellite': _satelliteParam},
          quiet: true,
          handler: (p) async {
            _pickSatellite(p);
            try {
              return CommandResult.ok(await migrationPlan());
            } catch (e) {
              return CommandResult.fail('$e');
            }
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceMigrationAutomations',
          description:
              'Automations and scripts that reference the old satellite. '
              'Listed only: the migration never changes them.',
          params: const {'satellite': _satelliteParam},
          quiet: true,
          handler: (p) async {
            _pickSatellite(p);
            try {
              final entities = await _migration.oldEntities();
              return CommandResult.ok({
                'items': await _migration.automations(entities),
              });
            } catch (e) {
              return CommandResult.fail('$e');
            }
          },
        ),
      )
      ..register(
        Command(
          name: 'vsMigrate',
          description:
              'Migrate from the Voice Satellite integration to native Voice '
              'Satellite: carry the groups over, stop the dashboard engine, '
              'start here, set the kiosk\'s entities, check. Rolls back on '
              'failure.',
          params: const {
            'groups': 'voice, appearance, conversation, assistant, timers',
            'deferred':
                'true at onboarding: turn on without waiting for '
                'Home Assistant, its selects set once it adds the kiosk',
            'satellite': _satelliteParam,
          },
          handler: (p) async {
            _pickSatellite(p);
            final raw = p['groups'];
            final groups = raw is List
                ? [for (final g in raw) '$g']
                : VoiceMigration.groups;
            final result = await migrate(
              groups,
              deferred: p['deferred'] == true,
            );
            return result['ok'] == true
                ? CommandResult.ok(result)
                : CommandResult.fail('${result['error']}');
          },
        ),
      )
      ..register(
        Command(
          name: 'voiceMigrationProgress',
          description: 'The migration switch\'s steps while it runs',
          quiet: true,
          handler: (_) async => CommandResult.ok({
            'running': _migrating,
            'steps': migrationSteps.value,
          }),
        ),
      )
      ..register(
        Command(
          name: 'vsRollback',
          description:
              'Run Voice Satellite from the dashboard again (the integration '
              'must still be installed). Nothing set here is lost.',
          handler: (_) async {
            await rollback();
            return const CommandResult.ok();
          },
        ),
      );
  }

  Future<Map<String, Object?>> migrationCheck({bool deferred = false}) async {
    final checks = <Map<String, Object?>>[];
    final ha = await commands.execute('haStatus', const {});
    final connected =
        ha.ok && ha.data is Map && (ha.data as Map)['connected'] == true;
    checks.add({'id': 'homeAssistant', 'ok': connected});
    if (deferred) {
      return {
        'checks': checks,
        'ready': connected,
        'satellite': _migration.oldSatellite,
      };
    }
    final esphomeOn = _settings.get(defs.esphomeEnabled);
    var added = false;
    if (esphomeOn) {
      final status = await commands.execute('esphomeStatus', const {});
      added =
          status.ok &&
          status.data is Map &&
          ((status.data as Map)['clients'] as num? ?? 0) > 0;
    }
    checks.add({'id': 'esphome', 'ok': added, 'esphomeOn': esphomeOn});
    // Unknown when Home Assistant did not answer: that says nothing about
    // the token's user.
    var admin = false;
    var known = false;
    if (connected) {
      try {
        final user = await _ha.request({'type': 'auth/current_user'});
        admin = user is Map && user['is_admin'] == true;
        known = user is Map;
      } catch (e) {
        log.warn(name, 'token user not checked: $e');
      }
    }
    checks.add({
      'id': 'admin',
      'ok': admin,
      'warnOnly': true,
      'unknown': !known,
    });
    final perms = await commands.execute('getSystemPermissions', const {});
    final mic =
        perms.ok &&
        perms.data is Map &&
        (perms.data as Map)['microphone'] == true;
    checks.add({'id': 'microphone', 'ok': mic});
    return {
      'checks': checks,
      'ready': connected && added && mic,
      'satellite': _migration.oldSatellite,
    };
  }

  Future<Map<String, Object?>> migrationPlan() async {
    final entities = await _migration.oldEntities();
    final storage = await commands.execute('getLocalStorage', const {});
    final browser = await _migration.oldBrowserConfig(
      storage.ok && storage.data is String ? storage.data as String : null,
    );
    final mapped = VoiceMigration.mapSettings(entities, browser);
    final lines = VoiceMigration.describe(mapped);
    return {
      'satellite': _migration.oldSatellite,
      'groups': [
        for (final g in VoiceMigration.groups)
          {'id': g, 'values': lines[g] ?? '', 'settings': mapped[g]},
      ],
      'selects': VoiceMigration.mapSelects(entities),
      'customCss': '${browser['custom_css'] ?? ''}'.trim().isNotEmpty,
    };
  }

  void _step(String id, String state) {
    migrationSteps.value = [
      for (final step in migrationSteps.value)
        step['id'] == id ? {'id': id, 'state': state} : step,
    ];
  }

  /// The switch: every step reported through [migrationSteps]. Rolls back
  /// to the dashboard runtime when the satellite does not come up.
  /// [deferred] is a migration at onboarding: no engine runs in the
  /// dashboard yet and Home Assistant has not added this kiosk, so the
  /// satellite is turned on without waiting for it and the old satellite's
  /// selects are kept to set once Home Assistant has the kiosk.
  Future<Map<String, Object?>> migrate(
    List<String> groups, {
    bool deferred = false,
  }) async {
    if (_migrating) {
      return {'ok': false, 'error': 'A migration is already running.'};
    }
    _migrating = true;
    migrationSteps.value = [
      for (final id
          in deferred
              ? const ['save', 'entities']
              : const ['save', 'stop', 'start', 'entities', 'check'])
        {'id': id, 'state': 'todo'},
    ];
    final fallbacks = <String>[];
    try {
      _step('save', 'run');
      final entities = await _migration.oldEntities();
      final storage = await commands.execute('getLocalStorage', const {});
      final browser = await _migration.oldBrowserConfig(
        storage.ok && storage.data is String ? storage.data as String : null,
      );
      final mapped = VoiceMigration.mapSettings(entities, browser);
      for (final group in groups) {
        final values = mapped[group] ?? const <String, Object>{};
        for (final entry in values.entries) {
          await _settings.setFromJson(
            entry.key,
            entry.value,
            source: 'migration',
          );
        }
      }
      _step('save', 'done');

      if (deferred) {
        _step('entities', 'run');
        final selects = groups.contains('voice')
            ? VoiceMigration.mapSelects(entities)
            : const <String, String>{};
        await _settings.set(
          defs.voicePendingSelects,
          selects.isEmpty ? '' : jsonEncode(selects),
          source: 'migration',
        );
        await _settings.set(defs.voiceEnabled, true, source: 'migration');
        await _settings.set(defs.voiceRuntime, 'native', source: 'migration');
        _step('entities', 'done');
        log.info(name, 'migrated from the Voice Satellite integration');
        return {'ok': true, 'fallbacks': fallbacks};
      }

      _step('stop', 'run');
      await commands.execute('vsEngine', const {'action': 'stop'});
      _step('stop', 'done');

      _step('start', 'run');
      await _settings.set(defs.voiceEnabled, true, source: 'migration');
      await _settings.set(defs.voiceRuntime, 'native', source: 'migration');
      // A muted satellite (the old one's mute carries over) is up without
      // listening for the wake word.
      final up = await _waitFor(
        () =>
            homeAssistant.value.subscribed &&
            (_wakeWord.listening || _settings.get(defs.voiceMute)),
        const Duration(seconds: 30),
      );
      if (!up) throw StateError('The satellite did not come up in time.');
      _step('start', 'done');

      _step('entities', 'run');
      if (groups.contains('voice')) {
        await refreshHomeAssistant();
        await _waitFor(
          () => homeAssistant.value.entities.containsKey('pipeline'),
          const Duration(seconds: 20),
        );
        final selects = VoiceMigration.mapSelects(entities);
        for (final entry in selects.entries) {
          final ok = await selectOption(entry.key, entry.value);
          if (!ok && entry.key.startsWith('wake_word')) {
            fallbacks.add(entry.value);
          }
        }
      }
      _step('entities', 'done');

      _step('check', 'run');
      final idle = await _waitFor(
        () => homeAssistant.value.satelliteEntity.isNotEmpty,
        const Duration(seconds: 15),
      );
      if (!idle) {
        throw StateError('Home Assistant did not report the satellite.');
      }
      _step('check', 'done');
      log.info(name, 'migrated from the Voice Satellite integration');
      return {'ok': true, 'fallbacks': fallbacks};
    } catch (e) {
      final running = migrationSteps.value.firstWhere(
        (s) => s['state'] == 'run',
        orElse: () => const {'id': ''},
      );
      if (running['id']!.isNotEmpty) _step(running['id']!, 'failed');
      log.warn(name, 'migration failed, back to the dashboard: $e');
      if (!deferred) await rollback();
      return {'ok': false, 'error': e is StateError ? e.message : '$e'};
    } finally {
      _migrating = false;
    }
  }

  Future<bool> _waitFor(bool Function() ready, Duration limit) async {
    final until = DateTime.now().add(limit);
    while (DateTime.now().isBefore(until)) {
      if (ready()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return ready();
  }

  /// Back to the integration's engine in the dashboard. The voice settings
  /// stay for next time.
  Future<void> rollback() async {
    await _settings.set(defs.voiceEnabled, false, source: 'migration');
    await _settings.set(defs.voiceRuntime, 'dashboard', source: 'migration');
    log.info(name, 'Voice Satellite runs from the dashboard again');
  }

  /// Home Assistant's selects on the kiosk, for the settings pages:
  /// {key: {entity_id, state, options, available}}, plus selectsMissing.
  Future<Map<String, Object?>> haSelects() async {
    if (homeAssistant.value.entities.isEmpty) await refreshHomeAssistant();
    final out = <String, Object?>{};
    for (final entry in homeAssistant.value.entities.entries) {
      final state = await _migration.stateOf(entry.value);
      final attributes = state?['attributes'];
      out[entry.key] = {
        'entity_id': entry.value,
        'state': state?['state'],
        'options': attributes is Map ? attributes['options'] : const [],
        'available':
            state != null &&
            state['state'] != 'unavailable' &&
            state['state'] != 'unknown',
      };
    }
    out['selectsMissing'] = homeAssistant.value.selectsMissing;
    // Every validated realtime provider, more choices for each Assistant,
    // and the one each wake word is on (its option, or null for Assist).
    out['realtime'] = {
      'options': [
        for (final provider in RealtimeProvider.values)
          if (realtimeReady(provider))
            {
              'value': realtimeOption(provider),
              'provider': providerName(provider),
            },
      ],
      'pipeline': _slotOption(1),
      'pipeline_2': _slotOption(2),
    };
    return out;
  }

  /// Sets one of Home Assistant's selects on the kiosk ([key] as in
  /// [VoiceHaState.entities]); false when it has no such option.
  Future<bool> selectOption(String key, String option) async {
    final entity = homeAssistant.value.entities[key];
    if (entity == null) return false;
    final state = await _migration.stateOf(entity);
    final attributes = state?['attributes'];
    final options = attributes is Map ? attributes['options'] : null;
    if (options is List && !options.contains(option)) return false;
    try {
      await _ha.request({
        'type': 'call_service',
        'domain': 'select',
        'service': 'select_option',
        'service_data': {'option': option},
        'target': {'entity_id': entity},
      });
      return true;
    } catch (e) {
      log.warn(name, 'select $entity not set: $e');
      return false;
    }
  }

  /// A turn or an announcement is running. False before [init] made the
  /// session: a settings page can draw first.
  bool get busy => _sessionMade && (_session.busy || _realtime.busy);
  bool _sessionMade = false;

  Map<String, Object?> describe() => {
    'runtime': _settings.get(defs.voiceRuntime),
    'enabled': enabled,
    'serving': _esphome.voiceServing,
    'subscribed': homeAssistant.value.subscribed,
    'satelliteEntity': homeAssistant.value.satelliteEntity,
    'entities': homeAssistant.value.entities,
    'selectsMissing': homeAssistant.value.selectsMissing,
    'busy': _session.busy || _realtime.busy,
    'conversation': _realtime.busy,
    'listening': _wakeWord.listening,
    'phase': view.value.phase.name,
    'command': view.value.command,
    'answer': view.value.answer,
    'wakeWords': _activeIds(),
    'engine': _settings.get(defs.voiceWakeWordEngine),
    'timers': _timers.length,
    'overlayFrames': overlayFrames,
    'audioSent': _audioSent,
    'audioRefused': _audioRefused,
    'events': _eventLog,
  };

  void _note(String line) {
    _eventLog.add(
      '${DateTime.now().toIso8601String().substring(11, 19)} $line',
    );
    if (_eventLog.length > 30) _eventLog.removeAt(0);
  }

  // ── wake word ──────────────────────────────────────────────────────────

  List<String> _activeIds() {
    try {
      final raw = jsonDecode(_settings.get(defs.voiceWakeWords));
      if (raw is List) return [for (final id in raw) '$id'];
    } catch (_) {}
    return const ['ok_nabu'];
  }

  WakeWordEngineType get _engine =>
      voiceEngines[_settings.get(defs.voiceWakeWordEngine)] ??
      WakeWordEngineType.vsWakeWord;

  /// The wake word slot (1 or 2) of the model [id], 1 when it is not one
  /// of the configured ones.
  int _slotForModel(String id) {
    final models = _wakeWord.config?.models ?? const [];
    final index = models.indexWhere((m) => m.id == id);
    return index < 0 ? 1 : index + 1;
  }

  /// The settings of one realtime provider: each has its own connection,
  /// model and voice.
  static ({
    SettingDef<String> apiKey,
    SettingDef<String> endpoint,
    SettingDef<String> model,
    SettingDef<String> voice,
    SettingDef<String> validated,
  })
  _realtimeDefs(RealtimeProvider provider) => switch (provider) {
    RealtimeProvider.openai => (
      apiKey: defs.voiceRealtimeOpenAiApiKey,
      endpoint: defs.voiceRealtimeOpenAiEndpoint,
      model: defs.voiceRealtimeOpenAiModel,
      voice: defs.voiceRealtimeOpenAiVoice,
      validated: defs.voiceRealtimeOpenAiValidated,
    ),
    RealtimeProvider.xai => (
      apiKey: defs.voiceRealtimeXaiApiKey,
      endpoint: defs.voiceRealtimeXaiEndpoint,
      model: defs.voiceRealtimeXaiModel,
      voice: defs.voiceRealtimeXaiVoice,
      validated: defs.voiceRealtimeXaiValidated,
    ),
  };

  /// The provider answering [slot]'s wake word: picked in its Assistant
  /// select, and still validated. Null for Assist.
  RealtimeProvider? _slotProvider(int slot) {
    final engine = _settings.get(
      slot == 2 ? defs.voiceEngine2 : defs.voiceEngine1,
    );
    final provider = RealtimeProvider.values
        .where((p) => p.id == engine)
        .firstOrNull;
    return provider != null && realtimeReady(provider) ? provider : null;
  }

  /// [slot]'s Assistant select's value when a provider answers it.
  String? _slotOption(int slot) {
    final provider = _slotProvider(slot);
    return provider == null ? null : realtimeOption(provider);
  }

  /// A provider's choice in the Assistant selects. No Home Assistant
  /// pipeline is named this.
  static String realtimeOption(RealtimeProvider provider) =>
      '__realtime_${provider.id}__';

  /// What Save & Validate records: the settings it connected with.
  String realtimeSignature(RealtimeProvider provider) {
    final d = _realtimeDefs(provider);
    return _signature(
      provider,
      endpoint: _settings.get(d.endpoint),
      apiKey: _settings.get(d.apiKey),
    );
  }

  static String _signature(
    RealtimeProvider provider, {
    required String endpoint,
    required String apiKey,
  }) => sha256
      .convert(
        utf8.encode([provider.id, endpoint.trim(), apiKey.trim()].join('\n')),
      )
      .toString();

  /// The provider connected with its settings as they are now.
  bool realtimeReady(RealtimeProvider provider) =>
      _settings.get(_realtimeDefs(provider).validated) ==
      realtimeSignature(provider);

  /// What a provider's row says: nothing set up yet, set up but not
  /// validated with its settings as they are now, validated, or validated
  /// with a problem since.
  /// [tools] tells a problem with the tools from one with the connection.
  ({RealtimeStatus status, String error, bool tools}) realtimeStatus(
    RealtimeProvider provider,
  ) {
    final d = _realtimeDefs(provider);
    if (_settings.get(d.apiKey).trim().isEmpty &&
        _settings.get(d.endpoint).trim().isEmpty) {
      return (status: RealtimeStatus.unconfigured, error: '', tools: false);
    }
    if (!realtimeReady(provider)) {
      return (status: RealtimeStatus.unvalidated, error: '', tools: false);
    }
    final problem = _realtimeProblems[provider];
    return problem == null
        ? (status: RealtimeStatus.validated, error: '', tools: false)
        : (
            status: RealtimeStatus.failed,
            error: problem.message,
            tools: problem.tools,
          );
  }

  void _realtimeProblem(
    RealtimeProvider provider,
    String? message, {
    bool tools = false,
  }) {
    final before = _realtimeProblems[provider];
    if (message == null || message.isEmpty) {
      _realtimeProblems.remove(provider);
    } else {
      _realtimeProblems[provider] = (tools: tools, message: message);
    }
    if (before != _realtimeProblems[provider]) realtimeStatusRevision.value++;
  }

  /// A provider's name, for the Assistant selects' choice.
  static String providerName(RealtimeProvider provider) =>
      provider == RealtimeProvider.xai ? 'xAI Grok' : 'OpenAI';

  /// Who answers the realtime conversation starting now.
  RealtimeProvider _activeProvider = RealtimeProvider.openai;

  /// Starts what answers [slot]'s wake word. One conversation at a time:
  /// a wake word during either kind is ignored, except over an
  /// announcement, which the Assist turn takes over as it always has.
  void _wakeSlot(int slot, String phrase) {
    if (_realtime.busy) return;
    final provider = _slotProvider(slot);
    if (provider != null) {
      if (_session.busy) return;
      _activeProvider = provider;
      unawaited(_realtime.wake(phrase));
      return;
    }
    unawaited(_session.wake(phrase));
  }

  RealtimeOptions _realtimeOptions() => RealtimeOptions(
    wakeSound: _settings.get(defs.voiceWakeSound),
    seamless: _settings.get(defs.voiceSeamlessWake),
    idleSeconds: _settings.get(defs.voiceRealtimeIdleSeconds).toInt(),
    talkOver: _settings.get(defs.voiceRealtimeTalkOver),
    language: _settings.get(defs.uiLanguage),
  );

  /// A provider's settings as the backend takes them.
  RealtimeConfig realtimeConfig(
    RealtimeProvider provider, {
    String? endpoint,
    String? apiKey,
    String? model,
    String? voice,
  }) {
    final d = _realtimeDefs(provider);
    return RealtimeConfig(
      provider: provider,
      endpoint: endpoint ?? _settings.get(d.endpoint),
      apiKey: apiKey ?? _settings.get(d.apiKey),
      model: model ?? _settings.get(d.model),
      voice: voice ?? _settings.get(d.voice),
      instructions: _settings.get(defs.voiceRealtimeInstructions),
    );
  }

  /// Home Assistant answered 404 on /api/mcp. Translated where it shows.
  static const mcpMissing =
      'Add the MCP Server integration in Home Assistant to control your home.';

  /// The tools a realtime conversation gets: Home Assistant's MCP server
  /// (or the one set instead) and the app's own.
  RealtimeToolbox realtimeToolbox() {
    final boxes = <RealtimeToolbox>[];
    switch (_settings.get(defs.voiceRealtimeTools)) {
      case 'home_assistant':
        final base = _settings
            .get(defs.haUrl)
            .trim()
            .replaceFirst(RegExp(r'/+$'), '');
        final token = _settings.get(defs.haToken);
        if (base.isNotEmpty && token.isNotEmpty) {
          boxes.add(
            McpToolbox(
              McpClient(url: Uri.parse('$base/api/mcp'), token: token),
              notFound: mcpMissing,
            ),
          );
        }
      case 'custom':
        final url = _settings.get(defs.voiceRealtimeMcpUrl).trim();
        final parsed = Uri.tryParse(url);
        if (url.isNotEmpty && parsed != null && parsed.hasScheme) {
          boxes.add(
            McpToolbox(
              McpClient(
                url: parsed,
                token: _settings.get(defs.voiceRealtimeMcpToken).trim(),
              ),
            ),
          );
        }
    }
    boxes.add(const LocalToolbox());
    return CombinedToolbox(boxes);
  }

  /// Save & Validate: connects once with [apiKey], [endpoint], [model]
  /// and [voice] before anything is stored, and reads the tools. Only a
  /// connection the provider takes stores them and marks the provider
  /// validated, which makes it a choice for the wake words. A refused one
  /// stores nothing. A null [apiKey] keeps the saved one (the remote admin
  /// never sees it).
  Future<Map<String, Object?>> realtimeSave(
    RealtimeProvider provider, {
    String? apiKey,
    required String endpoint,
    required String model,
    required String voice,
  }) async {
    final d = _realtimeDefs(provider);
    final String saved = _settings.get(d.apiKey);
    final key = (apiKey ?? saved).trim();
    endpoint = endpoint.trim();
    final toolbox = realtimeToolbox();
    var tools = 0;
    var toolsError = '';
    final listing = () async {
      try {
        final list = await toolbox.list();
        tools = list
            .where((t) => t.name != LocalToolbox.endConversation)
            .length;
        if (toolbox case final CombinedToolbox box
            when box.problems.isNotEmpty) {
          toolsError = box.problems.first;
        }
      } catch (e) {
        toolsError = '$e';
      } finally {
        toolbox.close();
      }
    }();
    final backend = OpenAiRealtimeBackend(
      config: realtimeConfig(
        provider,
        endpoint: endpoint,
        apiKey: key,
        model: model,
        voice: voice,
      ),
      toolbox: const LocalToolbox(),
      log: (line) => log.info(name, 'realtime test: $line'),
    );
    final done = Completer<String?>();
    final sub = backend.events.listen((e) {
      if (done.isCompleted) return;
      if (e is RealtimeReady) done.complete(null);
      if (e is RealtimeClosed) done.complete(e.error ?? 'closed');
    });
    unawaited(backend.start(const RealtimeStart()));
    final error = await done.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => 'no answer from the provider',
    );
    await sub.cancel();
    await backend.close();
    await listing;
    if (error != null) return {'connected': false, 'error': error};
    await _settings.set(d.apiKey, key, source: 'voice');
    await _settings.set(d.endpoint, endpoint, source: 'voice');
    await _settings.set(d.model, model, source: 'voice');
    await _settings.set(d.voice, voice, source: 'voice');
    await _settings.set(
      d.validated,
      _signature(provider, endpoint: endpoint, apiKey: key),
      source: 'voice',
    );
    _realtimeProblem(
      provider,
      toolsError.isEmpty ? null : toolsError,
      tools: true,
    );
    realtimeStatusRevision.value++;
    unawaited(refreshRealtimeCatalog(provider));
    return {
      'connected': true,
      'tools': tools,
      if (toolsError.isNotEmpty) 'toolsError': toolsError,
    };
  }

  // What each provider offers when it cannot be asked: xAI documents these
  // voices by name, and OpenAI lists no voices over its API at all.
  static const _openAiModels = ['gpt-realtime', 'gpt-realtime-mini'];
  static const _openAiVoices = [
    'alloy',
    'ash',
    'ballad',
    'cedar',
    'coral',
    'echo',
    'marin',
    'sage',
    'shimmer',
    'verse',
  ];
  static const _xaiModels = ['grok-voice-latest', 'grok-voice-think-fast-2.0'];
  static const _xaiVoices = ['ara', 'eve', 'rex'];

  final _catalogTimers = <RealtimeProvider, Timer>{};

  /// A provider's Model and Voice choices: its own lists when the kiosk
  /// talks to it directly with a key (OpenAI's realtime models, xAI's
  /// voices), the ones above otherwise. A relay has no such lists to ask.
  Future<void> refreshRealtimeCatalog(RealtimeProvider provider) async {
    final d = _realtimeDefs(provider);
    final xai = provider == RealtimeProvider.xai;
    var models = xai ? _xaiModels : _openAiModels;
    var voices = xai ? _xaiVoices : _openAiVoices;
    final key = _settings.get(d.apiKey).trim();
    if (_settings.get(d.endpoint).trim().isEmpty && key.isNotEmpty) {
      final headers = {'Authorization': 'Bearer $key'};
      try {
        if (xai) {
          final response = await http
              .get(
                Uri.parse('https://api.x.ai/v1/tts/voices'),
                headers: headers,
              )
              .timeout(const Duration(seconds: 10));
          final list = (jsonDecode(response.body) as Map)['voices'];
          final ids = [
            for (final v in (list as List? ?? const []))
              if (v is Map && '${v['voice_id'] ?? ''}'.isNotEmpty)
                '${v['voice_id']}'.toLowerCase(),
          ]..sort();
          if (ids.isNotEmpty) voices = ids;
        } else {
          final response = await http
              .get(
                Uri.parse('https://api.openai.com/v1/models'),
                headers: headers,
              )
              .timeout(const Duration(seconds: 10));
          final list = (jsonDecode(response.body) as Map)['data'];
          final ids = [
            for (final m in (list as List? ?? const []))
              // Conversation models only: not transcription, translation
              // or speech recognition.
              if (m is Map &&
                  '${m['id']}'.contains('realtime') &&
                  !RegExp('transcri|translat|whisper').hasMatch('${m['id']}'))
                '${m['id']}',
          ]..sort();
          if (ids.isNotEmpty) models = ids;
        }
      } catch (e) {
        log.info(name, 'realtime catalog: using the built-in lists ($e)');
      }
    }
    _settings.updateRealtimeCatalog(
      provider.id,
      models: models,
      voices: voices,
    );
  }

  RealtimeBackend _realtimeBackend() => OpenAiRealtimeBackend(
    config: realtimeConfig(_activeProvider),
    toolbox: realtimeToolbox(),
    log: (line) => log.info(name, 'realtime: $line'),
  );

  /// The phrase of the wake word in [slot], what pipeline 1 or 2 is
  /// picked by.
  String _phraseForSlot(int slot) {
    final config = _wakeWord.config;
    final models = config?.models ?? const [];
    if (models.isEmpty) return '';
    final index = (slot - 1).clamp(0, models.length - 1);
    return models[index].wakeWord;
  }

  /// Brings the wake word engine in line with the settings: configured and
  /// listening while enabled and unmuted, released otherwise (only when this
  /// manager configured it: the dashboard runtime's page owns it there).
  Future<void> _sync() async {
    if (!enabled) {
      await _session.dispose();
      await _realtime.dispose();
      if (_ownsWakeWord) {
        _ownsWakeWord = false;
        await _wakeWord.release('native-off', source: 'native satellite');
      }
      return;
    }
    if (_settings.get(defs.voiceMute)) {
      if (_session.busy) await _session.cancel();
      if (_realtime.busy) await _realtime.cancel();
      _ownsWakeWord = true;
      await _wakeWord.release('muted', source: 'native satellite');
      return;
    }
    final config = buildWakeConfig(
      engine: _engine,
      activeIds: _activeIds(),
      sensitivity: _settings.get(defs.voiceWakeWordSensitivity),
      noiseGate: _settings.get(defs.voiceNoiseGate),
      stopWord: _settings.get(defs.voiceStopWord),
      external: _external,
      custom: _custom.models,
    );
    _ownsWakeWord = true;
    await _wakeWord.configure(config, source: 'native satellite');
  }

  void _resumeWake() {
    if (enabled && !_settings.get(defs.voiceMute)) _wakeWord.setActive(true);
  }

  void _onStopWord() {
    if (!enabled) return;
    if (_ringing.isNotEmpty) {
      _dismissAlert();
      return;
    }
    if (_realtime.busy) {
      // A conversation keeps going: the stop word stops the answer.
      unawaited(_realtime.stopAnswer());
      return;
    }
    if (_session.busy) {
      unawaited(_session.cancel());
    } else {
      _session.dismiss();
    }
  }

  // ── the overlay ────────────────────────────────────────────────────────

  void _onView(AssistView next) {
    // Docked or full screen, the Appearance page's pick, for Assist turns
    // and realtime conversations alike. A preview says for itself.
    var shown = next.visible && !_previewDocked
        ? next.copyWith(
            docked: _settings.get(defs.voiceOverlayMode) == 'docked',
          )
        : next;
    if (_settings.get(defs.voiceHideSentimentTags) && next.answer.isNotEmpty) {
      shown = shown.copyWith(answer: stripSentimentTags(next.answer));
    }
    // Visible either way: the screensaver holds its screen off timer
    // under both. Only full screen covers what is under it, which the
    // browser and the screensaver then pause. Docked, both stay live.
    final was = view.value;
    view.value = shown;
    if (!next.visible) level.value = 0;
    final wasCovering = was.visible && !was.docked;
    final covers = shown.visible && !shown.docked;
    if (was.visible != shown.visible || wasCovering != covers) {
      bus.publish(AssistOverlayVisibility(shown.visible, covers: covers));
    }
  }

  /// A result was opened on the overlay: keep it up until dismissed.
  void holdResults({bool silence = false}) =>
      _session.holdResults(silence: silence);

  /// Double tap on the overlay, or the voiceCancel command: a ringing timer
  /// first, then the turn or the lingering answer.
  void dismiss() {
    if (_ringing.isNotEmpty) {
      _dismissAlert();
      return;
    }
    if (_realtime.busy) {
      unawaited(_realtime.cancel());
      return;
    }
    _session.dismiss();
  }

  void _onBusy(bool busy, String reason) {
    // The remote admin's status rows say Busy for the whole turn: the wake
    // word's microphone stays open through it, so nothing else moves them.
    _announceStatus();
    if (busy) {
      _previewDocked = false;
      if (_busyReasons.add(reason)) {
        bus.publish(
          VoiceInteractionChanged(
            active: true,
            reason: reason,
            source: InteractionSource.native,
          ),
        );
      }
      if (reason == 'announcement') {
        unawaited(commands.execute('screenOn', const {}));
        unawaited(
          commands.execute('bringToFront', const {'voiceInteraction': true}),
        );
      }
      return;
    }
    for (final held in _busyReasons.toList()) {
      bus.publish(
        VoiceInteractionChanged(
          active: false,
          reason: held,
          source: InteractionSource.native,
        ),
      );
    }
    _busyReasons.clear();
  }

  Future<void> _readChatLog(String conversationId) async {
    if (!_settings.get(defs.voiceShowTools) &&
        !_settings.get(defs.voiceShowAnswer)) {
      return;
    }
    try {
      final initial = Completer<Map<String, Object?>>();
      final unsubscribe = await _ha.subscribe(
        {
          'type': 'conversation/chat_log/subscribe',
          'conversation_id': conversationId,
        },
        (event) {
          if (event['event_type'] == 'initial_state' && !initial.isCompleted) {
            final data = event['data'];
            if (data is Map) initial.complete(data.cast<String, Object?>());
          }
        },
      );
      final chat = await initial.future.timeout(const Duration(seconds: 5));
      await unsubscribe();
      final content = chat['content'];
      if (content is! List) return;
      final digest = digestLatestTurn(content);
      _session.showResults(
        tools: _settings.get(defs.voiceShowTools) ? digest.tools : const [],
        results: digest.results,
      );
    } catch (e) {
      // A regular user token cannot read the chat log: the overlay keeps
      // the command and the answer, which is all the ESPHome events carry.
      log.debug(name, 'chat log not read: $e');
    }
  }

  // ── Home Assistant over ESPHome ────────────────────────────────────────

  void _onVoice(String kind, Map<String, Object?> fields) {
    switch (kind) {
      case 'subscribed':
        final on = fields['subscribed'] == true;
        if (on) {
          clearedNotices
            ..add('connection')
            ..add('not-connected');
        } else {
          unawaited(_session.connectionLost());
        }
        homeAssistant.value = VoiceHaState(
          subscribed: on,
          satelliteEntity: homeAssistant.value.satelliteEntity,
          entities: homeAssistant.value.entities,
          selectsMissing: homeAssistant.value.selectsMissing,
        );
        log.info(
          name,
          on
              ? 'Home Assistant took the satellite'
              : 'Home Assistant dropped the satellite',
        );
        if (on) unawaited(refreshHomeAssistant());
        if (!on && _session.busy) unawaited(_session.cancel());
      case 'response':
        _note('response port=${fields['port']} error=${fields['error']}');
        unawaited(_session.onResponse(error: fields['error'] == true));
      case 'event':
        final data = <String, String>{};
        final raw = fields['data'];
        if (raw is Map) {
          raw.forEach((k, v) => data['$k'] = '$v');
        }
        final type = (fields['type'] as num?)?.toInt() ?? -1;
        _note('event $type $data');
        log.debug(name, 'pipeline event $type $data');
        unawaited(_session.onEvent(type, data));
      case 'timer':
        _onTimerEvent(fields);
      case 'announce':
        if (!enabled) return;
        unawaited(
          _announceOverConversation().then(
            (_) => _session.announce(
              VoiceAnnouncement(
                mediaId: '${fields['mediaId'] ?? ''}',
                text: '${fields['text'] ?? ''}',
                preannounceMediaId: '${fields['preannounceMediaId'] ?? ''}',
                startConversation: fields['startConversation'] == true,
              ),
            ),
          ),
        );
      case 'setConfiguration':
        final active = [
          for (final id in (fields['active'] as List?) ?? const []) '$id',
        ];
        log.info(name, 'Home Assistant set the wake words: $active');
        unawaited(
          _settings.set(
            defs.voiceWakeWords,
            jsonEncode(active),
            source: 'esphome',
          ),
        );
    }
  }

  /// An announcement ends a realtime conversation first: the two would
  /// share the speaker and the microphone.
  Future<void> _announceOverConversation() async {
    if (_realtime.busy) await _realtime.cancel();
  }

  /// The wake words Home Assistant's selects offer: the engine's bundled
  /// models and the custom microWakeWord ones Home Assistant has.
  Future<Map<String, Object?>> _configuration(
    List<Map<Object?, Object?>> external,
  ) async {
    _external = [for (final raw in external) ?ExternalWakeWord.fromMap(raw)];
    final offered = offeredWakeWords(
      _engine,
      external: _external,
      custom: _custom.models,
    );
    _offeredSent = _offeredSignature();
    final listened = listenedWakeWords(_activeIds(), offered);
    final active = [for (final w in listened) w.id];
    _reportFallback(offered, listened);
    // Custom wake words may have arrived with this request.
    unawaited(_sync());
    return {
      'available': [
        for (final w in offered) {'id': w.id, 'wakeWord': w.phrase},
      ],
      'active': active,
      'maxActive': 2,
    };
  }

  /// Finds the kiosk's satellite and Home Assistant's selects on its device.
  Future<void> refreshHomeAssistant() async {
    final mac = (await _esphome.identityMac()).toLowerCase();
    if (mac.isEmpty) return;
    try {
      final list = await _ha.request({'type': 'config/entity_registry/list'});
      if (list is! List) return;
      var satellite = '';
      final entities = <String, String>{};
      for (final raw in list) {
        if (raw is! Map || raw['platform'] != 'esphome') continue;
        final unique = '${raw['unique_id'] ?? ''}'.toLowerCase();
        if (!unique.startsWith('$mac-')) continue;
        final key = unique.substring(mac.length + 1);
        final entityId = '${raw['entity_id']}';
        if (entityId.startsWith('assist_satellite.')) satellite = entityId;
        if (const {
          'pipeline',
          'pipeline_2',
          'vad_sensitivity',
          'wake_word',
          'wake_word_2',
        }.contains(key)) {
          entities[key] = entityId;
        }
      }
      // Home Assistant adds its Assistant and Wake word selects when the
      // ESPHome entry sets up. A kiosk that turned voice on after that has
      // the satellite but not the selects until the entry reloads. They are
      // missing from the registry, or kept there from an earlier setup but
      // not loaded (restored). Reload the entry once, as the user would
      // have to by hand. Reloading takes an administrator's token.
      var missing = false;
      if (satellite.isNotEmpty) {
        final pipeline = entities['pipeline'];
        final state = pipeline == null
            ? null
            : await _migration.stateOf(pipeline);
        final attributes = state?['attributes'];
        missing =
            pipeline == null ||
            (attributes is Map && attributes['restored'] == true);
      }
      if (missing && !_reloadedEntry) {
        _reloadedEntry = true;
        if (await _reloadEsphomeEntry(satellite)) missing = false;
      }
      homeAssistant.value = VoiceHaState(
        subscribed: homeAssistant.value.subscribed,
        satelliteEntity: satellite,
        entities: entities,
        selectsMissing: missing,
      );
    } catch (e) {
      log.debug(name, 'satellite lookup failed: $e');
    }
  }

  bool _reloadedEntry = false;

  Future<bool> _reloadEsphomeEntry(String satellite) async {
    try {
      final entry = await _ha.request({
        'type': 'config/entity_registry/get',
        'entity_id': satellite,
      });
      final id = entry is Map ? entry['config_entry_id'] : null;
      if (id is! String) return false;
      log.info(name, 'reloading the ESPHome entry for the assistant selects');
      await _ha.request({
        'type': 'call_service',
        'domain': 'homeassistant',
        'service': 'reload_config_entry',
        'service_data': {'entry_id': id},
      }, timeout: const Duration(seconds: 30));
      return true;
    } catch (e) {
      log.warn(name, 'ESPHome entry not reloaded: $e');
      return false;
    }
  }

  /// Runs a Home Assistant intent on this kiosk's device (the timers).
  /// Null on success, else why not.
  Future<String?> _intent(String intent, Map<String, Object?> slots) async {
    final base = _settings
        .get(defs.haUrl)
        .trim()
        .replaceFirst(RegExp(r'/+$'), '');
    final token = _settings.get(defs.haToken);
    if (base.isEmpty || token.isEmpty) return 'Home Assistant not configured';
    final device = await _deviceId();
    try {
      final response = await http
          .post(
            Uri.parse('$base/api/intent/handle'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': intent,
              'data': slots,
              'device_id': ?device,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return 'HTTP ${response.statusCode}';
      final body = jsonDecode(response.body);
      if (body is Map && body['response_type'] == 'error') {
        final speech = body['speech'];
        return speech is Map
            ? '${speech['plain']?['speech'] ?? 'failed'}'
            : 'failed';
      }
      return null;
    } catch (e) {
      return '$e';
    }
  }

  String? _deviceIdCache;

  Future<String?> _deviceId() async {
    if (_deviceIdCache case final cached?) return cached;
    final satellite = homeAssistant.value.satelliteEntity;
    if (satellite.isEmpty) await refreshHomeAssistant();
    final entity = homeAssistant.value.satelliteEntity;
    if (entity.isEmpty) return null;
    try {
      final entry = await _ha.request({
        'type': 'config/entity_registry/get',
        'entity_id': entity,
      });
      if (entry is Map && entry['device_id'] is String) {
        return _deviceIdCache = entry['device_id'] as String;
      }
    } catch (_) {}
    return null;
  }

  // ── timers ─────────────────────────────────────────────────────────────

  void _onTimerEvent(Map<String, Object?> fields) {
    final id = '${fields['id'] ?? ''}';
    if (id.isEmpty) return;
    final type = (fields['type'] as num?)?.toInt() ?? -1;
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (type) {
      case 0: // started
      case 1: // updated
        final previous = _timers[id];
        _timers[id] = _HaTimer(
          id: id,
          name: '${fields['name'] ?? ''}',
          createdSeconds:
              previous?.createdSeconds ??
              (fields['totalSeconds'] as num?)?.toInt() ??
              0,
          secondsLeft: (fields['secondsLeft'] as num?)?.toInt() ?? 0,
          active: fields['isActive'] == true,
          at: now,
        );
      case 2: // cancelled
        _timers.remove(id);
        if (_ringing.remove(id)) _pushAlert();
      case 3: // finished
        final timer = _timers.remove(id);
        _ringing.add(id);
        _ringingNames[id] = timer?.name ?? '${fields['name'] ?? ''}';
        _alertSpeech = null;
        _pushAlert();
        unawaited(_speakAlert());
    }
    _pushTimers();
  }

  final _ringingNames = <String, String>{};

  /// The spoken phrase of the ringing alert, once Home Assistant made it.
  String? _alertSpeech;
  String _alertSpeechText = '';
  int _speechGen = 0;

  /// The phrase for the ringing timers: the named one when any has a name.
  String timerPhrase(Iterable<String> names) {
    final named = [
      for (final n in names)
        if (n.trim().isNotEmpty) n.trim(),
    ];
    if (named.isEmpty) return _settings.get(defs.voiceTimerPhrase).trim();
    return _settings
        .get(defs.voiceTimerNamedPhrase)
        .replaceAll('{name}', named.join(', '))
        .trim();
  }

  /// Makes the alert's phrase with Home Assistant's text to speech, through
  /// the pipeline that answers wake word 1, and adds it to the ring.
  Future<void> _speakAlert() async {
    if (!_settings.get(defs.voiceTimerSpeak) ||
        _settings.get(defs.voiceMuteTimers) ||
        _ringing.isEmpty) {
      return;
    }
    final gen = ++_speechGen;
    final text = timerPhrase([
      for (final id in _ringing) _ringingNames[id] ?? '',
    ]);
    if (text.isEmpty) return;
    try {
      final done = Completer<String>();
      final unsubscribe = await _ha.subscribe(
        {
          'type': 'assist_pipeline/run',
          'start_stage': 'tts',
          'end_stage': 'tts',
          'input': {'text': text},
          if (await _pipelineId() case final String id) 'pipeline': id,
        },
        (event) {
          final data = event['data'];
          final fields = data is Map ? data : const {};
          switch (event['type']) {
            case 'tts-end':
              final output = fields['tts_output'];
              final url = output is Map ? '${output['url'] ?? ''}' : '';
              if (!done.isCompleted) done.complete(url);
            case 'error':
              if (!done.isCompleted) {
                done.completeError(
                  StateError('${fields['message'] ?? 'error'}'),
                );
              }
            case 'run-end':
              if (!done.isCompleted) done.complete('');
          }
        },
      );
      final url = await done.future
          .timeout(const Duration(seconds: 15))
          .whenComplete(unsubscribe);
      if (gen != _speechGen || _ringing.isEmpty || url.isEmpty) return;
      _alertSpeech = _absolute(url);
      _alertSpeechText = text;
      _pushAlert();
    } catch (e) {
      log.warn(name, 'timer phrase not made: $e');
    }
  }

  /// Runs a vs_show prompt through Home Assistant from the intent stage,
  /// on this kiosk's device so its tools know where they were asked.
  Future<void> _runShow(
    int gen,
    String prompt, {
    required bool speak,
    required int slot,
    required int seconds,
  }) async {
    var answer = '';
    var url = '';
    var conversationId = '';
    String? error;
    try {
      final device = await _deviceId();
      final pipeline = await _pipelineId(slot: slot);
      final done = Completer<void>();
      final unsubscribe = await _ha.subscribe(
        {
          'type': 'assist_pipeline/run',
          'start_stage': 'intent',
          'end_stage': speak ? 'tts' : 'intent',
          'input': {'text': prompt},
          'pipeline': ?pipeline,
          'device_id': ?device,
        },
        (event) {
          final raw = event['data'];
          final data = raw is Map ? raw : const {};
          switch (event['type']) {
            case 'intent-progress':
              final delta = data['chat_log_delta'];
              final content = delta is Map ? delta['content'] : null;
              if (content is String) {
                answer += content;
                _session.showAnswer(gen, answer);
              }
            case 'intent-end':
              final output = data['intent_output'];
              if (output is Map) {
                conversationId = '${output['conversation_id'] ?? ''}';
                final speech = _speechOf(output['response']);
                if (speech.isNotEmpty) answer = speech;
                _session.showAnswer(gen, answer, streaming: false);
              }
            case 'tts-end':
              final output = data['tts_output'];
              if (output is Map) url = '${output['url'] ?? ''}';
            case 'error':
              error = '${data['message'] ?? data['code'] ?? 'error'}';
              if (!done.isCompleted) done.complete();
            case 'run-end':
              if (!done.isCompleted) done.complete();
          }
        },
      );
      await done.future
          .timeout(const Duration(seconds: 90))
          .whenComplete(unsubscribe);
    } catch (e) {
      error ??= '$e';
    }
    if (conversationId.isNotEmpty) await _readChatLog(conversationId);
    if (error != null) {
      log.warn(name, 'vs_show failed: $error');
      if (answer.isEmpty) unawaited(_report('show', error!));
    }
    if (speak && url.isNotEmpty) await _session.showSpeak(gen, _absolute(url));
    await _session.endShow(
      gen,
      seconds: seconds,
      failed: error != null && answer.isEmpty,
    );
  }

  static String _speechOf(Object? response) {
    if (response is! Map) return '';
    final speech = response['speech'];
    if (speech is! Map) return '';
    final plain = speech['plain'];
    return plain is Map ? '${plain['speech'] ?? ''}' : '';
  }

  /// The id of the pipeline Home Assistant's Assistant 1 (or 2) select
  /// names, or null for the preferred one.
  Future<String?> _pipelineId({int slot = 1}) async {
    final entity =
        homeAssistant.value.entities[slot == 2 ? 'pipeline_2' : 'pipeline'];
    if (entity == null) return null;
    final state = await _migration.stateOf(entity);
    final chosen = '${state?['state'] ?? ''}';
    if (chosen.isEmpty || chosen == 'preferred') return null;
    try {
      final list = await _ha.request({'type': 'assist_pipeline/pipeline/list'});
      final pipelines = list is Map ? list['pipelines'] : null;
      for (final p in (pipelines as List? ?? const [])) {
        if (p is Map && p['name'] == chosen) return '${p['id']}';
      }
    } catch (_) {}
    return null;
  }

  /// Home Assistant's media paths are relative to its base URL.
  String _absolute(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = _settings
        .get(defs.haUrl)
        .trim()
        .replaceFirst(RegExp(r'/+$'), '');
    return '$base${url.startsWith('/') ? '' : '/'}$url';
  }

  void _pushTimers() {
    if (!_settings.get(defs.voiceTimerPills)) {
      unawaited(
        commands.execute('setVoiceTimers', {
          'entityId': timerEntity,
          'timers': const <Object>[],
        }),
      );
      return;
    }
    final showNames = _settings.get(defs.voiceTimerNameInPill);
    unawaited(
      commands.execute('setVoiceTimers', {
        'entityId': timerEntity,
        'timers': [
          for (final t in _timers.values)
            {
              'id': t.id,
              'name': showNames ? t.name : '',
              'totalSeconds': t.secondsLeft,
              'startedAt': t.at,
              'isActive': t.active,
            },
        ],
      }),
    );
  }

  void _pushAlert() {
    final showNames = _settings.get(defs.voiceTimerNameOnAlert);
    unawaited(
      commands.execute('setVoiceTimerAlert', {
        'entityId': timerEntity,
        'muted': _settings.get(defs.voiceMuteTimers),
        'speech': ?(_ringing.isEmpty ? null : _alertSpeech),
        'speechText': _alertSpeechText,
        'timers': [
          for (final id in _ringing)
            {
              'id': id,
              'name': showNames ? (_ringingNames[id] ?? '') : '',
              'totalSeconds': 0,
              'startedAt': 0,
            },
        ],
      }),
    );
    if (_ringing.isNotEmpty) {
      _onBusy(true, 'timer');
      unawaited(_wakeWord.setStopWordArmed(true));
    } else {
      unawaited(_wakeWord.setStopWordArmed(false));
      if (_busyReasons.remove('timer')) {
        bus.publish(
          const VoiceInteractionChanged(
            active: false,
            reason: 'timer',
            source: InteractionSource.native,
          ),
        );
      }
    }
  }

  void _dismissAlert() {
    _ringing.clear();
    _ringingNames.clear();
    _alertSpeech = null;
    _speechGen++;
    _pushAlert();
  }

  Future<void> _onTimerAction(VoiceTimerAction action) async {
    if (action.entityId != timerEntity) return;
    if (action.action == 'dismiss') {
      _dismissAlert();
      return;
    }
    final timer = _timers[action.id];
    if (timer == null) return;
    final intent = switch (action.action) {
      'pause' => 'HassPauseTimer',
      'resume' => 'HassUnpauseTimer',
      'cancel' => 'HassCancelTimer',
      _ => null,
    };
    if (intent == null) return;
    // The timer intents find a timer by its name, else by the duration it
    // was started with.
    final slots = <String, Object?>{};
    if (timer.name.isNotEmpty) {
      slots['name'] = timer.name;
    } else {
      final total = timer.createdSeconds;
      if (total ~/ 3600 > 0) slots['start_hours'] = total ~/ 3600;
      if (total % 3600 ~/ 60 > 0) slots['start_minutes'] = total % 3600 ~/ 60;
      if (total % 60 > 0) slots['start_seconds'] = total % 60;
    }
    final error = await _intent(intent, slots);
    if (error != null) {
      log.warn(name, 'timer ${action.action} failed: $error');
      await commands.execute('voiceTimerActionFailed', {
        'entityId': timerEntity,
      });
    }
  }

  /// A step of a turn in the App Logs, with what was said or answered.
  void _trace(String step, {String? text}) {
    final said = text != null && text.isNotEmpty;
    log.info(name, said ? '$step: "$text"' : step);
  }

  /// A problem from the session, logged and put on screen as Voice
  /// Satellite's toasts put the same ones.
  Future<void> _report(String code, String message) async {
    log.warn(name, 'voice error $code: $message');
    final notice = switch (code) {
      'microphone' => VoiceNotice(
        id: code,
        severity: VoiceSeverity.error,
        category: 'Microphone',
        message: message,
      ),
      'not-connected' => VoiceNotice(
        id: code,
        severity: VoiceSeverity.error,
        category: 'Connection',
        message: message,
      ),
      'connection-lost' => VoiceNotice(
        id: 'connection',
        severity: VoiceSeverity.error,
        category: 'Connection',
        message:
            'Lost connection to Home Assistant. Reconnecting automatically.',
      ),
      'realtime' => VoiceNotice(
        id: code,
        severity: VoiceSeverity.error,
        category: 'Realtime',
        message: message,
      ),
      'realtime-warning' => VoiceNotice(
        id: code,
        severity: VoiceSeverity.warning,
        category: 'Realtime',
        message: message,
      ),
      'playback' => VoiceNotice(
        id: code,
        severity: VoiceSeverity.warning,
        category: 'Text-to-speech',
        message: message,
      ),
      'watchdog' => VoiceNotice(
        id: code,
        severity: VoiceSeverity.warning,
        category: await _pipelineCategory(),
        message: message,
      ),
      'refused' => VoiceNotice(
        id: 'start',
        severity: VoiceSeverity.error,
        category: await _pipelineCategory(),
        message: message,
      ),
      _ => VoiceNotice(
        id: 'pipeline',
        severity: VoiceSeverity.error,
        category: await _pipelineCategory(),
        message: message.isNotEmpty
            ? message
            : 'An unexpected pipeline error occurred.',
      ),
    };
    notices.add(notice);
  }

  /// The pipeline of the last turn, as the notices name it: by its name,
  /// or plainly when it is the preferred one.
  Future<String> _pipelineCategory() async {
    final second = _phraseForSlot(2);
    final slot =
        _lastPhrase.isNotEmpty &&
            _lastPhrase == second &&
            second != _phraseForSlot(1)
        ? 2
        : 1;
    final entity =
        homeAssistant.value.entities[slot == 2 ? 'pipeline_2' : 'pipeline'];
    var chosen = '';
    if (entity != null) {
      try {
        final state = await _migration.stateOf(entity);
        chosen = '${state?['state'] ?? ''}';
      } catch (_) {}
    }
    if (chosen.isEmpty || chosen == 'preferred' || chosen == 'unavailable') {
      return 'Assist pipeline';
    }
    return 'Pipeline "$chosen"';
  }

  /// The wake word engine failing to start is shown once per failure, and
  /// taken down when it runs again.
  void _checkWakeFailure() {
    final failure = enabled && _ownsWakeWord ? _wakeWord.failure : null;
    if (failure == _wakeFailure) return;
    _wakeFailure = failure;
    if (failure == null) {
      clearedNotices.add('wake-word');
      return;
    }
    log.warn(name, 'wake word engine failed: ${failure.name}');
    notices.add(
      VoiceNotice(
        id: 'wake-word',
        severity: VoiceSeverity.error,
        category: 'Wake word',
        message: switch (failure) {
          EngineFailure.micBlocked =>
            'Microphone access is blocked. Allow it for Kiosk Satellite '
                'in the Android settings.',
          EngineFailure.micDeclined =>
            'Microphone access was declined, so the wake word cannot be '
                'heard.',
          EngineFailure.micLost => 'The microphone stopped working.',
          EngineFailure.modelsUnavailable =>
            'The wake word models could not be loaded.',
          EngineFailure.crashed =>
            'The wake word detector kept crashing on this device, so it '
                'was stopped.',
        },
      ),
    );
  }

  /// The VOICE_WAKE and VOICE_CANCEL broadcasts (VoiceIntentBridge.kt),
  /// sent by ADB, a remote's button mapper or an automation app.
  static const _intents = MethodChannel('kiosk_satellite/voice_intents');

  Future<void> _onIntent(MethodCall call) async {
    final (command, params) = switch (call.method) {
      'wake' => (
        'voiceWake',
        {'slot': ((call.arguments as Map?)?['slot'] as num?) ?? 1},
      ),
      'cancel' => ('voiceCancel', const <String, Object?>{}),
      _ => (null, const <String, Object?>{}),
    };
    if (command == null) return;
    log.info(name, '${call.method} broadcast');
    final result = await commands.execute(command, params);
    if (!result.ok) log.warn(name, '${call.method} broadcast: ${result.error}');
  }

  /// Tells the remote admin's status rows to read the status again.
  void _announceStatus() =>
      bus.publish(const RemoteStatusChanged('voice-status'));

  @override
  Future<void> dispose() async {
    _intents.setMethodCallHandler(null);
    homeAssistant.removeListener(_announceStatus);
    homeAssistant.removeListener(_watchSelects);
    _watchTimer?.cancel();
    for (final timer in _catalogTimers.values) {
      timer.cancel();
    }
    await _unwatchSelects?.call();
    _speaker.dispose();
    _custom.dispose();
    _selectsTimer?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _esphome.onVoice = null;
    _esphome.onVoiceConfiguration = null;
    await _session.dispose();
    await _realtime.dispose();
    await _ha.close();
    await notices.close();
    await clearedNotices.close();
  }
}

class _HaTimer {
  const _HaTimer({
    required this.id,
    required this.name,
    required this.createdSeconds,
    required this.secondsLeft,
    required this.active,
    required this.at,
  });

  final String id;
  final String name;

  /// The duration it was started with, what the intents name it by.
  final int createdSeconds;
  final int secondsLeft;
  final bool active;

  /// When [secondsLeft] was true, in epoch milliseconds.
  final int at;
}

class _EspLink implements VoiceLinkPort {
  _EspLink(this._esphome, {required this.onAudio, required this.onRequest});
  final BtProxyManager _esphome;
  final void Function(bool sent) onAudio;
  final void Function(bool start, String phrase, bool ok) onRequest;

  @override
  Future<bool> request({
    required bool start,
    String wakeWordPhrase = '',
  }) async {
    final ok = await _esphome.voiceRequest(
      start: start,
      wakeWordPhrase: wakeWordPhrase,
    );
    onRequest(start, wakeWordPhrase, ok);
    return ok;
  }

  @override
  Future<bool> audio(Uint8List pcm) async {
    final ok = await _esphome.voiceAudio(pcm);
    onAudio(ok);
    return ok;
  }

  @override
  Future<bool> finished() => _esphome.voiceAnnounceFinished();
}

class _WakeMic implements VoiceMicPort {
  _WakeMic(this._wakeWord);
  final WakeWordManager _wakeWord;

  @override
  Future<bool> open(void Function(Uint8List pcm, bool preRoll) onChunk) =>
      _wakeWord.openNativeAudioStream(onChunk);

  @override
  Future<void> close() => _wakeWord.closeNativeAudioStream();
}

class _Player implements VoicePlayerPort {
  _Player(this._commands);
  final CommandRegistry _commands;

  @override
  Future<String?> play(
    String url, {
    String text = '',
    bool announcement = false,
  }) async {
    final result = await _commands.execute('voiceSpeak', {
      'url': url,
      'text': text,
      if (announcement) 'kind': 'announcement',
    });
    final data = result.data;
    return result.ok && data is Map ? data['id'] as String? : null;
  }

  @override
  Future<(String, double)?> chime(String kind) async {
    final result = await _commands.execute('voiceChime', {'kind': kind});
    final data = result.data;
    if (!result.ok || data is! Map) return null;
    final id = data['id'];
    final duration = data['duration'];
    if (id is! String || duration is! num) return null;
    return (id, duration.toDouble());
  }

  @override
  Future<void> stop(String id) async {
    await _commands.execute('voiceStopSpeech', {'id': id});
  }

  @override
  Future<void> settle() async {
    await _commands.execute('voiceSpeakerDone', const {});
  }
}
