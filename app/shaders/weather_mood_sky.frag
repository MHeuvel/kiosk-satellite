#version 460 core
#include "weather_mood_common.glsl"
    void main() {
      vec2 pixel=FlutterFragCoord().xy;
      vec2 uv=vec2(pixel.x/resolution.x,1.-pixel.y/resolution.y);
      float night=weather.y;
      float wet=weather.z;
      float fog=weather.w;
      vec2 screen=vec2((uv.x-.5)*resolution.x/resolution.y,uv.y);
      vec3 ray=normalize(vec3(screen.x*.9,.28+uv.y*.9,1.35));
      float aspect=resolution.x/resolution.y;
      vec2 lightCenter=vec2(.17*aspect,.76);
      vec3 sunDir=normalize(vec3(lightCenter.x*.9,.28+lightCenter.y*.9,1.35));
      float sunDistance=length(screen-lightCenter);
      vec3 sky=mix(vec3(.60,.78,.91),vec3(.075,.32,.63),pow(uv.y,.55));
      sky=mix(sky,mix(vec3(.31,.39,.48),vec3(.12,.18,.26),uv.y),weather.x*.53+wet*.28);
      vec3 nightSky=mix(vec3(.080,.086,.102),vec3(.014,.017,.024),uv.y);
      sky=mix(sky,nightSky,night);
      sky*=1.-storm*.30;
      float sunVisibility=(1.-night)*(1.-wet)*(1.-snowfall)*(1.-storm);
      float warmth=.985+.015*sin(time*.21);
      sky+=vec3(1.,.76,.43)*exp(-sunDistance*sunDistance/.065)*.12*sunVisibility;
      float halo=exp(-sunDistance*sunDistance/.008)*.48*sunVisibility*warmth;
      sky=mix(sky,vec3(1.,.95,.82),halo);
      float sun=exp(-sunDistance*sunDistance/.0016)*sunVisibility;
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
      sky+=vec3(.47,.48,.52)*exp(-moonDistance*.82)*night*.48;
      vec3 celestial=mix(sky,vec3(1.,.99,.94),sun);
      celestial=mix(celestial,moonColor,moonMask*night);
      fragColor=vec4(clamp(celestial,0.,1.),1.);
    }
