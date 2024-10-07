shader_type particles;

uniform sampler2D particle_data;
uniform float scale_factor = 0.5;

void process(){
	
	ivec2 image_size = textureSize(particle_data, 0);
	ivec2 texel_pos = ivec2(int(mod(float(INDEX), float(image_size.x))),
							int(float(INDEX) / float(image_size.y)));
	
	vec4 particle_data_point = texelFetch(particle_data, texel_pos, 0);
	vec2 particle_position = particle_data_point.xy;
	vec2 particle_velocity = particle_data_point.wz;

		
	// TRANSFORM[3] is the position row of the 4x4 matrix TRANSFORM
	TRANSFORM[3].xy = particle_position;
	
	COLOR = vec4(1.0, 0.0, 0.0, 1.0);
	    // Normalize the input value between 0.0 and 1.0
    float normalized_value = clamp(particle_position.x / 500.0, 0.0, 1.0);
    
    vec4 blue = vec4(0.0, 0.0, 1.0, 1.0);
    vec4 red = vec4(1.0, 0.0, 0.0, 1.0);
    COLOR = mix(blue, red, normalized_value);
}

void start() {
	TRANSFORM[0] *= 0.5;
	
}
