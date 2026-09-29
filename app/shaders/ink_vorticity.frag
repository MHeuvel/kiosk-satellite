#version 460 core
#include <flutter/runtime_effect.glsl>
#include "ink_common.glsl"
// VORT_FRAG: vorticity confinement.
uniform float curl;
uniform float dt;
uniform sampler2D uVelocity;
uniform sampler2D uCurl;
out vec4 fragColor;

void main() {
  vec2 gl = glUv(FlutterFragCoord().xy);
  vec2 t = 1.0 / size;
  float L = SCALAR_AT(uCurl, gl - vec2(t.x, 0.0), size);
  float R = SCALAR_AT(uCurl, gl + vec2(t.x, 0.0), size);
  float T = SCALAR_AT(uCurl, gl + vec2(0.0, t.y), size);
  float B = SCALAR_AT(uCurl, gl - vec2(0.0, t.y), size);
  float C = SCALAR_AT(uCurl, gl, size);
  vec2 force = 0.5 * vec2(abs(T) - abs(B), abs(R) - abs(L));
  force /= length(force) + 0.0001;
  force *= curl * C;
  force.y *= -1.0;
  vec2 v = VELOCITY_AT(uVelocity, gl, size) + force * dt;
  fragColor = encodeVelocity(clamp(v, -1000.0, 1000.0));
}
