#version 460 core
#include <flutter/runtime_effect.glsl>
#include "ink_common.glsl"
// CLEAR_FRAG on the pressure: value times the last pressure. Also the
// identity copy used to find out whether offscreen images come back
// upside down (decoded = 0 copies the color as is).
uniform float value;
uniform float decoded;
uniform sampler2D uTexture;
out vec4 fragColor;

void main() {
  vec2 gl = glUv(FlutterFragCoord().xy);
  if (decoded < 0.5) {
    fragColor = SAMPLE_GL(uTexture, gl);
    return;
  }
  fragColor = encodeScalar(value * SCALAR_AT(uTexture, gl, size));
}
