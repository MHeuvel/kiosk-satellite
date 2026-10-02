import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/logging.dart';

/// How much recent audio [wakeEnergy] reads: the wake word plus the quiet
/// before it, which is where the noise floor comes from.
const wakeEnergyWindow = Duration(seconds: 3);

/// How loud the wake word reached this kiosk, in dB over its own noise floor.
///
/// The loudest 200 ms of the last 1.5 seconds (the wake word, whichever
/// engine fired and however late) against the quietest fifth of the whole
/// window. Measuring against the floor rather than full scale takes the
/// microphone gain out of it: a kiosk with a hot mic hears the room louder
/// too. The floor is clamped so audio a noise suppressor has silenced
/// cannot claim an endless margin. Null when there is too little audio.
double? wakeEnergy(Uint8List pcm) {
  const frame = 320; // 20 ms at 16 kHz
  final samples = ByteData.sublistView(pcm);
  final count = pcm.length ~/ 2 ~/ frame;
  if (count < 10) return null;
  final levels = List<double>.filled(count, 0);
  for (var f = 0; f < count; f++) {
    var sum = 0.0;
    for (var i = 0; i < frame; i++) {
      final s = samples.getInt16((f * frame + i) * 2, Endian.little) / 32768;
      sum += s * s;
    }
    final rms = math.sqrt(sum / frame);
    levels[f] = rms > 0 ? 20 * math.log(rms) / math.ln10 : -120;
  }
  final recent = levels.sublist(math.max(0, count - 75))
    ..sort((a, b) => b.compareTo(a));
  final loud = recent.take(10).toList();
  final speech = loud.reduce((a, b) => a + b) / loud.length;
  final sorted = [...levels]..sort();
  final floor = math.max(sorted[(sorted.length * 0.2).floor()], -75.0);
  return speech - floor;
}

/// What the arbitration decided for one wake.
class ArbitrationResult {
  const ArbitrationResult({
    required this.won,
    required this.rivals,
    this.winner,
    this.winnerEnergy,
    this.heard = const [],
  });

  final bool won;

  /// How many other kiosks claimed the same wake word in the window.
  final int rivals;

  /// The address of the kiosk that beat this one, when it lost.
  final String? winner;
  final double? winnerEnergy;

  /// Each rival claim for the log, with when it arrived against this
  /// kiosk's own: how far apart the kiosks detect is what sets the window.
  final List<String> heard;
}

/// Carries claims between kiosks. UDP broadcast on the real network;
/// tests hand in a loopback.
abstract class ArbitrationTransport {
  /// Start receiving. False when the port cannot be opened.
  Future<bool> open(void Function(Uint8List data, String from) onPacket);
  void send(Uint8List data);
  Future<void> close();
}

/// One datagram to the whole subnet per claim, on a port of its own: no
/// roster, no pairing and nothing else on the kiosk has to be turned on.
class UdpArbitrationTransport implements ArbitrationTransport {
  UdpArbitrationTransport({this.port = WakeArbiter.port});

  final int port;
  RawDatagramSocket? _socket;
  static final _broadcast = InternetAddress('255.255.255.255');

  @override
  Future<bool> open(void Function(Uint8List data, String from) onPacket) async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final d = socket.receive();
      if (d != null) onPacket(d.data, d.address.address);
    });
    _socket = socket;
    return true;
  }

  @override
  void send(Uint8List data) => _socket?.send(data, _broadcast, port);

  @override
  Future<void> close() async {
    _socket?.close();
    _socket = null;
  }
}

class _Claim {
  _Claim(this.id, this.phrase, this.energy, this.from, this.at);
  final String id;
  final String phrase;
  final double energy;
  final String from;
  final int at;
}

/// Settles which kiosk answers a wake word several of them heard.
///
/// Every kiosk that detects the wake word broadcasts a claim (the phrase and
/// [wakeEnergy]) and holds the wake for the window. Claims for the same
/// phrase that arrive within the window either side of its own detection
/// compete: the highest energy wins and the lower id breaks an exact tie.
/// Both kiosks see both claims, so both reach the same answer without a
/// second round. A claim that never arrives leaves both answering, which is
/// how it worked before.
class WakeArbiter {
  WakeArbiter(this._log, {ArbitrationTransport? transport, String? id})
    : _transport = transport ?? UdpArbitrationTransport(),
      id = id ?? _randomId();

