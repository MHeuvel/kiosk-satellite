import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'weather_mood_renderer.dart';
import 'weather_mood_information.dart';

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

/// Warmth peaks near the horizon and fades into the existing day/night scenes.
double weatherMoodTwilight(
  String? sun,
  DateTime localTime, {
  double? elevation,
}) {
  final validSun = sun == 'above_horizon' || sun == 'below_horizon';
  if (validSun &&
      elevation != null &&
      elevation.isFinite &&
      elevation.abs() <= 90) {
    final fade = ((elevation.abs() - 2) / 4).clamp(0.0, 1.0);
    return 1 - fade * fade * (3 - 2 * fade);
  }
  // Without elevation, use one hour around the local 6 AM / 6 PM fallback.
  // A valid sun state still prevents a warm scene in the wrong half of the day.
  final minutes =
      localTime.hour * 60 + localTime.minute + localTime.second / 60;
  final morning = (minutes - 360).abs();
  final evening = (minutes - 1080).abs();
  final distance = morning < evening ? morning : evening;
  if (validSun &&
      weatherMoodNight(sun, localTime) != weatherMoodNight(null, localTime)) {
    return 0;
  }
  final fade = ((distance - 10) / 20).clamp(0.0, 1.0);
  return 1 - fade * fade * (3 - 2 * fade);
}

bool weatherMoodHasScene(SettingsManager settings) =>
    settings.get(defs.screensaverWeatherPreview) ||
    settings.get(defs.screensaverWeatherEntity).trim().isNotEmpty;

({String condition, bool night, double twilight}) weatherMoodScene(
  SettingsManager settings,
  String condition,
  String? sun,
  DateTime localTime, {
  double? elevation,
}) => settings.get(defs.screensaverWeatherPreview)
    ? (
        condition: settings.get(defs.screensaverWeatherPreviewCondition),
        night: settings.get(defs.screensaverWeatherPreviewPeriod) == 'night',
        twilight:
            settings.get(defs.screensaverWeatherPreviewPeriod) == 'twilight'
            ? 1.0
            : 0.0,
      )
    : (
        condition: condition,
        night: weatherMoodNight(sun, localTime),
        twilight: weatherMoodTwilight(sun, localTime, elevation: elevation),
      );

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

class WeatherMoodScreensaver extends StatefulWidget {
  const WeatherMoodScreensaver({super.key, required this.container});
  final AppContainer container;

  @override
  State<WeatherMoodScreensaver> createState() => _WeatherMoodScreensaverState();
}

class _WeatherMoodScreensaverState extends State<WeatherMoodScreensaver>
    with WidgetsBindingObserver {
  GlanceSubscription? _live;
  StreamSubscription<SettingChanged>? _settings;
  StreamSubscription<ScreenStateChanged>? _screen;
  Timer? _retry;
  Timer? _clock;
  int _generation = 0;
  String _condition = 'exceptional';
  String? _sun;
  double? _sunElevation;
  WeatherMoodReadings _readings = WeatherMoodReadings();
  Map<String, String> _translations = const {};
  bool _screenOn = true;
  bool _foreground = true;
  bool _immediate = false;

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
          setState(() {});
        }
        unawaited(_subscribe(reset: true));
      } else if (event.key == defs.screensaverWeatherPreview.key) {
        setState(() {});
        unawaited(_update(immediate: true));
      } else if (event.key == defs.screensaverWeatherPreviewCondition.key ||
          event.key == defs.screensaverWeatherPreviewPeriod.key) {
        unawaited(_update(immediate: true));
      } else if (event.key == defs.screensaverWeatherLightning.key) {
        unawaited(_update());
      } else if (event.key.startsWith('screensaver.weather_') ||
          event.key.startsWith('screensaver.glance_')) {
        if (event.key == defs.screensaverWeatherBar.key) {
          unawaited(_loadTranslations());
        }
        setState(() {});
      }
    });
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_update()),
    );
    unawaited(_subscribe());
    unawaited(_loadTranslations());
  }

  Future<void> _loadTranslations() async {
    if (!widget.container.settings.get(defs.screensaverWeatherBar)) return;
    final translations = await widget.container.homeAssistant.stateTranslations(
      'weather',
    );
    if (mounted) setState(() => _translations = translations);
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
      _sunElevation = null;
      _readings = WeatherMoodReadings();
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
          final attrs = state['attributes'];
          if (_sun != 'above_horizon' && _sun != 'below_horizon') {
            _sunElevation = null;
          } else if (attrs is Map && attrs.containsKey('elevation')) {
            final elevation = attrs['elevation'];
            _sunElevation = elevation is num && elevation.isFinite
                ? elevation.toDouble()
                : null;
          }
        } else if (id == entity) {
          _readings.update(state);
          if (weatherMoodConditions.contains(value)) {
            _condition = value as String;
          }
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
      _sunElevation = null;
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
    if (!mounted) return;
    setState(() => _immediate = immediate);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = !Lifecycle.offScreen(state);
    unawaited(_activity());
  }

  Future<void> _activity() async {
    if (mounted) setState(() {});
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
    final scene = weatherMoodScene(
      widget.container.settings,
      _condition,
      _sun,
      DateTime.now(),
      elevation: _sunElevation,
    );
    final blur = widget.container.settings
        .get(defs.screensaverWeatherBlur)
        .toDouble()
        .clamp(0.0, 30.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: ImageFiltered(
            enabled: blur > 0,
            imageFilter: ui.ImageFilter.blur(
              sigmaX: blur,
              sigmaY: blur,
              tileMode: TileMode.clamp,
            ),
            child: WeatherMoodRenderer(
              condition: scene.condition,
              night: scene.night,
              twilight: scene.twilight,
              lightning: widget.container.settings.get(
                defs.screensaverWeatherLightning,
              ),
              active: _screenOn && _foreground,
              immediate: _immediate,
              lowPower:
                  widget.container.device.abis.isNotEmpty &&
                  !widget.container.device.abis.any(
                    (abi) => abi.contains('64'),
                  ),
              onError: (error) => widget.container.log.warn(
                'screensaver',
                'Weather Mood renderer stopped: $error',
              ),
            ),
          ),
        ),
        WeatherMoodInformation(
          container: widget.container,
          readings: _readings,
          translations: _translations,
        ),
      ],
    );
  }
}
