import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/gestures/gesture_mappings.dart';
import 'package:kiosk_satellite/managers/motion/motion_manager.dart';
import 'package:kiosk_satellite/ui/hand_gesture_tester.dart';

/// The Hand Gesture Tester modal: lights the digits the tracker reads
/// as up, names the count and the gesture it would trigger, and says so
/// when nothing is in view.
void main() {
  final reading = ValueNotifier<HandTestReading?>(null);
  final mappings = decodeGestureMappings(
    '[{"id":"open","trigger":{"type":"fingers","fingers":5},'
    '"action":{"type":"screensaver_stop"}}]',
  );

  Future<void> build(WidgetTester tester) async {
    reading.value = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HandGestureTesterDialog(reading: reading, mappings: mappings),
        ),
      ),
    );
  }

  Color fingerColor(WidgetTester tester, int i) {
    final box = tester.widget<AnimatedContainer>(
      find.byKey(ValueKey('finger-$i')),
    );
    return (box.decoration as BoxDecoration).color!;
  }

  testWidgets('no hand, no digits lit', (tester) async {
    await build(tester);
    expect(find.text('No hand in view'), findsOneWidget);
    expect(find.text('Show a hand to the camera.'), findsOneWidget);
    expect(find.textContaining('do not fire'), findsOneWidget);
    final primary = Theme.of(
      tester.element(find.byType(Dialog)),
    ).colorScheme.primary;
    for (var i = 0; i < 5; i++) {
      expect(fingerColor(tester, i), isNot(primary));
    }
  });

  testWidgets('an open hand lights every digit and names its gesture', (
    tester,
  ) async {
    await build(tester);
    reading.value = const HandTestReading(
      hands: 1,
      fingers: 5,
      fingersUp: [true, true, true, true, true],
    );
    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Show an open hand'), findsOneWidget);
    expect(find.text('Triggers: Stop the screensaver'), findsOneWidget);
    final primary = Theme.of(
      tester.element(find.byType(Dialog)),
    ).colorScheme.primary;
    for (var i = 0; i < 5; i++) {
      expect(fingerColor(tester, i), primary, reason: 'digit $i');
    }
  });

  testWidgets('four fingers leave the thumb dark and report no gesture', (
    tester,
  ) async {
    await build(tester);
    reading.value = const HandTestReading(
      hands: 2,
      fingers: 4,
      fingersUp: [false, true, true, true, true],
    );
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Show 4 fingers'), findsOneWidget);
    expect(find.text('No gesture uses this count.'), findsOneWidget);
    expect(find.textContaining('2 hands in view'), findsOneWidget);
    final primary = Theme.of(
      tester.element(find.byType(Dialog)),
    ).colorScheme.primary;
    expect(fingerColor(tester, 0), isNot(primary));
    expect(fingerColor(tester, 1), primary);
  });

  testWidgets('a closed hand reads zero', (tester) async {
    await build(tester);
    reading.value = const HandTestReading(
      hands: 1,
      fingers: 0,
      fingersUp: [false, false, false, false, false],
    );
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('No fingers up'), findsOneWidget);
    expect(find.text('No gesture uses this count.'), findsNothing);
  });
}
