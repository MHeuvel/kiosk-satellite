import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'assist_art.dart';

/// The Ink Blobs skin's background: the same GPU fluid simulation as its
/// script (ink-blobs.js, adapted there from Pavel Dobryakov's
/// WebGL-Fluid-Simulation, MIT License). Colored ink jets in from the
/// edges and the solver (vorticity confinement, 20 Jacobi pressure
/// iterations, advection) carries it into plumes; the audio level churns
/// the fluid. The passes run as Flutter fragment shaders on 128 texel
/// velocity and 512 texel dye fields, stepping every 33 ms like the
/// original, merged into fewer passes (see [_InkSim.step]).
class InkBlobsArt extends StatefulWidget {
  const InkBlobsArt({
    super.key,
    required this.dark,
    required this.mode,
    required this.reactive,
    required this.level,
  });

  final bool dark;
  final ArtMode mode;
  final bool reactive;
  final ValueListenable<double> level;

  @override
  State<InkBlobsArt> createState() => _InkBlobsArtState();
}

// The script's simulation settings.
const _simRes = 128.0;
const _dyeRes = 512.0;
const _pressure = 0.8;
const _curl = 30.0;
const _curlReact = 2.4;
const _velocityDissipation = 0.15;
const _densityDissipation = 0.18;
const _splatRadius = 0.016;
const _jetForce = 240.0;
const _dyeRate = 10.0;
const _idleJetRate = 0.35;
const _activeJetRate = 0.7;
const _audioGain = 1.6;

const _inkDark = [
  [255, 26, 26],
  [255, 209, 13],
  [31, 102, 255],
  [26, 235, 64],
  [224, 230, 240],
];
const _inkLight = [
  [217, 10, 10],
  [245, 184, 0],
  [10, 36, 217],
  [0, 140, 31],
  [10, 13, 18],
];

class _InkBlobsArtState extends State<InkBlobsArt>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  _InkSim? _sim;
  _InkPrograms? _programs;
  Size _size = Size.zero;
  Duration _lastStep = Duration.zero;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _InkPrograms.load().then(
      (programs) {
        if (mounted) setState(() => _programs = programs);
      },
      onError: (Object _) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  void _tick(Duration elapsed) {
    if ((elapsed - _lastStep).inMilliseconds < 33) return;
    final first = _lastStep == Duration.zero;
    final real = (elapsed - _lastStep).inMicroseconds / 1e6;
    _lastStep = elapsed;
    final programs = _programs;
    if (programs == null || _size.isEmpty || _failed) return;
    final sim = _sim ??= _InkSim(programs, _size);
    if (sim.size != _size) {
      sim.dispose();
      _sim = _InkSim(programs, _size);
      return;
    }
    // The script caps a step at one 60 Hz frame.
    final dt = first ? 0.016 : math.min(real, 0.0167);
    final raw = switch (widget.mode) {
      ArtMode.thinking => 0.3,
      ArtMode.idle => 0.0,
      _ => widget.reactive ? widget.level.value.clamp(0.0, 1.0) : 0.0,
    };
    final watch = Stopwatch()..start();
    sim.step(dt, raw, widget.dark ? _inkDark : _inkLight);
    ArtCost.step(watch);
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _sim?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _size = box.biggest;
      return RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _InkPainter(this, _frame),
        ),
      );
    },
  );
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.state, Listenable frame) : super(repaint: frame);
  final _InkBlobsArtState state;

  @override
  void paint(Canvas canvas, Size size) {
    final dye = state._sim?.dye;
    if (dye == null) return;
    // DISPLAY_FRAG: the dye as premultiplied color, stretched over the
    // screen with linear filtering like the original's canvas.
    canvas.drawImageRect(
      dye,
      Rect.fromLTWH(0, 0, dye.width.toDouble(), dye.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_InkPainter old) => false;
}

/// The compiled passes, loaded once, and whether this backend samples
/// offscreen images upside down.
class _InkPrograms {
  _InkPrograms._(this.programs, this.flipY);

  final Map<String, ui.FragmentProgram> programs;
  final double flipY;

  static Future<_InkPrograms>? _loading;

  static Future<_InkPrograms> load() => _loading ??= () async {
    final programs = <String, ui.FragmentProgram>{};
    for (final name in const [
      'splat_velocity',
      'curl',
      'vorticity',
      'divergence',
      'clear',
      'pressure4',
      'advect_velocity',
      'advect_dye',
    ]) {
      programs[name] = await ui.FragmentProgram.fromAsset(
        'shaders/ink_$name.frag',
      );
    }
    final flipped = await _samplesFlipped(programs['clear']!);
    return _InkPrograms._(programs, flipped ? 1 : 0);
  }();

  /// Copies an image whose top is red and bottom is blue through a
  /// shader and sees which comes out on top.
  static Future<bool> _samplesFlipped(ui.FragmentProgram copy) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 4, 2),
      Paint()..color = const Color(0xFFFF0000),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 2, 4, 2),
      Paint()..color = const Color(0xFF0000FF),
    );
    final sourcePicture = recorder.endRecording();
    final source = sourcePicture.toImageSync(4, 4);
    sourcePicture.dispose();
    final shader = copy.fragmentShader()
      ..setFloat(0, 4)
      ..setFloat(1, 4)
      ..setFloat(2, 0)
      ..setFloat(3, 1)
      ..setFloat(4, 0)
      ..setImageSampler(0, source);
    final out = ui.PictureRecorder();
    Canvas(
      out,
    ).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint()..shader = shader);
    final picture = out.endRecording();
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
}

