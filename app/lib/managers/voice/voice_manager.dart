import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
import 'ha_socket.dart';
import 'migration.dart';
import 'voice_session.dart';
import 'wake_catalog.dart';

/// Where Home Assistant stands with this kiosk's satellite.
class VoiceHaState {
  const VoiceHaState({
    this.subscribed = false,
    this.satelliteEntity = '',
    this.entities = const {},
  });

  /// A Home Assistant session holds the voice assistant subscription: the
  /// kiosk is added and its satellite is live.
  final bool subscribed;

  /// The kiosk's assist_satellite entity, once found in the registry.
  final String satelliteEntity;

  /// Home Assistant's own selects on the kiosk's device, by key: pipeline,
  /// pipeline_2, vad_sensitivity, wake_word, wake_word_2.
  final Map<String, String> entities;
}

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

  /// Errors to show as toasts: a code and the message.
  final errors = StreamController<(String, String)>.broadcast();

  late final VoiceSession _session;
  late final HaSocket _ha = HaSocket(
    baseUrl: () => _settings.get(defs.haUrl),
    token: () => _settings.get(defs.haToken),
  );

  final _subs = <StreamSubscription<Object?>>[];

  late final VoiceMigration _migration = VoiceMigration(_settings, _ha);

  /// The migration switch's steps while it runs: [{id, state}] with state
  /// todo, run, done or failed. Both wizards draw it.
  final migrationSteps = ValueNotifier<List<Map<String, String>>>(const []);
  bool _migrating = false;

  /// The custom wake words Home Assistant offered on its last request.
  List<ExternalWakeWord> _external = const [];

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

  /// A sample turn for Preview.
  static const _previewView = AssistView(
    phase: AssistPhase.speaking,
    command: 'What is the weather?',
    answer: 'Sunny and 72° right now, with a light breeze.',
  );

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
  );

  @override
  Future<void> init() async {
    _session = VoiceSession(
      link: _EspLink(
        _esphome,
        onAudio: (ok) => ok ? _audioSent++ : _audioRefused++,
        onRequest: (start, phrase, ok) =>
            _note('request start=$start phrase=$phrase -> $ok'),
      ),
      mic: _WakeMic(_wakeWord),
      player: _Player(commands),
      options: _options,
      onView: _onView,
      onLevel: (value) => level.value = value,
      onBusy: _onBusy,
      onStopArmed: (armed) => unawaited(_wakeWord.setStopWordArmed(armed)),
      onError: (code, message) {
        log.warn(name, 'voice error $code: $message');
        errors.add((code, message));
      },
      onIntentEnd: (conversation) => unawaited(_readChatLog(conversation)),
      onIdle: _resumeWake,
    );
    _esphome.onVoice = _onVoice;
    _esphome.onVoiceConfiguration = _configuration;

    _subs
      ..add(
        bus.on<WakeWordDetected>().listen((e) {
          if (!enabled || _settings.get(defs.voiceMute)) return;
          unawaited(_session.wake(e.phrase));
        }),
      )
      ..add(bus.on<StopWordDetected>().listen((_) => _onStopWord()))
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
            unawaited(_session.wake(_phraseForSlot(slot)));
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
          },
          handler: (p) async {
            if (_session.busy) {
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
            _onView(shown);
            level.value = 0.5;
            _previewTimer = Timer(Duration(seconds: seconds.clamp(1, 120)), () {
              if (view.value.answer == _previewView.answer) {
                _onView(AssistView.hidden);
              }
            });
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
          name: 'voiceSelectOption',
          description: "Set one of Home Assistant's selects on this kiosk",
          params: const {
            'key':
                'pipeline, pipeline_2, vad_sensitivity, wake_word, '
                'wake_word_2',
            'option': 'the option to set',
          },
          handler: (p) async {
            final ok = await selectOption(
              '${p['key'] ?? ''}',
              '${p['option'] ?? ''}',
            );
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
    await _sync();
  }

  // ── migration ──────────────────────────────────────────────────────────

  void _registerMigrationCommands() {
    commands
      ..register(
        Command(
          name: 'voiceMigrationCheck',
          description:
              'Before migrating from the Voice Satellite integration: Home '
              'Assistant connected, this kiosk added through ESPHome, an '
              'administrator token, the microphone allowed',
          quiet: true,
          handler: (_) async => CommandResult.ok(await migrationCheck()),
        ),
      )
      ..register(
        Command(
          name: 'voiceMigrationPlan',
          description:
              'What the migration carries over from the old satellite, group '
              'by group, and the values in each',
          quiet: true,
          handler: (_) async {
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
          quiet: true,
          handler: (_) async {
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
          },
          handler: (p) async {
            final raw = p['groups'];
            final groups = raw is List
                ? [for (final g in raw) '$g']
                : VoiceMigration.groups;
            final result = await migrate(groups);
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

  Future<Map<String, Object?>> migrationCheck() async {
    final checks = <Map<String, Object?>>[];
    final ha = await commands.execute('haStatus', const {});
    final connected =
        ha.ok && ha.data is Map && (ha.data as Map)['connected'] == true;
    checks.add({'id': 'homeAssistant', 'ok': connected});
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
    var admin = false;
    if (connected) {
      try {
        final user = await _ha.request({'type': 'auth/current_user'});
        admin = user is Map && user['is_admin'] == true;
      } catch (_) {}
    }
    checks.add({'id': 'admin', 'ok': admin, 'warnOnly': true});
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
  Future<Map<String, Object?>> migrate(List<String> groups) async {
    if (_migrating) return {'ok': false, 'error': 'already migrating'};
    _migrating = true;
    migrationSteps.value = [
      for (final id in const ['save', 'stop', 'start', 'entities', 'check'])
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

      _step('stop', 'run');
      await commands.execute('vsEngine', const {'action': 'stop'});
      _step('stop', 'done');

      _step('start', 'run');
      await _settings.set(defs.voiceEnabled, true, source: 'migration');
      await _settings.set(defs.voiceRuntime, 'native', source: 'migration');
      final up = await _waitFor(
        () => homeAssistant.value.subscribed && _wakeWord.listening,
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
      await rollback();
      return {'ok': false, 'error': '$e'};
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
  /// {key: {entity_id, state, options, available}}.
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

  Map<String, Object?> describe() => {
    'runtime': _settings.get(defs.voiceRuntime),
    'enabled': enabled,
    'serving': _esphome.voiceServing,
    'subscribed': homeAssistant.value.subscribed,
    'satelliteEntity': homeAssistant.value.satelliteEntity,
    'entities': homeAssistant.value.entities,
    'busy': _session.busy,
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
      if (_ownsWakeWord) {
        _ownsWakeWord = false;
        await _wakeWord.release('native-off', source: 'native satellite');
      }
      return;
    }
    if (_settings.get(defs.voiceMute)) {
      if (_session.busy) await _session.cancel();
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
    if (_session.busy) {
      unawaited(_session.cancel());
    } else {
      _session.dismiss();
    }
  }

  // ── the overlay ────────────────────────────────────────────────────────

  void _onView(AssistView next) {
    var shown = next;
    if (_settings.get(defs.voiceHideSentimentTags) && next.answer.isNotEmpty) {
      shown = next.copyWith(answer: stripSentimentTags(next.answer));
    }
    final was = view.value.visible;
    view.value = shown;
    if (!next.visible) level.value = 0;
    if (was != next.visible) bus.publish(AssistOverlayVisibility(next.visible));
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
    _session.dismiss();
  }

  void _onBusy(bool busy, String reason) {
    if (busy) {
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
        homeAssistant.value = VoiceHaState(
          subscribed: on,
          satelliteEntity: homeAssistant.value.satelliteEntity,
          entities: homeAssistant.value.entities,
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
          _session.announce(
            VoiceAnnouncement(
              mediaId: '${fields['mediaId'] ?? ''}',
              text: '${fields['text'] ?? ''}',
              preannounceMediaId: '${fields['preannounceMediaId'] ?? ''}',
              startConversation: fields['startConversation'] == true,
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

  /// The wake words Home Assistant's selects offer: the engine's bundled
  /// models and the custom microWakeWord ones Home Assistant has.
  Future<Map<String, Object?>> _configuration(
    List<Map<Object?, Object?>> external,
  ) async {
    _external = [for (final raw in external) ?ExternalWakeWord.fromMap(raw)];
    final offered = offeredWakeWords(_engine, external: _external);
    final ids = {for (final w in offered) w.id};
    final active = [
      for (final id in _activeIds())
        if (ids.contains(id)) id,
    ];
    if (active.isEmpty && offered.isNotEmpty) active.add(offered.first.id);
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
      homeAssistant.value = VoiceHaState(
        subscribed: homeAssistant.value.subscribed,
        satelliteEntity: satellite,
        entities: entities,
      );
      // Home Assistant adds its Assistant and Wake word selects when the
      // ESPHome entry sets up. A kiosk that turned voice on after that has
      // the satellite but not the selects until the entry reloads: reload
      // it once, as the user would have to by hand.
      if (satellite.isNotEmpty &&
          !entities.containsKey('pipeline') &&
          !_reloadedEntry) {
        _reloadedEntry = true;
        await _reloadEsphomeEntry(satellite);
      }
    } catch (e) {
      log.debug(name, 'satellite lookup failed: $e');
    }
  }

  bool _reloadedEntry = false;

  Future<void> _reloadEsphomeEntry(String satellite) async {
    try {
      final entry = await _ha.request({
        'type': 'config/entity_registry/get',
        'entity_id': satellite,
      });
      final id = entry is Map ? entry['config_entry_id'] : null;
      if (id is! String) return;
      log.info(name, 'reloading the ESPHome entry for the assistant selects');
      await _ha.request({
        'type': 'call_service',
        'domain': 'homeassistant',
        'service': 'reload_config_entry',
        'service_data': {'entry_id': id},
      }, timeout: const Duration(seconds: 30));
    } catch (e) {
      log.warn(name, 'ESPHome entry not reloaded: $e');
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
      if (answer.isEmpty) errors.add(('show', error!));
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

  @override
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _esphome.onVoice = null;
    _esphome.onVoiceConfiguration = null;
    await _session.dispose();
    await _ha.close();
    await errors.close();
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
  Future<String?> play(String url) async {
    final result = await _commands.execute('playSound', {
      'url': url,
      'stream': true,
    });
    final data = result.data;
    return result.ok && data is Map ? data['id'] as String? : null;
  }

  @override
  Future<(String, double)?> chime(String kind) async {
    final result = await _commands.execute('playVoiceChime', {'kind': kind});
    final data = result.data;
    if (!result.ok || data is! Map) return null;
    final id = data['id'];
    final duration = data['duration'];
    if (id is! String || duration is! num) return null;
    return (id, duration.toDouble());
  }

  @override
  Future<void> stop(String id) async {
    await _commands.execute('stopSound', {'id': id});
  }
}
