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
    this.twilight = 0,
    required this.lightning,
    required this.active,
    required this.lowPower,
    this.immediate = false,
    this.revealed = true,
    this.revealToken = 0,
    this.onReady,
    this.onError,
  });
  final String condition;
  final double twilight;
  final bool night, lightning, active, lowPower, immediate;

  /// Whether the scene is on screen yet. Hidden, a finished cloud image
  /// replaces the previous one instead of fading in over it.
  final bool revealed;

  /// Passed back through [onReady], so a caller can tell which change the
  /// finished scene reflects.
  final int revealToken;

  /// Called once the sky and a full cloud image for the latest immediate
  /// change are on screen, with the [revealToken] current at that change.
  final void Function(int token)? onReady;
  final void Function(Object error)? onError;

  @override
  State<WeatherMoodRenderer> createState() => _WeatherMoodRendererState();
}

/// Forgets the loaded shader programs. Each widget test has its own
/// binding, and programs and textures loaded in one are not usable in the
/// next.
@visibleForTesting
void resetWeatherMoodPrograms() => _Programs._cache.clear();

class _Programs {
  _Programs(
    this.sky,
    this.clouds,
    this.height,
    this.blend,
    this.noise,
    this.flipBlend,
  );
  final ui.FragmentProgram sky, clouds, height, blend;
  final ui.Image noise;
  final bool flipBlend;
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
          final height = await ui.FragmentProgram.fromAsset(
            'shaders/weather_mood_clouds_height.frag',
          );
          final blend = await ui.FragmentProgram.fromAsset(
            'shaders/weather_mood_blend.frag',
          );
          return _Programs(
            sky,
            clouds,
            height,
            blend,
            await _noise(),
            await _samplesFlipped(blend),
          );
        } catch (_) {
          _cache.remove(lowPower);
          rethrow;
        }
      });

  /// Impeller on OpenGL ES samples offscreen images upside down in runtime
  /// shaders. Sample a known image once and let the blend shader undo it.
  static Future<bool> _samplesFlipped(ui.FragmentProgram blend) async {
    final source = _picture(4, 4, (canvas) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 4, 2),
        Paint()..color = const Color(0xFFFF0000),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 2, 4, 2),
        Paint()..color = const Color(0xFF0000FF),
      );
    });
    final shader = blend.fragmentShader()
      ..setFloat(0, 4)
      ..setFloat(1, 4)
      ..setFloat(2, 1)
      ..setFloat(3, 0);
    _setStill(shader, 4);
    _setStill(shader, 12);
    for (var i = 0; i < 4; i++) {
      shader.setImageSampler(i, source);
    }
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..shader = shader);
    final picture = recorder.endRecording();
    final result = await picture.toImage(4, 4);
    picture.dispose();
    try {
      final bytes = await result.toByteData(format: ui.ImageByteFormat.rawRgba);
      return bytes != null && bytes.getUint8(2) > bytes.getUint8(0);
    } finally {
      result.dispose();
      shader.dispose();
      source.dispose();
    }
  }

  /// A keyframe that has not moved and fills the screen exactly.
  static void _setStill(ui.FragmentShader shader, int index) {
    const still = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0];
    for (final (i, value) in still.indexed) {
      shader.setFloat(index + i, value);
    }
  }

  static ui.Image _picture(int width, int height, void Function(Canvas) draw) {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(width, height);
    } finally {
      picture.dispose();
    }
  }

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
  ui.FragmentShader? _skyShader, _cloudShader, _heightShader, _blendShader;
  ui.Image? _skyImage;
  _Frame? _skyFrame;
  _BandBuild? _skyBuild;
  // The painter crossfades from the previous cloud keyframe to the next one
  // while the following keyframe is built one band per frame.
  _Keyframe? _cloudPrevious, _cloudNext;
  // Transparent stand-in for the first fade, so clouds appear gradually.
  _Keyframe? _clear;
  _BandBuild? _build;
  int _cloudTick = 0, _cycleTiles = 1;
  double _cloudMix = 1;
  _Frame? _frame;
  Timer? _timer;
  int? _frameCallback;
  Duration? _lastFrame;
  Size _size = Size.zero;
  bool _loading = true;
  bool _ready = false,
      _busy = false,
      _failed = false,
      _reducedMotion = false,
      _requested = false,
          // Shows the current clouds at once instead of fading to them.
          _snap =
          true;
  double? _lastTime;
  double _pixelRatio = 1;
  // Set by every immediate change until the scene it asked for is complete.
  bool _awaitingReady = true, _keyframeSinceSnap = false;
  int _readyToken = 0;
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
      _heightShader = programs.height.fragmentShader()
        ..setImageSampler(0, programs.noise, filterQuality: FilterQuality.low);
      _blendShader = programs.blend.fragmentShader()
        ..setFloat(3, programs.flipBlend ? 1 : 0);
      await _particles.load();
      final recorder = ui.PictureRecorder();
      Canvas(recorder);
      final empty = recorder.endRecording();
      _clear = _Keyframe(empty.toImageSync(1, 1), null, 1, 1);
      empty.dispose();
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
      _quality.recordFrame(timing.rasterDuration);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refreshRate = View.of(context).display.refreshRate;
    if (refreshRate.isFinite && refreshRate >= 20) {
      _quality.period = Duration(microseconds: (1000000 / refreshRate).round());
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (_pixelRatio != pixelRatio) {
      _pixelRatio = pixelRatio;
      _request();
    }
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      _lastTime = null;
      _snap = true;
      _request();
    }
  }

  @override
  void didUpdateWidget(WeatherMoodRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealToken != widget.revealToken) {
      _update(immediate: true);
    } else if (oldWidget.condition != widget.condition ||
        oldWidget.night != widget.night ||
        oldWidget.twilight != widget.twilight ||
        oldWidget.lightning != widget.lightning ||
        oldWidget.immediate != widget.immediate) {
      _update(immediate: widget.immediate || !_animate);
    }
    if (oldWidget.active != widget.active) {
      _lastTime = null;
      _snap = true;
    }
    _request();
  }

  void _update({required bool immediate}) {
    _scene.update(
      condition: widget.condition,
      night: widget.night,
      twilight: widget.twilight,
      lightning: widget.lightning,
      immediate: immediate,
    );
    if (immediate) _snap = true;
  }

  void _request() {
    _cancelLoop();
    _requested = true;
    if (!_ready || _busy || _failed || !mounted || _size.isEmpty) return;
    // A paused renderer can paint changed settings once without running a loop.
    _timer = Timer(Duration.zero, _render);
  }

  void _cancelLoop() {
    _timer?.cancel();
    _timer = null;
    final callback = _frameCallback;
    if (callback != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callback);
    }
    _frameCallback = null;
  }

  /// Wakes half a refresh before the frame [vsyncs] refreshes after the one
  /// that shows this render, so timer jitter never shifts the cadence.
  void _frameStarted(Duration timeStamp) {
    _frameCallback = null;
    final last = _lastFrame;
    _lastFrame = _animate ? timeStamp : null;
    if (!mounted || _failed || !(_animate || _requested)) return;
    if (_animate && last != null) _quality.recordTick(timeStamp - last);
    final wait = _quality.period * _quality.vsyncs - _quality.period ~/ 2;
    _timer = Timer(_requested ? Duration.zero : wait, _render);
  }

  void _render() {
    if (_busy || !mounted || !_ready || _size.isEmpty || _failed) return;
    _requested = false;
    _busy = true;
    final size = _size;
    final now = _clock.elapsed.inMicroseconds / 1000000;
    if (!_animate) _lastFrame = null;
    _scene.aspect = size.width / size.height;
    if (_animate && _lastTime != null) _scene.advance(now - _lastTime!);
    _lastTime = _animate ? now : null;
    final frame = _Frame(
      [..._scene.values],
      _scene.time,
      _scene.windTime,
      _scene.lightning,
      _scene.twilight,
      [..._scene.cumulus, 0, ..._scene.cumulusCopies, 0, 0],
    );
    try {
      if (_snap) {
        _awaitingReady = true;
        _keyframeSinceSnap = false;
        _readyToken = widget.revealToken;
      }
      _renderSky(frame, size);
      _renderClouds(frame, size);
      _snap = false;
      if (_awaitingReady && (!frame.hasClouds || _keyframeSinceSnap)) {
        _awaitingReady = false;
        final token = _readyToken;
        // After the frame that shows it.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onReady?.call(token);
        });
      }
      _frame = frame;
      _repaint.value++;
      if (const bool.fromEnvironment('WEATHER_MOOD_DIAGNOSTICS')) {
        _diagnosticFrames++;
        if (now - _diagnosticTime >= 15) {
          final seconds = now - _diagnosticTime;
          debugPrint(
            'WeatherMoodNative fps=${(_diagnosticFrames / seconds).toStringAsFixed(1)} cloudFps=${(_diagnosticClouds / seconds).toStringAsFixed(1)} clouds=${_cloudNext?.image.width}x${_cloudNext?.image.height} tiles=${_quality.tiles} scale=${_quality.scale.toStringAsFixed(2)} steps=${_quality.steps}',
          );
          _diagnosticTime = now;
          _diagnosticFrames = 0;
          _diagnosticClouds = 0;
        }
      }
    } catch (error) {
      if (mounted) _fail(error);
    } finally {
      _busy = false;
      if (!mounted) {
        _release();
      } else if (!_failed && (_animate || _requested)) {
        _frameCallback = SchedulerBinding.instance.scheduleFrameCallback(
          _frameStarted,
        );
      }
    }
  }

  /// The sky barely changes between frames, so every device keeps a cached
  /// image at the display's resolution. Changes render in a few bands and
  /// swap in once complete, so no frame shades the whole display.
  void _renderSky(_Frame frame, Size size) {
    final width = (size.width * _pixelRatio).ceil(),
        height = (size.height * _pixelRatio).ceil();
    final previous = _skyImage;
    final resized =
        previous == null ||
        previous.width != width ||
        previous.height != height;
    var build = _skyBuild;
    if (build != null &&
        (resized ||
            _snap ||
            !_animate ||
            build.width != width ||
            build.height != height)) {
      build.dispose();
      build = _skyBuild = null;
    }
    if (build == null) {
      if (!resized && !_snap && !frame.skyChangedSince(_skyFrame!)) return;
      build = _BandBuild(
        width,
        height,
        resized || _snap || !_animate ? 1 : _skyBands,
      )..frame = frame;
      if (build.tiles == 1) _quality.skipTick();
    }
    _renderBand(_skyShader!, build, clouds: false);
    if (!build.done) {
      _skyBuild = build;
      return;
    }
    _skyBuild = null;
    _skyImage = build.compose();
    _skyFrame = build.frame;
    previous?.dispose();
  }

  // Bands per sky update. Low-power GPUs take several frames to shade the
  // full display; fast ones barely notice either way.
  int get _skyBands => widget.lowPower ? 6 : 2;

  void _renderClouds(_Frame frame, Size size) {
    _quality.wind = frame.values[5];
    if (!frame.hasClouds) {
      _clearClouds();
      return;
    }
    final scale = math.min(
      1.0,
      math.min(_quality.width / size.width, _quality.height / size.height),
    );
    final width = math.max(1, (size.width * scale).round()),
        height = math.max(1, (size.height * scale).round());
    // The controller adapts upward from the floor, not from below it, and
    // no further than the longest keyframe interval allows.
    final floor = _quality.minimumTiles(width, height);
    final bands = _quality.tiles = math.max(
      floor,
      math.min(_quality.tiles, _quality.maxTiles),
    );
    if (!_animate) {
      // Paused scenes still render everything at once, but as separate
      // band draws so no single GPU submission runs long.
      _clearClouds();
      final build = _BandBuild(width, height, bands, denoise: widget.lowPower)
        ..frame = frame;
      while (!build.done) {
        _renderBand(_cloudShader!, build);
      }
      _cloudNext = _Keyframe.compose(build, null);
      _keyframeSinceSnap = true;
      _diagnosticClouds++;
      return;
    }
    // A snapshot from before a settings change is stale. The clouds on
    // screen stay until the new ones fade in over them.
    if (_snap) {
      _build?.dispose();
      _build = null;
    }
    var build = _build;
    if (build != null &&
        (build.viewWidth != width || build.viewHeight != height)) {
      build.dispose();
      build = _build = null;
    }
    if (build == null) {
      final margins = _margins(frame, width, height, bands);
      build = _build = _BandBuild(
        width,
        height,
        math.max(
          bands,
          _quality.minimumTiles(
            width + margins.left + margins.right,
            height + margins.top + margins.bottom,
          ),
        ),
        denoise: widget.lowPower,
        left: margins.left,
        top: margins.top,
        right: margins.right,
        bottom: margins.bottom,
      )..frame = frame;
      _cycleTiles = build.tiles;
    }
    _renderBand(_cloudShader!, build);
    if (build.done) {
      final shown = _cloudNext;
      if (_cloudPrevious != _clear) _cloudPrevious?.dispose();
      if (widget.revealed) {
        // The first clouds fade in from the bare sky.
        _cloudPrevious = shown ?? _clear;
      } else {
        // Nobody sees the scene yet, so it starts on the finished clouds.
        _cloudPrevious = null;
        shown?.dispose();
      }
      _cloudNext = _Keyframe.compose(build, _renderHeight(build));
      _keyframeSinceSnap = true;
      _build = null;
      _cloudTick = 0;
      _diagnosticClouds++;
    } else {
      _cloudTick++;
    }
    _cloudMix = _cloudNext == null
        ? 1
        : math.min(1, (_cloudTick + 1) / _cycleTiles);
  }

  /// Keyframes stay on screen for about three keyframe periods: while the
  /// next one builds, as the one fading in and as the one fading out. Slid
  /// along with their clouds, they need this much room past each edge
  /// where clouds come in.
  ({int left, int top, int right, int bottom}) _margins(
    _Frame frame,
    int width,
    int height,
    int bands,
  ) {
    final life = _quality.interval.inMicroseconds / 1000000 * bands * 3.5;
    final shift = weatherMoodCloudShift(
      fromTime: frame.time,
      fromWind: frame.windTime,
      toTime: frame.time + life,
      toWind: frame.windTime + life * frame.values[5],
      clouds: frame.values[0],
    );
    var left = 0.0, right = 0.0, bottom = 0.0, top = 0.0;
    for (final x in const [0.0, .5, 1.0]) {
      for (final y in const [0.0, .5, 1.0]) {
        final source = weatherMoodCloudSource(
          x,
          y,
          shift,
          width / height,
          height: 1.16,
        );
        left = math.max(left, -source.x);
        right = math.max(right, source.x - 1);
        bottom = math.max(bottom, -source.y);
        top = math.max(top, source.y - 1);
      }
    }
    int pixels(double amount, int size) => (math.min(amount, .3) * size).ceil();
    return (
      left: pixels(left, width),
      top: pixels(top, height),
      right: pixels(right, width),
      bottom: pixels(bottom, height),
    );
  }

  /// A small image of how high the clouds in [build] sit, which the blend
  /// shader uses to slide each part of the keyframe at its own speed. It
  /// costs a few percent of a band.
  ui.Image _renderHeight(_BandBuild build) {
    const scale = .25;
    final width = math.max(1, (build.width * scale).ceil()),
        height = math.max(1, (build.height * scale).ceil());
    return _shaderImage(
      _heightShader!,
      build.frame!,
      Size(build.viewWidth * scale, build.viewHeight * scale),
      width: width,
      rows: height,
      offset: Offset(-build.left * scale, -build.top * scale),
    );
  }

  void _renderBand(
    ui.FragmentShader shader,
    _BandBuild build, {
    bool clouds = true,
  }) {
    final top = build.rowStart(build.parts.length);
    build.parts.add(
      _shaderImage(
        shader,
        build.frame!,
        Size(build.viewWidth.toDouble(), build.viewHeight.toDouble()),
        width: build.width,
        rows: build.rowStart(build.parts.length + 1) - top,
        offset: Offset(-build.left.toDouble(), (top - build.top).toDouble()),
        clouds: clouds,
      ),
    );
  }

  void _clearClouds() {
    _build?.dispose();
    _build = null;
    if (_cloudPrevious != _clear) _cloudPrevious?.dispose();
    _cloudPrevious = null;
    _cloudNext?.dispose();
    _cloudNext = null;
    _cloudTick = 0;
    _cloudMix = 1;
  }

  /// Renders [rows] rows [width] pixels wide of a [resolution] sized view,
  /// starting at [offset] in the view's pixels.
  ui.Image _shaderImage(
    ui.FragmentShader shader,
    _Frame frame,
    Size resolution, {
    required int width,
    required int rows,
    Offset offset = Offset.zero,
    bool clouds = true,
  }) {
    final recorder = ui.PictureRecorder();
    frame.configure(shader, resolution, offset: offset, clouds: clouds);
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), rows.toDouble()),
      Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(width, rows);
    } finally {
      picture.dispose();
    }
  }

  void _fail(Object error) {
    _failed = true;
    _cancelLoop();
    widget.onError?.call(error);
    setState(() {});
  }

  void _release() {
    _skyShader?.dispose();
    _skyShader = null;
    _cloudShader?.dispose();
    _cloudShader = null;
    _heightShader?.dispose();
    _heightShader = null;
    _blendShader?.dispose();
    _blendShader = null;
    _clearClouds();
    _clear?.dispose();
    _clear = null;
    _skyBuild?.dispose();
    _skyBuild = null;
    _skyImage?.dispose();
    _skyImage = null;
    _particles.dispose();
  }

  @override
  void dispose() {
    _cancelLoop();
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
            _snap = true;
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

/// One shader image, rendered in horizontal bands on consecutive frames.
/// Every band uses the same scene snapshot, so the joined image matches a
/// single full render.
class _BandBuild {
  _BandBuild(
    this.viewWidth,
    this.viewHeight,
    int tiles, {
    this.denoise = false,
    this.left = 0,
    this.top = 0,
    int right = 0,
    int bottom = 0,
  }) : width = viewWidth + left + right,
       height = viewHeight + top + bottom,
       tiles = math.max(1, math.min(tiles, viewHeight + top + bottom));

  /// The view the shader renders, and the image, which reaches [left] and
  /// [top] pixels past the view's top left corner.
  final int viewWidth, viewHeight, width, height, left, top, tiles;

  /// Fewer ray steps leave grain in every texel, which the upscale to the
  /// screen magnifies. A blur under one texel removes it once per keyframe.
  final bool denoise;
  final parts = <ui.Image>[];
  _Frame? frame;
  bool get done => parts.length >= tiles;
  int rowStart(int band) => (height * band / tiles).round();

  ui.Image compose() {
    var image = parts.length == 1
        ? parts.removeLast()
        : _draw((canvas) {
            for (var i = 0; i < parts.length; i++) {
              canvas.drawImage(
                parts[i],
                Offset(0, rowStart(i).toDouble()),
                Paint(),
              );
            }
          });
    dispose();
    if (denoise) {
      final source = image;
      // Filtering the image itself clamps at its edges, where a filtered
      // layer would fade them into the sky.
      image = _draw(
        (canvas) => canvas.drawImage(
          source,
          Offset.zero,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: 1.1,
              sigmaY: 1.1,
              tileMode: TileMode.clamp,
            ),
        ),
      );
      source.dispose();
    }
    return image;
  }

  ui.Image _draw(void Function(Canvas) paint) {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(width, height);
    } finally {
      picture.dispose();
    }
  }

  void dispose() {
    for (final part in parts) {
      part.dispose();
    }
    parts.clear();
  }
}

