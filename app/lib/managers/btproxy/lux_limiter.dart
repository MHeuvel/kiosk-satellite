import 'dart:async';
import 'dart:math';

/// Rate limits the Ambient light entity for the Home Assistant recorder
/// (issue #521).
///
/// The native damper drops flicker and holds readings to one every 2
/// seconds, which is what adaptive brightness needs, and each reading it
/// sent used to become a recorder row. A driver that flaps between two
/// far-apart values clears the damper's deadband every time and wrote a row
/// every 2 seconds, all day. A plain time window would stop that at the
/// price of every real change: the damper sends a transition as a leading
/// reading and the settled value up to 2 seconds later, and an automation
/// triggering on a threshold must see the settled value at once.
///
/// So the limit is a token bucket. A publish spends one token, the bucket
/// holds [capacity] and refills one every [refill]. A real transition costs
/// two and passes untouched. A stream that empties the bucket is held, and
/// the latest reading goes out when the next token arrives, so the entity
/// still settles on the truth: a flapping driver collapses to one row per
/// [refill]. A reading equal to the one on the wire is never republished
/// and drops whatever was held, since the wire already tells the truth.
class LuxLimiter {
  LuxLimiter(this._publish, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final void Function(int lux) _publish;
  final DateTime Function() _now;

  static const capacity = 4;
  static const refill = Duration(seconds: 30);

  double _tokens = capacity.toDouble();
  DateTime? _refilledAt;
  int? _latest;
  int? _published;
  Timer? _pending;

  /// The newest reading offered, published or still held.
  int? get latest => _latest;

  /// The reading last handed to the publisher.
  int? get published => _published;

  /// A reading from the sensor, or the current value at registration.
  void offer(int lux) {
    _latest = lux;
    if (lux == _published) {
      _pending?.cancel();
      _pending = null;
      return;
    }
    // A held publish already carries whatever is latest when it fires.
    if (_pending != null) return;
    final now = _now();
    _refillTo(now);
    if (_tokens >= 1) {
      _emit(lux);
      return;
    }
    final wait = Duration(
      microseconds: ((1 - _tokens) * refill.inMicroseconds).ceil(),
    );
    _pending = Timer(wait, _flush);
  }

  void _flush() {
    _pending = null;
    _refillTo(_now());
    final lux = _latest;
    if (lux == null || lux == _published) return;
    _emit(lux);
  }

  void _emit(int lux) {
    // The timer fires when the token is due; rounding never withholds it.
    _tokens = max(0, _tokens - 1);
    _published = lux;
    _publish(lux);
  }

  void _refillTo(DateTime now) {
    final since = _refilledAt;
    _refilledAt = now;
    if (since == null) return;
    final earned = now.difference(since).inMicroseconds / refill.inMicroseconds;
    _tokens = min(capacity.toDouble(), _tokens + earned);
  }

  /// A new registration: the next reading is a first and the bucket is
  /// full again.
  void reset() {
    _pending?.cancel();
    _pending = null;
    _tokens = capacity.toDouble();
    _refilledAt = null;
    _latest = null;
    _published = null;
  }
}
