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
	COLOR = vec4(clamp(data.z/250.0, 0.0, 1.0), 0, 0, 1); // Red intensity shows velocity magnitude
	COLOR = vec4(texture(gradient_texture, vec2(clamp(data.z/250.0, 0.0, 1.0), 0.5)).rgb, 1);
	COLOR = texture(gradient_texture, vec2(1, 0.5));
// Show the full gradient as a test pattern:
float t = float(int(INDEX) % 100) / 99.0; // Creates 0.0 to 1.0 across particles
COLOR = texture(gradient_texture, vec2(t, 0.5));

}