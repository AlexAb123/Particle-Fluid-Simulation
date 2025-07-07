shader_type canvas_item;

render_mode unshaded;

uniform sampler2D depth_texture;
uniform int blur_size;
uniform float blur_strength;
uniform float blur_depth_factor;
uniform float camera_near;
uniform float camera_far;
uniform mat4 PROJECTION_MATRIX;
uniform int max_blur_size_pixels;

float gaussian(float x, float sigma) {
    return exp(-1.0 * (x * x) / (2.0 * sigma * sigma));
}

float distance_from_camera(float depth) {
	return (1.0 - depth) * (camera_far - camera_near) + camera_near;
}

 // Get blur size in pixels, scales with depth so that objects closer to the camera are blurred the same amount as objects far away
int get_blur_size_pixels(float depth, sampler2D tex) {
	float texture_height = vec2(textureSize(tex, 0)).y;
	float blur_size_pixels = float(blur_size) * PROJECTION_MATRIX[1][1] / distance_from_camera(depth) * texture_height * 0.5;
	return int(blur_size_pixels);
}

void fragment() {
	vec2 texel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec4 depth = texture(depth_texture, UV);
	if (depth.a == 0.0) discard;
	vec4 color = vec4(0);
	float total_weight = 0.0;
	int blur_size_pixels = min(max_blur_size_pixels, get_blur_size_pixels(depth.r, TEXTURE));
	for (int i = -blur_size_pixels; i <= blur_size_pixels; i++) {
		vec2 offset = vec2(0.0, float(i) * texel_size.y);
		vec4 sample_color = texture(TEXTURE, UV + offset);

		if (sample_color.a == 0.0) continue;
		float sigma = max(0.0001, float(blur_size_pixels) * blur_strength);
		float spatial_weight = gaussian(float(i), sigma);
		vec4 sample_depth = texture(depth_texture, UV +  offset);
		float depth_difference = distance_from_camera(depth.r) - distance_from_camera(sample_depth.r);
		float depth_weight = exp(-depth_difference * depth_difference * blur_depth_factor);

    	float combined_weight = spatial_weight * depth_weight;
		color += sample_color * combined_weight;
		total_weight += combined_weight;
	}
	COLOR = color / total_weight;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
