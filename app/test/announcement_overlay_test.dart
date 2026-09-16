import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/ui/intercom_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'audio only hides the announcement while playing and after it ends',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = AppContainer();
      await container.settings.init();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                IntercomCallOverlay(container: container),
                AnnouncementOverlay(container: container),
              ],
            ),
          ),
        ),
      );

      for (final audioOnly in [true, false]) {
        for (final state in ['listening', 'ended']) {
          container.bus.publish(
            IntercomStateChanged({
              'state': state,
              'call': {
                'automated': true,
                'outgoing': false,
                'audioOnly': audioOnly,
                'message': 'Dinner is ready',
              },
            }),
          );
          await tester.pump();
          expect(
            find.text('Dinner is ready'),
            audioOnly ? findsNothing : findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byType(AnnouncementOverlay),
              matching: find.byType(ModalBarrier),
            ),
            audioOnly ? findsNothing : findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byType(IntercomCallOverlay),
              matching: find.byType(ModalBarrier),
            ),
            findsNothing,
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await container.settings.dispose();
    },
  );
}
