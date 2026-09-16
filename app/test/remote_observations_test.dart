import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/remote/observations.dart';

void main() {
  testWidgets(
    'one observer serves all viewers and stops with the last subscription',
    (tester) async {
      final log = Logger();
      final commands = CommandRegistry(log);
      var reads = 0;
      var clients = 1;
      commands.register(
        Command(
          name: 'getRtspStatus',
          description: '',
          handler: (_) async {
            reads++;
            return CommandResult.ok({
              'clients': clients,
              'clientDetails': [
                {'connectedSeconds': reads},
              ],
            });
          },
        ),
      );
      final updates = <Map<String, Object?>>[];
      final observations = RemoteObservations(
        commands,
        (_, results) => updates.add(results),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(reads, 0);
      observations.observe({'rtsp'});
      observations.observe({'rtsp'});
      await tester.pump();
      expect(reads, 1);
      expect(updates.length, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(reads, 2);
      expect(
        updates.length,
        1,
        reason: 'elapsed time alone is not a state change',
      );
      clients = 2;
      await tester.pump(const Duration(seconds: 2));
      expect(updates.length, 2);
      observations.observe({});
      await tester.pump(const Duration(seconds: 20));
      expect(reads, 3);
      observations.dispose();
      await log.dispose();
    },
  );

  testWidgets('advertisement counters and log lines are not a change', (
    tester,
  ) async {
    final log = Logger();
    final commands = CommandRegistry(log);
    var received = 100;
    var running = true;
    commands.register(
      Command(
        name: 'bluetoothAdapterOn',
        description: '',
        handler: (_) async => const CommandResult.ok({'on': true}),
      ),
    );
    commands.register(
      Command(
        name: 'esphomeStatus',
        description: '',
        handler: (_) async {
          received += 50;
          return CommandResult.ok({
            'running': running,
            'received': received,
            'forwarded': received ~/ 2,
            'lastAdvertisementAt': received * 1000,
            'log': ['line $received'],
          });
        },
      ),
    );
    final updates = <Map<String, Object?>>[];
    final observations = RemoteObservations(
      commands,
      (_, results) => updates.add(results),
    );
    observations.observe({'bluetooth'});
    await tester.pump();
    expect(updates.length, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(updates.length, 1, reason: 'beacons flowing is not a change');
    running = false;
    await tester.pump(const Duration(seconds: 5));
    expect(updates.length, 2);
    // The results still carry the counters for whoever shows them.
    final esp = (updates.last['esphomeStatus'] as Map)['data'] as Map;
    expect(esp['received'], greaterThan(100));
    observations.dispose();
    await log.dispose();
  });
}
