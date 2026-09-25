#version 460 core
#include "weather_mood_common.glsl"
    void main() {
      vec2 pixel=FlutterFragCoord().xy+tileOffset;
      vec2 uv=vec2(pixel.x/resolution.x,1.-pixel.y/resolution.y);
      float night=weather.y*(1.-twilight);
      float wet=weather.z;
      float fog=weather.w;
      vec2 screen=vec2((uv.x-.5)*resolution.x/resolution.y,uv.y);
      vec3 ray=normalize(vec3(screen.x*.9,.28+uv.y*.9,1.35));
      float aspect=resolution.x/resolution.y;
      vec2 lightCenter=weatherLightCenter(aspect);
      vec3 sunDir=normalize(vec3(lightCenter.x*.9,.28+lightCenter.y*.9,1.35));
      float sunDistance=length(screen-lightCenter);
      vec3 sky=mix(vec3(.60,.78,.91),vec3(.075,.32,.63),pow(uv.y,.55));
      sky=mix(sky,mix(vec3(.31,.39,.48),vec3(.12,.18,.26),uv.y),weather.x*.53+wet*.28);
      vec3 nightSky=mix(vec3(.080,.086,.102),vec3(.014,.017,.024),uv.y);
      sky=mix(sky,nightSky,night);
      // Keep blue overhead, with a pastel glow near the horizon and low sun.
      vec3 warmSky=mix(vec3(.66,.77,.86),vec3(.13,.32,.57),pow(uv.y,.65));
      float horizon=1.-smoothstep(.02,.55,uv.y);
      float sunsetGlow=exp(-sunDistance*sunDistance/.36);
      float warmBand=clamp(horizon*(.50+.22*sunsetGlow)+sunsetGlow*.14,0.,1.);
      warmSky=mix(warmSky,vec3(.98,.69,.48),warmBand);
      vec3 overcastWarm=mix(vec3(.53,.53,.55),vec3(.19,.26,.36),uv.y);
      warmSky=mix(warmSky,overcastWarm,weather.x*.45+wet*.25);
      sky=mix(sky,warmSky,twilight);
      sky*=1.-storm*.30;
      float sunVisibility=(1.-night)*(1.-wet)*(1.-snowfall)*(1.-storm);
      float warmth=.985+.015*sin(time*.21);
      // Forward scattering pales the sky around the sun.
      sky=mix(sky,mix(vec3(.92,.96,1.),vec3(1.,.87,.68),twilight),exp(-sunDistance/.2)*.28*sunVisibility);
      sky+=mix(vec3(1.,.76,.43),vec3(1.,.68,.38),twilight)*exp(-sunDistance*sunDistance/.108)*.12*sunVisibility;
      // Glare keeps a long faint tail around the sun.
      float halo=exp(-sunDistance/.065)*.34*sunVisibility*warmth;
      sky=mix(sky,mix(vec3(1.,.96,.86),vec3(1.,.81,.54),twilight),halo);
      // Light clips to white at the disk and falls off steeply but without
      // a visible edge, like an overexposed photo.
      float bloom=exp(-max(sunDistance-.016,0.)/.013)*sunVisibility*warmth;
      sky+=mix(vec3(1.,.95,.84),vec3(1.,.84,.6),twilight)*bloom*1.1;
      float sun=(1.-smoothstep(.009,.021,sunDistance))*sunVisibility;
      vec2 moonP=(screen-lightCenter)/.032;
      float moonDistance=length(moonP);
      float moonMask=1.-smoothstep(.97,1.02,moonDistance);
      vec3 moonColor=vec3(0.);
      if(night>.001 && moonMask>.001) {
      float crater=fbm(vec3(moonP*4.,8.));
      vec3 normal=vec3(moonP,sqrt(max(0.,1.-dot(moonP,moonP))));
      float moonLight=clamp(dot(normal,normalize(vec3(-.55,.15,1.))),0.,1.);
      moonColor=vec3(.98,.99,1.)*(.83+crater*.17)*(.78+moonLight*.22);
      }
      float moonBloom=exp(-sunDistance*sunDistance/.009)*.28
        +exp(-sunDistance*sunDistance/.055)*.065;
      sky+=vec3(.96,.97,1.)*moonBloom*night;
      // The disk is never dimmer than the bloom it sits in, which already clips
      // to white near a low sun.
      vec3 celestial=mix(sky,max(sky,mix(vec3(1.,1.,.98),vec3(1.,.93,.76),twilight)),sun);
      celestial=mix(celestial,moonColor,moonMask*night);
      fragColor=vec4(clamp(celestial,0.,1.),1.);
    }