/// A finished cloud image and the scene moment it shows. It can reach past
/// the screen on the sides the clouds move in from.
class _Keyframe {
  _Keyframe(this.image, this.frame, this.viewWidth, this.viewHeight)
    : height = null,
      window = [viewWidth / image.width, viewHeight / image.height, 0, 0];

  _Keyframe._(this.image, this.height, _BandBuild build)
    : frame = build.frame,
      viewWidth = build.viewWidth,
      viewHeight = build.viewHeight,
      window = [
        build.viewWidth / build.width,
        build.viewHeight / build.height,
        build.left / build.width,
        build.top / build.height,
      ];

  factory _Keyframe.compose(_BandBuild build, ui.Image? height) =>
      _Keyframe._(build.compose(), height, build);

  final ui.Image image;

  /// How high the clouds sit, as (height - 1) / 2, over the same area as
  /// [image]. Only a keyframe that never moves goes without.
  final ui.Image? height;
  final _Frame? frame;
  final int viewWidth, viewHeight;

  /// Where the view sits in the image: scale, then offset, in texture
  /// coordinates.
  final List<double> window;

  Rect get view => Rect.fromLTWH(
    window[2] * image.width,
    window[3] * image.height,
    viewWidth.toDouble(),
    viewHeight.toDouble(),
  );

