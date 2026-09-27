#version 460 core
#include <flutter/runtime_effect.glsl>
#include "ink_common.glsl"
// GRAD_FRAG (subtracting the pressure gradient) and ADV_FRAG on the
// velocity itself, in one pass: the corrected velocity at each texel the
// advection reads is worked out here rather than stored.
uniform float dt;
uniform float dissipation;
uniform sampler2D uVelocity;
uniform sampler2D uPressure;
out vec4 fragColor;

vec3 raw(vec2 i) {
  return texture(uPressure, texelUv(i, size)).rgb;
}

// GRAD_FRAG at a texel, clamped to the edge. Decoding is linear, so the
// difference of two decoded pressures is the decoded difference of their
// raw colors.
vec2 corrected(vec2 i) {
  vec2 c = clamp(i, vec2(0.0), size - 1.0);
  vec3 k = vec3(255.0 * 65536.0, 255.0 * 256.0, 255.0)
    * (2.0 * SCALAR_RANGE / 16777215.0);
  vec2 gradient = vec2(
    dot(raw(c + vec2(1.0, 0.0)) - raw(c - vec2(1.0, 0.0)), k),
    dot(raw(c + vec2(0.0, 1.0)) - raw(c - vec2(0.0, 1.0)), k));
  return decodeVelocity(texture(uVelocity, texelUv(c, size))) - gradient;
}

void main() {
  vec2 gl = glUv(FlutterFragCoord().xy);
  // At the texel's own center the original's linear sampler returns the
  // texel itself.
  vec2 c = gl - dt * corrected(floor(gl * size)) / size;
  vec2 b = floor(c * size - 0.5);
  vec2 f = fract(c * size - 0.5);
  vec2 v = mix(
    mix(corrected(b), corrected(b + vec2(1.0, 0.0)), f.x),
    mix(corrected(b + vec2(0.0, 1.0)), corrected(b + vec2(1.0, 1.0)), f.x),
    f.y);
  fragColor = encodeVelocity(v / (1.0 + dissipation * dt));
}
