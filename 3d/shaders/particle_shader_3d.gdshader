shader_type particles;

uniform sampler2D particle_data;
uniform sampler2D gradient_texture: repeat_disable;
uniform int particle_count;
uniform float particle_size;
uniform int image_size;
uniform vec3 origin;

void start() {
	// Set particle size
	TRANSFORM[0] = vec4(particle_size, 0, 0, 0);
	TRANSFORM[1] = vec4(0, particle_size, 0, 0);
	TRANSFORM[2] = vec4(0, 0, particle_size, 0);
}

void process() {
	
	int index = int(INDEX);
	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);
	vec4 data = texelFetch(particle_data, pixel_coord, 0);

	vec3 pos = data.xyz;

	// Set particle position
	TRANSFORM[3].xyz = origin + pos;

	COLOR = texture(gradient_texture, vec2(data.w/450.0, 0.5));
}