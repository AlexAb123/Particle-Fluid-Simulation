shader_type spatial;

render_mode unshaded, fog_disabled;

uniform sampler2D depth_texture;
uniform float camera_near;
uniform float camera_far;

float distance_from_camera(float depth) {
	return (1.0 - depth) * (camera_far - camera_near) + camera_near;
}
vec3 get_view_pos(vec2 uv, mat4 inv_projection_matrix) {
	vec4 depth = texture(depth_texture, uv);
	vec3 view_vector = (inv_projection_matrix * vec4(uv * 2.0 - 1.0, depth.r, 1.0)).xyz;
	return normalize(view_vector) * distance_from_camera(depth.r);
}

void vertex() {
	 POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec4 depth = texture(depth_texture, SCREEN_UV);
	
	if (depth.a == 0.0) discard;
		
	vec3 center_pos = get_view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	
	vec2 step_size = 1.0 / vec2(textureSize(depth_texture, 0));
	vec3 ddx = get_view_pos(SCREEN_UV + vec2(step_size.x, 0.0), INV_PROJECTION_MATRIX) - center_pos;
	vec3 ddy = get_view_pos(SCREEN_UV + vec2(0.0, step_size.y), INV_PROJECTION_MATRIX) - center_pos;
	
	vec3 view_normal = normalize(cross(ddy, ddx));
	vec3 world_normal = (VIEW_MATRIX  * vec4(view_normal, 0.0)).xyz;
	//ALBEDO = world_normal * 0.5 + 0.5;
	ALBEDO = normalize(world_normal);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