  /// Sets the blend shader's shift and window uniforms from [index] for
  /// showing this keyframe at [now].
  void configure(ui.FragmentShader shader, int index, _Frame now) {
    final from = frame;
    final shift = from == null
        ? (x: 0.0, y: 0.0, z: 0.0)
        : weatherMoodCloudShift(
            fromTime: from.time,
            fromWind: from.windTime,
            toTime: now.time,
            toWind: now.windTime,
            clouds: now.values[0],
          );
    shader
      ..setFloat(index, shift.x)
      ..setFloat(index + 1, shift.y)
      ..setFloat(index + 2, shift.z)
      ..setFloat(index + 3, 0);
    for (var i = 0; i < 4; i++) {
      shader.setFloat(index + 4 + i, window[i]);
    }
  }

  void dispose() {
    image.dispose();
    height?.dispose();
  }
}

class _Frame {
  _Frame(
    this.values,
    this.time,
    this.windTime,
    this.lightning,
    this.twilight,
    this.cumulus,
  );
  final List<double> values;

  /// The cumulusSlide and cumulusCopy uniforms, padded to two vec4s.
  final List<double> cumulus;
  final double time, windTime, twilight;
  final WeatherMoodLightning lightning;

  /// Matches the sky shader's slow breathing of the sun's halo.
  double get _warmth => .985 + .015 * math.sin(time * .21);

