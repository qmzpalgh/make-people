shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 dye : source_color = vec4(0.7,0.4,0.3,1.);
uniform vec4 secondary : source_color = vec4(0.15,0.12,0.18,1.);
uniform vec4 lip_tone : source_color;
uniform int pattern=0;
uniform bool trousers=false;
uniform int coverage=3;
uniform int surface = 0;
uniform float freckles : hint_range(0.,1.) = 0.35;
varying vec3 local;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
	vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);
}
void vertex(){local=VERTEX;}
void fragment(){
	float region=surface==3?COLOR.r:COLOR.b;
	if((surface==0 || surface==3) && ((coverage==1 && region<.5)||(coverage==2 && region>=.5))){discard;}
	vec3 col=dye.rgb;
	float rough=.55;
	float fine=noise(UV*1150.);
	float height=0.;
	if(surface==0){
		float warm=noise(UV*64.)*.035+noise(UV*270.)*.018;
		col*=vec3(.88+warm,.84-warm,.83-warm);
		float occ=clamp(COLOR.a,0.,1.);
		col*=mix(vec3(.34,.23,.22),vec3(1.),pow(occ,1.6));
		float mottling=noise(UV*205.)*.055+noise(UV*41.)*.045-.05;
		col*=1.+mottling;
		float orbit=exp(-pow((abs(local.x)-.030)/.024,2.)-pow((local.y-1.491)/.014,2.))*smoothstep(.085,.12,local.z);
		col*=mix(vec3(1.),vec3(.84,.72,.72),orbit);
		col=mix(col,col*vec3(1.13,.68,.68),COLOR.g*.34);
		float lip=smoothstep(.1,.75,COLOR.r);
		col=mix(col,mix(col*vec3(.83,.43,.49),lip_tone.rgb*mix(.28,.84,occ),.32),lip*.91);
		vec2 p=local.xy*515.+local.z*139.;
		vec2 id=floor(p),d=fract(p)-vec2(.24+.52*hash(id),.24+.52*hash(id+3.));
		float speck=(1.-smoothstep(.055,.31,length(d)))*step(.71,hash(id+15.))*freckles*min(1.,COLOR.g*2.);
		col*=1.-.72*speck;
		rough=mix(.48+.13*fine,.48,lip);
		height=(fine-.5)*.000026;
		SSS_STRENGTH=.085;
		SSS_TRANSMITTANCE_COLOR=vec4(.87,.31,.19,1.);
	}else if(surface==1){
		vec2 p=(COLOR.rg-.5)*.36; float r=length(p);
		float a=atan(p.y,p.x);
		float iris=1.-smoothstep(.060,.066,r);
		float rays=noise(vec2(a*39.,r*140.))*.65+noise(vec2(a*90.,r*53.))*.35;
		col=mix(vec3(.48,.42,.39),dye.rgb*(.55+rays*1.4),iris);
		col=mix(col,vec3(.025,.019,.017),.7*exp(-pow((r-.061)/.006,2.)));
		col=mix(vec3(.005,.003,.002),col,smoothstep(.023,.027,r));
		float lid=1.-smoothstep(-.03,.045,p.y);
		col*=mix(.52,1.,lid);
		col*=mix(vec3(.79,.59,.55),vec3(1.),1.-smoothstep(.064,.14,abs(p.x)));
		col+=vec3(.7,.65,.58)*(1.-smoothstep(.002,.008,length(p-vec2(-.018,.02))));
		rough=.24;
	}else if(surface==2){
		float bend=sin(UV.y*14.+UV.x*12.)*.9+sin(UV.y*5.)*1.8;
		float fibers=noise(vec2(UV.x*410.+bend,UV.y*4.));
		float locks=noise(vec2(UV.x*61.+bend*.35,UV.y*2.));
		if(COLOR.g<.40 && fibers+.14*locks<(.4-COLOR.g)*1.6){discard;}
		col*=.52+.67*locks+.46*fibers;
		rough=.57+.12*fibers; height=(fibers-.5)*.00009;
	}else if(surface==7){
		float bend=sin(UV.y*11.+UV.x*19.)*1.8+sin(UV.y*6.+UV.x*25.)*1.2;
		float locks=noise(vec2(UV.x*125.+bend*.27,UV.y*1.2));
		float fibers=noise(vec2(UV.x*1500.+bend,UV.y*6.));
		col*=.35+.75*locks+.42*fibers+.37*COLOR.r;
		if(UV.y>.982 && UV.y<1.002 && fibers+locks*.2<(UV.y-.982)*34.){discard;}
		rough=.56+.18*fibers; height=(fibers-.5)*.000043;
	}else if(surface==3){
		col=mix(secondary.rgb,dye.rgb,smoothstep(.3,.72,COLOR.r))*(.64+.36*COLOR.a);
		vec2 thread=UV*1150.;
		float weave=sin(thread.x+sin(thread.y)*.7)*sin(thread.y);
		float atten=1.-smoothstep(.3,3.,max(fwidth(thread.x),fwidth(thread.y)));
		col*=.94+.055*weave*atten+.065*noise(UV*110.);
		float hem=1.-smoothstep(.1,.75,COLOR.g);
		col*=1.-hem*.16;
		if(pattern>0 && COLOR.r>.60){
			vec2 grid=local.xy*vec2(58.,64.);
			vec2 bands=abs(fract(grid+.5)-.5);
			float lines=1.-smoothstep(.025,.095,bands.y);
			if(pattern==2){lines=max(lines,1.-smoothstep(.025,.082,bands.x));}
			col=mix(col,col*1.55+vec3(.035),lines*.72);
		}
		rough=.79+.09*fine; height=weave*.000045*atten;
	}else if(surface==5){
		if(trousers && local.y>.093){discard;}
		col*=.89+.14*fine; rough=.45;
	}
	vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
	vec3 r1=cross(dy,NORMAL),r2=cross(NORMAL,dx);
	float det=dot(dx,r1);
	NORMAL=normalize(abs(det)*NORMAL-sign(det)*(dFdx(height)*r1+dFdy(height)*r2)+NORMAL*.0000000001);
	ALBEDO=col; ROUGHNESS=rough; SPECULAR=surface==2?.22:.3;
}
