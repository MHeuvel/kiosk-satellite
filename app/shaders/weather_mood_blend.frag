#version 460 core
#include <flutter/runtime_effect.glsl>
// Crossfades two premultiplied cloud keyframes so clouds rendered a few
// times per second still move smoothly.
uniform vec2 size;
uniform float amount;
// Some backends sample offscreen images upside down.
uniform float flipY;
uniform sampler2D previous;
uniform sampler2D next;
out vec4 fragColor;
void main() {
  vec2 uv=FlutterFragCoord().xy/size;
  uv.y=mix(uv.y,1.-uv.y,flipY);
  fragColor=mix(texture(previous,uv),texture(next,uv),amount);
}
