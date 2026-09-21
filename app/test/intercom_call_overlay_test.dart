import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/events.dart';
import 'package:kiosk_satellite/ui/intercom_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [
    const Size(320, 480),
    const Size(360, 640),
    const Size(640, 360),
    const Size(240, 427),
    const Size(1280, 800),
  ]) {
    for (final broadcast in [false, true]) {
      testWidgets('push to talk and hangup stay reachable at $size '
          '(broadcast: $broadcast)', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        final container = AppContainer();
        await container.settings.init();
        addTearDown(container.settings.dispose);
        final commands = <(String, Map<String, Object?>)>[];
        for (final name in ['intercomTalk', 'intercomHangup']) {
          container.commands.register(
            Command(
              name: name,
              description: 'Record overlay actions',
              handler: (params) async {
                commands.add((name, Map.of(params)));
                return const CommandResult.ok();
              },
            ),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: IntercomCallOverlay(container: container)),
          ),
        );
        container.bus.publish(
          IntercomStateChanged({
            'state': broadcast ? 'broadcasting' : 'in_call',
            'talkMode': 'ptt',
            'micGranted': true,
            'call': {
              'kind': broadcast ? 'broadcast' : 'call',
              'outgoing': true,
              'peer': {
                'id': 'kitchen',
                'name': 'Kitchen and dining room kiosk',
              },
              'since': DateTime.now().millisecondsSinceEpoch,
              'targets': [
                for (var i = 0; i < 12; i++)
                  {
                    'name': 'Kitchen and dining room kiosk $i',
                    'status': 'listening',
                  },
              ],
            },
          }),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final talk = find.text('Hold to talk');
        final end = find.byIcon(broadcast ? Icons.close : Icons.call_end);
        final endButton = find.ancestor(
          of: end,
          matching: find.byType(InkWell),
        );
        final screen = Offset.zero & size;
        expect(screen.contains(tester.getRect(endButton).topLeft), isTrue);
        expect(screen.contains(tester.getRect(endButton).bottomRight), isTrue);
        expect(end.hitTestable(), findsOneWidget);
        final talkButton = find.ancestor(
          of: talk,
          matching: find.byType(AnimatedContainer),
        );
        // End sits under the pill, except on a short screen where it sits
        // beside it.
        final talkRect = tester.getRect(talkButton);
        final endRect = tester.getRect(endButton);
        if (size.height < 480) {
          expect(endRect.left, greaterThan(talkRect.right));
          expect(endRect.center.dy, closeTo(talkRect.center.dy, 3));
        } else {
          expect(endRect.top, greaterThan(talkRect.bottom));
          expect((endRect.center.dx - talkRect.center.dx).abs(), lessThan(1));
        }
        final press = await tester.startGesture(tester.getCenter(talk));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(commands.last.$1, 'intercomTalk');
        expect(commands.last.$2, {'on': true});
        expect(end.hitTestable(), findsOneWidget);
        await press.up();
        await tester.pump();
        expect(commands.last.$1, 'intercomTalk');
        expect(commands.last.$2, {'on': false});
        await tester.tap(end);
        await tester.pump();
        expect(commands.last.$1, 'intercomHangup');
        expect(commands.last.$2, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
