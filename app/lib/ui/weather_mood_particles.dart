import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'weather_mood_scene.dart';

class _Particle {
  _Particle(double Function() random)
    : x = random(),
      y = random(),
      depth = random(),
      phase = random() * math.pi * 2,
      variation = random(),
      drift = random();
  final double x, y, depth, phase, variation, drift;
}

/// Deterministic fields keep the approved spacing, speeds and depth layers.
class WeatherMoodParticles {
  WeatherMoodParticles() {
    var seed = 9127;
    double random() {
      seed = (seed * 1664525 + 1013904223) & 0xffffffff;
      return seed / 4294967296;
    }

    List<_Particle> field(int count) =>
        List.generate(count, (_) => _Particle(random));
    _rain = field(620);
    _snow = field(180);
    _motes = field(32);
    _nearRain = field(30);
    _nearSnow = field(24);
    _rain.addAll(field(650));
    _nearRain.addAll(field(24));
    _hail = field(240);
    _wind = field(80);
    _nearHail = field(32);
    _stars = field(700);
  }
  late final List<_Particle> _rain,
      _snow,
      _motes,
      _nearRain,
      _nearSnow,
      _hail,
      _wind,
      _nearHail;
  late final List<_Particle> _stars;
  Float32List _starTransforms = Float32List(0), _starRects = Float32List(0);
  Int32List _starColors = Int32List(0);
  final _starPaint = ui.Paint()..filterQuality = ui.FilterQuality.low;
  Float32List _rainPositions = Float32List(0),
      _rainTextureCoordinates = Float32List(0);
  Int32List _rainColors = Int32List(0);
  Uint16List _rainIndices = Uint16List(0);
  ui.ImageShader? _rainShader;
  final _rainPaint = ui.Paint()..filterQuality = ui.FilterQuality.low;
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.low;
  final _stroke = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;
  final _dot = ui.Paint();
  final _sprites = <ui.Image>[];
  int _boltId = -1;
  double _boltWidth = 0;
  List<ui.Path> _bolts = [];

