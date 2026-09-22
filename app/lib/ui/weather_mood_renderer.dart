import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'weather_mood_particles.dart';
import 'weather_mood_scene.dart';

class WeatherMoodRenderer extends StatefulWidget {
  const WeatherMoodRenderer({
    super.key,
    required this.condition,
    required this.night,
    required this.lightning,
    required this.active,
    required this.lowPower,
    this.immediate = false,
    this.onError,
  });
  final String condition;
  final bool night, lightning, active, lowPower, immediate;
  final void Function(Object error)? onError;

  @override
  State<WeatherMoodRenderer> createState() => _WeatherMoodRendererState();
}

class _Programs {
  _Programs(this.sky, this.clouds, this.noise);
  final ui.FragmentProgram sky, clouds;
  final ui.Image noise;
  static final _cache = <bool, Future<_Programs>>{};
  static Future<_Programs> load(bool lowPower) =>
      _cache.putIfAbsent(lowPower, () async {
        try {
          final sky = await ui.FragmentProgram.fromAsset(
            'shaders/weather_mood_sky.frag',
          );
          final clouds = await ui.FragmentProgram.fromAsset(
            lowPower
                ? 'shaders/weather_mood_clouds_low.frag'
                : 'shaders/weather_mood_clouds.frag',
          );
          return _Programs(sky, clouds, await _noise());
        } catch (_) {
          _cache.remove(lowPower);
          rethrow;
        }
      });
  static Future<ui.Image> _noise() async {
    final values = Uint8List(256 * 256), pixels = Uint8List(256 * 256 * 4);
    var seed = 71;
    for (var i = 0; i < values.length; i++) {
      seed = (seed * 1664525 + 1013904223) & 0xffffffff;
      values[i] = seed >> 24;
    }
    for (var y = 0; y < 256; y++) {
      for (var x = 0; x < 256; x++) {
        final i = (y * 256 + x) * 4;
        pixels[i] = values[y * 256 + x];
        pixels[i + 1] = values[((y + 17) % 256) * 256 + (x + 37) % 256];
        pixels[i + 3] = 255;
      }
    }
    final result = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      256,
      256,
      ui.PixelFormat.rgba8888,
      result.complete,
    );
    return result.future;
  }
}

class _WeatherMoodRendererState extends State<WeatherMoodRenderer> {
  final _scene = WeatherMoodScene();
  final _repaint = ValueNotifier<int>(0);
  final _particles = WeatherMoodParticles();
  final _clock = Stopwatch()..start();
  late final _quality = WeatherMoodQuality(lowPower: widget.lowPower);
  ui.FragmentShader? _skyShader, _cloudShader;
  ui.Image? _cloudImage;
  ui.Image? _skyImage;
  _Frame? _skyFrame;
  _Frame? _frame;
  Timer? _timer;
  Size _size = Size.zero;
  bool _loading = true;
  bool _ready = false,
      _busy = false,
      _failed = false,
      _reducedMotion = false,
      _requested = false;
  double? _lastTime;
  double _pixelRatio = 1;
  double _lastCloudTime = double.negativeInfinity;
  int _cloudRevision = -1;
  int _revision = 0;
  int _diagnosticFrames = 0;
  int _diagnosticClouds = 0;
  double _diagnosticTime = 0;