class _Jet {
  _Jet({
    required this.dir,
    required this.x,
    required this.y,
    required this.vy,
    required this.color,
    required this.duration,
    required this.force,
    required this.dyeMul,
  });

  final double dir;
  final double x;
  final double y;
  final double vy;
  final List<double> color;
  double age = 0;
  final double duration;
  final double force;
  final double dyeMul;
}

/// The fields and one step of the solver, as the script's step().
class _InkSim {
  _InkSim(this.programs, this.size) {
    final aspect = size.width / size.height;
    final a = aspect < 1 ? 1 / aspect : aspect;
    (int, int) res(double r) => size.width > size.height
        ? ((r * a).round(), r.round())
        : (r.round(), (r * a).round());
    final sim = res(_simRes);
    final dyeRes = res(_dyeRes);
    simW = sim.$1;
    simH = sim.$2;
    dyeW = dyeRes.$1;
    dyeH = dyeRes.$2;
    _shaders = {
      for (final e in programs.programs.entries)
        e.key: e.value.fragmentShader(),
    };
    // Zero fields: velocity and pressure encode 0 at mid range.
    velocity = _fill(simW, simH, const Color(0xFF800800));
    pressure = _fill(simW, simH, const Color(0xFF800000));
    dye = _fill(dyeW, dyeH, const Color(0x00000000));
    _jetColor = _random.nextInt(5);
    _jetSide = _random.nextBool() ? -1 : 1;
  }

  final _InkPrograms programs;
  final Size size;
  late final int simW;
  late final int simH;
  late final int dyeW;
  late final int dyeH;
  late final Map<String, ui.FragmentShader> _shaders;
  late ui.Image velocity;
  late ui.Image pressure;
  late ui.Image dye;
  final _random = math.Random();
  final _jets = <_Jet>[];
  late int _jetColor;
  late int _jetSide;
  double _spawn = 0;
  double _smoothLevel = 0;
  double _seed = 0;

  double get _aspect => size.width / size.height;

