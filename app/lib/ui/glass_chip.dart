import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The glass shader, on renderers that can run it as a backdrop filter.
final Future<ui.FragmentProgram?> _glassProgram =
    ui.ImageFilter.isShaderFilterSupported
    ? ui.FragmentProgram.fromAsset(
        'shaders/weather_mood_glass.frag',
      ).then<ui.FragmentProgram?>((program) => program, onError: (_) => null)
    : Future.value(null);

/// The colors of a glass chip at a Background opacity from 0 to 1, for
/// the tinted chip renderers without backdrop shaders draw instead. The
/// fill follows the opacity, and the edge and icon circles fade with it, so
/// a fully transparent chip leaves only its content.
class GlassPalette {
  GlassPalette(this.opacity, {this.blur = 0})
    : fill = const Color(0xFF1C1C1E).withValues(alpha: opacity),
      edge = Colors.white.withValues(alpha: .16 * opacity),
      circle = Colors.white.withValues(
        alpha: .14 * (opacity / .7).clamp(0.0, 1.0),
      ),
      ring = Colors.white.withValues(
        alpha: .26 * (opacity / .5).clamp(0.0, 1.0),
      );

  final double opacity;
  final Color fill, edge, circle;

  /// How much the glass blurs the scene behind it, as a blur sigma in
  /// logical pixels. The engine's blur runs before the glass shader, which
  /// costs a fast device next to nothing and a slow one a quarter of its
  /// frames, so it stays 0 there and the shader's own light frosting is
  /// all.
  final double blur;

  /// The thin light ring around an icon's disc, like the chip's own rim.
  final Color ring;

  /// An icon's disc: a translucent circle inside a light ring.
  BoxDecoration disc(double scale) => BoxDecoration(
    color: circle,
    shape: BoxShape.circle,
    border: Border.all(color: ring, width: 1.2 * scale),
  );

  /// Light catching the top of the glass: a faint sheen that fades out
  /// toward the bottom of each chip.
  Color get sheen => Color.alphaBlend(
    Colors.white.withValues(alpha: .12 * (opacity / .5).clamp(0.0, 1.0)),
    fill,
  );

  /// The tinted chip. A StadiumBorder keeps the radius at half the chip's
  /// own height; an oversized corner radius once froze Impeller's raster
  /// thread.
  ShapeDecoration get decoration => ShapeDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [sheen, fill],
      stops: const [0, .6],
    ),
    shape: StadiumBorder(side: BorderSide(color: edge)),
  );
}

/// A chip of frosted glass over the scene under a thin light rim.
/// Renderers without backdrop shaders, the moments before the shader loads
/// and a fully transparent [palette] show [fallback] instead. A blurred copy of the scene behind every chip would
/// cost the legacy renderer a backdrop read and blur per chip on every
/// frame. Chips under one [BackdropGroup] share a single read of the scene.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.palette,
    required this.fallback,
    required this.child,
  });
  final GlassPalette palette;
  final Widget fallback;

  /// The chip's content without any decoration: the glass draws the tint
  /// and rim itself.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (palette.opacity <= 0) return fallback;
    return FutureBuilder<ui.FragmentProgram?>(
      future: _glassProgram,
      builder: (context, snapshot) {
        final program = snapshot.data;
        if (program == null) return fallback;
        return ClipPath(
          clipper: const ShapeBorderClipper(shape: StadiumBorder()),
          child: _GlassBackdrop(
            program: program,
            tint: palette.opacity,
            blur: palette.blur,
            backdropKey: BackdropGroup.of(context)?.backdropKey,
            child: child,
          ),
        );
      },
    );
  }
}

class _GlassBackdrop extends SingleChildRenderObjectWidget {
  const _GlassBackdrop({
    required this.program,
    required this.tint,
    required this.blur,
    required this.backdropKey,
    super.child,
  });
  final ui.FragmentProgram program;
  final double tint, blur;
  final BackdropKey? backdropKey;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassBackdrop(program.fragmentShader(), tint, blur, backdropKey);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGlassBackdrop renderObject,
  ) => renderObject
    ..tint = tint
    ..blur = blur
    ..backdropKey = backdropKey;
}

/// Paints its child over the glass. The shader needs the chip's place on
/// screen, which is only known once it paints.
class _RenderGlassBackdrop extends RenderProxyBox {
  _RenderGlassBackdrop(this._shader, this._tint, this._blur, this._backdropKey);
  final ui.FragmentShader _shader;
  double _tint, _blur;
  BackdropKey? _backdropKey;

  set blur(double value) {
    if (value == _blur) return;
    _blur = value;
    markNeedsPaint();
  }

  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  set tint(double value) {
    if (value == _tint) return;
    _tint = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    // The backdrop is in the view's device pixels. The root view's own
    // ratio applies here: the MediaQuery ratio below a UI scale exemption
    // differs from it.
    RenderObject root = this;
    while (root.parent != null) {
      root = root.parent!;
    }
    final ratio = root is RenderView
        ? root.configuration.devicePixelRatio
        : 1.0;
    final rect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    _shader
      ..setFloat(2, rect.left * ratio)
      ..setFloat(3, rect.top * ratio)
      ..setFloat(4, rect.width * ratio)
      ..setFloat(5, rect.height * ratio)
      ..setFloat(6, _tint)
      ..setFloat(7, rect.height / size.height * ratio);
    final layer = (this.layer as BackdropFilterLayer?) ?? BackdropFilterLayer();
    layer
      ..filter = _blur > 0
          ? ui.ImageFilter.compose(
              outer: ui.ImageFilter.shader(_shader),
              inner: ui.ImageFilter.blur(
                sigmaX: _blur,
                sigmaY: _blur,
                tileMode: TileMode.clamp,
              ),
            )
          : ui.ImageFilter.shader(_shader)
      ..backdropKey = _backdropKey;
    this.layer = layer;
    context.pushLayer(layer, super.paint, offset);
  }

  @override
  void dispose() {
    _shader.dispose();
    super.dispose();
  }
}
