shader_type spatial;

render_mode unshaded, fog_disabled;

uniform sampler2D depth_texture;
uniform sampler2D normal_texture;
uniform sampler2D thickness_texture;
uniform sampler2D background_texture;
uniform float camera_near;
uniform float camera_far;

uniform vec3 sun_world_pos;
uniform vec3 sun_color: source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_intensity: hint_range(0.0, 5.0) = 1.0;
uniform float specular_power: hint_range(1.0, 128.0) = 0.01;

uniform vec3 water_color: source_color = vec3(0, 0, 1);

float distance_from_camera(float depth) {
	return (1.0 - depth) * (camera_far - camera_near) + camera_near;
}
vec3 get_view_pos(vec2 uv, mat4 inv_projection_matrix) {
	vec4 depth = texture(depth_texture, uv);
	vec3 view_vector = (inv_projection_matrix * vec4(uv * 2.0 - 1.0, depth.r, 1.0)).xyz;
	return normalize(view_vector) * distance_from_camera(depth.r);
}
void fragment() {
	float thickness = texture(thickness_texture, SCREEN_UV).a;
	float depth = texture(depth_texture, SCREEN_UV).r;
	if (depth == 0.0) discard;
	vec3 world_normal = normalize(texture(normal_texture, SCREEN_UV).rgb * 2.0 - 1.0);
	vec3 background = texture(background_texture, SCREEN_UV).rgb;
	
    
    // Get positions in world space
    vec3 view_pos = get_view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos, 1.0)).xyz;
    
    // === BLINN-PHONG IN WORLD SPACE ===
    
    // Step 1: World view direction (surface to camera)
    vec3 world_view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
    
    // Step 2: World light direction (surface to sun)
    vec3 world_light_dir = normalize(sun_world_pos - world_pos);
    
    // Step 3: Half-vector in world space
    vec3 world_half_vector = normalize(world_view_dir + world_light_dir);
    
    // Step 4: Calculate specular with world space normal
    float ndoth = max(dot(world_normal, world_half_vector), 0.0);
    float specular_factor = pow(ndoth, specular_power);
    
    // Step 5: Calculate sun reflection
    vec3 sun_reflection = sun_color * specular_factor * sun_intensity;
    
    // === OUTPUT ===
    vec3 final_color = background + sun_reflection;
    
    ALBEDO = final_color;
    ALPHA = 0.8;
}

void vertex() {
	 POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}