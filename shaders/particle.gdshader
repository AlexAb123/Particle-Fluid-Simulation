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
	

}

void start(){

}