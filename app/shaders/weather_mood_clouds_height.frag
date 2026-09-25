#version 460 core
// How high the visible cloud sits along each view ray, weighted the way
// the cloud shader stacks its samples. A small image of it lets the blend
// shader slide every part of a keyframe at its own speed, since low clouds
// cross the screen faster than high ones. Stored as (height - 1) / 2.
#define CLOUD_STEPS 16
#include "weather_mood_common.glsl"
void main() {
  vec2 pixel=FlutterFragCoord().xy+tileOffset;
  vec2 uv=vec2(pixel.x/resolution.x,1.-pixel.y/resolution.y);
  vec2 screen=vec2((uv.x-.5)*resolution.x/resolution.y,uv.y);
  vec3 ray=normalize(vec3(screen.x*.9,.28+uv.y*.9,1.35));
  float start=1.16/ray.y;
  float stride=(2.54/ray.y-start)/float(CLOUD_STEPS);
  cloudFootprint=stride*2.1;
  float transmission=1.,weight=0.,height=0.;
  if(weather.x>=.001) {
    for(int i=0;i<CLOUD_STEPS;i++) {
      vec3 p=ray*(start+(float(i)+.5)*stride);
      float d=density(p);
      if(d>.005) {
        float alpha=1.-exp(-d*stride*3.2);
        weight+=transmission*alpha;
        height+=transmission*alpha*p.y;
        transmission*=1.-alpha;
        if(transmission<.012) break;
      }
    }
  }
  float y=weight>.001?height/weight:1.5;
  fragColor=vec4(clamp((y-1.)*.5,0.,1.),0.,0.,1.);
}