  /// Clouds, fog, the downpour veil and hail tint all live in the cloud pass.
  bool get hasClouds =>
      values[0] > .001 ||
      values[3] > .001 ||
      values[6] > .001 ||
      values[8] > .001;

  bool skyChangedSince(_Frame previous) {
    if ((twilight - previous.twilight).abs() > .002) return true;
    for (final i in [0, 1, 2, 4, 9]) {
      if ((values[i] - previous.values[i]).abs() > .002) return true;
    }
    // Only the daytime sun's warmth depends on time. Its halo moves less
    // than one color step until the warmth changes by this much.
    return values[1] < .999 && (_warmth - previous._warmth).abs() > .006;
  }

  /// Sets the uniforms weather_mood_common.glsl declares. The sky shader
  /// never uses the cumulus, so its compiled form has no room for them.
  void configure(
    ui.FragmentShader shader,
    Size size, {
    Offset offset = Offset.zero,
    bool clouds = true,
  }) {
    final uniforms = [
      size.width,
      size.height,
      time,
      ...values.take(4),
      values[4],
      ...values.skip(5),
      windTime,
      // The painter draws lightning over the cached clouds on every frame.
      0.0,
      lightning.x,
      1 - (lightning.y + .20),
      twilight,
      offset.dx,
      offset.dy,
      if (clouds) ...cumulus,
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
        cloud = owner._cloudNext;
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
      frame.configure(sky, size, clouds: false);
      canvas.drawRect(Offset.zero & size, Paint()..shader = sky);
    }
    owner._particles.paintStars(
      canvas,
      size,
      frame.values[1] * (1 - frame.twilight),
      frame.time,
    );
    final blend = owner._blendShader;
    if (cloud != null && blend != null) {
      // Always through the blend shader, which slides each keyframe to
      // where its clouds are now.
      final previous = owner._cloudPrevious ?? cloud;
      final mix = owner._cloudPrevious == null ? 1.0 : owner._cloudMix;
      blend
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, mix);
      previous.configure(blend, 4, frame);
      cloud.configure(blend, 12, frame);
      blend
        ..setImageSampler(0, previous.image, filterQuality: FilterQuality.low)
        ..setImageSampler(1, cloud.image, filterQuality: FilterQuality.low)
        ..setImageSampler(
          2,
          previous.height ?? previous.image,
          filterQuality: FilterQuality.low,
        )
        ..setImageSampler(
          3,
          cloud.height ?? cloud.image,
          filterQuality: FilterQuality.low,
        );
      canvas.drawRect(Offset.zero & size, Paint()..shader = blend);
    } else if (cloud != null) {
      canvas.drawImageRect(
        cloud.image,
        cloud.view,
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low,
      );
    }
    if (frame.lightning.strength > .001) {
      // Lightning illuminates every animation frame while clouds are cached.
      // These stops follow a Gaussian glow around the strike.
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
      twilight: frame.twilight,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WeatherPainter oldDelegate) => true;
}
