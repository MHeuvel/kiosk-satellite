import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random, sqrt;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/command_registry.dart';
import '../../core/events.dart';
import '../../core/manager.dart';
import '../audio/mic_hub.dart';
import '../notifications/notification_sounds.dart';
import '../remote/auth.dart';
import '../settings/definitions.dart' as defs;
import '../settings/settings_manager.dart';
import 'intercom_audio.dart';

/// One kiosk on the roster, with what its identity probe said.
class IntercomKiosk {
  IntercomKiosk({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.version,
  });

  final String id;
  String name;
  String address;
  int port;
  String version;

  /// Whether the kiosk was in the last mDNS snapshot.
  bool heard = true;

  /// What `GET /api/intercom/identity` answered, or null before a probe.
  bool? enabled;
  String? keyFingerprint;
  bool dnd = false;
  DateTime? probedAt;
  bool probeFailed = false;

  String get url => 'http://$address:$port';

  /// ready, off, key, dnd, offline, unknown.
  String status(String ourFingerprint) {
    if (!heard) return 'offline';
    if (enabled == null) return probeFailed ? 'offline' : 'unknown';
    if (enabled == false) return 'off';
    if (keyFingerprint != ourFingerprint) return 'key';
    if (dnd) return 'dnd';
    return 'ready';
  }

  Map<String, Object?> toJson(String ourFingerprint) {
    final s = status(ourFingerprint);
    return {
      'id': id,
      'name': name,
      'address': address,
      'port': port,
      'version': version,
      'status': s,
      'statusText': switch (s) {
        'ready' => 'Ready',
        'off' => 'Intercom off',
        'key' => 'Different key',
        'dnd' => 'Do not disturb',
        'offline' => 'Offline',
        _ => 'Checking…',
      },
    };
  }
}

/// The call this kiosk is on, or was on until the card closes.
class IntercomCall {
  IntercomCall({
    required this.id,
    required this.kind,
    required this.outgoing,
    required this.peer,
  });

  final String id;

  /// `call` or `broadcast`.
  final String kind;
  final bool outgoing;

  /// The other kiosk: the callee, the caller, or the broadcast's sender.
  /// For a broadcast this kiosk sends, the first target (the card names
  /// them all through [targets]).
  Map<String, Object?> peer;

  /// When the voice started flowing, null while still connecting.
  DateTime? since;
  DateTime? endedAt;
  String reason = '';

  /// An announcement's spoken text, for its card. Empty for a clip.
  String message = '';
  bool farTalking = false;
  bool localTalking = false;
  bool muted = false;

  /// When Answer automatically opens the call, for the countdown.
  DateTime? autoAnswerAt;

  /// Frames sent and received, for the status and a silent link.
  int sent = 0;
  int received = 0;

  /// An announcement Home Assistant asked for: the audio is a decoded
  /// clip, not the microphone, and the card offers Stop alone.
  bool automated = false;

  /// The broadcast's recipients, by kiosk id: `listening`, `busy`, `dnd`,
  /// `off`, `unreachable`, `key`.
  final targets = <String, Map<String, Object?>>{};

  int get durationSeconds {
    final s = since;
    if (s == null) return 0;
    return (endedAt ?? DateTime.now()).difference(s).inSeconds;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'outgoing': outgoing,
    'peer': peer,
    'since': since?.millisecondsSinceEpoch,
    'talking': farTalking,
    'localTalking': localTalking,
    'muted': muted,
    'reason': reason,
    'duration': durationSeconds,
    'autoAnswerAt': autoAnswerAt?.millisecondsSinceEpoch,
    'sent': sent,
    'received': received,
    'automated': automated,
    'message': message,
    if (kind == 'broadcast') 'targets': targets.values.toList(),
  };
}

/// One audio socket: to the kiosk called, or from the kiosk calling.
class _Link {
  _Link(this.peerId, this.channel);
  final String peerId;
  final WebSocketChannel channel;
  StreamSubscription<Object?>? sub;

