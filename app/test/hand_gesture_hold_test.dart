import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/gestures/hand_gesture_hold.dart';

void main() {
  late HandGestureHold hold;
  setUp(() => hold = HandGestureHold());

  bool read(int ms, {int hands = 1, int? fingers = 5, int duration = 1000}) =>
      hold.update(
        hands: hands,
        fingers: fingers,
        now: Duration(milliseconds: ms),
        hold: Duration(milliseconds: duration),
      );

  test('Instant confirms the first reading', () {
    expect(read(0, duration: 0), isTrue);
    expect(hold.progress, 1);
  });

  test('a steady count confirms only when fresh readings span the hold', () {
    for (final ms in [0, 250, 500, 750, 999]) {
      expect(read(ms), isFalse);
    }
    expect(read(1000), isTrue);
    expect(hold.progress, 1);
  });

  test('a passing hand cannot complete a hold when it returns later', () {
    expect(read(0), isFalse);
    expect(read(2000), isFalse);
    expect(hold.progress, 0);
    expect(read(2500), isFalse);
    expect(read(3000), isTrue);
  });

  test('brief unknown readings preserve the hold but cannot confirm it', () {
    read(0);
    read(500);
    expect(read(750, fingers: null), isFalse);
    expect(read(1000, fingers: null), isFalse);
    expect(hold.progress, 0.5);
    expect(read(1100), isTrue);
  });

  test('unknown readings do not extend the grace period', () {
    read(0);
    read(500);
    read(1000, fingers: null);
    expect(read(1300, fingers: null), isFalse);
    expect(hold.count, isNull);
    expect(read(1500), isFalse);
    expect(hold.progress, 0);
  });

  test('changing the count starts a separate hold', () {
    read(0);
    read(500);
    expect(read(750, fingers: 2), isFalse);
    expect(read(1250, fingers: 2), isFalse);
    expect(read(1750, fingers: 2), isTrue);
  });

  test('removing the hand or lowering every finger cancels the hold', () {
    for (final fingers in [null, 0]) {
      hold.reset();
      read(0);
      read(500);
      read(600, hands: fingers == null ? 0 : 1, fingers: fingers);
      expect(hold.progress, 0);
      expect(read(750), isFalse);
      expect(read(1250), isFalse);
      expect(read(1750), isTrue);
    }
  });
}
