#version 460 core
#include <flutter/runtime_effect.glsl>
// Crossfades two premultiplied cloud keyframes. Each one first slides to
// where the clouds it shows have moved since it was rendered, so wind
// driven clouds glide between keyframes instead of fading from one place
// to the next.
uniform vec2 size;
uniform float amount;
// Some backends sample offscreen images upside down.
uniform float flipY;
// How far each keyframe's cloud volume has moved since it was rendered, in
// xyz. Impeller pads a vec3 uniform to four floats, so these are vec4.
uniform vec4 previousShift;
// Where the screen sits inside each keyframe, which can reach past the
// screen's edges: scale, then offset, in texture coordinates.
uniform vec4 previousWindow;
uniform vec4 nextShift;
uniform vec4 nextWindow;
uniform sampler2D previous;
uniform sampler2D next;
// How high the visible cloud is across each keyframe, as (height - 1) / 2.
uniform sampler2D previousHeight;
uniform sampler2D nextHeight;
out vec4 fragColor;

// Where a keyframe shows a view position, before any movement.
vec2 place(vec2 view,vec4 window) {
  vec2 uv=clamp(vec2(view.x,1.-view.y)*window.xy+window.zw,0.,1.);
  uv.y=mix(uv.y,1.-uv.y,flipY);
  return uv;
}

// Where a keyframe saw what the view shows now, for cloud at this height.
vec2 shifted(vec2 view,vec4 shift,vec4 window,float height) {
  // Follow the cloud shader's view ray to that height, step back by the
  // shift and find where the keyframe saw that point.
  float aspect=size.x/size.y;
  vec3 ray=vec3((view.x-.5)*aspect*.9,.28+view.y*.9,1.35);
  vec3 point=ray*(height/ray.y)-shift.xyz;
  point*=1.35/point.z;
  return place(vec2(point.x/(.9*aspect)+.5,(point.y-.28)/.9),window);
}

void main() {
  vec2 pixel=FlutterFragCoord().xy/size;
  vec2 view=vec2(pixel.x,1.-pixel.y);
  // Low clouds cross the screen faster than high ones. Take the height
  // here, then again where that puts the cloud's origin.
  float height=1.+2.*texture(previousHeight,place(view,previousWindow)).r;
  height=1.+2.*texture(previousHeight,shifted(view,previousShift,previousWindow,height)).r;
  vec4 before=texture(previous,shifted(view,previousShift,previousWindow,height));
  height=1.+2.*texture(nextHeight,place(view,nextWindow)).r;
  height=1.+2.*texture(nextHeight,shifted(view,nextShift,nextWindow,height)).r;
  vec4 after=texture(next,shifted(view,nextShift,nextWindow,height));
  fragColor=mix(before,after,amount);
}
