#version 460 core
#include <flutter/runtime_effect.glsl>
#include "ink_common.glsl"
// SPLAT_FRAG on the velocity field, for up to four jets at once: each
// adds exp(-|p|^2 / radius) times its force at its point.
uniform float aspectRatio;
uniform float radius;
uniform vec4 jet0;
uniform vec4 jet1;
uniform vec4 jet2;
uniform vec4 jet3;
uniform sampler2D uTarget;
out vec4 fragColor;

vec2 splat(vec2 gl, vec4 jet) {
  vec2 p = gl - jet.xy;
  p.x *= aspectRatio;
  return exp(-dot(p, p) / radius) * jet.zw;
}

void main() {
  vec2 gl = glUv(FlutterFragCoord().xy);
  vec2 v = VELOCITY_AT(uTarget, gl, size);
  v += splat(gl, jet0) + splat(gl, jet1) + splat(gl, jet2) + splat(gl, jet3);
  fragColor = encodeVelocity(v);
}