  void sendText(Map<String, Object?> msg) {
    try {
      channel.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  void sendBytes(Uint8List bytes) {
    try {
      channel.sink.add(bytes);
    } catch (_) {}
  }

  Future<void> close() async {
    await sub?.cancel();
    sub = null;
    try {
      await channel.sink.close();
    } catch (_) {}
  }
}

/// Kiosks on the same network talk to each other.
///
/// A call is placed from the kiosk menu's sheet (or a gesture) and rings
/// on the kiosk picked; Announce to all talks to every ready kiosk at once,
/// one way, and Home Assistant's announce action does the same with a
/// spoken message. Both
/// signaling and voice ride the other kiosk's remote admin port: three
/// REST routes before the bearer gate, verified with a token signed by the
/// shared intercom key, and one WebSocket per call carrying raw 16 kHz
/// PCM16 chunks both ways, straight from the microphone hub. Playback
/// goes through a communication-route AudioTrack so the platform echo
/// canceller keeps the far voice out of the near microphone.
///
/// The roster is the kiosk switcher's list (the `fleet` command), each
/// entry probed with `GET /api/intercom/identity` for whether its intercom
/// is on, which key it holds and whether it is on Do not disturb.
///
/// Both UIs draw the `intercomStatus` command and hear
/// [IntercomStateChanged] when to redraw. The call itself holds the
/// screensaver, the rotation and the home timer the way a voice turn does
/// ([VoiceInteractionChanged] with reason `intercom`), ducks the music
/// through the same event and pauses wake word detection.
///
/// States: idle, calling (waiting for the other kiosk to pick up), ringing
/// (a call coming in), in_call, broadcasting (this kiosk talks to
/// everyone), listening (a broadcast coming in), ended (the card's last
/// words, ten seconds) and missed (a minute for Home Assistant).
class IntercomManager extends Manager {
  IntercomManager(super.bus, super.commands, super.log, this._settings);

  final SettingsManager _settings;

  @override
  String get name => 'intercom';

  /// Swapped for fakes in tests.
  http.Client Function() clientFactory = http.Client.new;
  WebSocketChannel Function(Uri uri) socketFactory = (uri) =>
      WebSocketChannel.connect(uri);
  IntercomAudio audio = IntercomAudio();
  MicHub micHub = MicHub.instance;
  Future<bool> Function() micPermission = () async =>
      await Permission.microphone.request().isGranted;
  Random random = Random.secure();

  /// How long one call to another kiosk may take.
  Duration requestTimeout = const Duration(seconds: 4);
  Duration probeTimeout = const Duration(seconds: 3);

  /// Answer automatically waits this long with Decline on screen.
  Duration autoAnswerDelay = const Duration(seconds: 3);

  /// The card stays up this long after a call ends.
  Duration endedHold = const Duration(seconds: 10);

  /// A broadcast's card closes this long after the sender is done.
  Duration broadcastHold = const Duration(seconds: 5);

  /// The state sensor reads missed for this long.
  Duration missedHold = const Duration(minutes: 1);

  /// The ring sound repeats at this cadence.
  Duration ringCadence = const Duration(seconds: 4);

  /// How long a probe result is trusted.
  Duration probeTtl = const Duration(seconds: 30);

  /// How long a call rings here before it is missed: the Ring for setting.
  /// Tests shorten it.
  Duration Function()? ringForOverride;

  Duration get _ringFor =>
      ringForOverride?.call() ??
      Duration(
        seconds: int.tryParse(_settings.get(defs.intercomRingSeconds)) ?? 30,
      );

  /// The margin the caller waits past the callee's own ring time.
  Duration callerMargin = const Duration(seconds: 10);

  // ── State ──────────────────────────────────────────────────────────

  String _state = 'idle';
  IntercomCall? _call;
  final _links = <String, _Link>{};
  final _kiosks = <String, IntercomKiosk>{};
  String _selfId = '';
  String _selfName = '';
  String _selfAddress = '';
  int _selfPort = 0;
  String _selfVersion = '';
  bool _fleetEnabled = false;
  bool _aec = true;
  bool _micGranted = true;

  /// The tokens verified so far, by their expiry, so one cannot be replayed.
  final _seenTokens = <String, int>{};

  /// What the answer mode was before the Do not disturb tile flipped it.
  String _dndPrevious = 'ring';

  StreamSubscription<Uint8List>? _mic;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _ringTimer;
  Timer? _chimeTimer;
  Timer? _autoTimer;
  Timer? _holdTimer;
  Timer? _connectTimer;
  Timer? _missedTimer;
  Timer? _injectTimer;
  DateTime _lastLevel = DateTime.fromMillisecondsSinceEpoch(0);
  double _farLevel = 0;
  double _nearLevel = 0;
  bool _interactionHeld = false;
  int _nextId = 0;

  String get state => _state;
  IntercomCall? get call => _call;
  List<IntercomKiosk> get kiosks => List.unmodifiable(_kiosks.values);

  bool get enabled => _settings.get(defs.intercomEnabled);

  /// Whether the feature can run at all: the remote admin serves and the
  /// discovery names this kiosk and finds the others.
  bool get available => _fleetEnabled;

  bool get dnd =>
      _settings.get(defs.intercomAnswerMode) == 'dnd' ||
      _settings.get(defs.lockdownEnabled);

  String get key => _settings.get(defs.intercomKey);

  /// The first eight hex digits of the key's SHA-256, what the identity
  /// probe compares. Empty with no key.
  String get keyFingerprint => fingerprintOf(key);

  static String fingerprintOf(String key) => key.isEmpty
      ? ''
      : sha256.convert(utf8.encode(key)).toString().substring(0, 8);

  AuthStore? _auth;
  String _authKey = '';
  AuthStore get _tokens {
    if (_auth == null || _authKey != key) {
      _authKey = key;
      _auth = AuthStore('intercom:$key');
    }
    return _auth!;
  }

  // ── Init ───────────────────────────────────────────────────────────

  @override
  Future<void> init() async {
    _registerCommands();
    _subs.add(bus.on<FleetChanged>().listen((_) => _readFleet()));
    _subs.add(
      bus.on<SettingChanged>().listen((e) {
        if (e.key == defs.intercomEnabled.key) {
          unawaited(_onEnabledChanged());
        } else if (e.key == defs.intercomVolume.key) {
          unawaited(audio.setVolume(_playbackGain()));
        } else if (e.key == defs.intercomAnswerMode.key ||
            e.key == defs.lockdownEnabled.key ||
            e.key == defs.intercomKey.key ||
            e.key == defs.intercomTalkMode.key) {
          _changed();
        } else if (e.key == defs.remoteEnabled.key ||
            e.key == defs.remotePassword.key ||
            e.key == defs.remoteFleetDiscovery.key) {
          unawaited(_readFleet());
        }
      }),
    );
    // Another Voice Satellite turn or a page taking the microphone ends
    // the call: the page holds the microphone exclusively.
    micHub.browserCapturing.addListener(_onBrowserCapture);
    _aec = await audio.echoCancellerAvailable();
    await _readFleet();
    if (enabled && key.isEmpty) await _ensureKey();
  }

  @override
  Future<void> dispose() async {
    micHub.browserCapturing.removeListener(_onBrowserCapture);
    for (final s in _subs) {
      await s.cancel();
    }
    await _finish('ended', notify: false);
    _cancelTimers();
    _holdTimer?.cancel();
    _missedTimer?.cancel();
  }

  Future<void> _onEnabledChanged() async {
    if (enabled) {
      await _ensureKey();
      unawaited(_probeAll(force: true));
    } else if (_state != 'idle') {
      await _finish('ended');
    }
    _changed();
  }

  void _onBrowserCapture() {
    if (micHub.browserCapturing.value && _active) {
      log.info(name, 'the page took the microphone, ending the call');
      unawaited(hangup(reason: 'mic_busy'));
    }
  }

  Future<void> _ensureKey() async {
    if (key.isNotEmpty) return;
    await _settings.set(defs.intercomKey, _newKey());
    log.info(name, 'intercom key made');
  }

  String _newKey() => base64Url
      .encode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');

  // ── The roster ─────────────────────────────────────────────────────

  Future<void> _readFleet() async {
    final r = await commands.execute('fleet', const {});
    if (!r.ok || r.data is! Map) return;
    final data = (r.data as Map).cast<String, Object?>();
    _fleetEnabled = data['enabled'] == true;
    final devices = data['devices'];
    final heard = <String>{};
    if (devices is List) {
      for (final d in devices) {
        if (d is! Map) continue;
        final id = '${d['id'] ?? ''}';
        if (id.isEmpty) continue;
        if (d['self'] == true) {
          _selfId = id;
          _selfName = '${d['name'] ?? ''}';
          _selfAddress = '${d['address'] ?? ''}';
          _selfPort = (d['port'] as num?)?.toInt() ?? 0;
          _selfVersion = '${d['version'] ?? ''}';
          continue;
        }
        heard.add(id);
        final k = _kiosks[id];
        if (k == null) {
          _kiosks[id] = IntercomKiosk(
            id: id,
            name: '${d['name'] ?? ''}',
            address: '${d['address'] ?? ''}',
            port: (d['port'] as num?)?.toInt() ?? 2324,
            version: '${d['version'] ?? ''}',
          );
        } else {
          k
            ..name = '${d['name'] ?? ''}'
            ..address = '${d['address'] ?? ''}'
            ..port = (d['port'] as num?)?.toInt() ?? k.port
            ..version = '${d['version'] ?? ''}'
            ..heard = true;
        }
      }
    }
    for (final k in _kiosks.values) {
      if (!heard.contains(k.id)) k.heard = false;
    }
    _changed();
    if (enabled) unawaited(_probeAll());
  }

  /// Probes every heard kiosk whose result is stale. A forced probe waits
  /// for one already under way, then runs; an ordinary one rides it.
  Future<void> _probeAll({bool force = false}) async {
    final inFlight = _probeFuture;
    if (inFlight != null) {
      await inFlight;
      if (!force) return;
    }
    final run = _probeDue(force);
    _probeFuture = run;
    try {
      await run;
    } finally {
      if (_probeFuture == run) _probeFuture = null;
    }
  }

  Future<void>? _probeFuture;

  Future<void> _probeDue(bool force) async {
    final now = DateTime.now();
    final due = [
      for (final k in _kiosks.values)
        if (k.heard &&
            (force ||
                k.probedAt == null ||
                now.difference(k.probedAt!) > probeTtl))
          k,
    ];
    if (due.isEmpty) return;
    await Future.wait([for (final k in due) _probe(k)]);
    _changed();
  }

  Future<void> _probe(IntercomKiosk k) async {
    final res = await _get(
      '${k.url}/api/intercom/identity',
      timeout: probeTimeout,
    );
    k.probedAt = DateTime.now();
    final data = _jsonOf(res);
    if (res == null || res.statusCode != 200 || data == null) {
      k.probeFailed = true;
      // An older build without the route: the intercom is off there.
      if (res != null && res.statusCode == 404) {
        k.probeFailed = false;
        k.enabled = false;
      }
      return;
    }
    k.probeFailed = false;
    k.enabled = data['enabled'] == true;
    k.keyFingerprint = '${data['key'] ?? ''}';
    k.dnd = data['dnd'] == true;
    final n = '${data['name'] ?? ''}';
    if (n.isNotEmpty) k.name = n;
  }

  IntercomKiosk? _kioskById(String id) => _kiosks[id];

  List<IntercomKiosk> get _ready => [
    for (final k in _kiosks.values)
      if (k.status(keyFingerprint) == 'ready') k,
  ];

  // ── Status ─────────────────────────────────────────────────────────

  Map<String, Object?> status() => {
    'available': available,
    'enabled': enabled,
    'state': _state,
    'answerMode': _settings.get(defs.intercomAnswerMode),
    'talkMode': talkMode,
    'dnd': dnd,
    'lockdown': _settings.get(defs.lockdownEnabled),
    'aec': _aec,
    'micGranted': _micGranted,
    'self': {'id': _selfId, 'name': _selfName},
    'call': _call?.toJson(),
    'kiosks':
        [for (final k in _kiosks.values..toList()) k.toJson(keyFingerprint)]
          ..sort(
            (a, b) => '${a['name']}'.toLowerCase().compareTo(
              '${b['name']}'.toLowerCase(),
            ),
          ),
  };

  /// The effective talk mode: the setting, unless the platform has no echo
  /// canceller, which forces push to talk.
  String get talkMode => _aec ? _settings.get(defs.intercomTalkMode) : 'ptt';

  void _changed() => bus.publish(IntercomStateChanged(status()));

  bool get _active =>
      _state == 'in_call' || _state == 'broadcasting' || _state == 'listening';

  bool get _busy => _state != 'idle' && _state != 'ended' && _state != 'missed';

  // ── Commands ───────────────────────────────────────────────────────

  void _registerCommands() {
    commands
      ..register(
        Command(
          name: 'intercomStatus',
          description:
              'The intercom as both UIs draw it: state, the current call, '
              'the kiosks on the network and their readiness.',
          quiet: true,
          handler: (_) async {
            if (enabled) unawaited(_probeAll());
            return CommandResult.ok(status());
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomKiosks',
          description: 'The roster, probed afresh when asked.',
          params: const {'probe': 'true to probe every kiosk again'},
          quiet: true,
          handler: (p) async {
            await _readFleet();
            if (p['probe'] == true) await _probeAll(force: true);
            return CommandResult.ok(status()['kiosks']);
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomCall',
          description: 'Call another kiosk by its id.',
          params: const {'id': "The kiosk's id from intercomStatus"},
          handler: (p) async {
            final k = _kioskById('${p['id'] ?? ''}');
            if (k == null) return const CommandResult.fail('unknown kiosk');
            return _place(k);
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomBroadcast',
          description: 'Talk to every ready kiosk at once, push to talk.',
          handler: (_) async => _broadcast(),
        ),
      )
      ..register(
        Command(
          name: 'intercomAnswer',
          description: 'Answer the call ringing here (the kiosk screen only).',
          handler: (_) async => _answer(),
        ),
      )
      ..register(
        Command(
          name: 'intercomDecline',
          description: 'Decline the call ringing here (the kiosk screen only).',
          handler: (_) async {
            if (_state != 'ringing') {
              return const CommandResult.fail('nothing is ringing');
            }
            await _signalPeer('decline');
            await _finish('declined');
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomHangup',
          description:
              'End the call, cancel one being placed, or close a broadcast.',
          handler: (_) async {
            if (!_busy) return const CommandResult.fail('no call');
            await hangup();
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomDismiss',
          description: 'Close the card left after a call ended or was missed.',
          quiet: true,
          handler: (_) async {
            if (_state == 'ended' || _state == 'missed') {
              _holdTimer?.cancel();
              _missedTimer?.cancel();
              _call = null;
              _setState('idle');
            }
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomTalk',
          description: 'Push to talk: on while the button is held.',
          params: const {'on': 'true while held'},
          quiet: true,
          handler: (p) async {
            final c = _call;
            if (c == null || !_active) {
              return const CommandResult.fail('no call');
            }
            final on = p['on'] == true;
            if (c.localTalking == on) return const CommandResult.ok();
            c.localTalking = on;
            for (final l in _links.values) {
              l.sendText({'type': 'talk', 'on': on});
            }
            _changed();
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomMute',
          description: 'Hands free: mute or unmute this microphone.',
          params: const {'on': 'true to mute'},
          handler: (p) async {
            final c = _call;
            if (c == null || !_active) {
              return const CommandResult.fail('no call');
            }
            c.muted = p['on'] == true;
            for (final l in _links.values) {
              l.sendText({'type': 'talk', 'on': !c.muted});
            }
            _changed();
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomOpen',
          description: 'Open the sheet of kiosks to call on the kiosk screen.',
          handler: (_) async {
            if (!enabled) return const CommandResult.fail('intercom is off');
            if (!available) {
              return const CommandResult.fail(
                'the intercom needs the remote admin and Find other kiosks',
              );
            }
            bus.publish(const IntercomOpenRequested());
            return const CommandResult.ok();
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomSetDnd',
          description:
              'Do not disturb on or off: flips the answer mode and back to '
              'what it was.',
          params: const {'on': 'true for Do not disturb'},
          handler: (p) async {
            final on = p['on'] == true;
            final mode = _settings.get(defs.intercomAnswerMode);
            if (on && mode != 'dnd') {
              _dndPrevious = mode;
              await _settings.set(defs.intercomAnswerMode, 'dnd');
            } else if (!on && mode == 'dnd') {
              await _settings.set(defs.intercomAnswerMode, _dndPrevious);
            }
            return CommandResult.ok({'dnd': dnd});
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomSetKey',
          description: 'Paste a key from another kiosk, or make a new one.',
          params: const {
            'key': 'The key to use',
            'regenerate': 'true for a fresh random key',
          },
          handler: (p) async {
            final String next;
            if (p['regenerate'] == true) {
              next = _newKey();
            } else {
              next = '${p['key'] ?? ''}'.trim();
              if (next.length < 16) {
                return const CommandResult.fail(
                  'a key is at least 16 characters',
                );
              }
            }
            await _settings.set(defs.intercomKey, next);
            _seenTokens.clear();
            unawaited(_probeAll(force: true));
            return CommandResult.ok({'key': next});
          },
        ),
      )
      ..register(
        Command(
          name: 'announcementTtsEngines',
          description:
              "Home Assistant's text to speech entities, for the engine "
              'picker: id and name each.',
          quiet: true,
          handler: (_) async {
            final engines = await _ttsEngines();
            return engines == null
                ? const CommandResult.fail('could not reach Home Assistant')
                : CommandResult.ok(engines);
          },
        ),
      )
      ..register(
        Command(
          name: 'announce',
          description:
              'Play an announcement on this kiosk: a message Home Assistant '
              'speaks, or an audio URL, with a chime first.',
          params: const {
            'message': 'What to say, through Home Assistant text to speech',
            'url': 'An audio file to play instead of a message',
            'volume':
                'A share of the master volume, 0..1, instead of the media '
                'volume; 0 or missing keeps the media volume',
          },
          handler: (p) async => _announce(p),
        ),
      )
      // A test hook, like injectWakeAudio: a 16 kHz mono PCM16 WAV sent
      // over the live call's socket in 80 ms chunks as if this kiosk's
      // microphone had heard it, whatever the talk mode says. How a
      // conversation is simulated when one person tests both ends.
      ..register(
        Command(
          name: 'intercomInjectAudio',
          description:
              'Send a WAV (16 kHz mono PCM16, base64) into the live call as '
              'this kiosk\'s voice, for testing.',
          params: const {'wavBase64': 'WAV file (16 kHz mono PCM16), base64'},
          quiet: true,
          handler: (p) async {
            if (!_active || _links.isEmpty) {
              return const CommandResult.fail('no live call');
            }
            final wav = p['wavBase64'];
            if (wav is! String || wav.isEmpty) {
              return const CommandResult.fail('wavBase64 required');
            }
            final pcm = _wavPcm16k(base64Decode(wav));
            if (pcm == null) {
              return const CommandResult.fail('not a 16 kHz mono PCM16 WAV');
            }
            await _streamClip(_call!, pcm);
            return CommandResult.ok({'ms': pcm.length ~/ 32});
          },
        ),
      )
      // The wire side, called by the remote server.
      ..register(
        Command(
          name: 'intercomIdentity',
          description:
              'What another kiosk learns about this one before a call: '
              'whether the intercom is on, which key it holds, Do not disturb.',
          quiet: true,
          handler: (_) async => CommandResult.ok({
            'id': _selfId,
            'name': _selfName,
            'version': _selfVersion,
            'enabled': enabled && available,
            'key': keyFingerprint,
            'dnd': dnd,
          }),
        ),
      )
      ..register(
        Command(
          name: 'intercomIncoming',
          description:
              'A call or broadcast from another kiosk landed here (the '
              'remote server relays it with the token and the real address).',
          quiet: true,
          handler: (p) async => _incoming(p),
        ),
      )
      ..register(
        Command(
          name: 'intercomSignal',
          description:
              'The other side of a call answered, declined, cancelled or '
              'hung up (relayed by the remote server).',
          quiet: true,
          handler: (p) async => _signal(p),
        ),
      )
      ..register(
        Command(
          name: 'intercomVerify',
          description:
              'Whether a token opens the audio socket of the call named.',
          quiet: true,
          handler: (p) async {
            final callId = '${p['call'] ?? ''}';
            final ok =
                _verifyToken('${p['token'] ?? ''}', callId) &&
                _call?.id == callId &&
                (_state == 'in_call' || _state == 'listening');
            return ok
                ? const CommandResult.ok()
                : const CommandResult.fail('refused');
          },
        ),
      )
      ..register(
        Command(
          name: 'intercomAttachSocket',
          description:
              'The audio socket of a call this kiosk was called on, opened '
              'by the caller (the remote server hands it over).',
          quiet: true,
          handler: (p) async {
            final channel = p['channel'];
            final callId = '${p['call'] ?? ''}';
            if (channel is! WebSocketChannel ||
                _call?.id != callId ||
                !(_state == 'in_call' || _state == 'listening')) {
              return const CommandResult.fail('no such call');
            }
            await _attach(channel, '${_call!.peer['id']}');
            return const CommandResult.ok();
          },
        ),
      );
  }

  // ── Placing a call ─────────────────────────────────────────────────

  Future<CommandResult> _place(IntercomKiosk k) async {
    if (!enabled) return const CommandResult.fail('intercom is off');
    if (!available) return const CommandResult.fail('needs the remote admin');
    if (_busy) {
      // Reply from a broadcast: leave it, then call.
      if (_state == 'listening') {
        await _finish('ended', notify: false);
      } else {
        return const CommandResult.fail('already in a call');
      }
    }
    _holdTimer?.cancel();
    _missedTimer?.cancel();
    final id = _callId();
    final c = IntercomCall(
      id: id,
      kind: 'call',
      outgoing: true,
      peer: _peerOf(k),
    );
    _call = c;
    _setState('calling');
    log.info(name, 'calling ${k.name}');
    final res = await _post(
      '${k.url}/api/intercom/call',
      {'call': id, 'kind': 'call', 'from': _selfInfo()},
      token: _tokens.issueToken(
        ttl: const Duration(seconds: 60),
        claims: {'intercom': id, 'from': _selfId, 'n': _nonce()},
      ),
    );
    if (_call != c) return const CommandResult.ok();
    final data = _jsonOf(res);
    final st = res == null
        ? 'unreachable'
        : res.statusCode == 403
        ? 'key'
        : '${data?['status'] ?? 'failed'}';
    switch (st) {
      case 'ringing':
      case 'auto':
        // The callee answers or declines through intercomSignal; its own
        // ring timeout tells us a miss, with a margin here.
        _ringTimer = Timer(_ringFor + callerMargin, () => _finish('no_answer'));
        _changed();
        return const CommandResult.ok();
      default:
        await _finish(st);
        return CommandResult.fail(_reasonText(st));
    }
  }

  Future<CommandResult> _broadcast() async {
    if (!enabled) return const CommandResult.fail('intercom is off');
    if (!available) return const CommandResult.fail('needs the remote admin');
    if (_busy) return const CommandResult.fail('already in a call');
    await _readFleet();
    await _probeAll();
    final targets = _ready;
    if (targets.isEmpty) return const CommandResult.fail('no kiosk is ready');
    if (!await _openMic()) {
      return const CommandResult.fail('microphone not granted');
    }
    return _startBroadcast(targets);
  }

  /// Fans an announcement out: one socket per kiosk that takes it. With
  /// [audio] (an announcement from Home Assistant) the clip plays into
  /// every socket, and here too when [playLocally], instead of the
  /// microphone, and the announcement ends when the clip does.
  Future<CommandResult> _startBroadcast(
    List<IntercomKiosk> targets, {
    Uint8List? audio,
    bool playLocally = false,
  }) async {
    _holdTimer?.cancel();
    _missedTimer?.cancel();
    final id = _callId();
    final c = IntercomCall(
      id: id,
      kind: 'broadcast',
      outgoing: true,
      peer: targets.isEmpty
          ? {'id': _selfId, 'name': _selfName, 'address': _selfAddress}
          : _peerOf(targets.first),
    )..automated = audio != null;
    for (final k in targets) {
      c.targets[k.id] = {'id': k.id, 'name': k.name, 'status': 'calling'};
    }
    _call = c;
    _setState('broadcasting');
    log.info(
      name,
      '${audio == null ? 'announcing' : 'playing an announcement'} to '
      '${targets.length} kiosks${playLocally ? ' and here' : ''}',
    );
    await Future.wait([for (final k in targets) _inviteBroadcast(c, k)]);
    if (_call != c) return const CommandResult.ok();
    if (_links.isEmpty && !playLocally) {
      await _finish('no_targets');
      return CommandResult.fail(_targetsSummary(c));
    }
    c.since = DateTime.now();
    if (audio != null) {
      if (playLocally) await _startPlayback();
      unawaited(
        _streamClip(c, audio, local: playLocally).then((_) {
          if (_call == c && _state == 'broadcasting') _finish('ended');
        }),
      );
    }
    _changed();
    return CommandResult.ok({
      'targets': c.targets.values.toList(),
      'self': playLocally,
      if (audio != null) 'ms': audio.length ~/ 32,
    });
  }

  static String _targetsSummary(IntercomCall c) => c.targets.values
      .map((t) => '${t['name']}: ${_targetText('${t['status']}')}')
      .join(', ');

  static String _targetText(String status) => switch (status) {
    'listening' => 'listening',
    'busy' => 'busy',
    'dnd' => 'do not disturb',
    'off' => 'intercom off',
    'refused' => 'announcements off',
    'key' => 'a different key',
    'unreachable' => 'unreachable',
    'left' => 'done',
    _ => status,
  };

  /// Sends [pcm] (16 kHz mono PCM16) in 80 ms chunks to every link, and
  /// to this kiosk's own speaker when [local], on the clock a microphone
  /// would keep. Resolves when the clip ran out or the call ended.
  Future<void> _streamClip(
    IntercomCall c,
    Uint8List pcm, {
    bool local = false,
  }) {
    _injectTimer?.cancel();
    var offset = 0;
    const chunk = 2560;
    final done = Completer<void>();
    _injectTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (_call != c || !_active || offset >= pcm.length) {
        t.cancel();
        if (_injectTimer == t) _injectTimer = null;
        if (!done.isCompleted) done.complete();
        return;
      }
      final end = (offset + chunk).clamp(0, pcm.length);
      final piece = Uint8List.fromList(pcm.sublist(offset, end));
      offset = end;
      c.sent++;
      for (final l in _links.values) {
        l.sendBytes(piece);
      }
      if (local) audio.write(piece);
      _nearLevel = _level(piece);
      _publishLevel();
    });
    return done.future;
  }

  // ── Announcements from Home Assistant ──────────────────────────────

  /// The `announce` action: a message for Home Assistant's text to speech
  /// or an audio URL, played on this kiosk alone with a chime first. Its
  /// own feature under ESPHome, Announcements; the intercom only lends
  /// it the playback sink and the card.
  Future<CommandResult> _announce(Map<String, Object?> p) async {
    if (!_settings.get(defs.announcementsEnabled)) {
      return const CommandResult.fail('announcements are off');
    }
    if (_busy) return const CommandResult.fail('in a call');
    final message = '${p['message'] ?? ''}'.trim();
    final url = '${p['url'] ?? ''}'.trim();
    if (message.isEmpty && url.isEmpty) {
      return const CommandResult.fail('message or url required');
    }
    final source = url.isNotEmpty ? url : await _ttsUrl(message);
    if (source == null) {
      return const CommandResult.fail('Home Assistant could not speak it');
    }
    final bytes = await _fetchAudio(source);
    if (bytes == null) return CommandResult.fail('could not fetch $source');
    final pcm = await audio.decode(bytes);
    if (pcm == null || pcm.isEmpty) {
      return const CommandResult.fail('could not decode the audio');
    }
    if (_busy) return const CommandResult.fail('in a call');
    _holdTimer?.cancel();
    _missedTimer?.cancel();
    final c =
        IntercomCall(
            id: _callId(),
            kind: 'broadcast',
            outgoing: false,
            peer: const {'id': 'home-assistant', 'name': 'Home Assistant'},
          )
          ..automated = true
          ..message = message;
    _call = c;
    await _comeForward();
    _setState('listening');
    if (_settings.get(defs.announcementsChime)) {
      await _announcementChime();
    }
    // The media fader, unless the action names a volume of its own: a
    // share of the master, 0..1, on the same squared taper the faders
    // use. 0 or less (the action cannot leave a number out) means the
    // fader.
    final asked = p['volume'];
    final askedVolume = asked is num
        ? asked.toDouble()
        : double.tryParse('$asked') ?? 0;
    final share = askedVolume > 0
        ? askedVolume.clamp(0.0, 1.0)
        : _settings.get(defs.mediaVolume).toDouble().clamp(0, 100) / 100;
    await _startPlayback(volume: share * share);
    c.since = DateTime.now();
    log.info(name, 'announcement from Home Assistant, ${pcm.length ~/ 32} ms');
    unawaited(
      _streamClip(c, pcm, local: true).then((_) {
        if (_call == c && _state == 'listening') _finish('broadcast_over');
      }),
    );
    return CommandResult.ok({'ms': pcm.length ~/ 32});
  }

  /// The chime before an announcement: the picked sound file through the
  /// chime player, else the built-in two note chime the native sink
  /// synthesizes. Waits for it, so the words start after it.
  Future<void> _announcementChime() async {
    final volume = _settings
        .get(defs.notificationsVolume)
        .toDouble()
        .clamp(0.0, 1.0);
    final sound = _settings.get(defs.announcementsChimeFile).trim();
    final path = sound.isEmpty ? null : await NotificationSounds.resolve(sound);
    if (path != null) {
      await commands.execute('playChime', {'source': path, 'volume': volume});
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return;
    }
    await audio.chime(volume: volume);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
  }

  /// Home Assistant's `tts.*` entities as `{entity_id, name}`, or null
  /// when it cannot be reached.
  Future<List<Map<String, String>>?> _ttsEngines() async {
    final base = _haBase;
    final token = _settings.get(defs.haToken);
    if (base.isEmpty || token.isEmpty) return null;
    final states = await _get('$base/api/states', token: token);
    if (states == null || states.statusCode != 200) return null;
    Object? list;
    try {
      list = jsonDecode(states.body);
    } catch (_) {
      return null;
    }
    if (list is! List) return null;
    final out = <Map<String, String>>[];
    for (final e in list) {
      if (e is! Map) continue;
      final id = '${e['entity_id']}';
      if (!id.startsWith('tts.')) continue;
      final attrs = e['attributes'];
      final friendly = attrs is Map ? '${attrs['friendly_name'] ?? ''}' : '';
      out.add({'entity_id': id, 'name': friendly.isEmpty ? id : friendly});
    }
    out.sort(
      (a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
    );
    return out;
  }

  /// Asks Home Assistant to speak [message] and answers the audio URL.
  Future<String?> _ttsUrl(String message) async {
    final base = _haBase;
    final token = _settings.get(defs.haToken);
    if (base.isEmpty || token.isEmpty) return null;
    var engine = _settings.get(defs.announcementsTtsEngine).trim();
    if (engine.isEmpty) {
      final engines = await _ttsEngines();
      engine = engines == null || engines.isEmpty
          ? ''
          : engines.first['entity_id']!;
      if (engine.isEmpty) {
        log.warn(name, 'Home Assistant has no text to speech entity');
        return null;
      }
    }
    final res = await _post('$base/api/tts_get_url', {
      'engine_id': engine,
      'message': message,
    }, token: token);
    final data = _jsonOf(res);
    final url = data?['url'];
    if (res == null || res.statusCode != 200 || url is! String) {
      log.warn(
        name,
        'tts_get_url with $engine: ${res?.statusCode} ${res?.body}',
      );
      return null;
    }
    return url;
  }

  String get _haBase =>
      _settings.get(defs.haUrl).trim().replaceAll(RegExp(r'/+$'), '');

  Future<Uint8List?> _fetchAudio(String url) async {
    final base = _haBase;
    final onHa = base.isNotEmpty && url.startsWith(base);
    final client = clientFactory();
    try {
      final res = await client
          .get(
            Uri.parse(url),
            headers: {
              if (onHa)
                'Authorization': 'Bearer ${_settings.get(defs.haToken)}',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      return res.bodyBytes;
    } catch (e) {
      log.debug(name, 'GET $url: $e');
      return null;
    } finally {
      client.close();
    }
  }

  Future<void> _inviteBroadcast(IntercomCall c, IntercomKiosk k) async {
    final res = await _post(
      '${k.url}/api/intercom/call',
      {'call': c.id, 'kind': 'broadcast', 'from': _selfInfo()},
      token: _tokens.issueToken(
        ttl: const Duration(seconds: 60),
        claims: {'intercom': c.id, 'from': _selfId, 'n': _nonce()},
      ),
    );
    if (_call != c) return;
    final data = _jsonOf(res);
    final st = res == null
        ? 'unreachable'
        : res.statusCode == 403
        ? 'key'
        : '${data?['status'] ?? 'failed'}';
    c.targets[k.id]?['status'] = st;
    if (st != 'listening') return;
    final ok = await _connect(k, c.id);
    if (_call != c) return;
    if (!ok) c.targets[k.id]?['status'] = 'unreachable';
  }

  /// Opens the audio socket to a kiosk that answered.
  Future<bool> _connect(IntercomKiosk k, String callId) async {
    final token = _tokens.issueToken(
      ttl: const Duration(seconds: 60),
      claims: {'intercom': callId, 'from': _selfId, 'n': _nonce()},
    );
    final uri = Uri.parse(
      'ws://${k.address}:${k.port}/api/intercom/audio/$callId?token=$token',
    );
    try {
      final channel = socketFactory(uri);
      await channel.ready.timeout(requestTimeout);
      await _attach(channel, k.id);
      return true;
    } catch (e) {
      log.warn(name, 'audio socket to ${k.name}: $e');
      return false;
    }
  }

  // ── A call coming in ───────────────────────────────────────────────

  Future<CommandResult> _incoming(Map<String, Object?> p) async {
    final callId = '${p['call'] ?? ''}';
    final kind = '${p['kind'] ?? 'call'}';
    final from = (p['from'] as Map?)?.cast<String, Object?>() ?? const {};
    if (callId.isEmpty || from['id'] == null) {
      return const CommandResult.fail('call and from required');
    }
    if (!enabled || !available) return CommandResult.ok({'status': 'off'});
    if (!_verifyToken('${p['token'] ?? ''}', callId)) {
      return CommandResult.ok({'status': 'key', 'code': 403});
    }
    // Accept announcements off refuses Announce to all. Lockdown Mode
    // and Do not disturb refuse everything.
    if (kind == 'broadcast' &&
        !_settings.get(defs.intercomAcceptAnnouncements)) {
      return CommandResult.ok({'status': 'refused'});
    }
    if (dnd) return CommandResult.ok({'status': 'dnd'});
    if (_busy) return CommandResult.ok({'status': 'busy'});
    final peer = {
      'id': '${from['id']}',
      'name': '${from['name'] ?? ''}',
      // Where it really came from, whatever the body says.
      'address': '${p['address'] ?? from['address'] ?? ''}',
      'port': (from['port'] as num?)?.toInt() ?? 2324,
      'version': '${from['version'] ?? ''}',
    };
    _holdTimer?.cancel();
    _missedTimer?.cancel();
    final c = IntercomCall(
      id: callId,
      kind: kind == 'broadcast' ? 'broadcast' : 'call',
      outgoing: false,
      peer: peer,
    );
    _call = c;
    await _comeForward();
    if (c.kind == 'broadcast') {
      _setState('listening');
      log.info(name, '${peer['name']} is announcing');
      unawaited(_ring(short: true));
      unawaited(_startPlayback());
      _armConnectTimeout();
      return CommandResult.ok({'status': 'listening'});
    }
    final auto = _settings.get(defs.intercomAnswerMode) == 'auto';
    _setState('ringing');
    log.info(name, '${peer['name']} is calling');
    unawaited(_ring(short: auto));
    if (auto) {
      c.autoAnswerAt = DateTime.now().add(autoAnswerDelay);
      _autoTimer = Timer(autoAnswerDelay, () {
        if (_call == c && _state == 'ringing') unawaited(_answer());
      });
    } else {
      _chimeTimer = Timer.periodic(ringCadence, (_) => _ring());
      _ringTimer = Timer(_ringFor, () async {
        if (_call != c || _state != 'ringing') return;
        await _signalPeer('missed');
        await _finish('missed');
      });
    }
    _changed();
    return CommandResult.ok({'status': auto ? 'auto' : 'ringing'});
  }

  /// A call or an announcement coming in wakes a dark screen and brings
  /// the kiosk in front of whatever app covers it, the way a wake word
  /// does: bringToFront wakes the display first, then switches tasks,
  /// which needs the Display over other apps grant and is logged without
  /// it. screenOn is the fallback where the command is missing (tests).
  Future<void> _comeForward() async {
    final r = await commands.execute('bringToFront', const {});
    if (!r.ok) await commands.execute('screenOn', const {});
  }

  Future<CommandResult> _answer() async {
    final c = _call;
    if (c == null || _state != 'ringing') {
      return const CommandResult.fail('nothing is ringing');
    }
    _cancelTimers();
    await audio.stopRing();
    if (!await _openMic()) {
      // Answer anyway: listening is still worth it, the card says why
      // nothing goes out.
      log.warn(name, 'microphone not granted, the call is listen only');
    }
    _setState('in_call');
    await _startPlayback();
    _armConnectTimeout();
    final ok = await _signalPeer('answer');
    if (!ok && _call == c) {
      await _finish('unreachable');
      return const CommandResult.fail('the caller did not answer');
    }
    _changed();
    return const CommandResult.ok();
  }

  /// Nothing came over the socket in time: the caller went away.
  void _armConnectTimeout() {
    _connectTimer?.cancel();
    _connectTimer = Timer(const Duration(seconds: 10), () {
      if (_links.isEmpty && (_state == 'in_call' || _state == 'listening')) {
        unawaited(_finish('failed'));
      }
    });
  }

  Future<CommandResult> _signal(Map<String, Object?> p) async {
    final callId = '${p['call'] ?? ''}';
    final action = '${p['action'] ?? ''}';
    if (!_verifyToken('${p['token'] ?? ''}', callId)) {
      return const CommandResult.fail('refused');
    }
    final c = _call;
    if (c == null || c.id != callId) {
      return const CommandResult.fail('no such call');
    }
    switch (action) {
      case 'answer':
        if (_state != 'calling') return const CommandResult.fail('not calling');
        _ringTimer?.cancel();
        final k = _kioskById('${c.peer['id']}');
        if (k == null) {
          await _finish('failed');
          return const CommandResult.fail('unknown kiosk');
        }
        if (!await _openMic()) {
          log.warn(name, 'microphone not granted, the call is listen only');
        }
        _setState('in_call');
        await _startPlayback();
        unawaited(() async {
          final ok = await _connect(k, c.id);
          if (!ok && _call == c) await _finish('failed');
        }());
        return const CommandResult.ok();
      case 'decline':
        await _finish('declined');
        return const CommandResult.ok();
      case 'missed':
        await _finish('no_answer');
        return const CommandResult.ok();
      case 'cancel':
      case 'hangup':
        await _finish(_state == 'ringing' ? 'cancelled' : 'ended');
        return const CommandResult.ok();
    }
    return const CommandResult.fail('unknown action');
  }

  /// Tells the other side of the current call something. True when it
  /// took it.
  Future<bool> _signalPeer(String action) async {
    final c = _call;
    if (c == null) return false;
    final url =
        'http://${c.peer['address']}:${c.peer['port']}/api/intercom/call/${c.id}';
    final res = await _post(
      url,
      {'action': action},
      token: _tokens.issueToken(
        ttl: const Duration(seconds: 60),
        claims: {'intercom': c.id, 'from': _selfId, 'n': _nonce()},
      ),
    );
    return res != null && res.statusCode == 200;
  }

  // ── The audio socket ───────────────────────────────────────────────

  Future<void> _attach(WebSocketChannel channel, String peerId) async {
    final c = _call;
    if (c == null) {
      try {
        await channel.sink.close();
      } catch (_) {}
      return;
    }
    final old = _links.remove(peerId);
    await old?.close();
    final link = _Link(peerId, channel);
    _links[peerId] = link;
    _connectTimer?.cancel();
    link.sub = channel.stream.listen(
      (raw) => _onFrame(link, raw),
      onDone: () => _onLinkClosed(link),
      onError: (Object e) {
        log.debug(name, 'audio socket: $e');
        _onLinkClosed(link);
      },
    );
    c.since ??= DateTime.now();
    if (c.kind == 'broadcast' && c.outgoing) {
      c.targets[peerId]?['status'] = 'listening';
    }
    // The other side learns our talk state at once: hands free with the
    // microphone open reads as talking.
    link.sendText({'type': 'talk', 'on': _sending});
    if (!c.outgoing || c.kind == 'call') {
      log.info(name, 'voice connected with ${c.peer['name']}');
    }
    _changed();
  }

  void _onFrame(_Link link, Object? raw) {
    final c = _call;
    if (c == null) return;
    if (raw is String) {
      Map<String, Object?>? msg;
      try {
        final d = jsonDecode(raw);
        if (d is Map) msg = d.cast<String, Object?>();
      } catch (_) {}
      if (msg == null) return;
      switch ('${msg['type']}') {
        case 'talk':
          c.farTalking = msg['on'] == true;
          _changed();
        case 'end':
          unawaited(_peerEnded(link));
      }
      return;
    }
    if (raw is List<int>) {
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
      c.received++;
      audio.write(bytes);
      _farLevel = _level(bytes);
      _publishLevel();
    }
  }

  Future<void> _peerEnded(_Link link) async {
    final c = _call;
    if (c == null) return;
    if (c.kind == 'broadcast' && c.outgoing) {
      c.targets[link.peerId]?['status'] = 'left';
      await link.close();
      _links.remove(link.peerId);
      if (_links.isEmpty) await _finish('ended');
      _changed();
      return;
    }
    await _finish(_state == 'listening' ? 'broadcast_over' : 'ended');
  }

  void _onLinkClosed(_Link link) {
    if (_links[link.peerId] != link) return;
    _links.remove(link.peerId);
    final c = _call;
    if (c == null || !_active) return;
    if (c.kind == 'broadcast' && c.outgoing) {
      c.targets[link.peerId]?['status'] = 'left';
      if (_links.isEmpty) unawaited(_finish('ended'));
      _changed();
      return;
    }
    unawaited(_finish(_state == 'listening' ? 'broadcast_over' : 'ended'));
  }

  // ── Microphone and playback ────────────────────────────────────────

  /// Whether chunks go out right now.
  bool get _sending {
    final c = _call;
    if (c == null || !_active || _mic == null) return false;
    if (c.kind == 'broadcast' && !c.outgoing) return false;
    if (c.automated) return false;
    if (talkMode == 'ptt') return c.localTalking;
    return !c.muted;
  }

  Future<bool> _openMic() async {
    if (_mic != null) return true;
    if (micHub.browserCapturing.value) return false;
    _micGranted = await micPermission();
    if (!_micGranted) {
      _changed();
      return false;
    }
    _mic = micHub.stream().listen(
      (chunk) {
        if (!_sending) return;
        _call?.sent++;
        for (final l in _links.values) {
          l.sendBytes(chunk);
        }
        _nearLevel = _level(chunk);
        _publishLevel();
      },
      onError: (Object e) {
        log.warn(name, 'microphone: $e');
      },
    );
    return true;
  }

  Future<void> _closeMic() async {
    final sub = _mic;
    _mic = null;
    await sub?.cancel();
  }

  Future<void> _startPlayback({double? volume}) async {
    if (audio.open) return;
    final ok = await audio.start(volume: volume ?? _playbackGain());
    if (!ok) log.warn(name, 'playback could not open');
  }

  /// The intercom fader on the app's squared taper.
  double _playbackGain() {
    final pct = _settings.get(defs.intercomVolume).toDouble().clamp(0, 100);
    final f = pct / 100;
    return f * f;
  }

  /// The ring: the picked sound file through the chime player, else the
  /// built-in telephone ring the native sink synthesizes (no asset). A
  /// short ring is one burst: Answer automatically and a broadcast.
  Future<void> _ring({bool short = false}) async {
    final volume = _settings
        .get(defs.notificationsVolume)
        .toDouble()
        .clamp(0.0, 1.0);
    final sound = _settings.get(defs.intercomRingSound).trim();
    final path = sound.isEmpty ? null : await NotificationSounds.resolve(sound);
    if (path != null) {
      await commands.execute('playChime', {'source': path, 'volume': volume});
      return;
    }
    final err = await audio.ring(volume: volume, short: short);
    if (err != null) {
      log.warn(name, 'ring failed: $err');
    } else {
      log.debug(name, 'ring${short ? ' (short)' : ''} at $volume');
    }
  }

  static double _level(Uint8List pcm) {
    if (pcm.length < 4) return 0;
    final data = ByteData.sublistView(pcm);
    var sum = 0.0;
    final n = pcm.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final s = data.getInt16(i * 2, Endian.little).toDouble();
      sum += s * s;
    }
    final rms = sqrt(sum / n);
    return (rms / 4000).clamp(0.0, 1.0);
  }

  void _publishLevel() {
    final now = DateTime.now();
    if (now.difference(_lastLevel) < const Duration(milliseconds: 66)) return;
    _lastLevel = now;
    bus.publish(IntercomLevel(near: _nearLevel, far: _farLevel));
  }

  // ── Ending ─────────────────────────────────────────────────────────

  /// Ends whatever is going on: cancels a call being placed, declines
  /// nothing (that is intercomDecline), hangs up a live call or closes a
  /// broadcast.
  Future<void> hangup({String reason = 'ended'}) async {
    final c = _call;
    if (c == null) return;
    if (_links.isNotEmpty) {
      for (final l in _links.values) {
        l.sendText(const {'type': 'end'});
      }
    } else if (_state == 'calling' || _state == 'in_call') {
      await _signalPeer(_state == 'calling' ? 'cancel' : 'hangup');
    }
    await _finish(_state == 'calling' ? 'cancelled' : reason);
  }

  Future<void> _finish(String reason, {bool notify = true}) async {
    final c = _call;
    _cancelTimers();
    _connectTimer?.cancel();
    _injectTimer?.cancel();
    _injectTimer = null;
    await audio.stopRing();
    for (final l in _links.values.toList()) {
      await l.close();
    }
    _links.clear();
    await _closeMic();
    await audio.stop();
    if (c == null) {
      if (_state != 'idle' && _state != 'ended' && _state != 'missed') {
        _setState('idle');
      }
      return;
    }
    c.endedAt = DateTime.now();
    c.reason = reason;
    c.farTalking = false;
    c.localTalking = false;
    final wasBusy = _busy;
    log.info(name, 'call with ${c.peer['name']}: ${_reasonText(reason)}');
    if (reason == 'missed') {
      _setState('missed', notify: notify);
      _missedTimer?.cancel();
      _missedTimer = Timer(missedHold, () {
        if (_state == 'missed') {
          _call = null;
          _setState('idle');
        }
      });
      return;
    }
    if (!wasBusy) {
      _call = null;
      _setState('idle', notify: notify);
      return;
    }
    _setState('ended', notify: notify);
    _holdTimer?.cancel();
    _holdTimer = Timer(
      reason == 'broadcast_over' ? broadcastHold : endedHold,
      () {
        if (_state == 'ended' && _call == c) {
          _call = null;
          _setState('idle');
        }
      },
    );
  }

  void _cancelTimers() {
    _ringTimer?.cancel();
    _chimeTimer?.cancel();
    _autoTimer?.cancel();
    _ringTimer = null;
    _chimeTimer = null;
    _autoTimer = null;
  }

  void _setState(String next, {bool notify = true}) {
    if (_state == next) {
      if (notify) _changed();
      return;
    }
    _state = next;
    // The card's last words hold nothing: the screensaver and the wake
    // word come back the moment the voice stops.
    final holds = next != 'idle' && next != 'missed' && next != 'ended';
    if (holds != _interactionHeld) {
      _interactionHeld = holds;
      bus.publish(
        VoiceInteractionChanged(
          active: holds,
          reason: 'intercom',
          source: InteractionSource.command,
        ),
      );
    }
    if (notify) _changed();
  }

  static String _reasonText(String reason) => switch (reason) {
    'ended' => 'ended',
    'declined' => 'declined',
    'cancelled' => 'cancelled',
    'busy' => 'busy',
    'dnd' => 'do not disturb',
    'off' => 'its intercom is off',
    'key' => 'a different intercom key',
    'no_answer' => 'no answer',
    'missed' => 'missed',
    'unreachable' => 'did not answer',
    'failed' => 'the voice link failed',
    'mic_busy' => 'the page took the microphone',
    'no_targets' => 'nobody could take it',
    'broadcast_over' => 'the broadcast ended',
    _ => reason,
  };

  // ── Trust ──────────────────────────────────────────────────────────

  bool _verifyToken(String token, String callId) {
    if (key.isEmpty || token.isEmpty) return false;
    final claims = _tokens.claimsOf(token);
    if (claims == null) return false;
    if ('${claims['intercom']}' != callId) return false;
    final exp = claims['exp'];
    if (exp is! int) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    _seenTokens.removeWhere((_, e) => e < now);
    if (_seenTokens.containsKey(token)) return false;
    _seenTokens[token] = exp;
    return true;
  }

  String _nonce() => random.nextInt(1 << 30).toRadixString(36);

  String _callId() =>
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
      '-${(++_nextId).toRadixString(36)}-${_nonce()}';

  Map<String, Object?> _selfInfo() => {
    'id': _selfId,
    'name': _selfName,
    'address': _selfAddress,
    'port': _selfPort,
    'version': _selfVersion,
  };

  Map<String, Object?> _peerOf(IntercomKiosk k) => {
    'id': k.id,
    'name': k.name,
    'address': k.address,
    'port': k.port,
    'version': k.version,
  };

  // ── HTTP ───────────────────────────────────────────────────────────

  Future<http.Response?> _get(
    String url, {
    Duration? timeout,
    String? token,
  }) async {
    final client = clientFactory();
    try {
      return await client
          .get(
            Uri.parse(url),
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(timeout ?? requestTimeout);
    } catch (e) {
      log.debug(name, 'GET $url: $e');
      return null;
    } finally {
      client.close();
    }
  }

  Future<http.Response?> _post(
    String url,
    Map<String, Object?> body, {
    required String token,
  }) async {
    final client = clientFactory();
    try {
      return await client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
    } catch (e) {
      log.debug(name, 'POST $url: $e');
      return null;
    } finally {
      client.close();
    }
  }

  static Map<String, Object?>? _jsonOf(http.Response? res) {
    if (res == null) return null;
    try {
      final decoded = jsonDecode(res.body);
      return decoded is Map ? decoded.cast<String, Object?>() : null;
    } catch (_) {
      return null;
    }
  }
}

/// PCM16 payload of a 16 kHz mono WAV, or null when it is anything else.
/// The wake word harness has the same reader.
Uint8List? _wavPcm16k(Uint8List wav) {
  if (wav.length < 12) return null;
  final bd = ByteData.sublistView(wav);
  if (String.fromCharCodes(wav.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(wav.sublist(8, 12)) != 'WAVE') {
    return null;
  }
  var off = 12;
  var ok = false;
  while (off + 8 <= wav.length) {
    final id = String.fromCharCodes(wav.sublist(off, off + 4));
    final size = bd.getUint32(off + 4, Endian.little);
    final body = off + 8;
    if (id == 'fmt ' && body + 16 <= wav.length) {
      final format = bd.getUint16(body, Endian.little);
      final channels = bd.getUint16(body + 2, Endian.little);
      final rate = bd.getUint32(body + 4, Endian.little);
      final bits = bd.getUint16(body + 14, Endian.little);
      ok = format == 1 && channels == 1 && rate == 16000 && bits == 16;
    } else if (id == 'data') {
      if (!ok) return null;
      final end = body + size > wav.length ? wav.length : body + size;
      return Uint8List.sublistView(wav, body, end & ~1);
    }
    off = body + size + (size & 1);
  }
  return null;
}