  @override
  void initState() {
    super.initState();
    _update(immediate: true);
    SchedulerBinding.instance.addTimingsCallback(_timings);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final programs = await _Programs.load(widget.lowPower);
      if (!mounted) return;
      _skyShader = programs.sky.fragmentShader()
        ..setImageSampler(0, programs.noise, filterQuality: FilterQuality.low);
      _cloudShader = programs.clouds.fragmentShader()
        ..setImageSampler(0, programs.noise, filterQuality: FilterQuality.low);
      await _particles.load();
      if (!mounted) {
        _release();
        return;
      }
      _ready = true;
      _request();
    } catch (error) {
      if (mounted) {
        _fail(error);
      } else {
        _release();
      }
    } finally {
      _loading = false;
      if (!mounted) _release();
    }
  }

  bool get _animate => widget.active && !_reducedMotion;

  void _timings(List<FrameTiming> timings) {
    if (!_animate || !_ready || _failed) return;
    for (final timing in timings) {
      _quality.recordFrame(timing.totalSpan);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (_pixelRatio != pixelRatio) {
      _pixelRatio = pixelRatio;
      _revision++;
      _request();
    }
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      _lastTime = null;
      _request();
    }
  }

  @override
  void didUpdateWidget(WeatherMoodRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition ||
        oldWidget.night != widget.night ||
        oldWidget.lightning != widget.lightning ||
        oldWidget.immediate != widget.immediate) {
      _update(immediate: widget.immediate || !_animate);
    }
    if (oldWidget.active != widget.active) {
      _lastTime = null;
      _revision++;
    }
    _request();
  }

  void _update({required bool immediate}) {
    _scene.update(
      condition: widget.condition,
      night: widget.night,
      lightning: widget.lightning,
      immediate: immediate,
    );
    _revision++;
  }

  void _request() {
    _timer?.cancel();
    _timer = null;
    _requested = true;
    if (!_ready || _busy || _failed || !mounted || _size.isEmpty) return;
    // A paused renderer can paint changed settings once without running a loop.
    _timer = Timer(Duration.zero, () => unawaited(_render()));
  }

  Future<void> _render() async {
    if (_busy || !mounted || !_ready || _size.isEmpty || _failed) return;
    _requested = false;
    _busy = true;
    final revision = _revision, size = _size;
    final started = _clock.elapsed;
    final now = started.inMicroseconds / 1000000;
    if (_animate && _lastTime != null) _scene.advance(now - _lastTime!);
    _lastTime = _animate ? now : null;
    final frame = _Frame(
      [..._scene.values],
      _scene.time,
      _scene.windTime,
      _scene.lightning,
    );
    ui.Image? image, skyImage;
    try {
      final skySize = Size(
        (size.width * _pixelRatio).ceilToDouble(),
        (size.height * _pixelRatio).ceilToDouble(),
      );
      // The sky barely changes between particle frames. Keep its full-size
      // GPU image on slower devices instead of shading every pixel again.
      if (widget.lowPower &&
          (_skyImage == null ||
              _skyImage!.width != skySize.width ||
              _skyImage!.height != skySize.height ||
              frame.skyChangedSince(_skyFrame!))) {
        skyImage = _shaderImage(_skyShader!, frame, skySize);
      }
      final scale = math.min(
        1.0,
        math.min(_quality.width / size.width, _quality.height / size.height),
      );
      final width = math.max(1, (size.width * scale).round()),
          height = math.max(1, (size.height * scale).round());
      // Clouds drift slowly enough to reuse their image between particle
      // frames. Settings and size changes still take effect immediately.
      final redrawClouds =
          !widget.lowPower ||
          _cloudImage == null ||
          revision != _cloudRevision ||
          _cloudImage!.width != width ||
          _cloudImage!.height != height ||
          now - _lastCloudTime >= 1 / _quality.cloudFps;
      if (redrawClouds) {
        image = _shaderImage(
          _cloudShader!,
          frame,
          Size(width.toDouble(), height.toDouble()),
          includeFlash: !widget.lowPower,
        );
      }
      if (!mounted || revision != _revision || size != _size) {
        image?.dispose();
        image = null;
        skyImage?.dispose();
        skyImage = null;
        return;
      }
      if (skyImage != null) {
        _skyImage?.dispose();
        _skyImage = skyImage;
        skyImage = null;
        _skyFrame = frame;
      }
      if (image != null) {
        final previous = _cloudImage;
        _cloudImage = image;
        image = null;
        _lastCloudTime = now;
        _cloudRevision = revision;
        previous?.dispose();
        if (const bool.fromEnvironment('WEATHER_MOOD_DIAGNOSTICS')) {
          _diagnosticClouds++;
        }
      }
      _frame = frame;
      _repaint.value++;
      await SchedulerBinding.instance.endOfFrame;
      if (const bool.fromEnvironment('WEATHER_MOOD_DIAGNOSTICS')) {
        _diagnosticFrames++;
        if (now - _diagnosticTime >= 15) {
          debugPrint(
            'WeatherMoodNative fps=${(_diagnosticFrames / (now - _diagnosticTime)).toStringAsFixed(1)} cloudFps=${(_diagnosticClouds / (now - _diagnosticTime)).toStringAsFixed(1)} clouds=${width}x$height scale=${_quality.scale} steps=${_quality.steps}',
          );
          _diagnosticTime = now;
          _diagnosticFrames = 0;
          _diagnosticClouds = 0;
        }
      }
    } catch (error) {
      image?.dispose();
      skyImage?.dispose();
      if (mounted) _fail(error);
    } finally {
      _busy = false;
      if (!mounted) {
        _release();
      } else if (!_failed && (_animate || _requested)) {
        final spent = (_clock.elapsed - started).inMicroseconds;
        final wait = math.max(0, (1000000 / _quality.fps).round() - spent);
        _timer = Timer(
          Duration(microseconds: wait),
          () => unawaited(_render()),
        );
      }
    }
  }

  ui.Image _shaderImage(
    ui.FragmentShader shader,
    _Frame frame,
    Size size, {
    bool includeFlash = true,
  }) {
    final recorder = ui.PictureRecorder();
    frame.configure(shader, size, includeFlash: includeFlash);
    Canvas(recorder).drawRect(Offset.zero & size, Paint()..shader = shader);
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(size.width.ceil(), size.height.ceil());
    } finally {
      picture.dispose();
    }
  }

  void _fail(Object error) {
    _failed = true;
    _timer?.cancel();
    widget.onError?.call(error);
    setState(() {});
  }

  void _release() {
    _skyShader?.dispose();
    _skyShader = null;
    _cloudShader?.dispose();
    _cloudShader = null;
    _cloudImage?.dispose();
    _cloudImage = null;
    _skyImage?.dispose();
    _skyImage = null;
    _particles.dispose();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    _clock.stop();
    _repaint.dispose();
    // A pending picture owns its shader until rasterization finishes.
    if (!_busy && !_loading) _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (size.isFinite && size != _size) {
            _size = size;
            _revision++;
            _request();
          }
          return CustomPaint(
            size: size,
            painter: _WeatherPainter(this, _repaint),
          );
        },
      ),
    ),
  );
}

