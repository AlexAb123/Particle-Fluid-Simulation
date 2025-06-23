shader_type particles;

uniform sampler2D particle_data;
uniform int particle_count;
uniform int image_size;

void start() {

}

void process() {

	int index = int(INDEX);
	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);

	vec4 data = texelFetch(particle_data, pixel_coord, 0);


	vec2 pos = data.xy;

	TRANSFORM[3].xy = pos;
}