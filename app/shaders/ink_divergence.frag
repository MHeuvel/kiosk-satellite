#version 460 core
#include <flutter/runtime_effect.glsl>
#include "ink_common.glsl"
// DIV_FRAG, with the original's reflecting walls.
uniform sampler2D uVelocity;
out vec4 fragColor;

void main() {
  vec2 gl = glUv(FlutterFragCoord().xy);
  vec2 t = 1.0 / size;
  vec2 vL = gl - vec2(t.x, 0.0);
  vec2 vR = gl + vec2(t.x, 0.0);
  vec2 vT = gl + vec2(0.0, t.y);
  vec2 vB = gl - vec2(0.0, t.y);
  float L = VELOCITY_AT(uVelocity, vL, size).x;
  float R = VELOCITY_AT(uVelocity, vR, size).x;
  float T = VELOCITY_AT(uVelocity, vT, size).y;
  float B = VELOCITY_AT(uVelocity, vB, size).y;
  vec2 C = VELOCITY_AT(uVelocity, gl, size);
  if (vL.x < 0.0) L = -C.x;
  if (vR.x > 1.0) R = -C.x;
  if (vT.y > 1.0) T = -C.y;
  if (vB.y < 0.0) B = -C.y;
  fragColor = encodeScalar(0.5 * (R - L + T - B));
}
