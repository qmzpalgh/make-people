shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec4 dye : source_color;
uniform sampler2D strands : source_color, filter_linear_mipmap, repeat_disable;
void fragment(){
	vec4 fibers=texture(strands,UV);
	ALBEDO=dye.rgb*(.65+fibers.r*.6);
	ROUGHNESS=.8; SPECULAR=.12;
	ALPHA=fibers.a;
}
