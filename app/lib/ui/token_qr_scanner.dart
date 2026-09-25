import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'theme.dart';
import '../l10n/messages.dart';

/// Full-screen scanner for the QR code Home Assistant shows next to a newly
/// created long-lived access token, so the token never has to be typed on
/// the device. Pops with the decoded text on the first hit, or null when
/// closed. Only reachable from the setup wizard, and only on devices with a
/// camera; the remote admin's wizard keeps paste, where it belongs.
class TokenQrScanner extends StatefulWidget {
  const TokenQrScanner({super.key});

  @override
  State<TokenQrScanner> createState() => _TokenQrScannerState();
}

class _TokenQrScannerState extends State<TokenQrScanner> {
  final _controller = MobileScannerController(
    facing: CameraFacing.front,
    formats: const [BarcodeFormat.qrCode],
  );

  /// A capture can carry several frames' worth of hits; pop exactly once.
  bool _done = false;
  bool _switching = false;
  bool _initialCamera = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCameraChanged);
  }

  void _onCameraChanged() {
    if (!_initialCamera) return;
    final state = _controller.value;
    if (state.isRunning) {
      _initialCamera = false;
    } else if (state.error?.errorCode == MobileScannerErrorCode.unsupported) {
      // A device with only a rear camera must still be able to scan.
      _initialCamera = false;
      scheduleMicrotask(() {
        if (mounted && !_done) {
          unawaited(_controller.start(cameraDirection: CameraFacing.back));
        }
      });
    }
  }

  Future<void> _flipCamera() async {
    if (_switching || _done || !_controller.value.isRunning) return;
    setState(() => _switching = true);
    try {
      await _controller.switchCamera();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onCameraChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _done = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n(context).setupQrCameraFailed,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Viewfinder: a rounded frame in the middle, the copy above and
          // below it, everything readable over any camera image.
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 3),
                borderRadius: BorderRadius.circular(Ks.radiusCard),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text(
                    l10n(context).setupQrTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: Ks.displayFont,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n(context).setupQrHelp,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 16,
                    children: [
                      _RoundAction(
                        icon: Icons.close,
                        tooltip: l10n(context).commonCancel,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (context, state, _) => _RoundAction(
                          icon: Icons.flip_camera_android_outlined,
                          tooltip: l10n(context).setupQrFlipCamera,
                          onTap:
                              state.isRunning &&
                                  !_switching &&
                                  (state.availableCameras == null ||
                                      state.availableCameras! > 1) &&
                                  (state.cameraDirection ==
                                          CameraFacing.front ||
                                      state.cameraDirection ==
                                          CameraFacing.back)
                              ? _flipCamera
                              : null,
                        ),
                      ),
                      ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (context, state, _) => _RoundAction(
                          icon: state.torchState == TorchState.on
                              ? Icons.flashlight_off_outlined
                              : Icons.flashlight_on_outlined,
                          tooltip: state.torchState == TorchState.on
                              ? l10n(context).setupQrFlashOff
                              : l10n(context).setupQrFlashOn,
                          onTap:
                              state.isRunning &&
                                  !_switching &&
                                  state.torchState != TorchState.unavailable
                              ? _controller.toggleTorch
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The scanner's round dark action button, legible over the camera image.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black54,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: IconButton(
      iconSize: 26,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      disabledColor: Colors.white38,
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onTap,
    ),
  );
}
