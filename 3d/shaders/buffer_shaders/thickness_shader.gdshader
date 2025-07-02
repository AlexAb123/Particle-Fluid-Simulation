shader_type spatial;
render_mode unshaded, blend_add;

uniform sampler2D particle_data;
uniform int particle_count;
uniform float particle_size;
uniform int image_size;
uniform vec3 origin;

varying vec3 world_pos;

void vertex() {
	int index = int(VERTEX.x);
	VERTEX.x = float(index);
    POINT_SIZE = particle_size;
	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);
	world_pos = origin + texelFetch(particle_data, pixel_coord, 0).xyz;
	VERTEX.xyz = world_pos;
}
void fragment() {
	
	if (CAMERA_VISIBLE_LAYERS != 8u) discard; // Discard if layer is not thickness layer

	vec2 center_offset = POINT_COORD - vec2(0.5); // vec2(0.5) is the center
	float distance_from_center = length(center_offset);
	if (length(center_offset) > 0.5) discard;

	ALBEDO = vec3(0,1,0);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
