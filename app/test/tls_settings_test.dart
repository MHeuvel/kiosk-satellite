import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/core/command_registry.dart';
import 'package:kiosk_satellite/core/tls_identity.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/managers/settings/definitions.dart';
import 'package:kiosk_satellite/ui/settings_screen.dart';
import 'package:kiosk_satellite/ui/theme.dart';
import 'package:kiosk_satellite/ui/kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('encryption switches belong to their feature pages', () {
    expect(remoteTls.category, 'Device');
    expect(remoteTls.subpage, 'Remote Administration');
    expect(cameraRtspTls.category, 'Camera');
    expect(cameraRtspTls.subpage, 'RTSP & ONVIF Streaming');
    expect(intercomTls.category, 'Intercom');
    expect(intercomTls.section, 'TLS');
    expect(cameraRtspTls.section, 'TLS');
    expect(allSettings.indexOf(remoteTls), allSettings.indexOf(remotePort) + 1);
    for (final def in [remoteTls, cameraRtspTls, intercomTls]) {
      expect(def.perDevice, true);
    }
    expect(allSettings.where((d) => d.subpage == 'TLS'), isEmpty);
  });

  for (final initial in [false, true]) {
    testWidgets(
      'protocol confirmation can cancel or confirm from HTTPS=$initial',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'ks.remote.tls': initial,
          'ks.remote.port': 3456,
        });
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          TlsIdentity.channel,
          (_) async => {
            'certificate': File(
              'test/fixtures/tls/cert.pem',
            ).readAsStringSync(),
            'privateKey': File('test/fixtures/tls/key.pem').readAsStringSync(),
            'notAfter': DateTime.now()
                .add(const Duration(days: 90))
                .millisecondsSinceEpoch,
            'imported': false,
          },
        );
        addTearDown(
          () => messenger.setMockMethodCallHandler(TlsIdentity.channel, null),
        );
        final container = AppContainer();
        await container.settings.init();
        addTearDown(() async {
          await container.settings.dispose();
          await container.bus.dispose();
          await container.log.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(Brightness.light),
            localizationsDelegates: UiStrings.localizationsDelegates,
            supportedLocales: UiStrings.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => SettingTile(
                  container: container,
                  def: remoteTls,
                  onChanged: () => update(() {}),
                ),
              ),
            ),
          ),
        );
        Future<void> toggle() async {
          await tester.runAsync(() async {
            await tester.tap(find.byType(SwitchListTile));
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
        }

        await toggle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final copy = tester.widget<CopyBox>(find.byType(CopyBox));
        expect(copy.multiline, isTrue);
        final address = copy.value;
        expect(Uri.parse(address).scheme, initial ? 'http' : 'https');
        expect(Uri.parse(address).port, 3456);
        expect(container.settings.get(remoteTls), initial);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(container.settings.get(remoteTls), initial);
        await toggle();
        await tester.runAsync(() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(container.settings.get(remoteTls), !initial);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  for (final locale in UiStrings.supportedLocales) {
    final strings = lookupUiStrings(locale);
    for (final brightness in Brightness.values) {
      testWidgets(
        'TLS controls and import dialog fit a narrow $brightness screen in $locale',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues({
            'ks.camera.enabled': true,
            'ks.camera.rtsp.enabled': true,
          });
          final container = AppContainer();
          await container.settings.init();
          container.commands.register(
            Command(
              name: 'importTlsCertificate',
              description: '',
              handler: (_) async => const CommandResult.fail(
                'PlatformException(tls, Certificate and private key do not match., null, null)',
              ),
            ),
          );
          container.commands.register(
            Command(
              name: 'tlsCertificate',
              description: '',
              handler: (_) async => CommandResult.ok({
                'certificate': 'public certificate',
                'fingerprint': 'abcdef01' * 8,
                'expires': '2027-09-23T12:00:00Z',
                'imported': false,
                'expired': false,
              }),
            ),
          );
          addTearDown(() async {
            await container.settings.dispose();
            await container.bus.dispose();
            await container.log.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(brightness),
              locale: locale,
              localizationsDelegates: UiStrings.localizationsDelegates,
              supportedLocales: UiStrings.supportedLocales,
              home: SubpageSettingsScreen(
                container: container,
                category: 'Device',
                subpage: 'TLS',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(strings.tlsCertificateType), findsOneWidget);
          expect(find.textContaining('2027'), findsOneWidget);
          expect(find.text('Trusted kiosks'), findsNothing);
          expect(find.text('Use HTTPS'), findsNothing);
          expect(find.text('Encrypt stream'), findsNothing);
          expect(find.text('Certificate'), findsNothing);
          expect(find.text(strings.tlsCertificateManagement), findsOneWidget);
          expect(
            find.text('HTTPS and encrypted RTSP share this certificate.'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text(strings.tlsImportCertificate));
          await tester.pumpAndSettle();
          await tester.tap(find.text(strings.tlsImportCertificate));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.byType(TextFormField), findsNWidgets(2));
          expect(
            find.widgetWithText(FilledButton, strings.commonImport),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.widgetWithText(FilledButton, strings.commonImport),
          );
          await tester.pumpAndSettle();
          expect(find.text(strings.tlsThisFieldIsRequired), findsNWidgets(2));
          expect(tester.takeException(), isNull);
          await tester.enterText(
            find.byType(TextFormField).at(0),
            'certificate',
          );
          await tester.enterText(
            find.byType(TextFormField).at(1),
            'private key',
          );
          await tester.tap(
            find.widgetWithText(FilledButton, strings.commonImport),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining(strings.tlsKeyMismatch), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.widgetWithText(TextButton, strings.commonCancel),
          );
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
