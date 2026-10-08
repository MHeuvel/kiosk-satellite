import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../managers/plugins/plugin_manager.dart';
import '../l10n/messages.dart';
import 'theme.dart';
import 'ui_scale.dart' show UiScaleExempt;

/// Plugin overlays and floating windows stay below the kiosk drawer and
/// ambient overlays. Windows sit over the native overlays.
class PluginOverlay extends StatelessWidget {
  const PluginOverlay({super.key, required this.plugins});
  final PluginManager plugins;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      PluginNativeOverlays(plugins: plugins),
      ValueListenableBuilder<List<PluginWindow>>(
        valueListenable: plugins.windows,
        builder: (context, windows, _) => LayoutBuilder(
          builder: (context, bounds) => Stack(
            children: [
              for (var i = 0; i < windows.length; i++)
                _FloatingWindow(
                  key: ValueKey(windows[i].id),
                  window: windows[i],
                  plugins: plugins,
                  available: bounds.biggest,
                  index: i,
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// The theme native overlays draw with: the Material 3 color roles plus
/// success, as ARGB, and whether it is dark.
Map<String, Object?> pluginOverlayTheme(ThemeData theme) {
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return {
    'dark': dark,
    'colors': {
      'primary': scheme.primary.toARGB32(),
      'onPrimary': scheme.onPrimary.toARGB32(),
      'primaryContainer': scheme.primaryContainer.toARGB32(),
      'onPrimaryContainer': scheme.onPrimaryContainer.toARGB32(),
      'secondary': scheme.secondary.toARGB32(),
      'onSecondary': scheme.onSecondary.toARGB32(),
      'secondaryContainer': scheme.secondaryContainer.toARGB32(),
      'onSecondaryContainer': scheme.onSecondaryContainer.toARGB32(),
      'tertiary': scheme.tertiary.toARGB32(),
      'onTertiary': scheme.onTertiary.toARGB32(),
      'tertiaryContainer': scheme.tertiaryContainer.toARGB32(),
      'onTertiaryContainer': scheme.onTertiaryContainer.toARGB32(),
      'error': scheme.error.toARGB32(),
      'onError': scheme.onError.toARGB32(),
      'errorContainer': scheme.errorContainer.toARGB32(),
      'onErrorContainer': scheme.onErrorContainer.toARGB32(),
      'surface': scheme.surface.toARGB32(),
      'onSurface': scheme.onSurface.toARGB32(),
      'onSurfaceVariant': scheme.onSurfaceVariant.toARGB32(),
      'surfaceContainerLowest': scheme.surfaceContainerLowest.toARGB32(),
      'surfaceContainerLow': scheme.surfaceContainerLow.toARGB32(),
      'surfaceContainer': scheme.surfaceContainer.toARGB32(),
      'surfaceContainerHigh': scheme.surfaceContainerHigh.toARGB32(),
      'surfaceContainerHighest': scheme.surfaceContainerHighest.toARGB32(),
      'inverseSurface': scheme.inverseSurface.toARGB32(),
      'onInverseSurface': scheme.onInverseSurface.toARGB32(),
      'inversePrimary': scheme.inversePrimary.toARGB32(),
      'outline': scheme.outline.toARGB32(),
      'outlineVariant': scheme.outlineVariant.toARGB32(),
      'shadow': scheme.shadow.toARGB32(),
      'scrim': scheme.scrim.toARGB32(),
      'success': (dark ? ksSage : ksSageOnLight).toARGB32(),
    },
  };
}

/// Native plugin overlays, bottom to top. The kiosk has two of these
/// layers: one in the kiosk plane under the menu and the screensaver, and
/// one in the voice overlay's slot for overlays that asked to be on top.
class PluginNativeOverlays extends StatelessWidget {
  const PluginNativeOverlays({
    super.key,
    required this.plugins,
    this.onTop = false,
  });
  final PluginManager plugins;
  final bool onTop;

  static const viewType = 'kiosk_satellite/plugin_overlay';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: plugins.overlayEpoch,
    builder: (context, epoch, _) =>
        ValueListenableBuilder<List<PluginNativeOverlay>>(
          valueListenable: plugins.overlays,
          builder: (context, overlays, _) {
            final shown = overlays.where((o) => o.onTop == onTop).toList();
            if (shown.isEmpty) return const SizedBox.shrink();
            final theme = plugins.overlayTheme(
              pluginOverlayTheme(Theme.of(context)),
            );
            // Native views draw in physical pixels, so Scale UI leaves them
            // alone the way it leaves the dashboard alone.
            return UiScaleExempt(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final overlay in shown)
                    _NativeOverlay(
                      key: ValueKey('${overlay.id}@$epoch'),
                      overlay: overlay,
                      theme: theme,
                    ),
                ],
              ),
            );
          },
        ),
  );
}

class _NativeOverlay extends StatelessWidget {
  const _NativeOverlay({super.key, required this.overlay, required this.theme});
  final PluginNativeOverlay overlay;
  final Map<String, Object?> theme;

  static Alignment _alignment(String anchor) => switch (anchor) {
    'top-left' => Alignment.topLeft,
    'top' => Alignment.topCenter,
    'top-right' => Alignment.topRight,
    'left' => Alignment.centerLeft,
    'right' => Alignment.centerRight,
    'bottom-left' => Alignment.bottomLeft,
    'bottom' => Alignment.bottomCenter,
    'bottom-right' => Alignment.bottomRight,
    _ => Alignment.center,
  };

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    // Until Android has measured a wrapped view it is laid out at one
    // pixel and kept invisible, so it never flashes at the wrong size.
    final ready = !overlay.wraps || overlay.measured != null;
    return Padding(
      padding: EdgeInsets.all(overlay.inset.toDouble()),
      child: LayoutBuilder(
        builder: (context, bounds) {
          double side(int value, double? measured, double available) =>
              math.max(1, switch (value) {
                PluginNativeOverlay.fill => available,
                PluginNativeOverlay.wrap =>
                  measured == null ? 1 : math.min(measured / ratio, available),
                _ => math.min(value.toDouble(), available),
              });
          return Align(
            alignment: _alignment(overlay.anchor),
            child: SizedBox(
              width: side(
                overlay.width,
                overlay.measured?.width,
                bounds.maxWidth,
              ),
              height: side(
                overlay.height,
                overlay.measured?.height,
                bounds.maxHeight,
              ),
              child: Opacity(
                opacity: ready ? 1 : 0,
                // A visual-only overlay lets every touch through.
                child: IgnorePointer(
                  ignoring: !ready || !overlay.touchable,
                  child: AndroidView(
                    viewType: PluginNativeOverlays.viewType,
                    creationParams: {
                      'id': overlay.pluginId,
                      'session': overlay.session,
                      'key': overlay.key,
                      'generation': overlay.generation,
                      'width': overlay.width,
                      'height': overlay.height,
                      'inset': overlay.inset,
                      'theme': theme,
                    },
                    creationParamsCodec: const StandardMessageCodec(),
                    // Every touch inside the overlay is the plugin's, even
                    // a drag the kiosk's own detectors would otherwise win.
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        EagerGestureRecognizer.new,
                      ),
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FloatingWindow extends StatefulWidget {
  const _FloatingWindow({
    super.key,
    required this.window,
    required this.plugins,
    required this.available,
    required this.index,
  });
  final PluginWindow window;
  final PluginManager plugins;
  final Size available;
  final int index;

  @override
  State<_FloatingWindow> createState() => _FloatingWindowState();
}

class _FloatingWindowState extends State<_FloatingWindow> {
  Offset? _position;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final window = widget.window;
    final width = math.min(360.0, math.max(0.0, widget.available.width - 24));
    final height = math.min(260.0, math.max(0.0, widget.available.height - 24));
    final wanted =
        _position ??
        Offset(
          widget.available.width - width - 20 - widget.index * 24,
          24 + widget.index * 24,
        );
    final position = Offset(
      wanted.dx.clamp(
        12.0,
        math.max(12.0, widget.available.width - width - 12),
      ),
      wanted.dy.clamp(
        12.0,
        math.max(12.0, widget.available.height - height - 12),
      ),
    );
    return Positioned(
      left: position.dx,
      top: position.dy,
      width: width,
      height: height,
      child: Material(
        elevation: 12,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) =>
                  setState(() => _position = position + details.delta),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.drag_indicator, size: 20),
                    ),
                    Expanded(
                      child: Text(
                        window.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n(context).pluginCloseWindow(window.title),
                      icon: const Icon(Icons.close),
                      onPressed: () => unawaited(
                        widget.plugins.windowEvent(window.id, closed: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(window.message),
                ),
              ),
            ),
            if (window.buttonLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await widget.plugins.windowEvent(
                              window.id,
                              closed: false,
                            );
                            if (mounted) setState(() => _busy = false);
                          },
                    child: Text(
                      window.buttonLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
