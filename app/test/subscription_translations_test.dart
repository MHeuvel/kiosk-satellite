import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/home_assistant/home_assistant_manager.dart';
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Weather condition labels come from Home Assistant over the entity
/// subscription's own socket. A failed lookup used to be cached as an
/// English server, and the widget then read "Rainy" instead of "Pluvieux"
/// until the app restarted (issue #900).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A Home Assistant stand-in speaking [language]. While [failing] says
  /// so, it rejects the config lookup. [asked] records the commands.
  Future<(HttpServer, HomeAssistantManager)> start(
    String language,
    List<String> asked, {
    bool Function()? failing,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add(jsonEncode({'type': 'auth_required'}));
      socket.listen((raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        final type = '${msg['type']}';
        if (type == 'auth') {
          socket.add(jsonEncode({'type': 'auth_ok'}));
          return;
        }
        asked.add(type);
        Map<String, Object?> result(Object? value) => {
          'id': msg['id'],
          'type': 'result',
          'success': true,
          'result': value,
        };
        switch (type) {
          case 'subscribe_entities':
            socket.add(jsonEncode(result(null)));
          case 'get_config':
            if (failing?.call() ?? false) {
              socket.add(
                jsonEncode({
                  'id': msg['id'],
                  'type': 'result',
                  'success': false,
                  'error': {'code': 'unknown_error'},
                }),
              );
            } else {
              socket.add(jsonEncode(result({'language': language})));
            }
          case 'frontend/get_translations':
            socket.add(
              jsonEncode(
                result({
                  'resources': {
                    'component.weather.entity_component._.state.rainy':
                        'Pluvieux',
                  },
                }),
              ),
            );
        }
      });
    });
    SharedPreferences.setMockInitialValues({
      'ks.ha.url': 'http://127.0.0.1:${server.port}',
      'ks.ha.token': 'token',
    });
    final bus = EventBus();
    final log = Logger();
    final settings = SettingsManager(bus, CommandRegistry(log), log);
    await settings.init();
    return (
      server,
      HomeAssistantManager(bus, CommandRegistry(log), log, settings),
    );
  }

  Future<Map<String, String>> translations(HomeAssistantManager ha) async {
    final got = Completer<Map<String, String>>();
    final live = await ha.subscribeEntities(
      ['weather.home'],
      (_, _) {},
      translationDomain: 'weather',
      onTranslations: got.complete,
    );
    addTearDown(() => live?.close());
    return got.future.timeout(const Duration(seconds: 2));
  }

  test('a French server sends its wording over the subscription', () async {
    final asked = <String>[];
    final (server, ha) = await start('fr', asked);
    addTearDown(() => server.close(force: true));
    expect(await translations(ha), {'rainy': 'Pluvieux'});
    // The second subscription reads the cache instead of asking again.
    expect(await translations(ha), {'rainy': 'Pluvieux'});
    expect(asked.where((t) => t == 'frontend/get_translations').length, 1);
  });

  test('an English server answers empty without a lookup', () async {
    final asked = <String>[];
    final (server, ha) = await start('en-GB', asked);
    addTearDown(() => server.close(force: true));
    expect(await translations(ha), isEmpty);
    expect(asked, isNot(contains('frontend/get_translations')));
  });

  test('a failed lookup is not cached as English', () async {
    final asked = <String>[];
    var failing = true;
    final (server, ha) = await start('fr', asked, failing: () => failing);
    addTearDown(() => server.close(force: true));
    await expectLater(translations(ha), throwsA(isA<TimeoutException>()));
    // The next connection, such as the owner's reopen, asks again.
    failing = false;
    expect(await translations(ha), {'rainy': 'Pluvieux'});
  });
}
