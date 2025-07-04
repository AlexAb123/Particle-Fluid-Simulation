shader_type spatial;

render_mode unshaded, fog_disabled;

uniform sampler2D depth_texture;

void vertex() {
	 POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec4 depth = texture(depth_texture, SCREEN_UV);
	ALPHA = depth.a;
	ALBEDO = vec3(depth.r);

}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
