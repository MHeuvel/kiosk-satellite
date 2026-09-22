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
      vec3 color=vec3(0.);
      float transmission=1.;
      float start=1.16/ray.y;
      float end=2.54/ray.y;
      float stride=(end-start)/float(CLOUD_STEPS);
      cloudFootprint=stride*2.1;
      vec3 cloudColor=vec3(0.);
      for(int i=0;i<CLOUD_STEPS;i++) {
        if(weather.x<.001) break;
        // Independently stagger each sample to break coherent cloud bands.
        float offset=hash(vec2(pixel.x,resolution.y-pixel.y)+vec2(float(i)*31.7,float(i)*17.3));
        vec3 p=ray*(start+(float(i)+offset)*stride);
        float d=density(p);
        if(d>.005) {
          float shade=density(p+sunDir*.26);
          float light=exp(-shade*1.9);
          vec3 ambient=mix(vec3(.30,.38,.49),vec3(.59,.65,.72),smoothstep(1.2,2.5,p.y));
          ambient=mix(ambient,vec3(.68,.73,.79),(1.-smoothstep(.10,.40,weather.x))*.75);
          vec3 direct=vec3(1.0,.94,.83)*light*.56;
          vec3 lit=ambient+direct;
          lit=mix(lit,lit*vec3(.48,.56,.66),wet*.7);
          lit=mix(lit,lit*vec3(.185,.195,.215),night);
          lit*=1.-storm*.36;
          float alpha=1.-exp(-d*stride*3.2);
          cloudColor+=transmission*alpha*lit;
          transmission*=1.-alpha;
          if(transmission<.012) break;
        }
      }
      color=cloudColor;
      // Fog fills the view with overlapping banks instead of a flat tint.
      float mist=fbm(vec3(screen.x*2.-time*.018,uv.y*3.,time*.009));
      float veil=fog*(.68+.24*mist);
      vec3 fogColor=mix(vec3(.48,.57,.64),vec3(.80,.84,.86),uv.y*.55+mist*.45);
      fogColor=mix(fogColor,fogColor*vec3(.25,.255,.27),night);
      color=mix(color,fogColor,veil);
      float flashDistance=length(vec2((uv.x-flashPosition.x)*aspect,uv.y-flashPosition.y));
      float illumination=flash*(.035+.60*exp(-flashDistance*flashDistance/.42));
      color=mix(color,vec3(.55,.62,1.),illumination);
      vec3 hailTint=mix(vec3(.75,.77,.79),vec3(.177,.183,.195),night);
      color=mix(color,hailTint,effects.w*(.17+.12*mist));
      float rainVeil=effects.y*(.025+.045*mist);
      color=mix(color,mix(vec3(.41,.49,.57),vec3(.174,.181,.196),night),rainVeil);
      color=clamp(color,0.,1.);
      // Premultiplied atmosphere lets the native sky show through cloud gaps.
      float visibility=transmission*(1.-veil)*(1.-illumination)*(1.-effects.w*(.17+.12*mist))*(1.-rainVeil);
      fragColor=vec4(min(color,vec3(1.-visibility)),1.-visibility);
    }
