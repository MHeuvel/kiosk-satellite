// Shared by the Ink Blobs fluid passes (a port of the Voice Satellite
// skin's WebGL simulation, itself adapted from Pavel Dobryakov's
// WebGL-Fluid-Simulation, MIT License).
//
// Coordinates follow the original's GL convention: gl.y runs up. Stored
// images are in screen order (row 0 at the top), and some backends sample
// offscreen images upside down, which flipY undoes.
//
// Flutter renders into 8-bit images, where the original used half-float
// textures, so the signed fields are packed: a scalar into 24 bits of RGB,
// the velocity into 12 bits per component. Alpha stays 1 so nothing is
// ever premultiplied. Packed images are sampled nearest; where the original
// relied on linear filtering the helpers below filter by hand.

// Every pass targets a [size] texel field and shares flipY; they come
// first in each pass's uniforms. Skia's shading language takes no
// samplers as function parameters, so the sampling helpers are macros.
uniform vec2 size;
uniform float flipY;

const float VEL_RANGE = 1200.0;
const float SCALAR_RANGE = 16384.0;

vec2 glUv(vec2 fragCoord) {
  vec2 p = fragCoord / size;
  return vec2(p.x, 1.0 - p.y);
}

// A gl position as the uv to sample a stored image at.
vec2 imageUv(vec2 gl) {
  vec2 u = vec2(gl.x, 1.0 - gl.y);
  u.y = mix(u.y, 1.0 - u.y, flipY);
  return u;
}

vec4 encodeScalar(float v) {
  float n = floor(clamp(v / (2.0 * SCALAR_RANGE) + 0.5, 0.0, 1.0) * 16777215.0 + 0.5);
  float r = floor(n / 65536.0);
  float g = floor((n - r * 65536.0) / 256.0);
  float b = n - r * 65536.0 - g * 256.0;
  return vec4(r / 255.0, g / 255.0, b / 255.0, 1.0);
}

float decodeScalar(vec4 c) {
  vec3 b = floor(c.rgb * 255.0 + 0.5);
  float n = b.r * 65536.0 + b.g * 256.0 + b.b;
  return (n / 16777215.0 - 0.5) * 2.0 * SCALAR_RANGE;
}

vec4 encodeVelocity(vec2 v) {
  vec2 n = floor(clamp(v / (2.0 * VEL_RANGE) + 0.5, 0.0, 1.0) * 4095.0 + 0.5);
  float r = floor(n.x / 16.0);
  float hi = floor(n.y / 256.0);
  float g = (n.x - r * 16.0) * 16.0 + hi;
  float b = n.y - hi * 256.0;
  return vec4(r / 255.0, g / 255.0, b / 255.0, 1.0);
}

vec2 decodeVelocity(vec4 c) {
  vec3 b = floor(c.rgb * 255.0 + 0.5);
  float lo = floor(b.g / 16.0);
  float nx = b.r * 16.0 + lo;
  float ny = (b.g - lo * 16.0) * 256.0 + b.b;
  return (vec2(nx, ny) / 4095.0 - 0.5) * 2.0 * VEL_RANGE;
}

// The uv of the texel of a [res] texel field at an index, clamped to the
// edge like the original's CLAMP_TO_EDGE.
vec2 texelUv(vec2 index, vec2 res) {
  return imageUv((clamp(index, vec2(0.0), res - 1.0) + 0.5) / res);
}

// The texel nearest a gl position.
#define SAMPLE_GL(s, gl) texture(s, imageUv(gl))
#define VELOCITY_AT(s, gl, res) decodeVelocity(texture(s, texelUv(floor((gl) * (res)), res)))
#define SCALAR_AT(s, gl, res) decodeScalar(texture(s, texelUv(floor((gl) * (res)), res)))

// Linear filtering of the packed velocity, as the original's LINEAR
// sampler did.
vec2 bilinearVelocity(vec4 a, vec4 b, vec4 c, vec4 d, vec2 f) {
  return mix(
    mix(decodeVelocity(a), decodeVelocity(b), f.x),
    mix(decodeVelocity(c), decodeVelocity(d), f.x),
    f.y);
}
#define VELOCITY_LINEAR(s, gl, res) bilinearVelocity( \
  texture(s, texelUv(floor((gl) * (res) - 0.5), res)), \
  texture(s, texelUv(floor((gl) * (res) - 0.5) + vec2(1.0, 0.0), res)), \
  texture(s, texelUv(floor((gl) * (res) - 0.5) + vec2(0.0, 1.0), res)), \
  texture(s, texelUv(floor((gl) * (res) - 0.5) + vec2(1.0, 1.0), res)), \
  fract((gl) * (res) - 0.5))

// Rounds a premultiplied dye value to 8 bits stochastically, so the slow
// dissipation still fades it on average (plain rounding would stall it).
// The noise is Dave Hoskins' hash without sine, cheap on small GPUs.
vec4 ditherDye(vec4 v, vec2 fragCoord, float seed) {
  vec4 x = clamp(v, 0.0, 1.0) * 255.0;
  vec4 p = fract((fragCoord + seed).xyxy * vec4(0.1031, 0.1030, 0.0973, 0.1099));
  p += dot(p, p.wzxy + 33.33);
  vec4 r = fract((p.xxyz + p.yzzw) * p.zywx);
  return (floor(x) + step(r, fract(x))) / 255.0;
}
