import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kiosk_satellite/core/app_locales.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings.dart';
import 'package:kiosk_satellite/l10n/generated/ui_strings_en.dart';
import 'package:kiosk_satellite/ui/token_qr_scanner.dart';

class _Spanish extends UiStringsEn {
  @override
  String get setupQrTitle => 'Escanea el código QR del token';
  @override
  String get setupQrHelp =>
      'Aparece junto a un token recién creado en tu perfil de Home Assistant.';
  @override
  String get setupQrCameraFailed => 'No se pudo iniciar la cámara.';
  @override
  String get setupQrFlashOff => 'Apagar la linterna';
  @override
  String get setupQrFlashOn => 'Encender la linterna';
  @override
  String get commonCancel => 'Cancelar';
}

class _Delegate extends LocalizationsDelegate<UiStrings> {
  const _Delegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<UiStrings> load(Locale locale) => SynchronousFuture(
    locale.languageCode == 'es' ? _Spanish() : UiStringsEn(),
  );
  @override
  bool shouldReload(_Delegate old) => false;
}

class _Scanner extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  final torch = StreamController<TorchState>.broadcast();
  var starts = 0;
  var toggles = 0;
  var failed = false;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => torch.stream;
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    expect(options.formats, [BarcodeFormat.qrCode]);
    if (failed) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(320, 600),
    );
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> toggleTorch() async {
    toggles++;
    torch.add(TorchState.on);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Scanner scanner;
  late ValueNotifier<Locale> language;
  setUp(() {
    scanner = _Scanner();
    MobileScannerPlatform.instance = scanner;
    language = ValueNotifier(const Locale('es'));
  });
  tearDown(() async {
    language.dispose();
    await scanner.captures.close();
    await scanner.torch.close();
  });
  Future<void> show(WidgetTester tester, void Function(String?) result) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: language,
        builder: (context, locale, _) => MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: const [
            _Delegate(),
            ...appLocalizationsDelegates,
          ],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result(
                  await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (_) => const TokenQrScanner()),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'scanner translates without restarting capture or altering token',
    (tester) async {
      String? result;
      var returns = 0;
      await show(tester, (value) {
        result = value;
        returns++;
      });
      expect(find.text('Escanea el código QR del token'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Encender la linterna'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Apagar la linterna'), findsOneWidget);
      expect(scanner.toggles, 1);
      language.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Turn off the flashlight'), findsOneWidget);
      language.value = const Locale('es');
      await tester.pumpAndSettle();
      expect(scanner.starts, 1);
      scanner.captures.add(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '  Raw.Token+KeepCase  '),
            Barcode(rawValue: 'second'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(result, 'Raw.Token+KeepCase');
      expect(returns, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('camera failure and cancel remain usable in Spanish', (
    tester,
  ) async {
    scanner.failed = true;
    var returned = false;
    await show(tester, (value) {
      expect(value, isNull);
      returned = true;
    });
    expect(find.text('No se pudo iniciar la cámara.'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
