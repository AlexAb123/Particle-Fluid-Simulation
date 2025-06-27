shader_type particles;

uniform sampler2D particle_data;
uniform sampler2D gradient_texture;
uniform int particle_count;
uniform float particle_size;
uniform int image_size;

void start() {
	// Set particle size
	TRANSFORM[0] = vec4(particle_size, 0, 0, 0);
	TRANSFORM[1] = vec4(0, particle_size, 0, 0);
}

void process() {

	int index = int(INDEX);
	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);

	vec4 data = texelFetch(particle_data, pixel_coord, 0);

	vec2 pos = data.xy;

	// Set particle positions
	TRANSFORM[3].xy = pos;
	COLOR = texelFetch(gradient_texture, ivec2(clamp(int(data.z/4.0), 0, 99), 0), 0);

}