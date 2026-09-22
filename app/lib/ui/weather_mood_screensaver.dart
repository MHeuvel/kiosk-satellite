import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../app_container.dart';
import '../core/events.dart';
import '../core/lifecycle.dart';
import '../l10n/messages.dart';
import '../managers/home_assistant/home_assistant_manager.dart'
    show GlanceSubscription;
import '../managers/settings/definitions.dart' as defs;
import '../managers/settings/settings_manager.dart';

/// The sun entity takes precedence over a weather provider's day/night label.
bool weatherMoodNight(String? sun, DateTime localTime) => switch (sun) {
  'above_horizon' => false,
  'below_horizon' => true,
  _ => localTime.hour < 6 || localTime.hour >= 18,
};

bool weatherMoodHasScene(SettingsManager settings) =>
    settings.get(defs.screensaverWeatherPreview) ||
    settings.get(defs.screensaverWeatherEntity).trim().isNotEmpty;

({String condition, bool night}) weatherMoodScene(
  SettingsManager settings,
  String condition,
  String? sun,
  DateTime localTime,
) => settings.get(defs.screensaverWeatherPreview)
    ? (
        condition: settings.get(defs.screensaverWeatherPreviewCondition),
        night: settings.get(defs.screensaverWeatherPreviewPeriod) == 'night',
      )
    : (condition: condition, night: weatherMoodNight(sun, localTime));

const weatherMoodConditions = {
  'sunny',
  'clear-night',
  'partlycloudy',
  'cloudy',
  'rainy',
  'pouring',
  'snowy',
  'snowy-rainy',
  'fog',
  'hail',
  'lightning',
  'lightning-rainy',
  'windy',
  'windy-variant',
  'exceptional',
};

/// An offline rendering document. Only weather states cross into JavaScript.
String weatherMoodDocument(String script, {bool lowPower = false}) =>
    '''<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'none'">
<style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:linear-gradient(#445366,#9da8b2)}canvas{position:absolute;inset:0;width:100%;height:100%;pointer-events:none}</style>
</head><body><canvas id="scene"></canvas><canvas id="particles"></canvas>
<script>window.__weatherMoodLowPower=$lowPower;
$script</script></body></html>''';

class WeatherMoodScreensaver extends StatefulWidget {
  const WeatherMoodScreensaver({super.key, required this.container});
  final AppContainer container;

  @override
  State<WeatherMoodScreensaver> createState() => _WeatherMoodScreensaverState();
}

