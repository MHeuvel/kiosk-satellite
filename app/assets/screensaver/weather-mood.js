(() => {
  'use strict';
  const canvas = document.querySelector('#scene');
  const gl = canvas.getContext('webgl', { alpha: false, antialias: false });
  if (!gl) return;
  const rendererInfo=gl.getExtension('WEBGL_debug_renderer_info');
  const renderer=rendererInfo?String(gl.getParameter(rendererInfo.UNMASKED_RENDERER_WEBGL)):'';
  const lowPower=window.__weatherMoodLowPower===true || /Mali[- ]T\d/i.test(renderer)
    || (navigator.hardwareConcurrency>0 && navigator.hardwareConcurrency<=4);
  // Start within the budget of older GPUs before submitting the first frame.
  const quality=lowPower?{width:560,height:350,steps:40,fps:15}:{width:1100,height:720,steps:96,fps:30};
  let resolutionScale=1,slowFrames=0;
  const vertex = `
    attribute vec2 position;
    varying vec2 uv;
    void main() { uv = position*.5+.5; gl_Position=vec4(position,0.,1.); }
  `;
  const fragment = `
    precision highp float;
    varying vec2 uv;
    uniform sampler2D noiseMap;
    uniform sampler2D sceneLayer;
    uniform vec2 resolution;
    uniform float time;
    uniform vec4 weather;
    uniform float snowfall;
    uniform vec4 effects;
    uniform float storm;
    uniform float windTime;
    uniform float flash;
    uniform vec2 flashPosition;
    uniform float patchRadius;
    float cloudFootprint;
    float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float noise(vec3 p) {
      vec3 i=floor(p), f=fract(p);
      f=f*f*(3.-2.*f);
      vec2 st=i.xy+vec2(37.,17.)*i.z+f.xy;
      vec2 n=texture2D(noiseMap,(st+.5)/256.).rg;
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
    void main() {
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
      // Only a subset of stars twinkle, each at its own speed and phase.
      vec2 starP=screen*175.;
      vec2 starCell=floor(starP);
      float seed=hash(starCell);
      vec2 starCenter=.2+vec2(hash(starCell+3.),hash(starCell+11.))*.6;
      float distance=length(fract(starP)-starCenter);
      float brightness=hash(starCell+23.);
      float size=mix(.055,.115,pow(brightness,3.));
      float star=exp(-distance*distance/(size*size))*step(.991,seed);
      float twinkle=mix(1.,.70+.30*sin(time*(.65+hash(starCell+5.)*1.1)+seed*600.),step(.65,brightness));
      vec3 starColor=mix(vec3(.65,.80,1.),vec3(1.,.94,.80),hash(starCell+47.));
      sky+=starColor*star*night*(.5+brightness*.85)*twinkle;
      vec2 moonP=(screen-lightCenter)/.032;
      float moonDistance=length(moonP);
      float moonMask=1.-smoothstep(.97,1.02,moonDistance);
      float crater=fbm(vec3(moonP*4.,8.));
      vec3 normal=vec3(moonP,sqrt(max(0.,1.-dot(moonP,moonP))));
      float moonLight=clamp(dot(normal,normalize(vec3(-.55,.15,1.))),0.,1.);
      vec3 moonColor=vec3(.98,.99,1.)*(.83+crater*.17)*(.78+moonLight*.22);
      sky+=vec3(.47,.48,.52)*exp(-moonDistance*.82)*night*.48;
      if(patchRadius>0.) {
        vec3 celestial=mix(sky,vec3(1.,.99,.94),sun);
        celestial=mix(celestial,moonColor,moonMask*night);
        float coverage=texture2D(sceneLayer,uv).a;
        float feather=1.-smoothstep(.70,1.,sunDistance*resolution.y/patchRadius);
        gl_FragColor=vec4(max(vec3(0.),celestial-sky)*coverage*feather,0.);
        return;
      }
      vec3 color=sky;
      float transmission=1.;
      float start=1.16/ray.y;
      float end=2.54/ray.y;
      float stride=(end-start)/${quality.steps}.;
      cloudFootprint=stride*2.1;
      vec3 cloudColor=vec3(0.);
      for(int i=0;i<${quality.steps};i++) {
        if(weather.x<.001) break;
        // Independently stagger each sample to break coherent cloud bands.
        float offset=hash(gl_FragCoord.xy+vec2(float(i)*31.7,float(i)*17.3));
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
      color=sky*transmission+cloudColor;
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
      color+=(hash(gl_FragCoord.xy+13.)-.5)/255.;
      // Carry atmospheric visibility for the sharp celestial pass.
      float visibility=transmission*(1.-veil)*(1.-illumination)*(1.-effects.w*(.17+.12*mist))*(1.-rainVeil);
      gl_FragColor=vec4(color,visibility);
    }
  `;
  function compile(type,source) {
    const shader=gl.createShader(type);
    gl.shaderSource(shader,source);
    gl.compileShader(shader);
    if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
    return shader;
  }
  let program;
  try {
    program=gl.createProgram();
    gl.attachShader(program,compile(gl.VERTEX_SHADER,vertex));
    gl.attachShader(program,compile(gl.FRAGMENT_SHADER,fragment));
    gl.bindAttribLocation(program,0,'position');
    gl.linkProgram(program);
    if(!gl.getProgramParameter(program,gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));
  } catch(error) { console.error(error); return; }
  gl.useProgram(program);
  const buffer=gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER,buffer);
  gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);
  const position=gl.getAttribLocation(program,'position');
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position,2,gl.FLOAT,false,0,0);
  // Upscale the inexpensive scene, then refine only the small celestial area.
  const composite=gl.createProgram();
  gl.attachShader(composite,compile(gl.VERTEX_SHADER,vertex));
  gl.attachShader(composite,compile(gl.FRAGMENT_SHADER,`
    precision mediump float;
    varying vec2 uv;
    uniform sampler2D scene;
    void main() { gl_FragColor=vec4(texture2D(scene,uv).rgb,1.); }
  `));
  gl.bindAttribLocation(composite,0,'position');
  gl.linkProgram(composite);
  if(!gl.getProgramParameter(composite,gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(composite));
  gl.useProgram(composite);
  gl.uniform1i(gl.getUniformLocation(composite,'scene'),1);
  gl.useProgram(program);
  const sceneTexture=gl.createTexture();
  gl.activeTexture(gl.TEXTURE1);
  gl.bindTexture(gl.TEXTURE_2D,sceneTexture);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
  const sceneFramebuffer=gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER,sceneFramebuffer);
  gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,sceneTexture,0);
  gl.bindFramebuffer(gl.FRAMEBUFFER,null);
  gl.activeTexture(gl.TEXTURE0);
  let sceneWidth=0,sceneHeight=0;
  // Paired channels provide adjacent slices of repeatable volume noise.
  let seed=71;
  const values=new Uint8Array(256*256);
  for(let i=0;i<values.length;i++) { seed=(Math.imul(seed,1664525)+1013904223)>>>0; values[i]=seed>>>24; }
  const pixels=new Uint8Array(256*256*4);
  for(let y=0;y<256;y++) for(let x=0;x<256;x++) {
    const i=(y*256+x)*4;
    pixels[i]=values[y*256+x];
    pixels[i+1]=values[((y+17)%256)*256+(x+37)%256];
    pixels[i+2]=0;
    pixels[i+3]=255;
  }
  const texture=gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D,texture);
  gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,256,256,0,gl.RGBA,gl.UNSIGNED_BYTE,pixels);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.REPEAT);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.REPEAT);
  const uniforms=Object.fromEntries(['resolution','time','weather','snowfall','effects','storm','windTime','flash','flashPosition','noiseMap','sceneLayer','patchRadius'].map(name=>[name,gl.getUniformLocation(program,name)]));
  gl.uniform1i(uniforms.noiseMap,0);
  gl.uniform1i(uniforms.sceneLayer,1);
  const presets={
    clear:{values:[0,0,0,0,0]},
    partlycloudy:{values:[.065,0,0,0,0]},
    cloudy:{values:[.68,0,0,0,0]},
    rainy:{values:[.95,0,1,0,0]},
    snowy:{values:[.77,0,0,0,1]},
    fog:{values:[.7,0,0,1,0]},
    pouring:{values:[1,0,1,0,0,.24,1,0,0,.55]},
    'snowy-rainy':{values:[.88,0,.62,0,.75,.08,0,0,0,.12]},
    windy:{values:[.065,0,0,0,0,1,0,0,0,0]},
    'windy-variant':{values:[.87,0,0,0,0,1,0,0,0,.12]},
    lightning:{values:[.98,0,0,0,0,.20,0,1,0,.68]},
    'lightning-rainy':{values:[1,0,1,0,0,.32,.36,1,0,.68]},
    hail:{values:[.94,0,0,0,0,.14,0,0,1,.44]},
    exceptional:{values:[.48,0,0,0,0,0,0,0,0,0]}
  };
  // Values hold cloud cover, night, rain, fog, snow, wind, downpour, lightning, hail and storm darkness.
  for(const preset of Object.values(presets)) while(preset.values.length<10) preset.values.push(0);
  const conditionModes=Object.fromEntries(['sunny','clear-night','partlycloudy','cloudy','rainy','pouring','snowy','snowy-rainy','fog','hail','lightning','lightning-rainy','windy','windy-variant','exceptional'].map(condition=>[condition,['sunny','clear-night'].includes(condition)?'clear':condition]));
  const state={ready:true,paused:matchMedia('(prefers-reduced-motion: reduce)').matches,time:18,windTime:0,stormStart:18,forcedStrike:null,strikeSerial:0,mode:'exceptional',period:'day',current:[...presets.exceptional.values],frames:0};
  const particleCanvas=document.querySelector('#particles');
  const particleContext=particleCanvas.getContext('2d');
  let particleSeed=9127;
  function random() { particleSeed=(Math.imul(particleSeed,1664525)+1013904223)>>>0; return particleSeed/4294967296; }
  function field(count) {
    return Array.from({length:count},()=>({x:random(),y:random(),depth:random(),phase:random()*Math.PI*2,variation:random(),drift:random()}));
  }
  const rainParticles=field(620),snowParticles=field(180),motes=field(32);
  const nearRainParticles=field(30),nearSnowParticles=field(24);
  rainParticles.push(...field(650));
  nearRainParticles.push(...field(24));
  const hailParticles=field(240),windParticles=field(80);
  const nearHailParticles=field(32);
  const flake=document.createElement('canvas');
  flake.width=flake.height=48;
  const flakeContext=flake.getContext('2d');
  const flakeGradient=flakeContext.createRadialGradient(24,24,0,24,24,24);
  flakeGradient.addColorStop(0,'rgba(248,251,255,.95)');
  flakeGradient.addColorStop(.28,'rgba(240,246,255,.85)');
  flakeGradient.addColorStop(.6,'rgba(230,240,255,.40)');
  flakeGradient.addColorStop(1,'rgba(230,240,255,0)');
  flakeContext.fillStyle=flakeGradient;
  flakeContext.fillRect(0,0,48,48);
  const defocused=document.createElement('canvas');
  defocused.width=defocused.height=96;
  const defocusedContext=defocused.getContext('2d');
  const blurGradient=defocusedContext.createRadialGradient(48,48,0,48,48,48);
  blurGradient.addColorStop(0,'rgba(236,245,255,.80)');
  blurGradient.addColorStop(.25,'rgba(236,245,255,.68)');
  blurGradient.addColorStop(.55,'rgba(225,238,250,.30)');
  blurGradient.addColorStop(1,'rgba(225,238,250,0)');
  defocusedContext.fillStyle=blurGradient;
  defocusedContext.fillRect(0,0,96,96);
  const ice=document.createElement('canvas');
  ice.width=ice.height=48;
  const iceContext=ice.getContext('2d');
  const iceGradient=iceContext.createRadialGradient(20,17,2,24,24,22);
  iceGradient.addColorStop(0,'rgba(255,255,255,1)');
  iceGradient.addColorStop(.55,'rgba(251,252,253,.94)');
  iceGradient.addColorStop(.80,'rgba(230,235,240,.72)');
  iceGradient.addColorStop(1,'rgba(238,241,245,0)');
  iceContext.fillStyle=iceGradient;iceContext.fillRect(0,0,48,48);
  const nearIce=document.createElement('canvas');
  nearIce.width=nearIce.height=96;
  const nearIceContext=nearIce.getContext('2d');
  const nearIceGradient=nearIceContext.createRadialGradient(46,44,0,48,48,48);
  nearIceGradient.addColorStop(0,'rgba(255,255,255,.95)');
  nearIceGradient.addColorStop(.30,'rgba(255,255,255,.72)');
  nearIceGradient.addColorStop(.65,'rgba(248,250,252,.26)');
  nearIceGradient.addColorStop(1,'rgba(248,250,252,0)');
  nearIceContext.fillStyle=nearIceGradient;nearIceContext.fillRect(0,0,96,96);
  const wrap=(value,range)=>((value%range)+range)%range;
  function eventRandom(value) { const n=Math.sin(value*127.1+311.7)*43758.5453; return n-Math.floor(n); }
  const strikeTimes=[1.2];
  function lightningEvent(sampleTime=state.time) {
    if(state.current[7]<.001)return {strength:0,x:.5,y:0,id:-1,age:0,pulses:0};
    const elapsed=Math.max(0,sampleTime-state.stormStart);
    while(strikeTimes[strikeTimes.length-1]<=elapsed) {
      const id=strikeTimes.length;
      strikeTimes.push(strikeTimes[id-1]+2.8+eventRandom(id+77)*4.4);
    }
    let low=0,high=strikeTimes.length-1;
    while(low<high) {const mid=Math.ceil((low+high)/2);if(strikeTimes[mid]<=elapsed)low=mid;else high=mid-1;}
    let id=low,age=elapsed-strikeTimes[id];
    if(state.forcedStrike!==null&&sampleTime-state.forcedStrike>=0&&sampleTime-state.forcedStrike<2) {
      age=sampleTime-state.forcedStrike;id=10000+state.strikeSerial;
    }
    let envelope=0,onset=0;
    const pulses=1+Math.floor(eventRandom(id+19)*3);
    for(let i=0;i<pulses;i++) {
      if(i>0)onset+=.34+eventRandom(id*7+i+3)*.32;
      const local=age-onset;
      const decay=.09+eventRandom(id*13+i+8)*.13;
      if(local>=0&&local<.8)envelope=Math.max(envelope,Math.min(1,local/.018)*Math.exp(-local/decay)*(i===0?1:.55+eventRandom(id+i)*.45));
    }
    return {strength:envelope*state.current[7],x:.26+eventRandom(id+13)*.48,y:-.06+eventRandom(id+37)*.10,id,age,pulses};
  }
  let boltCache=null;
  function lightningPath(start,end,amplitude,steps,seed) {
    let points=[start,end];
    for(let level=0;level<steps;level++) {
      const next=[points[0]];
      for(let i=1;i<points.length;i++) {
        const a=points[i-1],b=points[i];
        next.push({x:(a.x+b.x)/2+(eventRandom(seed+level*113+i*7)-.5)*amplitude,y:(a.y+b.y)/2+(eventRandom(seed+level*31+i)-.5)*amplitude*.14},b);
      }
      points=next;amplitude*=.52;
    }
    return points;
  }
  function drawLightning(context,width,height,event) {
    if(event.strength<.005) return;
    const key=event.id+':'+width+':'+height;
    if(!boltCache||boltCache.key!==key) {
      const start={x:event.x*width,y:event.y*height};
      const end={x:start.x+(eventRandom(event.id+81)-.5)*width*.35,y:height*(.76+eventRandom(event.id+88)*.30)};
      const points=lightningPath(start,end,height*.34,6,event.id*117+9);
      const branches=[];
      for(let i=0;i<5;i++) {
        const index=12+Math.floor(eventRandom(event.id+i*11)*34);
        const from=points[index];
        const side=eventRandom(event.id+i+9)>.5?1:-1;
        const to={x:from.x+side*height*(.09+eventRandom(event.id+i+31)*.24),y:from.y+height*(.09+eventRandom(event.id+i+71)*.23)};
        branches.push(lightningPath(from,to,height*.12,4,event.id+i*39));
      }
      boltCache={key,points,branches};
    }
    context.save();context.globalCompositeOperation='screen';context.lineJoin='round';
    const glow=context.createLinearGradient(0,0,0,height);
    glow.addColorStop(0,'rgba(129,112,255,0)');glow.addColorStop(.12,'rgba(139,133,255,1)');glow.addColorStop(.72,'rgba(108,154,255,1)');glow.addColorStop(1,'rgba(108,154,255,.35)');
    function trace(points,lineWidth,alpha,color) {
      context.lineWidth=lineWidth;context.globalAlpha=event.strength*alpha;context.strokeStyle=color;
      context.beginPath();points.forEach((point,i)=>i?context.lineTo(point.x,point.y):context.moveTo(point.x,point.y));context.stroke();
    }
    trace(boltCache.points,19,.15,glow);trace(boltCache.points,8,.31,glow);trace(boltCache.points,3.4,.88,'rgb(179,199,255)');trace(boltCache.points,1.45,1,'rgb(248,250,255)');
    for(const branch of boltCache.branches) {
      trace(branch,6,.13,glow);trace(branch,1.4,.61,'rgb(170,195,255)');trace(branch,.6,.86,'rgb(233,241,255)');
    }
    context.restore();
  }
  function drawParticles() {
    const context=particleContext;
    const scale=particleCanvas.height/720;
    const width=particleCanvas.width/scale,height=720;
    const t=state.time;
    context.setTransform(1,0,0,1,0,0);
    context.clearRect(0,0,particleCanvas.width,particleCanvas.height);
    context.setTransform(scale,0,0,scale,0,0);
    context.lineCap='round';
    const wind=state.current[5],downpour=state.current[6];
    const windTravel=state.windTime*95;
    drawLightning(context,width,height,lightningEvent());
    const rainStrength=state.current[2];
    if(rainStrength>.002) {
      const count=Math.round(440*Math.min(1.4,width/1280)*(1+downpour*.90));
      const gust=Math.sin(t*.17)*.022+Math.sin(t*.39)*.012;
      for(let i=0;i<count;i++) {
        const p=rainParticles[i];
        const depth=p.depth*p.depth;
        const speed=(430+depth*880+p.variation*110)*(1+downpour*.18);
        const length=(5+depth*31+p.variation*6)*(1+downpour*.35);
        const tilt=-.12-wind*.48+gust*(1+wind*2)+(p.drift-.5)*.035;
        const y=wrap(p.y*(height+140)+t*speed,height+140)-70;
        const x=wrap(p.x*(width+300)+y*tilt+t*(5+depth*8),width+300)-150;
        context.globalAlpha=Math.min(1,rainStrength*(.16+depth*.40)*(.65+p.variation*.35)*(1+downpour*.22));
        context.lineWidth=.55+depth*1.15;
        const tail=context.createLinearGradient(x-tilt*length,y-length,x,y);
        tail.addColorStop(0,'rgba(192,212,227,0)');
        tail.addColorStop(.7,'rgba(211,228,240,.70)');
        tail.addColorStop(1,'rgba(226,238,245,1)');
        context.strokeStyle=tail;
        context.beginPath();context.moveTo(x-tilt*length,y-length);context.lineTo(x,y);context.stroke();
      }
      const nearCount=Math.round(20*Math.min(1.4,width/1280)*(1+downpour*.75));
      for(let i=0;i<nearCount;i++) {
        const p=nearRainParticles[i];
        const length=65+p.depth*95;
        const breadth=7+p.depth*12;
        const speed=1050+p.depth*950;
        const tilt=-.12-wind*.48+gust*(1+wind*2)+(p.drift-.5)*.035;
        const y=wrap(p.y*(height+360)+t*speed,height+360)-180;
        const x=wrap(p.x*(width+360)+y*tilt+t*14,width+360)-180;
        context.globalAlpha=rainStrength*(.18+p.variation*.24)*.65;
        context.save();context.translate(x,y);context.rotate(-Math.atan(tilt));
        context.drawImage(defocused,-breadth/2,-length/2,breadth,length);
        context.restore();
      }
    }
    const snowStrength=state.current[4];
    if(snowStrength>.002) {
      const count=Math.round(145*Math.min(1.2,width/1280));
      for(let i=0;i<count;i++) {
        const p=snowParticles[i];
        const depth=p.depth;
        const radius=.8+Math.pow(depth,2.8)*4.7;
        const speed=13+depth*39+p.variation*12;
        const y=wrap(p.y*(height+70)+t*speed,height+70)-35;
        const flutter=Math.sin(t*(.30+p.drift*.5)+p.phase)*(8+depth*20);
        const sway=Math.sin(t*.13+p.phase)*17;
        const x=wrap(p.x*(width+110)+t*(4+p.drift*8)+flutter+sway-windTravel*(.3+depth),width+110)-55;
        context.globalAlpha=snowStrength*(.28+depth*.57);
        context.save();context.translate(x,y);context.rotate(Math.sin(t*.5+p.phase)*.4);
        context.drawImage(flake,-radius,-radius*.8,radius*2,radius*1.6);
        context.restore();
      }
      const nearCount=Math.round(16*Math.min(1.4,width/1280));
      for(let i=0;i<nearCount;i++) {
        const p=nearSnowParticles[i];
        const radius=10+p.depth*15;
        const y=wrap(p.y*(height+150)+t*(110+p.depth*110),height+150)-75;
        const flutter=Math.sin(t*(.22+p.drift*.25)+p.phase)*(28+p.depth*24);
        const x=wrap(p.x*(width+180)+t*(7+p.drift*13)+flutter-windTravel*(.8+p.depth),width+180)-90;
        context.globalAlpha=snowStrength*(.28+p.variation*.30)*.65;
        context.save();context.translate(x,y);context.rotate(p.phase+Math.sin(t*.25)*.4);
        context.drawImage(defocused,-radius,-radius*.83,radius*2,radius*1.66);
        context.restore();
      }
    }
    const hailStrength=state.current[8];
    if(hailStrength>.002) {
      const count=Math.round(160*Math.min(1.4,width/1280));
      for(let i=0;i<count;i++) {
        const p=hailParticles[i];
        const radius=1.2+p.depth*p.depth*4.0;
        const speed=640+p.depth*1050;
        const y=wrap(p.y*(height+80)+t*speed,height+80)-40;
        const x=wrap(p.x*(width+180)-y*(.025+wind*.16)-windTravel*.25,width+180)-90;
        context.globalAlpha=hailStrength*(.47+p.depth*.40);
        context.save();context.translate(x,y);context.rotate(p.phase+t*(.7+p.variation));
        context.drawImage(ice,-radius,-radius*1.12,radius*2,radius*2.24);
        context.restore();
      }
      const nearCount=Math.round(19*Math.min(1.4,width/1280));
      for(let i=0;i<nearCount;i++) {
        const p=nearHailParticles[i];
        const radius=8+p.depth*13;
        const y=wrap(p.y*(height+180)+t*(1250+p.depth*1100),height+180)-90;
        const x=wrap(p.x*(width+200)-y*(.04+wind*.18)-windTravel*.40,width+200)-100;
        context.globalAlpha=hailStrength*(.20+p.variation*.22);
        context.save();context.translate(x,y);context.rotate(.05+wind*.18);
        context.drawImage(nearIce,-radius,-radius*1.5,radius*2,radius*3);
        context.restore();
      }
    }
    const windStrength=wind*(1-rainStrength)*(1-snowStrength)*(1-hailStrength);
    if(windStrength>.002) {
      const count=Math.round(52*Math.min(1.4,width/1280));
      for(let i=0;i<count;i++) {
        const p=windParticles[i];
        const x=wrap(p.x*(width+140)-windTravel*(1.7+p.depth*2.5),width+140)-70;
        const y=wrap(p.y*height+Math.sin(t*.42+p.phase)*(8+p.depth*15),height);
        context.globalAlpha=windStrength*(.06+p.variation*.10);context.strokeStyle='rgb(227,232,224)';context.lineWidth=.6+p.depth;
        context.beginPath();context.moveTo(x,y);context.lineTo(x+3+p.depth*7,y-1);context.stroke();
      }
    }
    const clearStrength=(1-state.current[1])*Math.max(0,1-state.current[0]/.065)*(1-rainStrength)*(1-snowStrength)*(1-state.current[3]);
    if(clearStrength>.002) {
      for(const p of motes) {
        const x=wrap(p.x*(width+70)+t*(1.7+p.drift*3.5)+Math.sin(t*.19+p.phase)*9,width+70)-35;
        const y=wrap(p.y*(height+60)-t*(1.5+p.depth*2.5)+Math.sin(t*.23+p.phase)*8,height+60)-30;
        const radius=.7+p.depth*1.6;
        const light=.5+.5*Math.exp(-((x-width*.67)**2+(y-height*.24)**2)/80000);
        context.globalAlpha=clearStrength*(.07+p.variation*.10)*light;
        context.fillStyle='rgb(255,233,181)';
        context.beginPath();context.arc(x,y,radius,0,Math.PI*2);context.fill();
      }
    }
    context.globalAlpha=1;
  }
  let lightningEnabled=true;
  function targetWeather() { const values=[...presets[state.mode].values]; values[1]=state.period==='night'?1:0; if(!lightningEnabled) values[7]=0; return values; }
  let last=0,frame=0;
  function draw() {
    if(!sceneWidth||!sceneHeight) return;
    // Do not sample the scene texture while it is attached for rendering.
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D,texture);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindFramebuffer(gl.FRAMEBUFFER,sceneFramebuffer);
    gl.viewport(0,0,sceneWidth,sceneHeight);
    gl.uniform2f(uniforms.resolution,sceneWidth,sceneHeight);
    gl.uniform1f(uniforms.time,state.time);
    gl.uniform4fv(uniforms.weather,state.current.slice(0,4));
    gl.uniform1f(uniforms.snowfall,state.current[4]);
    gl.uniform4fv(uniforms.effects,state.current.slice(5,9));
    gl.uniform1f(uniforms.storm,state.current[9]);
    gl.uniform1f(uniforms.windTime,state.windTime);
    const lightning=lightningEvent();
    gl.uniform1f(uniforms.flash,lightning.strength);
    gl.uniform2f(uniforms.flashPosition,lightning.x,1-(lightning.y+.20));
    gl.drawArrays(gl.TRIANGLES,0,6);
    gl.bindFramebuffer(gl.FRAMEBUFFER,null);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D,sceneTexture);
    gl.activeTexture(gl.TEXTURE0);
    gl.viewport(0,0,canvas.width,canvas.height);
    gl.useProgram(composite);
    gl.drawArrays(gl.TRIANGLES,0,6);
    gl.useProgram(program);
    // Reuse cloud coverage and refine only the celestial body, with a soft edge.
    const night=state.current[1];
    const sunVisible=(1-night)*(1-state.current[2])*(1-state.current[4])*(1-state.current[9]);
    if(night>.001||sunVisible>.001) {
      const radius=Math.ceil(canvas.height*(.11*(1-night)+.048*night));
      gl.uniform2f(uniforms.resolution,canvas.width,canvas.height);
      gl.uniform1f(uniforms.patchRadius,radius);
      gl.enable(gl.SCISSOR_TEST);
      gl.scissor(Math.floor(canvas.width*.67-radius),Math.floor(canvas.height*.76-radius),radius*2+2,radius*2+2);
      gl.enable(gl.BLEND);
      gl.blendFunc(gl.ONE,gl.ONE);
      gl.drawArrays(gl.TRIANGLES,0,6);
      gl.disable(gl.BLEND);
      gl.disable(gl.SCISSOR_TEST);
      gl.uniform1f(uniforms.patchRadius,0);
      gl.uniform2f(uniforms.resolution,sceneWidth,sceneHeight);
    }
    drawParticles();
    state.frames++;
  }
  function resize(drawFrame=true) {
    // Android can load the document before the platform view has a size.
    if(innerWidth<1||innerHeight<1) {sceneWidth=sceneHeight=0;return;}
    const scale=Math.min(devicePixelRatio||1,quality.width*resolutionScale/innerWidth,quality.height*resolutionScale/innerHeight);
    sceneWidth=Math.max(1,Math.round(innerWidth*scale));
    sceneHeight=Math.max(1,Math.round(innerHeight*scale));
    const outputScale=Math.min(devicePixelRatio||1,1920/innerWidth,1920/innerHeight);
    canvas.width=Math.max(1,Math.round(innerWidth*outputScale));
    canvas.height=Math.max(1,Math.round(innerHeight*outputScale));
    particleCanvas.width=sceneWidth;
    particleCanvas.height=sceneHeight;
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D,sceneTexture);
    gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,sceneWidth,sceneHeight,0,gl.RGBA,gl.UNSIGNED_BYTE,null);
    gl.activeTexture(gl.TEXTURE0);
    if(drawFrame) draw();
  }
  function tick(now) {
    frame=0;
    if(state.paused||document.hidden||!state.ready) { last=0; return; }
    const frameBudget=1000/quality.fps;
    if(!last||now-last>=frameBudget-1) {
      // Sustained slow frames lower resolution rather than queueing more work.
      if(last && now-last>frameBudget*1.8) slowFrames++;
      else slowFrames=Math.max(0,slowFrames-1);
      if(slowFrames>=8 && resolutionScale>.5) {
        resolutionScale=Math.max(.5,resolutionScale*.8);slowFrames=0;resize(false);
      }
      const dt=last?Math.min((now-last)/1000,.15):0;
      state.time+=dt;
      const target=targetWeather();
      state.current=state.current.map((value,i)=>value+(target[i]-value)*Math.min(1,dt*1.1));
      state.windTime+=dt*state.current[5];
      draw();
      last=now;
    }
    frame=requestAnimationFrame(tick);
  }
  function schedule() { if(!frame&&!state.paused&&!document.hidden&&state.ready) frame=requestAnimationFrame(tick); }
  function update(data) {
    const mode=Object.hasOwn(conditionModes,data.condition)?conditionModes[data.condition]:null;
    const period=data.night?'night':'day';
    if(mode && presets[mode].values[7]>0 && presets[state.mode].values[7]===0) state.stormStart=state.time;
    if(mode) state.mode=mode;
    state.period=period;
    lightningEnabled=data.lightning!==false;
    if(!lightningEnabled) state.current[7]=0;
    if(data.immediate || state.paused) state.current=targetWeather();
    draw(); schedule();
  }
  function setActive(active) {
    state.paused=!active || matchMedia('(prefers-reduced-motion: reduce)').matches;
    last=0;
    if(state.paused) { cancelAnimationFrame(frame); frame=0; }
    else schedule();
  }
  addEventListener('resize',resize);
  document.addEventListener('visibilitychange',()=>{last=0;schedule();});
  canvas.addEventListener('webglcontextlost',event=>{
    event.preventDefault();state.ready=false;cancelAnimationFrame(frame);frame=0;
  });
  canvas.addEventListener('webglcontextrestored',()=>location.reload());
  window.weatherMood={update,setActive,getPerformance:()=>({lowPower,steps:quality.steps,targetFps:quality.fps,width:sceneWidth,height:sceneHeight,outputWidth:canvas.width,outputHeight:canvas.height,resolutionScale,frames:state.frames,paused:state.paused})};
  resize();schedule();
})();