  Future<void> load() async {
    const colors = [
      [
        ui.Color(0xFFF8FBFF),
        ui.Color(0xD9F0F6FF),
        ui.Color(0x66E6F0FF),
        ui.Color(0x00E6F0FF),
      ],
      [
        ui.Color(0xCCECF5FF),
        ui.Color(0xADECF5FF),
        ui.Color(0x4DE1EEFA),
        ui.Color(0x00E1EEFA),
      ],
      [
        ui.Color(0xFFFFFFFF),
        ui.Color(0xF0FBFCFD),
        ui.Color(0xB8E6EBF0),
        ui.Color(0x00EEF1F5),
      ],
      [
        ui.Color(0xF2FFFFFF),
        ui.Color(0xB8FFFFFF),
        ui.Color(0x42F8FAFC),
        ui.Color(0x00F8FAFC),
      ],
    ];
    const stops = [
      [0.0, .28, .6, 1.0],
      [0.0, .25, .55, 1.0],
      [0.0, .55, .8, 1.0],
      [0.0, .3, .65, 1.0],
    ];
    for (var i = 0; i < 4; i++) {
      final recorder = ui.PictureRecorder();
      final target = ui.Canvas(recorder);
      target.drawRect(
        const ui.Rect.fromLTWH(0, 0, 96, 96),
        ui.Paint()
          ..shader = ui.Gradient.radial(
            const ui.Offset(48, 48),
            48,
            colors[i],
            stops[i],
          ),
      );
      final picture = recorder.endRecording();
      try {
        _sprites.add(await picture.toImage(96, 96));
      } finally {
        picture.dispose();
      }
    }

    // A shared streak texture lets all distant rain use one draw call.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const rect = ui.Rect.fromLTWH(0, 0, 32, 128);
    canvas.drawRect(
      rect,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          const ui.Offset(0, 128),
          const [
            ui.Color(0x00C0D4E3),
            ui.Color(0xB3D3E4F0),
            ui.Color(0xFFE2EEF5),
          ],
          [0, .7, 1],
        ),
    );
    canvas.drawRect(
      rect,
      ui.Paint()
        ..blendMode = ui.BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          const ui.Offset(32, 0),
          const [
            ui.Color(0x00FFFFFF),
            ui.Color(0xFFFFFFFF),
            ui.Color(0xFFFFFFFF),
            ui.Color(0x00FFFFFF),
          ],
          [0, .3, .7, 1],
        ),
    );
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(32, 128);
      _sprites.add(image);
      _rainShader = ui.ImageShader(
        image,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
        filterQuality: ui.FilterQuality.low,
      );
      _rainPaint.shader = _rainShader;
    } finally {
      picture.dispose();
    }
  }

  void dispose() {
    _rainPaint.shader = null;
    _rainShader?.dispose();
    _rainShader = null;
    for (final image in _sprites) {
      image.dispose();
    }
    _sprites.clear();
  }

  void _sprite(
    ui.Canvas canvas,
    int image,
    double x,
    double y,
    double width,
    double height,
    double angle,
    double opacity,
  ) {
    if (_sprites.length < 4) return;
    _paint.color = ui.Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1));
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.drawImageRect(
      _sprites[image],
      const ui.Rect.fromLTWH(0, 0, 96, 96),
      ui.Rect.fromLTWH(-width / 2, -height / 2, width, height),
      _paint,
    );
    canvas.restore();
  }

  /// Batch the small star sprites instead of evaluating random star cells at
  /// every screen pixel. Only the brighter subset twinkles.
  void paintStars(ui.Canvas canvas, ui.Size size, double night, double time) {
    if (night < .001 || _sprites.length < 4) return;
    final scale = size.height / 720;
    final count = (440 * size.aspectRatio / (1280 / 720)).round().clamp(
      1,
      _stars.length,
    );
    if (_starColors.length != count) {
      _starTransforms = Float32List(count * 4);
      _starRects = Float32List(count * 4);
      _starColors = Int32List(count);
      for (var i = 0; i < count; i++) {
        _starRects[i * 4 + 2] = 96;
        _starRects[i * 4 + 3] = 96;
      }
    }
    for (var i = 0; i < count; i++) {
      final p = _stars[i];
      final radius = (.45 + math.pow(p.depth, 3) * .65) * scale;
      final twinkle = p.depth > .65
          ? .70 + .30 * math.sin(time * (.65 + p.variation * 1.1) + p.phase)
          : 1.0;
      final alpha = (night * (.5 + p.depth * .85) * twinkle * 255)
          .round()
          .clamp(0, 255);
      final red = (166 + 89 * p.drift).round(),
          green = (204 + 36 * p.drift).round(),
          blue = (255 - 51 * p.drift).round();
      _starColors[i] = (alpha << 24) | (red << 16) | (green << 8) | blue;
      _starTransforms[i * 4] = radius / 48;
      _starTransforms[i * 4 + 1] = 0;
      _starTransforms[i * 4 + 2] = p.x * size.width - radius;
      _starTransforms[i * 4 + 3] = p.y * size.height - radius;
    }
    canvas.drawRawAtlas(
      _sprites[0],
      _starTransforms,
      _starRects,
      _starColors,
      ui.BlendMode.modulate,
      ui.Offset.zero & size,
      _starPaint,
    );
  }

  void paint(
    ui.Canvas canvas,
    ui.Size size,
    List<double> values,
    double t,
    double windTime,
    WeatherMoodLightning lightning,
  ) {
    final scale = size.height / 720, width = size.width / scale;
    const height = 720.0;
    canvas.save();
    canvas.scale(scale);
    _lightning(canvas, width, lightning);
    final windStrength = values[5],
        downpour = values[6],
        rainStrength = values[2],
        snowStrength = values[4],
        hailStrength = values[8];
    final windTravel = windTime * 95;
    final gust = math.sin(t * .17) * .022 + math.sin(t * .39) * .012;
    if (rainStrength > .002) {
      final count = (440 * math.min(1.4, width / 1280) * (1 + downpour * .90))
          .round();
      if (_rainColors.length != count * 4) {
        _rainPositions = Float32List(count * 8);
        _rainTextureCoordinates = Float32List(count * 8);
        _rainColors = Int32List(count * 4);
        _rainIndices = Uint16List(count * 6);
        for (var i = 0; i < count; i++) {
          _rainTextureCoordinates.setRange(i * 8, i * 8 + 8, [
            0,
            0,
            32,
            0,
            0,
            128,
            32,
            128,
          ]);
          final v = i * 4;
          _rainIndices.setRange(i * 6, i * 6 + 6, [
            v,
            v + 1,
            v + 2,
            v + 1,
            v + 3,
            v + 2,
          ]);
        }
      }
      for (var i = 0; i < count; i++) {
        final p = _rain[i];
        final depth = p.depth * p.depth;
        final speed =
            (430 + depth * 880 + p.variation * 110) * (1 + downpour * .18);
        final length =
            (5 + depth * 31 + p.variation * 6) * (1 + downpour * .35);
        final tilt =
            -.12 -
            windStrength * .48 +
            gust * (1 + windStrength * 2) +
            (p.drift - .5) * .035;
        final y = (p.y * (height + 140) + t * speed) % (height + 140) - 70;
        final x =
            (p.x * (width + 300) + y * tilt + t * (5 + depth * 8)) %
                (width + 300) -
            150;
        final opacity =
            (rainStrength *
                    (.16 + depth * .40) *
                    (.65 + p.variation * .35) *
                    (1 + downpour * .22))
                .clamp(0.0, 1.0);
        final halfWidth = (.55 + depth * 1.15) * .7;
        final dx = halfWidth / math.sqrt(1 + tilt * tilt), dy = -tilt * dx;
        final tx = x - tilt * length, ty = y - length;
        final at = i * 8;
        _rainPositions[at] = tx - dx;
        _rainPositions[at + 1] = ty - dy;
        _rainPositions[at + 2] = tx + dx;
        _rainPositions[at + 3] = ty + dy;
        _rainPositions[at + 4] = x - dx;
        _rainPositions[at + 5] = y - dy;
        _rainPositions[at + 6] = x + dx;
        _rainPositions[at + 7] = y + dy;
        final color = ((opacity * 255).round() << 24) | 0xFFFFFF;
        _rainColors.fillRange(i * 4, i * 4 + 4, color);
      }
      if (_rainShader != null) {
        final mesh = ui.Vertices.raw(
          ui.VertexMode.triangles,
          _rainPositions,
          textureCoordinates: _rainTextureCoordinates,
          colors: _rainColors,
          indices: _rainIndices,
        );
        canvas.drawVertices(mesh, ui.BlendMode.modulate, _rainPaint);
        mesh.dispose();
      }
      final countNear =
          (20 * math.min(1.4, width / 1280) * (1 + downpour * .75)).round();
      for (final p in _nearRain.take(countNear)) {
        final length = 65 + p.depth * 95,
            breadth = 7 + p.depth * 12,
            speed = 1050 + p.depth * 950;
        final tilt =
            -.12 -
            windStrength * .48 +
            gust * (1 + windStrength * 2) +
            (p.drift - .5) * .035;
        final y = (p.y * (height + 360) + t * speed) % (height + 360) - 180;
        final x =
            (p.x * (width + 360) + y * tilt + t * 14) % (width + 360) - 180;
        _sprite(
          canvas,
          1,
          x,
          y,
          breadth,
          length,
          -math.atan(tilt),
          rainStrength * (.18 + p.variation * .24) * .65,
        );
      }
    }
    if (snowStrength > .002) {
      for (final p in _snow.take((145 * math.min(1.2, width / 1280)).round())) {
        final radius = .8 + math.pow(p.depth, 2.8) * 4.7,
            speed = 13 + p.depth * 39 + p.variation * 12;
        final y = (p.y * (height + 70) + t * speed) % (height + 70) - 35;
        final flutter =
            math.sin(t * (.30 + p.drift * .5) + p.phase) * (8 + p.depth * 20);
        final sway = math.sin(t * .13 + p.phase) * 17;
        final x =
            (p.x * (width + 110) +
                    t * (4 + p.drift * 8) +
                    flutter +
                    sway -
                    windTravel * (.3 + p.depth)) %
                (width + 110) -
            55;
        _sprite(
          canvas,
          0,
          x,
          y,
          radius * 2,
          radius * 1.6,
          math.sin(t * .5 + p.phase) * .4,
          snowStrength * (.28 + p.depth * .57),
        );
      }
      for (final p in _nearSnow.take(
        (16 * math.min(1.4, width / 1280)).round(),
      )) {
        final radius = 10 + p.depth * 15,
            y =
                (p.y * (height + 150) + t * (110 + p.depth * 110)) %
                    (height + 150) -
                75;
        final flutter =
            math.sin(t * (.22 + p.drift * .25) + p.phase) * (28 + p.depth * 24);
        final x =
            (p.x * (width + 180) +
                    t * (7 + p.drift * 13) +
                    flutter -
                    windTravel * (.8 + p.depth)) %
                (width + 180) -
            90;
        _sprite(
          canvas,
          1,
          x,
          y,
          radius * 2,
          radius * 1.66,
          p.phase + math.sin(t * .25) * .4,
          snowStrength * (.28 + p.variation * .30) * .65,
        );
      }
    }
    if (hailStrength > .002) {
      for (final p in _hail.take((160 * math.min(1.4, width / 1280)).round())) {
        final radius = 1.2 + p.depth * p.depth * 4,
            speed = 640 + p.depth * 1050;
        final y = (p.y * (height + 80) + t * speed) % (height + 80) - 40;
        final x =
            (p.x * (width + 180) -
                    y * (.025 + windStrength * .16) -
                    windTravel * .25) %
                (width + 180) -
            90;
        _sprite(
          canvas,
          2,
          x,
          y,
          radius * 2,
          radius * 2.24,
          p.phase + t * (.7 + p.variation),
          hailStrength * (.47 + p.depth * .40),
        );
      }
      for (final p in _nearHail.take(
        (19 * math.min(1.4, width / 1280)).round(),
      )) {
        final radius = 8 + p.depth * 13,
            y =
                (p.y * (height + 180) + t * (1250 + p.depth * 1100)) %
                    (height + 180) -
                90;
        final x =
            (p.x * (width + 200) -
                    y * (.04 + windStrength * .18) -
                    windTravel * .4) %
                (width + 200) -
            100;
        _sprite(
          canvas,
          3,
          x,
          y,
          radius * 2,
          radius * 3,
          .05 + windStrength * .18,
          hailStrength * (.20 + p.variation * .22),
        );
      }
    }
    final air =
        windStrength *
        (1 - rainStrength) *
        (1 - snowStrength) *
        (1 - hailStrength);
    _stroke.shader = null;
    if (air > .002) {
      for (final p in _wind.take((52 * math.min(1.4, width / 1280)).round())) {
        final x =
            (p.x * (width + 140) - windTravel * (1.7 + p.depth * 2.5)) %
                (width + 140) -
            70;
        final y =
            (p.y * height + math.sin(t * .42 + p.phase) * (8 + p.depth * 15)) %
            height;
        _stroke
          ..color = ui.Color.fromRGBO(
            227,
            232,
            224,
            air * (.06 + p.variation * .10),
          )
          ..strokeWidth = .6 + p.depth;
        canvas.drawLine(
          ui.Offset(x, y),
          ui.Offset(x + 3 + p.depth * 7, y - 1),
          _stroke,
        );
      }
    }
    final clear =
        (1 - values[1]) *
        math.max(0, 1 - values[0] / .065) *
        (1 - rainStrength) *
        (1 - snowStrength) *
        (1 - values[3]);
    if (clear > .002) {
      for (final p in _motes) {
        final x =
            (p.x * (width + 70) +
                    t * (1.7 + p.drift * 3.5) +
                    math.sin(t * .19 + p.phase) * 9) %
                (width + 70) -
            35;
        final y =
            (p.y * (height + 60) -
                    t * (1.5 + p.depth * 2.5) +
                    math.sin(t * .23 + p.phase) * 8) %
                (height + 60) -
            30;
        final light =
            .5 +
            .5 *
                math.exp(
                  -(math.pow(x - width * .67, 2) +
                          math.pow(y - height * .24, 2)) /
                      80000,
                );
        _dot.color = ui.Color.fromRGBO(
          255,
          233,
          181,
          clear * (.07 + p.variation * .10) * light,
        );
        canvas.drawCircle(ui.Offset(x, y), .7 + p.depth * 1.6, _dot);
      }
    }
    canvas.restore();
  }

  List<ui.Offset> _path(
    ui.Offset start,
    ui.Offset end,
    double amplitude,
    int steps,
    double seed,
  ) {
    var points = [start, end];
    for (var level = 0; level < steps; level++) {
      final next = [points.first];
      for (var i = 1; i < points.length; i++) {
        final a = points[i - 1], b = points[i];
        next.add(
          ui.Offset(
            (a.dx + b.dx) / 2 +
                (weatherMoodRandom(seed + level * 113 + i * 7) - .5) *
                    amplitude,
            (a.dy + b.dy) / 2 +
                (weatherMoodRandom(seed + level * 31 + i) - .5) *
                    amplitude *
                    .14,
          ),
        );
        next.add(b);
      }
      points = next;
      amplitude *= .52;
    }
    return points;
  }

  void _lightning(ui.Canvas canvas, double width, WeatherMoodLightning event) {
    if (event.strength < .005) return;
    const height = 720.0;
    if (_boltId != event.id || _boltWidth != width) {
      final start = ui.Offset(event.x * width, event.y * height);
      final end = ui.Offset(
        start.dx + (weatherMoodRandom(event.id + 81.0) - .5) * width * .35,
        height * (.76 + weatherMoodRandom(event.id + 88.0) * .30),
      );
      final points = _path(start, end, height * .34, 6, event.id * 117.0 + 9);
      final paths = [points];
      for (var i = 0; i < 5; i++) {
        final from =
            points[12 + (weatherMoodRandom(event.id + i * 11.0) * 34).floor()];
        final side = weatherMoodRandom(event.id + i + 9.0) > .5 ? 1 : -1;
        final to = ui.Offset(
          from.dx +
              side *
                  height *
                  (.09 + weatherMoodRandom(event.id + i + 31.0) * .24),
          from.dy +
              height * (.09 + weatherMoodRandom(event.id + i + 71.0) * .23),
        );
        paths.add(_path(from, to, height * .12, 4, event.id + i * 39.0));
      }
      _bolts = paths
          .map((points) => ui.Path()..addPolygon(points, false))
          .toList();
      _boltId = event.id;
      _boltWidth = width;
    }
    _stroke
      ..blendMode = ui.BlendMode.screen
      ..strokeJoin = ui.StrokeJoin.round;
    final glow = ui.Gradient.linear(
      ui.Offset.zero,
      const ui.Offset(0, height),
      const [
        ui.Color(0x008170FF),
        ui.Color(0xFF8B85FF),
        ui.Color(0xFF6C9AFF),
        ui.Color(0x596C9AFF),
      ],
      [0, .12, .72, 1],
    );
    void trace(
      ui.Path path,
      double width,
      double alpha,
      ui.Color color, [
      ui.Shader? shader,
    ]) {
      _stroke
        ..strokeWidth = width
        ..color = color.withValues(alpha: alpha * event.strength)
        ..shader = shader;
      canvas.drawPath(path, _stroke);
    }

    trace(_bolts.first, 19, .15, const ui.Color(0xFFFFFFFF), glow);
    trace(_bolts.first, 8, .31, const ui.Color(0xFFFFFFFF), glow);
    trace(_bolts.first, 3.4, .88, const ui.Color(0xFFB3C7FF));
    trace(_bolts.first, 1.45, 1, const ui.Color(0xFFF8FAFF));
    for (final path in _bolts.skip(1)) {
      trace(path, 6, .13, const ui.Color(0xFFFFFFFF), glow);
      trace(path, 1.4, .61, const ui.Color(0xFFAAC3FF));
      trace(path, .6, .86, const ui.Color(0xFFE9F1FF));
    }
    _stroke
      ..blendMode = ui.BlendMode.srcOver
      ..shader = null;
  }
}