  static ui.Image _fill(int w, int h, Color color) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()
        ..color = color
        ..blendMode = BlendMode.src,
    );
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(w, h);
    } finally {
      picture.dispose();
    }
  }

  /// Runs [name] over a [w] by [h] target and returns the result.
  ui.Image _pass(
    String name,
    int w,
    int h,
    List<double> floats,
    List<(ui.Image, bool)> samplers,
  ) {
    final shader = _shaders[name]!;
    shader
      ..setFloat(0, w.toDouble())
      ..setFloat(1, h.toDouble())
      ..setFloat(2, programs.flipY);
    for (final (i, v) in floats.indexed) {
      shader.setFloat(3 + i, v);
    }
    for (final (i, (image, linear)) in samplers.indexed) {
      shader.setImageSampler(
        i,
        image,
        filterQuality: linear ? FilterQuality.low : FilterQuality.none,
      );
    }
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.src,
    );
    final picture = recorder.endRecording();
    try {
      return ArtCost.snapshot(() => picture.toImageSync(w, h));
    } finally {
      picture.dispose();
    }
  }

  ui.Image _swap(ui.Image old, ui.Image next) {
    old.dispose();
    return next;
  }

  void _spawnJet(double level, List<List<int>> palette) {
    final side = _jetSide;
    _jetSide = -_jetSide;
    final c = palette[_jetColor % palette.length];
    _jetColor++;
    // Left jets stay in the upper area, clear of the chat.
    final y = side < 0
        ? 0.52 + _random.nextDouble() * 0.38
        : 0.12 + _random.nextDouble() * 0.76;
    _jets.add(
      _Jet(
        dir: side < 0 ? 1 : -1,
        x: side < 0 ? 0.02 : 0.98,
        y: y,
        vy: (_random.nextDouble() - 0.5) * 0.6,
        color: [c[0] / 255, c[1] / 255, c[2] / 255],
        duration: 0.4 + _random.nextDouble() * 0.3,
        force: _jetForce * (0.85 + level * 0.3),
        dyeMul: 0.9 + level * 0.5,
      ),
    );
  }

  // Every pass is an offscreen image, and on low end GPUs each one has a
  // fixed cost of a few milliseconds whatever it does. So the script's
  // passes are merged where that is cheaper: the 20 Jacobi iterations are
  // five passes of four, the gradient goes with the velocity advection and
  // the dye splat with the dye advection. Eleven passes a step instead of
  // 19. Passes that do much more than that cost more than they save there,
  // so the velocity splat, curl and vorticity stay apart.
  void step(double dt, double raw, List<List<int>> palette) {
    _smoothLevel += (raw - _smoothLevel) * (raw > _smoothLevel ? 0.2 : 0.08);
    final eff = math.min(1.0, _smoothLevel * _audioGain);
    final curl = _curl * (1 + eff * _curlReact);
    _spawn += dt * (_idleJetRate + eff * _activeJetRate);
    while (_spawn >= 1) {
      _spawn -= 1;
      _spawnJet(eff, palette);
    }
    _seed = (_seed + 1.618) % 1000;
    final (velocityJets, points, colors) = _jetUniforms(dt);
    // splat velocity
    if (_jets.isNotEmpty) {
      velocity = _swap(
        velocity,
        _pass(
          'splat_velocity',
          simW,
          simH,
          [_aspect, _splatRadius, ...velocityJets],
          [(velocity, false)],
        ),
      );
    }
    // curl
    final curlField = _pass('curl', simW, simH, const [], [(velocity, false)]);
    // vorticity
    velocity = _swap(
      velocity,
      _pass(
        'vorticity',
        simW,
        simH,
        [curl, dt],
        [(velocity, false), (curlField, false)],
      ),
    );
    curlField.dispose();
    // divergence
    final divergence = _pass('divergence', simW, simH, const [], [
      (velocity, false),
    ]);
    // The 20 Jacobi iterations, four to a pass, the first starting from
    // the last pressure times the script's PRESSURE (its clear pass).
    for (var i = 0; i < 20; i += 4) {
      pressure = _swap(
        pressure,
        _pass(
          'pressure4',
          simW,
          simH,
          [i == 0 ? _pressure : 1.0],
          [(pressure, false), (divergence, false)],
        ),
      );
    }
    divergence.dispose();
    // gradient subtract and advect velocity
    velocity = _swap(
      velocity,
      _pass(
        'advect_velocity',
        simW,
        simH,
        [dt, _velocityDissipation],
        [(velocity, false), (pressure, false)],
      ),
    );
    // splat and advect dye
    dye = _swap(
      dye,
      _pass(
        'advect_dye',
        dyeW,
        dyeH,
        [
          dt,
          _densityDissipation,
          simW.toDouble(),
          simH.toDouble(),
          _seed,
          _aspect,
          _splatRadius,
          ...points,
          ...colors,
        ],
        [(velocity, false), (dye, true)],
      ),
    );
  }

  /// Each jet streams force and dye for its life, on a sine envelope: the
  /// splat uniforms for up to four of them (there are rarely more than two
  /// at once), idle slots far off screen.
  (List<double>, List<double>, List<double>) _jetUniforms(double dt) {
    final velocityJets = <double>[];
    final points = <double>[];
    final colors = <double>[];
    for (var i = _jets.length - 1; i >= 0; i--) {
      final j = _jets[i];
      j.age += dt;
      final tt = j.age / j.duration;
      if (tt >= 1) {
        _jets.removeAt(i);
        continue;
      }
      if (points.length == 8) continue;
      final env = math.sin(tt * math.pi);
      velocityJets.addAll([
        j.x,
        j.y,
        j.dir * j.force * env,
        j.vy * j.force * env,
      ]);
      points.addAll([j.x, j.y]);
      final a = _dyeRate * dt * env * j.dyeMul;
      colors.addAll([j.color[0] * a, j.color[1] * a, j.color[2] * a, a]);
    }
    while (points.length < 8) {
      velocityJets.addAll([-10, -10, 0, 0]);
      points.addAll([-10, -10]);
      colors.addAll([0, 0, 0, 0]);
    }
    return (velocityJets, points, colors);
  }

  void dispose() {
    velocity.dispose();
    pressure.dispose();
    dye.dispose();
    for (final s in _shaders.values) {
      s.dispose();
    }
  }
}