class _Frame {
  _Frame(this.values, this.time, this.windTime, this.lightning);
  final List<double> values;
  final double time, windTime;
  final WeatherMoodLightning lightning;
  bool skyChangedSince(_Frame previous) {
    for (final i in [0, 1, 2, 4, 9]) {
      if ((values[i] - previous.values[i]).abs() > .002) return true;
    }
    // Only the daytime sun's subtle warmth depends on time.
    return values[1] < .999 && time - previous.time >= 1;
  }

  void configure(
    ui.FragmentShader shader,
    Size size, {
    bool includeFlash = true,
  }) {
    final uniforms = [
      size.width,
      size.height,
      time,
      ...values.take(4),
      values[4],
      ...values.skip(5),
      windTime,
      includeFlash ? lightning.strength : 0.0,
      lightning.x,
      1 - (lightning.y + .20),
    ];
    for (var i = 0; i < uniforms.length; i++) {
      shader.setFloat(i, uniforms[i]);
    }
  }
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.owner, Listenable repaint) : super(repaint: repaint);
  final _WeatherMoodRendererState owner;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final frame = owner._frame,
        sky = owner._skyShader,
        cloud = owner._cloudImage;
    if (frame == null || sky == null || owner._failed) {
      canvas.drawColor(const Color(0xFF151820), BlendMode.src);
      return;
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final skyImage = owner._skyImage;
    if (skyImage != null) {
      canvas.drawImageRect(
        skyImage,
        Rect.fromLTWH(
          0,
          0,
          skyImage.width.toDouble(),
          skyImage.height.toDouble(),
        ),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low,
      );
    } else {
      frame.configure(sky, size);
      canvas.drawRect(Offset.zero & size, Paint()..shader = sky);
    }
    owner._particles.paintStars(canvas, size, frame.values[1], frame.time);
    if (cloud != null) {
      canvas.drawImageRect(
        cloud,
        Rect.fromLTWH(0, 0, cloud.width.toDouble(), cloud.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low,
      );
    }
    if (owner.widget.lowPower && frame.lightning.strength > .001) {
      // Lightning illuminates every animation frame even when clouds are
      // cached. These stops follow the cloud shader's Gaussian glow.
      final strength = frame.lightning.strength;
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(
              frame.lightning.x * size.width,
              (frame.lightning.y + .20) * size.height,
            ),
            3 * math.sqrt(.42) * size.height,
            List.generate(13, (i) {
              final distance = i / 12 * 3;
              return const Color(0xFF8C9EFF).withValues(
                alpha: strength * (.035 + .60 * math.exp(-distance * distance)),
              );
            }),
            List.generate(13, (i) => i / 12),
          ),
      );
    }
    owner._particles.paint(
      canvas,
      size,
      frame.values,
      frame.time,
      frame.windTime,
      frame.lightning,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WeatherPainter oldDelegate) => true;
}
