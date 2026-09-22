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
uniform sampler2D noiseMap;
out vec4 fragColor;
    float cloudFootprint;
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
    float cumulus(vec3 p,vec3 center,float size,vec3 proportions) {
      vec3 q=(p-center)/(size*proportions);
      if(any(greaterThan(abs(q),vec3(1.9,1.6,1.5)))) return 0.;
      float variation=hash(center.xz);
      float leftShape=hash(center.xz+13.);
      float rightShape=hash(center.xz+39.);
      float evolution=time*.009;
      q.x+=(noise(q*1.7+center+evolution)-.5)*.30;
      q.y+=(noise(q*2.1+center*3.-evolution)-.5)*.18;
      float base=length(q/vec3(1.0,.29,.55))-1.;
      float left=length((q-vec3(-.60+leftShape*.18,.08+leftShape*.31,.02))/vec3(.37+leftShape*.28,.29+leftShape*.31,.53))-1.;
      float top=length((q-vec3(-.35+variation*.65,.20+variation*.20,-.03))/vec3(.39+variation*.20,.38+variation*.26,.59))-1.;
      float right=length((q-vec3(.43+rightShape*.22,.06+rightShape*.30,.04))/vec3(.34+rightShape*.31,.26+rightShape*.26,.49))-1.;
      float shape=softUnion(softUnion(base,left),softUnion(top,right));
      float detail=noise(q*4.3+center*7.)*.65+noise(q*8.1+23.)*.35;
      shape+=(detail-.5)*.85;
      float billows=.20+noise(q*3.1+center*5.)*.95;
      return (1.-smoothstep(-.42,.34,shape))*smoothstep(-.44,-.12,q.y)*billows;
    }
    float density(vec3 p) {
      float sparse=0.;
      if(weather.x<.40) {
        vec3 drift=p-vec3(sin((time-18.)*.016)*.65,0.,sin((time-18.)*.009)*.17);
        drift.x=mod(drift.x+windTime*.085+8.,16.)-8.;
        sparse=cumulus(drift,vec3(-1.18,1.55,3.5),.62,vec3(1.18,.61,.92));
        sparse+=cumulus(drift,vec3(1.65,1.52,5.7),.74,vec3(1.36,.38,.76));
        sparse+=cumulus(drift,vec3(.72,1.52,2.6),.37,vec3(.88,.96,1.05));
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