  static const port = 2330;
  static const _tag = 'wake_arbitration';

  /// Claims are older than any window after this.
  static const _keepMs = 2000;

  final Logger _log;
  final ArbitrationTransport _transport;

  /// Random per run: only needs to be the same on both sides of a tie.
  final String id;

  final _clock = Stopwatch()..start();
  final _heard = <String, _Claim>{};
  final _random = math.Random();
  bool _running = false;

  bool get running => _running;

  static String _randomId() {
    final r = math.Random.secure();
    return List.generate(
      8,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> start() async {
    if (_running) return;
    try {
      _running = await _transport.open(_onPacket);
      _log.info(_tag, 'listening on UDP $port');
    } catch (e) {
      _log.warn(_tag, 'cannot listen on UDP $port: $e');
    }
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _heard.clear();
    await _transport.close();
    _log.info(_tag, 'stopped');
  }

  static String _normalize(String phrase) =>
      phrase.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Rounded so both sides compare the very numbers that went on the wire.
  static double _round(double energy) => (energy * 10).round() / 10;

  void _prune() {
    final now = _clock.elapsedMilliseconds;
    _heard.removeWhere((_, c) => now - c.at > _keepMs);
  }

  void _onPacket(Uint8List data, String from) {
    if (!_running) return;
    Object? msg;
    try {
      msg = jsonDecode(utf8.decode(data));
    } catch (_) {
      return;
    }
    if (msg is! Map ||
        msg['ks'] != 'wake' ||
        msg['v'] != 1 ||
        msg['id'] is! String ||
        msg['p'] is! String ||
        msg['e'] is! num ||
        msg['n'] is! int) {
      return;
    }
    final claimId = msg['id'] as String;
    final phrase = msg['p'] as String;
    final energy = (msg['e'] as num).toDouble();
    if (claimId == id || claimId.length > 64 || !energy.isFinite) return;
    _prune();
    // Each claim goes out more than once; the first copy sets the time.
    _heard.putIfAbsent(
      '$claimId:${msg['n']}',
      () => _Claim(
        claimId,
        _normalize(phrase),
        _round(energy),
        from,
        _clock.elapsedMilliseconds,
      ),
    );
  }

  /// Claim this wake and wait out [window]. Won when no other kiosk heard
  /// the same phrase louder.
  Future<ArbitrationResult> contend({
    required String phrase,
    required double energy,
    required Duration window,
  }) async {
    if (!_running) return const ArbitrationResult(won: true, rivals: 0);
    final mine = _normalize(phrase);
    final level = _round(energy);
    final packet = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'ks': 'wake',
          'v': 1,
          'id': id,
          'n': _random.nextInt(1 << 30),
          'p': mine,
          'e': level,
        }),
      ),
    );
    final at = _clock.elapsedMilliseconds;
    // Broadcast is never acknowledged, so the claim goes out three times.
    _transport.send(packet);
    for (final delay in const [15, 30]) {
      Timer(Duration(milliseconds: delay), () {
        if (_running) _transport.send(packet);
      });
    }
    await Future<void>.delayed(window);
    final span = window.inMilliseconds;
    final rivals = [
      for (final c in _heard.values)
        if (c.phrase == mine && (c.at - at).abs() <= span) c,
    ];
    _prune();
    _Claim? best;
    for (final c in rivals) {
      if (best == null ||
          c.energy > best.energy ||
          (c.energy == best.energy && c.id.compareTo(best.id) < 0)) {
        best = c;
      }
    }
    final won =
        best == null ||
        level > best.energy ||
        (level == best.energy && id.compareTo(best.id) < 0);
    return ArbitrationResult(
      won: won,
      rivals: rivals.length,
      winner: won ? null : best.from,
      winnerEnergy: won ? null : best.energy,
      heard: [
        for (final c in rivals)
          '${c.from} ${c.energy} dB at '
              '${c.at >= at ? '+' : ''}${c.at - at} ms',
      ],
    );
  }
}
