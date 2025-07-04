shader_type canvas_item;

render_mode unshaded;

uniform sampler2D depth_texture;
uniform int blur_size;
uniform float blur_strength;
uniform float blur_depth_falloff;

void vertex() {
	
}

float gaussian(float x, float sigma) {
    return exp(-1.0 * (x * x) / (2.0 * sigma * sigma));
}

void fragment() {
	vec2 texel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
	float depth = texture(depth_texture, UV).r;
	vec4 color = vec4(0);
	float total_weight = 0.0;
	for (int i = -blur_size; i <= blur_size; i++) {
		vec2 offset = vec2(float(i) * texel_size.x, 0.0);
		vec4 sample_color = texture(TEXTURE, UV + offset);
		
		if (sample_color.a == 0.0) continue;
		float spatial_weight = gaussian(float(i), blur_strength);
		float sample_depth = texture(depth_texture, UV + offset).r;
		float depth_weight = gaussian(sample_depth - depth, blur_depth_falloff);

    	float combined_weight = spatial_weight * depth_weight;
		color += sample_color * combined_weight;
		total_weight += combined_weight;
	}
	COLOR = color / float(total_weight);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