class _WeatherMoodScreensaverState extends State<WeatherMoodScreensaver>
    with WidgetsBindingObserver {
  static final _script = rootBundle.loadString(
    'assets/screensaver/weather-mood.js',
  );
  InAppWebViewController? _controller;
  GlanceSubscription? _live;
  StreamSubscription<SettingChanged>? _settings;
  StreamSubscription<ScreenStateChanged>? _screen;
  Timer? _retry;
  Timer? _clock;
  int _generation = 0;
  String _condition = 'exceptional';
  String? _sun;
  bool _screenOn = true;
  bool _foreground = true;
  bool _loaded = false;
  bool _rendererFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = Lifecycle.onScreen;
    _screenOn = widget.container.screen.isScreenOn;
    _screen = widget.container.bus.on<ScreenStateChanged>().listen((event) {
      _screenOn = event.on;
      unawaited(_activity());
    });
    _settings = widget.container.bus.on<SettingChanged>().listen((event) {
      if (event.key == defs.screensaverWeatherEntity.key ||
          event.key == defs.haUrl.key ||
          event.key == defs.haToken.key) {
        if (event.key == defs.screensaverWeatherEntity.key) {
          if (!weatherMoodHasScene(widget.container.settings)) {
            _controller = null;
            _loaded = false;
          }
          setState(() {});
        }
        unawaited(_subscribe(reset: true));
      } else if (event.key == defs.screensaverWeatherPreview.key) {
        if (!weatherMoodHasScene(widget.container.settings)) {
          _controller = null;
          _loaded = false;
        }
        setState(() {});
        unawaited(_update(immediate: true));
      } else if (event.key == defs.screensaverWeatherPreviewCondition.key ||
          event.key == defs.screensaverWeatherPreviewPeriod.key) {
        unawaited(_update(immediate: true));
      } else if (event.key == defs.screensaverWeatherLightning.key) {
        unawaited(_update());
      }
    });
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_update()),
    );
    unawaited(_subscribe());
  }

  Future<void> _subscribe({bool reset = false}) async {
    final generation = ++_generation;
    _retry?.cancel();
    final previous = _live;
    _live = null;
    await previous?.close();
    if (!mounted || generation != _generation) return;
    if (reset) {
      _condition = 'exceptional';
      _sun = null;
      unawaited(_update());
    }
    final entity = widget.container.settings
        .get(defs.screensaverWeatherEntity)
        .trim();
    if (entity.isEmpty) return;
    final live = await widget.container.homeAssistant.subscribeEntities(
      [if (entity.startsWith('weather.')) entity, 'sun.sun'],
      (id, state) {
        if (!mounted || generation != _generation) return;
        final value = state['state'];
        if (id == 'sun.sun') {
          if (value is String) _sun = value;
        } else if (id == entity && weatherMoodConditions.contains(value)) {
          _condition = value as String;
        }
        unawaited(_update());
      },
    );
    if (!mounted || generation != _generation) {
      await live?.close();
      return;
    }
    _live = live;
    void retry() {
      if (!mounted || generation != _generation) return;
      _sun = null;
      unawaited(_update());
      _retry?.cancel();
      _retry = Timer(
        const Duration(seconds: 10),
        () => unawaited(_subscribe()),
      );
    }

    if (live == null || live.isClosed) {
      retry();
    } else {
      live.onClosed = retry;
    }
  }

  Future<void> _update({bool immediate = false}) async {
    if (!_loaded) return;
    final scene = weatherMoodScene(
      widget.container.settings,
      _condition,
      _sun,
      DateTime.now(),
    );
    final data = jsonEncode({
      'condition': scene.condition,
      'night': scene.night,
      'lightning': widget.container.settings.get(
        defs.screensaverWeatherLightning,
      ),
      'immediate': immediate,
    });
    try {
      await _controller?.evaluateJavascript(
        source: 'window.weatherMood?.update($data)',
      );
    } catch (_) {
      // A dismissed WebView can finish a pending state update after disposal.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = !Lifecycle.offScreen(state);
    unawaited(_activity());
  }

  Future<void> _activity() async {
    final active = _screenOn && _foreground;
    try {
      if (active) await _controller?.resume();
      if (_loaded) {
        await _controller?.evaluateJavascript(
          source: 'window.weatherMood?.setActive($active)',
        );
      }
      if (!active) await _controller?.pause();
    } catch (_) {
      // The platform view may have been removed during the lifecycle change.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _settings?.cancel();
    _screen?.cancel();
    _retry?.cancel();
    _clock?.cancel();
    unawaited(_live?.close());
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!weatherMoodHasScene(widget.container.settings)) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                screensaverText(
                  context,
                  'Select a weather entity in Settings > Screensaver > Weather Mood.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),
        ),
      );
    }
    if (_rendererFailed) {
      return const ColoredBox(color: Color(0xFF151820));
    }
    return FutureBuilder<String>(
      future: _script,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(color: Color(0xFF445366));
        }
        return IgnorePointer(
          child: InAppWebView(
            initialData: InAppWebViewInitialData(
              data: weatherMoodDocument(
                snapshot.data!,
                lowPower:
                    widget.container.device.abis.isNotEmpty &&
                    !widget.container.device.abis.any(
                      (abi) => abi.contains('64'),
                    ),
              ),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              javaScriptBridgeEnabled: false,
              blockNetworkLoads: true,
              allowFileAccess: false,
              allowContentAccess: false,
              domStorageEnabled: false,
              supportZoom: false,
              disableDefaultErrorPage: true,
            ),
            onWebViewCreated: (controller) => _controller = controller,
            onRenderProcessGone: (_, detail) {
              _controller = null;
              _loaded = false;
              widget.container.log.warn(
                'screensaver',
                'Weather Mood renderer stopped (crashed: ${detail.didCrash})',
              );
              if (mounted) setState(() => _rendererFailed = true);
            },
            onLoadStart: (_, _) => _loaded = false,
            onLoadStop: (_, _) async {
              _loaded = true;
              await _update(immediate: true);
              await _activity();
            },
          ),
        );
      },
    );
  }
}
