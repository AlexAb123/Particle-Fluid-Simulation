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
uniform float sun_sharpness: hint_range(0.0, 1000.0) = 500.0;
uniform float sun_intensity: hint_range(0.0, 500.0) = 5.0;
uniform float refraction_strength: hint_range(0.0, 500.0) = 5.0;
uniform vec3 extinction_coefficients = vec3(0.45, 0.01, 0.005);
uniform float transparency: hint_range(0.0, 1.0) = 0.3;


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
	vec3 surface_normal = normalize(texture(normal_texture, SCREEN_UV).rgb * 2.0 - 1.0);
	vec3 background = texture(background_texture, SCREEN_UV).rgb;

    vec3 view_pos = get_view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos, 1.0)).xyz;
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos); // Camera to particle vector
    vec3 light_dir = normalize(sun_world_pos - world_pos); // Sun to particle vector
    vec3 sun_dir = -light_dir; // Particle to sun vector
	vec3 reflect_dir = reflect(view_dir, surface_normal); // Reflected direction (as if the water was a mirror)

    float alignment = max(dot(reflect_dir, sun_dir), 0.0); // How similar is the reflection vector and vector to sun
	float sun_brightness = pow(alignment, sun_sharpness);
	
	vec3 reflect_color = sun_color * sun_brightness * sun_intensity;
	
	float brightness = max(dot(surface_normal, light_dir) * 0.5 + 0.5, 0.20);
	vec3 light_color = water_color * brightness;

    // Beer-Lambert law. Light gets absorbed as it travels through water
    vec3 transmission = exp(-thickness * extinction_coefficients);
    vec3 refract_color = light_color * transmission;
	
    ALBEDO = background * transparency + refract_color + reflect_color;
}

void vertex() {
	 POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}