float curve(vec2 p,float w,float y,float r){float x=clamp(p.x,-w,w);return length(p-vec2(x,y-.31*x*x-.105*x))-r;}
float logo(vec2 p){return max(length(p)-.74,-min(curve(p,.44,.21,.064),min(curve(p,.38,-.035,.053),curve(p,.32,-.245,.043))));}
// Natural polished optics, intentionally green tinted for the requested brand mark.
float heightAt(vec2 p){float d=max(-logo(p),0.);float bevel=.13*sqrt(max(1.-exp(-d*25.),.00001));return bevel+.009*sin(2.*p.x+1.5*p.y);}
vec3 thinFilmPalette(float phase){return .5+.5*cos(6.2831853*(phase+vec3(0.,.33,.67)));}
vec3 sampleEnv(vec3 r,float shift){float yaw=atan(r.z,r.x),pitch=asin(clamp(r.y,-1.,1.));float b1=smoothstep(.55,.95,sin(yaw+.7*pitch+shift+iTime*.06));float b2=smoothstep(.75,.99,cos(yaw*1.4-pitch+shift-iTime*.045));return vec3(.025+.03*(r.y*.5+.5))+vec3(.95)*b1+vec3(1.6)*b2;}
vec3 aces(vec3 c){return clamp((c*(2.51*c+.03))/(c*(2.43*c+.59)+.14),0.,1.);}
void mainImage(out vec4 fragColor,in vec2 fragCoord){
vec2 p=(fragCoord-.5*iResolution.xy)/min(iResolution.x,iResolution.y)*2.;float d=logo(p),aa=2./min(iResolution.x,iResolution.y);float mask=1.-smoothstep(-aa,aa,d);float t=iTime*.19;
float h=heightAt(p),eps=.004;vec2 grad=vec2(heightAt(p+vec2(eps,0.))-heightAt(p-vec2(eps,0.)),heightAt(p+vec2(0.,eps))-heightAt(p-vec2(0.,eps)))/(2.*eps);vec3 n=normalize(vec3(-grad,1.));vec3 v=normalize(vec3(-p*.12,2.2-h*.18));float nv=clamp(dot(n,v),.001,1.);float fresnel=.04+.96*pow(1.-nv,5.);
vec3 reflected=sampleEnv(reflect(-v,n),0.);vec3 transmitted=vec3(sampleEnv(refract(-v,n,1./1.51),.025).r,sampleEnv(refract(-v,n,1./1.52),0.).g,sampleEnv(refract(-v,n,1./1.53),-.025).b);float thickness=.2+h*2.;transmitted*=exp(-vec3(6.5,.25,5.3)*thickness);transmitted+=vec3(.004,.2,.022);
reflected=mix(reflected,reflected*thinFilmPalette(nv*2.4+h*1.6-t*.15),.035*pow(1.-nv,3.));vec3 l1=normalize(vec3(.6+.1*sin(t),.75,.85)),l2=normalize(vec3(-.75,-.45+.08*cos(t),.65));float spec=6.3*pow(max(dot(n,normalize(l1+v)),0.),320.)+2.6*pow(max(dot(n,normalize(l2+v)),0.),180.);spec=min(spec,2.5);spec=spec/(1.+.25*spec);float rim=smoothstep(.8,.95,1.-nv),inner=smoothstep(.55,.8,1.-nv)*(1.-rim);
vec3 col=mix(transmitted,reflected,fresnel);col*=1.-.25*inner;col+=vec3(spec*.62)+vec3(.72,1.,.84)*rim*.18;col*=1.-.12*dot(p,p);col=pow(aces(col*1.15),vec3(1./2.2));fragColor=vec4(col*mask,1.);
}