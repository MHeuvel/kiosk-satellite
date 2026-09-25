#include <flutter/runtime_effect.glsl>
uniform vec2 resolution;
uniform float time;
uniform vec4 weather;
uniform float snowfall;
uniform vec4 effects;
uniform float storm;
uniform float windTime;
uniform float flash;
uniform vec2 flashPosition;
uniform float twilight;
// Offsets a band rendered on its own so it lines up with the full image.
uniform vec2 tileOffset;
// Where the scene has carried each scattered cumulus from its resting spot,
// in xyz. Impeller pads a vec3 uniform to four floats, so this is a vec4.
uniform vec4 cumulusSlide;
// The same for the second clouds in the left and near lanes, in xy.
uniform vec4 cumulusCopy;
uniform sampler2D noiseMap;
out vec4 fragColor;
    float cloudFootprint;
    vec2 weatherLightCenter(float aspect) {
      return vec2(.34*aspect,mix(.76,.28,twilight));
    }
    float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float noise(vec3 p) {
      vec3 i=floor(p), f=fract(p);
      f=f*f*(3.-2.*f);
      vec2 st=i.xy+vec2(37.,17.)*i.z+f.xy;
      vec2 n=texture(noiseMap,fract((st+.5)/256.)).rg;
      return mix(n.r,n.g,f.z);
    }
    float fbm(vec3 p) {
      return noise(p)*.45 + noise(p*2.02+13.1)*.28 + noise(p*4.03+27.7)*.17 + noise(p*8.07+9.2)*.10;
    }
    float softUnion(float a,float b) {
      float h=max(.30-abs(a-b),0.)/.30;
      return min(a,b)-h*h*.075;
    }
    // A cumulus at center. Its seed picks its shape, so two clouds of the
    // same size can differ.
    float cumulus(vec3 p,vec3 center,float size,vec3 proportions,vec3 seed) {
      vec3 q=(p-center)/(size*proportions);
      if(any(greaterThan(abs(q),vec3(1.9,1.6,1.5)))) return 0.;
      float variation=hash(seed.xz);
      float leftShape=hash(seed.xz+13.);
      float rightShape=hash(seed.xz+39.);
      float evolution=time*.009;
      q.x+=(noise(q*1.7+seed+evolution)-.5)*.30;
      q.y+=(noise(q*2.1+seed*3.-evolution)-.5)*.18;
      float base=length(q/vec3(1.0,.29,.55))-1.;
      float left=length((q-vec3(-.60+leftShape*.18,.08+leftShape*.31,.02))/vec3(.37+leftShape*.28,.29+leftShape*.31,.53))-1.;
      float top=length((q-vec3(-.35+variation*.65,.20+variation*.20,-.03))/vec3(.39+variation*.20,.38+variation*.26,.59))-1.;
      float right=length((q-vec3(.43+rightShape*.22,.06+rightShape*.30,.04))/vec3(.34+rightShape*.31,.26+rightShape*.26,.49))-1.;
      float shape=softUnion(softUnion(base,left),softUnion(top,right));
      float detail=noise(q*4.3+seed*7.)*.65+noise(q*8.1+23.)*.35;
      shape+=(detail-.5)*.85;
      float billows=.20+noise(q*3.1+seed*5.)*.95;
      return (1.-smoothstep(-.42,.34,shape))*smoothstep(-.44,-.12,q.y)*billows;
    }
    float density(vec3 p) {
      float sparse=0.;
      if(weather.x<.40) {
        vec3 drift=p-vec3(0.,0.,sin((time-18.)*.009)*.17);
        float spread=1.+.12*smoothstep(.065,.10,weather.x);
        vec3 left=vec3(-1.18,1.55,3.5),far=vec3(1.65,1.52,5.7),near=vec3(.72,1.52,2.6);
        sparse=cumulus(drift-vec3(cumulusSlide.x,0.,0.),left,.62*spread,vec3(1.18,.61,.92),left);
        sparse+=cumulus(drift-vec3(cumulusSlide.y,0.,0.),far,.74*spread,vec3(1.36,.38,.76),far);
        sparse+=cumulus(drift-vec3(cumulusSlide.z,0.,0.),near,.37*spread,vec3(.88,.96,1.05),near);
        // A windy sky carries a second cloud half a loop behind the first in
        // the two lanes above the weather bar, so one always comes in as the
        // other leaves. Fuller skies drop them for the calm layout.
        float windy=1.-smoothstep(.065,.10,weather.x);
        if(windy>.001) {
          float extra=cumulus(drift-vec3(cumulusCopy.x,0.,0.),left,.62*spread,vec3(1.18,.61,.92),left+vec3(7.3,0.,3.1));
          extra+=cumulus(drift-vec3(cumulusCopy.y,0.,0.),near,.37*spread,vec3(.88,.96,1.05),near+vec3(5.9,0.,2.3));
          sparse+=extra*windy;
        }
        sparse*=smoothstep(0.,.05,weather.x);
        if(weather.x<=.10) return sparse;
      }
      float band=smoothstep(1.15,1.42,p.y)*(1.-smoothstep(2.05,2.55,p.y));
      vec3 q=mat3(.80,-.48,.36,.60,.64,-.48,0.,.60,.80)*(p*2.1)+vec3(time*.032,0.,time*.014);
      q.x+=windTime*.17;
      // Filter detail finer than the distance between volume samples.
      float fine=1.-smoothstep(.10,.32,cloudFootprint);
      float shape=(noise(q)*.55+noise(q*2.02+13.1)*.30+noise(q*4.03+27.7)*.15*fine)/(.85+.15*fine);
      float threshold=mix(.64,.37,weather.x);
      threshold+=.085*(1.-smoothstep(.10,.45,weather.x));
      float overcast=smoothstep(threshold,threshold+.17,shape)*band*mix(2.8,3.5,weather.x)*smoothstep(0.,.12,weather.x);
      return mix(sparse,overcast,smoothstep(.10,.40,weather.x));
    }
