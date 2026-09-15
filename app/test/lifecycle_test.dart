import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/lifecycle.dart';

/// Where the app stands on screen (issue #560): Android reports resumed
/// only once the Activity's window holds the input focus, so a return
/// under a focus-holding window stops at inactive and must still count.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('off screen is hidden, paused or detached; nothing yet is on', () {
    expect(Lifecycle.offScreen(AppLifecycleState.hidden), isTrue);
    expect(Lifecycle.offScreen(AppLifecycleState.paused), isTrue);
    expect(Lifecycle.offScreen(AppLifecycleState.detached), isTrue);
    expect(Lifecycle.offScreen(AppLifecycleState.inactive), isFalse);
    expect(Lifecycle.offScreen(AppLifecycleState.resumed), isFalse);
    expect(Lifecycle.offScreen(null), isFalse);
  });

  test('every resumed is a return; an inactive only after a pause', () {
    final watch = ReturnWatch();
    // On the way out inactive comes first and is not a return.
    expect(watch.returned(AppLifecycleState.inactive), isFalse);
    expect(watch.returned(AppLifecycleState.hidden), isFalse);
    expect(watch.returned(AppLifecycleState.paused), isFalse);
    expect(watch.off, isTrue);
    // Back without the input focus: hidden, then inactive, and there it
    // stays. The inactive is the return.
    expect(watch.returned(AppLifecycleState.hidden), isFalse);
    expect(watch.returned(AppLifecycleState.inactive), isTrue);
    expect(watch.off, isFalse);
    // The focus arriving later reads as a return as well; consumers are
    // idempotent and used to run on every resumed already.
    expect(watch.returned(AppLifecycleState.resumed), isTrue);
    // A dialog flicker never left the screen: only its resumed counts.
    expect(watch.returned(AppLifecycleState.inactive), isFalse);
    expect(watch.returned(AppLifecycleState.resumed), isTrue);
    // A return with focus, the ordinary way.
    expect(watch.returned(AppLifecycleState.paused), isFalse);
    expect(watch.returned(AppLifecycleState.resumed), isTrue);
    expect(watch.off, isFalse);
  });

  test('onScreen follows the last state the binding reported', () {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(Lifecycle.onScreen, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(Lifecycle.onScreen, isTrue);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(Lifecycle.onScreen, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(Lifecycle.onScreen, isTrue);
  });
}
