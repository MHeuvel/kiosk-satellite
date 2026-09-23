/// Confirms a finger count using fresh camera readings, never a delayed action.
class HandGestureHold {
  // The camera normally reports every 250 ms. Allow two missed readings.
  static const maxGap = Duration(milliseconds: 750);

  int? count;
  Duration? _since;
  Duration? _lastSeen;
  double progress = 0;

  void reset() {
    count = null;
    _since = null;
    _lastSeen = null;
    progress = 0;
  }

  /// Returns true only on a matching reading that completes the hold.
  /// Unknown readings briefly preserve the candidate but cannot confirm it.
  bool update({
    required int hands,
    required int? fingers,
    required Duration now,
    required Duration hold,
  }) {
    if (hold > Duration.zero &&
        _lastSeen != null &&
        now - _lastSeen! > maxGap) {
      reset();
    }
    if (hands == 0 || fingers == 0) {
      reset();
      return false;
    }
    if (fingers == null || fingers < 0) {
      if (hold == Duration.zero) reset();
      return false;
    }
    if (count != fingers) {
      reset();
      count = fingers;
      _since = now;
    }
    _lastSeen = now;
    progress = hold == Duration.zero
        ? 1
        : ((now - _since!).inMicroseconds / hold.inMicroseconds).clamp(0, 1);
    return progress == 1;
  }
}
