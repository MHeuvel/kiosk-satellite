#version 460 core
#include <flutter/runtime_effect.glsl>
#include "ink_common.glsl"
// CURL_FRAG.
uniform sampler2D uVelocity;
out vec4 fragColor;

void main() {
  vec2 gl = glUv(FlutterFragCoord().xy);
  vec2 t = 1.0 / size;
  float L = VELOCITY_AT(uVelocity, gl - vec2(t.x, 0.0), size).y;
  float R = VELOCITY_AT(uVelocity, gl + vec2(t.x, 0.0), size).y;
  float T = VELOCITY_AT(uVelocity, gl + vec2(0.0, t.y), size).x;
  float B = VELOCITY_AT(uVelocity, gl - vec2(0.0, t.y), size).x;
  fragColor = encodeScalar(0.5 * (R - L - T + B));
}
