shader_type sky;
uniform vec4 edge : source_color = vec4(.54,.50,.62,1.);
uniform vec4 center : source_color = vec4(.82,.74,.77,1.);
void sky(){
	vec2 p=SCREEN_UV;
	float glow=exp(-dot((p-vec2(.58,.36))*vec2(1.35,1.),(p-vec2(.58,.36))*vec2(1.35,1.))*3.);
	float shaft=p.x*.8+p.y*.39;
	COLOR=mix(edge.rgb,center.rgb,glow)+.025*smoothstep(.25,.32,shaft)*(1.-smoothstep(.57,.66,shaft));
}
