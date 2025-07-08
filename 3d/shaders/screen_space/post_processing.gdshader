shader_type spatial;

render_mode unshaded, fog_disabled;

uniform sampler2D depth_texture;
uniform sampler2D normal_texture;
uniform sampler2D thickness_texture;
uniform float camera_near;
uniform float camera_far;

void vertex() {
	 POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec4 depth = texture(depth_texture, SCREEN_UV);
	if (depth.a == 0.0) discard;
	vec4 normal = texture(normal_texture, SCREEN_UV);
	vec4 thickness = texture(thickness_texture, SCREEN_UV);

	ALBEDO = thickness.rgb;
	ALPHA = 0.8;
}