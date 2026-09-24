#version 460 core
#include <flutter/runtime_effect.glsl>
// A glass chip over the Weather Mood scene: the backdrop refracts near the
// rounded edge like a lens, with a slight color split, under a bright rim
// that catches the light from the top left. The middle stays clear.
uniform vec2 uSize;
// The chip in the backdrop's pixels: left, top, width, height.
uniform vec4 uRect;
// Darkening from Background opacity, 0 to 1.
uniform float uTint;
// Device pixels per logical pixel, so the effect keeps its size.
uniform float uScale;
uniform sampler2D uBackdrop;
out vec4 fragColor;

vec3 backdrop(vec2 pixel) {
  vec2 uv = clamp(pixel / uSize, vec2(0.), vec2(1.));
#ifdef IMPELLER_TARGET_OPENGLES
  // The input texture is stored upside down on OpenGL ES.
  uv.y = 1. - uv.y;
#endif
  return texture(uBackdrop, uv).rgb;
}

void main() {
  vec2 pixel = FlutterFragCoord().xy;
  // The engine may hand over only the clipped chip or the whole backdrop.
  bool cropped = abs(uSize.x - uRect.z) < 4. && abs(uSize.y - uRect.w) < 4.;
  vec2 origin = cropped ? vec2(0.) : uRect.xy;
  vec2 halfSize = uRect.zw * .5;
  vec2 center = origin + halfSize;
  float radius = halfSize.y;
  // Distance to the stadium's outline and the outward normal there.
  float spine = max(halfSize.x - radius, 0.);
  vec2 nearest = vec2(clamp(pixel.x, center.x - spine, center.x + spine), center.y);
  vec2 away = pixel - nearest;
  float reach = length(away);
  vec2 normal = reach > .001 ? away / reach : vec2(0., -1.);
  float depth = radius - reach;
  if (depth < 0.) {
    fragColor = vec4(backdrop(pixel), 1.);
    return;
  }
  // Refraction: a rounded rim bends the view inward, strongest at the edge.
  float bevel = min(radius * .75, 22. * uScale);
  float rim = 1. - clamp(depth / bevel, 0., 1.);
  float bend = rim * rim * bevel * .55;
  vec2 shift = -normal * bend;
  vec3 color = vec3(
    backdrop(pixel + shift * 1.12).r,
    backdrop(pixel + shift).g,
    backdrop(pixel + shift * .88).b
  );
  // A touch of softening through the glass.
  float soft = 1.6 * uScale;
  color = color * .4 + (
    backdrop(pixel + shift + vec2(soft, 0.)) +
    backdrop(pixel + shift - vec2(soft, 0.)) +
    backdrop(pixel + shift + vec2(0., soft)) +
    backdrop(pixel + shift - vec2(0., soft))
  ) * .15;
  // Tint for legibility, then a faint lift like light passing through.
  color = mix(color, vec3(.06, .07, .09), uTint * .75);
  color += .035;
  // Specular rim: a thin line of light, brightest facing the top left.
  vec2 light = normalize(vec2(-.55, -.85));
  float facing = max(dot(normal, light), 0.);
  float back = max(dot(normal, -light), 0.);
  float line = exp(-pow(depth / (1.4 * uScale), 2.));
  float glow = exp(-depth / (7. * uScale));
  color += vec3(1.) * (line * (.12 + .3 * facing + .1 * back) +
                       glow * (.12 * facing + .04 * back));
  fragColor = vec4(clamp(color, 0., 1.), 1.);
}
