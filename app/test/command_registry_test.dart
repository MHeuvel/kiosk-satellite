import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/logging.dart';

void main() {
  // The app log ends up pasted into public issues, and a realtime API key
  // logged with its command was revoked by OpenAI minutes later (#804).
  group('command log', () {
    late Logger log;
    late CommandRegistry registry;
    Map<String, Object?>? received;

    setUp(() {
      log = Logger();
      registry = CommandRegistry(log).as('remote admin');
      received = null;
      registry.register(
        Command(
          name: 'saveKey',
          description: 'test',
          secretParams: const {'apiKey'},
          handler: (p) async {
            received = p;
            return const CommandResult.ok();
          },
        ),
      );
    });

    test(
      'redacts secret params but hands the handler the real value',
      () async {
        await registry.execute('saveKey', {
          'provider': 'openai',
          'apiKey': 'sk-proj-secret',
        });
        final line = log.recent.single.message;
        expect(line, isNot(contains('sk-proj-secret')));
        expect(line, contains('apiKey: <redacted>'));
        expect(line, contains('provider: openai'));
        expect(line, endsWith('[remote admin]'));
        expect(received!['apiKey'], 'sk-proj-secret');
      },
    );

    test('leaves a missing secret param out of the redaction', () async {
      await registry.execute('saveKey', {'provider': 'openai'});
      expect(log.recent.single.message, isNot(contains('apiKey')));
    });
  });
}
