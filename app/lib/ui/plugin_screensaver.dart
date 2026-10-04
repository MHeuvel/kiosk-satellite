import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../app_container.dart';
import '../core/events.dart';
import 'package:kiosk_satellite/core/lifecycle.dart';
import '../managers/settings/definitions.dart' as defs;

/// An isolated rendering document. All input and screensaver policy stays in KS.
String pluginScreensaverDocument(String html) =>
    '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; media-src data: blob:; frame-src about:; connect-src 'none'; form-action 'none'; base-uri 'none'">
<style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#000}iframe{position:absolute;top:0;left:0;border:0;width:100%;height:100%;pointer-events:none}</style></head>
<body><iframe sandbox="allow-scripts" srcdoc="${const HtmlEscape(HtmlEscapeMode.attribute).convert(html)}"></iframe>
<script>
// A new publication loads in a hidden frame and only replaces the shown one
// once it has painted, so a slideshow never drops to black between photos.
let current = document.querySelector('iframe'), pending;
window.ksUpdateDocument = function(html) {
  if (pending) pending.remove();
  const next = document.createElement('iframe');
  next.setAttribute('sandbox', 'allow-scripts');
  next.style.opacity = '0';
  pending = next;
  next.onload = function() {
    requestAnimationFrame(() => requestAnimationFrame(() => {
      if (pending !== next) return;
      next.style.opacity = '1';
      current.remove();
      current = next;
      pending = null;
    }));
  };
  next.srcdoc = html;
  document.body.appendChild(next);
};
</script></body></html>''';

/// Configuration travels in the fragment, never in the local asset request path.
Uri? pluginScreensaverAssetUrl(Map<String, Object?> renderer) {
  final entry = renderer['entry'] as String?;
  final origin = renderer['assetOrigin'] as String?;
  if (entry == null || origin == null) return null;
  return Uri.parse(origin)
      .resolve('/assets/$entry')
      .replace(fragment: renderer['dataJson'] as String? ?? '{}');
}

class PluginScreensaver extends StatelessWidget {
  const PluginScreensaver({
    super.key,
    required this.container,
    required this.mode,
  });
  final AppContainer container;
  final String mode;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, Map<String, Object?>>>(
        valueListenable: container.plugins.screensavers,
        builder: (context, renderers, _) {
          final renderer = renderers[mode];
          if (renderer == null) return const ColoredBox(color: Colors.black);
          return _Document(
            // Inline HTML updates load into the live WebView. Anything else
            // that changes the document's origin or options rebuilds it.
            key: ValueKey((
              mode,
              renderer['entry'],
              renderer['assetOrigin'],
              renderer['assetDirectory'],
              renderer['dataJson'],
            )),
            container: container,
            renderer: renderer,
          );
        },
      );
}

class _Document extends StatefulWidget {
  const _Document({super.key, required this.container, required this.renderer});
  final AppContainer container;
  final Map<String, Object?> renderer;
  @override
  State<_Document> createState() => _DocumentState();
}

class _DocumentState extends State<_Document> with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  StreamSubscription<ScreenStateChanged>? _screen;
  StreamSubscription<SettingChanged>? _settings;
  Timer? _shift;
  Offset _offset = Offset.zero;
  bool _screenOn = true;
  bool _foreground = true;
  bool _failed = false;
  bool _loaded = false;
  String? _html;

  @override
  void initState() {
    super.initState();
    _html = widget.renderer['html'] as String?;
    WidgetsBinding.instance.addObserver(this);
    _foreground = Lifecycle.onScreen;
    // Paused under the native voice overlay too, which shows a still of the
    // screensaver.
    widget.container.screensaver.renderPaused.addListener(_renderPaused);
    _screen = widget.container.bus.on<ScreenStateChanged>().listen((e) {
      _screenOn = e.on;
      unawaited(_activity());
    });
    _settings = widget.container.bus.on<SettingChanged>().listen((e) {
      if (e.key == defs.screensaverPixelShift.key &&
          !widget.container.settings.get(defs.screensaverPixelShift) &&
          mounted) {
        setState(() => _offset = Offset.zero);
      }
    });
    _shift = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted ||
          !_foreground ||
          !_screenOn ||
          !widget.container.settings.get(defs.screensaverPixelShift)) {
        return;
      }
      final max = min(24.0, MediaQuery.sizeOf(context).width * .015);
      final random = Random();
      setState(
        () => _offset = Offset(
          (random.nextDouble() * 2 - 1) * max,
          (random.nextDouble() * 2 - 1) * max,
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant _Document oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new publication brings back a renderer that crashed, since the key no
    // longer changes for inline updates.
    if (_failed && widget.renderer['html'] != oldWidget.renderer['html']) {
      _failed = false;
      _loaded = false;
      _controller = null;
      _html = widget.renderer['html'] as String?;
      return;
    }
    unawaited(_updateDocument());
  }

  /// Hands newer inline HTML to the loaded page. Anything that arrives before
  /// the first load finishes is sent from onLoadStop.
  Future<void> _updateDocument() async {
    final html = widget.renderer['html'] as String?;
    if (!_loaded || html == null || html == _html) return;
    _html = html;
    try {
      await _controller?.evaluateJavascript(
        source: 'window.ksUpdateDocument(${jsonEncode(html)});',
      );
    } catch (e) {
      // Retry with the next publication.
      _html = null;
      widget.container.log.warn('plugins', 'Screensaver update failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = !Lifecycle.offScreen(state);
    unawaited(_activity());
  }

  void _renderPaused() => unawaited(_activity());

  Future<void> _activity() async {
    try {
      if (_foreground &&
          _screenOn &&
          !widget.container.screensaver.renderPaused.value) {
        await _controller?.resume();
      } else {
        await _controller?.pause();
      }
    } catch (_) {
      // The renderer may already be disposed during a mode or session change.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.container.screensaver.renderPaused.removeListener(_renderPaused);
    _screen?.cancel();
    _settings?.cancel();
    _shift?.cancel();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetUrl = pluginScreensaverAssetUrl(widget.renderer);
    return ColoredBox(
      color: Colors.black,
      child: _failed
          ? const SizedBox.expand()
          : ClipRect(
              child: Transform.translate(
                offset: _offset,
                child: IgnorePointer(
                  child: InAppWebView(
                    initialUrlRequest: assetUrl == null
                        ? null
                        : URLRequest(url: WebUri.uri(assetUrl)),
                    initialData: assetUrl != null
                        ? null
                        : InAppWebViewInitialData(
                            data: pluginScreensaverDocument(
                              widget.renderer['html'] as String,
                            ),
                          ),
                    initialSettings: InAppWebViewSettings(
                      webViewAssetLoader: assetUrl == null
                          ? null
                          : WebViewAssetLoader(
                              domain: assetUrl.host,
                              httpAllowed: false,
                              pathHandlers: [
                                InternalStoragePathHandler(
                                  path: '/assets/',
                                  directory:
                                      widget.renderer['assetDirectory']
                                          as String,
                                ),
                              ],
                            ),
                      javaScriptEnabled: true,
                      javaScriptBridgeEnabled: false,
                      blockNetworkLoads: true,
                      allowFileAccess: false,
                      allowContentAccess: false,
                      allowFileAccessFromFileURLs: false,
                      allowUniversalAccessFromFileURLs: false,
                      domStorageEnabled: false,
                      supportZoom: false,
                      disableDefaultErrorPage: true,
                      useShouldOverrideUrlLoading: true,
                      mediaPlaybackRequiresUserGesture: true,
                    ),
                    shouldOverrideUrlLoading: (_, action) async =>
                        (assetUrl == null
                            ? const [
                                'about:blank',
                                'about:srcdoc',
                              ].contains(action.request.url.toString())
                            : action.request.url?.origin == assetUrl.origin &&
                                  action.request.url?.path == assetUrl.path)
                        ? NavigationActionPolicy.ALLOW
                        : NavigationActionPolicy.CANCEL,
                    onPermissionRequest: (_, request) async =>
                        PermissionResponse(
                          resources: request.resources,
                          action: PermissionResponseAction.DENY,
                        ),
                    onCreateWindow: (_, action) async => false,
                    onWebViewCreated: (controller) {
                      _controller = controller;
                      unawaited(_activity());
                    },
                    onLoadStop: (_, _) {
                      _loaded = true;
                      unawaited(_updateDocument());
                    },
                    onRenderProcessGone: (_, detail) {
                      if (mounted) setState(() => _failed = true);
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
