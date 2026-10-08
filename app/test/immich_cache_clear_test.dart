import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/event_bus.dart';
import 'package:kiosk_satellite/core/logging.dart';
import 'package:kiosk_satellite/managers/screensaver/immich_manager.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart' as defs;
import 'package:kiosk_satellite/managers/settings/settings_manager.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SupportPath extends PathProviderPlatform {
  _SupportPath(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

/// Turning the local Immich cache off deletes the copies it kept, and a
/// start with the cache already off deletes copies left from before
/// (issue #895).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late Directory cache;
  late SettingsManager settings;
  late PathProviderPlatform oldPaths;

  Future<void> build({required bool caching}) async {
    SharedPreferences.setMockInitialValues({
      'ks.screensaver.immich_cache': caching,
    });
    final bus = EventBus();
    final log = Logger();
    final commands = CommandRegistry(log);
    settings = SettingsManager(bus, commands, log);
    await settings.init();
    await ImmichManager(bus, commands, log, settings).init();
    await pumpEventQueue();
  }

  setUp(() async {
    support = await Directory.systemTemp.createTemp('immich_cache_test');
    cache = Directory('${support.path}/immich_cache');
    await cache.create();
    await File('${cache.path}/a.img').writeAsBytes([1, 2, 3]);
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SupportPath(support.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = oldPaths;
    await support.delete(recursive: true);
  });

  test('turning the cache off deletes the cached items', () async {
    await build(caching: true);
    expect(await cache.exists(), true);

    await settings.set(defs.screensaverImmichCache, false);
    await pumpEventQueue();

    expect(await cache.exists(), false);
  });

  test('a start with the cache off deletes leftover items', () async {
    await build(caching: false);

    expect(await cache.exists(), false);
  });

  test('a start with the cache on keeps the cached items', () async {
    await build(caching: true);

    expect(await File('${cache.path}/a.img').exists(), true);
  });
}
