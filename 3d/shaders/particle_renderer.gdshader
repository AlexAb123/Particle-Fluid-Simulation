shader_type spatial;
render_mode unshaded, blend_add;

uniform sampler2D particle_data;
uniform sampler2D gradient_texture: repeat_disable;
uniform int particle_count;
uniform float particle_size;
uniform int image_size;
uniform vec3 origin;
varying vec4 data;
varying vec3 world_pos;

void vertex() {
	int index = int(VERTEX.x);
	VERTEX.x = float(index);
    POINT_SIZE = particle_size;

	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);
	data = texelFetch(particle_data, pixel_coord, 0);

	vec3 pos = data.xyz;

	world_pos = pos + origin;

	VERTEX.xyz = world_pos;
}

void fragment() {

	vec2 center_offset = POINT_COORD - vec2(0.5); // vec2(0.5) is the center
	float distance_from_center = length(center_offset);
	if (length(center_offset) > 0.5) discard;

	float depth = (distance(CAMERA_POSITION_WORLD, world_pos) - 50.0) / 300.0;

	ALBEDO = vec3(depth-0.5, 0, 0);
	ALPHA = 0.05; // ALPHA * number of overlapping particles = thickness in the next shaders
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
