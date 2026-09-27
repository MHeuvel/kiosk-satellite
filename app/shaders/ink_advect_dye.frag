#version 460 core
#include <flutter/runtime_effect.glsl>
#include "ink_common.glsl"
// SPLAT_FRAG on the dye for up to four jets, then ADV_FRAG on the dye
// carried by the (lower resolution) velocity, in one pass: the splats are
// added where the advection reads. The original steps by the dye's texel
// size, as here. Each jet adds exp(-|p|^2 / radius) times its
// premultiplied color at its point; idle jets add nothing and are skipped.
uniform float dt;
uniform float dissipation;
uniform vec2 velocitySize;
uniform float seed;
uniform float aspectRatio;
uniform float radius;
uniform vec4 point01;
uniform vec4 point23;
uniform vec4 color0;
uniform vec4 color1;
uniform vec4 color2;
uniform vec4 color3;
uniform sampler2D uVelocity;
uniform sampler2D uSource;
out vec4 fragColor;

vec4 splat(vec2 gl, vec2 point, vec4 color) {
  if (color.a == 0.0) return vec4(0.0);
  vec2 p = gl - point;
  p.x *= aspectRatio;
  return exp(-dot(p, p) / radius) * color;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 gl = glUv(frag);
  vec2 c = gl - dt * VELOCITY_LINEAR(uVelocity, gl, velocitySize) / size;
  vec4 d = SAMPLE_GL(uSource, c)
    + splat(c, point01.xy, color0) + splat(c, point01.zw, color1)
    + splat(c, point23.xy, color2) + splat(c, point23.zw, color3);
  fragColor = ditherDye(d / (1.0 + dissipation * dt), frag, seed);
}
