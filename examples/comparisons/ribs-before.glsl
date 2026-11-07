#define SKILL 0
#define DARK 0
#ifndef SKILL
#define SKILL 0
#endif
#ifndef DARK
#define DARK 0
#endif
vec3 thinFilmPalette(float phase){return .5+.5*cos(6.283185*(vec3(phase)+vec3(0.,.33,.67)));}
vec3 warmPalette(float v){return mix(vec3(.95,.06,.42),vec3(1.,.38,.055),.5+.5*sin(v));}
vec3 pinkSpectrum(float v){vec3 c=thinFilmPalette(v);float green=max(0.,c.g-max(c.r,c.b));return clamp(c+green*vec3(.9,-.92,.55),0.,1.);}
float heightField(vec2 p){float t=iTime*.22;float x=p.x+.033*sin(p.y*2.+t);float r=cos(x*15.);return r*.16+.035*sin(p.y*3.5+t+x*7.);}
vec3 sampleEnv(vec3 R,float shift){float pitch=asin(clamp(R.y,-1.,1.)),yaw=atan(R.z,R.x);float b1=smoothstep(.55,.95,sin(yaw*2.+pitch*3.+shift)),b2=smoothstep(.75,.99,cos(yaw*3.-pitch*4.+shift));
#if DARK
 return vec3(.001)+b1*pinkSpectrum(pitch*.3+shift*.12)*1.2+b2*pinkSpectrum(pitch*.4+.3)*1.6;
#else
 return vec3(.12,.017,.045)+b1*warmPalette(pitch*2.+shift)*1.2+b2*vec3(1.,.76,.6)*1.6;
#endif
}
void mainImage(out vec4 color,in vec2 fragCoord){
 vec2 uv=(fragCoord-.5*iResolution.xy)/iResolution.y*2.3;
 float h=heightField(uv),eps=.006;
 vec3 N=normalize(vec3(-(heightField(uv+vec2(eps,0.))-h)/eps*.55,-(heightField(uv+vec2(0.,eps))-h)/eps*.55,1.));
 vec3 V=normalize(vec3(0.,0.,2.2)-vec3(uv,h*.18));float nv=max(dot(N,V),.001);
 float x=uv.x+.033*sin(uv.y*2.+iTime*.22);
 float phase=x*15.+uv.y*1.5+iTime*.1;
#if DARK
 float band=pow(.5+.5*sin(phase),5.);vec3 col=pinkSpectrum(phase*.08)*band*.7;
#else
 vec3 col=warmPalette(uv.y*2.+x*3.+iTime*.1)*(.45+.55*(.5+.5*cos(x*15.)));
#endif
#if SKILL
 float F=.12+.88*pow(1.-nv,4.5);
 vec3 transmitted=vec3(sampleEnv(refract(-V,N,1./1.48),h*1.2+.22).r,sampleEnv(refract(-V,N,1./1.52),h*1.2).g,sampleEnv(refract(-V,N,1./1.56),h*1.2-.22).b);
 float thickness=clamp(.65-h*.45,.1,1.3);
 // Warm absorption art direction retains pink/orange instead of navy valleys.
 transmitted*=exp(-vec3(.18,.6,.5)*thickness*2.2);
#if DARK
 vec3 film=pinkSpectrum(nv*2.4+h*1.6-iTime*.035);
#else
 vec3 film=warmPalette(nv*8.+h*5.-iTime*.2);
#endif
 vec3 reflected=sampleEnv(reflect(-V,N),h*1.2)*mix(vec3(1.),film,.65);
 vec3 L1=normalize(vec3(.6,.75,.85)),L2=normalize(vec3(-.75,-.45,.65));
 float key=pow(max(dot(N,normalize(L1+V)),0.),180.)*3.8;
 float fill=pow(max(dot(N,normalize(L2+V)),0.),90.)*1.4;
 float rim=pow(max(dot(N,normalize(L1+V)),0.),24.)*.45;
 col=mix(transmitted,reflected,F)+film*(fill+rim)*.3+min(key,2.5)*.12;
#if DARK
 float darkness=smoothstep(.48,.84,sin(phase+sin(uv.y*2.-iTime*.25)));
 col*=darkness;col+=film*pow(max(0.,1.-nv),5.)*.3;
#else
 // Satin rather than mirror: soften the contrast of the warm studio reflections.
 col=mix(col,warmPalette(uv.y*2.+iTime*.1)*.6,.25);
#endif
#endif
 col*=1.15;col=clamp((col*(2.51*col+.03))/(col*(2.43*col+.59)+.14),0.,1.);
 color=vec4(pow(col,vec3(1./2.2)),1.);
}
