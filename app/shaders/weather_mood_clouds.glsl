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
      vec3 color=vec3(0.);
      float transmission=1.;
      float start=1.16/ray.y;
      float end=2.54/ray.y;
      float stride=(end-start)/float(CLOUD_STEPS);
      cloudFootprint=stride*2.1;
      vec3 cloudColor=vec3(0.);
      float exposedCloud=0.;
      float fairCloud=(1.-smoothstep(.10,.40,weather.x))*(1.-wet)*(1.-fog);
      float backlight=.18+.82*exp(-sunDistance*sunDistance/.65);
      float twilightLight=twilight*(.20+.45*exp(-sunDistance*sunDistance/.65));
      float fairAmbient=(1.-smoothstep(.10,.40,weather.x))*.75;
      // Every lighting tint scales each sample the same way, so apply the
      // product once after the loop instead of on every sample.
      // Backlit interiors stay shaded so thin edges can catch the light.
      vec3 tint=vec3(1.-fairCloud*backlight*.26);
      tint*=mix(vec3(1.),vec3(.48,.56,.66),wet*.7);
      tint*=mix(vec3(1.),vec3(.185,.195,.215),night);
      tint*=mix(vec3(1.),vec3(1.04,.83,.71),twilightLight);
      tint*=1.-storm*.36;
#ifdef CLOUD_LOW_NOISE
      // Few steps leave visible grain. Interleaved gradient noise with a
      // golden ratio step spreads each pixel's samples evenly through the
      // cloud and pushes the remaining error to fine detail the keyframe
      // blur removes.
      float dither=fract(52.9829189*fract(dot(pixel,vec2(.06711056,.00583715))));
#endif
      if(weather.x>=.001) {
        for(int i=0;i<CLOUD_STEPS;i++) {
          // Independently stagger each sample to break coherent cloud bands.
  #ifdef CLOUD_LOW_NOISE
        float offset=fract(dither+float(i)*.618034);
#else
        float offset=hash(vec2(pixel.x,resolution.y-pixel.y)+vec2(float(i)*31.7,float(i)*17.3));
#endif
          vec3 p=ray*(start+(float(i)+offset)*stride);
          float d=density(p);
          if(d>.005) {
            float shade=density(p+sunDir*.26);
            float light=exp(-shade*1.9);
            vec3 ambient=mix(vec3(.30,.38,.49),vec3(.59,.65,.72),smoothstep(1.2,2.5,p.y));
            ambient=mix(ambient,vec3(.68,.73,.79),fairAmbient);
            vec3 direct=vec3(1.0,.94,.83)*light*.56;
            float alpha=1.-exp(-d*stride*3.2);
            cloudColor+=transmission*alpha*(ambient+direct);
            exposedCloud+=transmission*alpha*light;
            transmission*=1.-alpha;
            if(transmission<.012) break;
          }
        }
      }
      cloudColor*=tint;
      // Reuse the light samples and accumulated depth for a soft silver lining.
      // Thin cloud lets light through, while dense interiors suppress the glow.
      float silver=exposedCloud*pow(transmission,1.4)*fairCloud*backlight;
      vec3 rimColor=mix(vec3(1.,.94,.80),vec3(.96,.97,1.),night);
      rimColor=mix(rimColor,vec3(1.,.86,.69),twilightLight);
      cloudColor+=rimColor*silver*mix(1.8,.85,night);
      color=cloudColor;
      // Fog fills the view with overlapping banks instead of a flat tint.
      float mist=fbm(vec3(screen.x*2.-time*.018,uv.y*3.,time*.009));
      float veil=fog*(.68+.24*mist);
      vec3 fogColor=mix(vec3(.48,.57,.64),vec3(.80,.84,.86),uv.y*.55+mist*.45);
      fogColor=mix(fogColor,fogColor*vec3(.25,.255,.27),night);
      fogColor=mix(fogColor,fogColor*vec3(1.04,.91,.83),twilightLight);
      color=mix(color,fogColor,veil);
      // Lightning is painted over the cached clouds on every frame instead.
      vec3 hailTint=mix(vec3(.75,.77,.79),vec3(.177,.183,.195),night);
      hailTint=mix(hailTint,hailTint*vec3(1.02,.92,.84),twilightLight);
      color=mix(color,hailTint,effects.w*(.17+.12*mist));
      float rainVeil=effects.y*(.025+.045*mist);
      vec3 rainTint=mix(vec3(.41,.49,.57),vec3(.174,.181,.196),night);
      rainTint=mix(rainTint,vec3(.47,.45,.43),twilightLight);
      color=mix(color,rainTint,rainVeil);
      color=clamp(color,0.,1.);
      // Premultiplied atmosphere lets the native sky show through cloud gaps.
      float visibility=transmission*(1.-veil)*(1.-effects.w*(.17+.12*mist))*(1.-rainVeil);
      fragColor=vec4(min(color,vec3(1.-visibility)),1.-visibility);
    }
