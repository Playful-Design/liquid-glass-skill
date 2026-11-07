#define SKILL 1
#ifndef SKILL
#define SKILL 0
#endif
// Flowing violet glass: broad folds with nested polished contour ridges.
vec3 thinFilmPalette(float p){return .5+.5*cos(6.283185*(vec3(p)+vec3(0.,.33,.67)));}
float heightField(vec2 p){
 float t=iTime*.18;
 float fold=p.y+.38*sin(p.x*3.+t)+.12*sin(p.x*5.-t*.6);
 float h=.38*sin(fold*5.4)+.10*cos(p.x*2.-p.y*2.+t);
 return h+.026*sin(fold*31.)*exp(-pow(sin(fold*5.4)*2.,2.));
}
vec3 sampleEnv(vec3 R,float shift){
 float pitch=asin(clamp(R.y,-1.,1.)),yaw=atan(R.z,R.x);
 float b1=smoothstep(.55,.95,sin(yaw*2.+pitch*3.+shift));
 float b2=smoothstep(.75,.99,cos(yaw*3.-pitch*4.+shift));
 return vec3(.008,.004,.017)+b1*vec3(.52,.38,.74)*.85+b2*vec3(.89,.83,1.)*1.6;
}
void mainImage(out vec4 color,in vec2 fragCoord){
 vec2 uv=(fragCoord-.5*iResolution.xy)/iResolution.y*2.65;
 float h=heightField(uv),eps=.006;
 vec3 N=normalize(vec3(-(heightField(uv+vec2(eps,0.))-h)/eps*.55,-(heightField(uv+vec2(0.,eps))-h)/eps*.55,1.));
 vec3 V=normalize(vec3(0.,0.,2.2)-vec3(uv,h*.18));float nv=max(dot(N,V),.001);
 vec3 L1=normalize(vec3(.6,.75,.85)),L2=normalize(vec3(-.75,-.45,.65));
 vec3 col=mix(vec3(.08,.025,.17),vec3(.65,.49,.83),.5+.5*h)+vec3(.35,.24,.5)*pow(max(dot(N,L1),0.),8.);
#if SKILL
 float fresnel=.12+.88*pow(1.-nv,4.5);
 vec3 Tr=refract(-V,N,1./1.48),Tg=refract(-V,N,1./1.52),Tb=refract(-V,N,1./1.56);
 vec3 transmitted=vec3(sampleEnv(Tr,h*1.2+.22).r,sampleEnv(Tg,h*1.2).g,sampleEnv(Tb,h*1.2-.22).b);
 float thickness=clamp(.65-h*.45,.1,1.3);
 // Violet tint requested by the reference: stronger green absorption.
 transmitted*=exp(-vec3(.28,.65,.12)*thickness*2.2);
 vec3 film=thinFilmPalette(nv*2.4+h*1.6-iTime*.15);
 vec3 reflected=sampleEnv(reflect(-V,N),h*1.2)*mix(vec3(1.),mix(film,vec3(.8,.55,1.),.8),.65);
 float key=pow(max(dot(N,normalize(L1+V)),0.),180.)*3.8;
 float fill=pow(max(dot(N,normalize(L2+V)),0.),90.)*1.4;
 float halo=pow(max(dot(N,normalize(L1+V)),0.),24.)*.45;
 col=mix(transmitted,reflected,fresnel)+vec3(.8,.65,1.)*(fill+halo)*.45;
 key=min(key,2.5);col+=key/(1.+.25*key);
 float rim=smoothstep(.8,.95,1.-nv);col*=1.-.25*smoothstep(.55,.8,1.-nv)*(1.-rim);col+=rim*vec3(.48,.37,.65);
#endif
 col*=max(.45,1.-dot(uv,uv)*.07)*1.15;
 col=clamp((col*(2.51*col+.03))/(col*(2.43*col+.59)+.14),0.,1.);
 color=vec4(pow(col,vec3(1./2.2)),1.);
}
