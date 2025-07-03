shader_type spatial;
render_mode unshaded, blend_add;

uniform sampler2D particle_data;
uniform int particle_count;
uniform float particle_size;
uniform int image_size;
uniform vec3 origin;

uniform float camera_near;
uniform float camera_far;

varying vec3 world_pos;

void vertex() {
	int index = int(VERTEX.x);
	VERTEX.x = float(index);
	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);
	world_pos = origin + texelFetch(particle_data, pixel_coord, 0).xyz;
	VERTEX.xyz = world_pos;
    POINT_SIZE = particle_size / distance(CAMERA_POSITION_WORLD, world_pos);
}

void fragment() {
	vec2 center_offset = POINT_COORD - vec2(0.5); // vec2(0.5) is the center
	float squared_center_offset = dot(center_offset, center_offset);
	if (squared_center_offset > 0.25) discard;
	
	float linear_depth = distance(CAMERA_POSITION_WORLD, world_pos);
	float z_offset = sqrt(0.25 - squared_center_offset); // Solve for z: x^2 + y^2 + z^2 = R^2
	float z_offset_world = z_offset * particle_size / max(0.01, linear_depth); // Transform z_offset into world coordinates
	float sphere_linear_depth = linear_depth - z_offset_world; // Adjust linear depth for rounded surface of the sphere
	float depth = 1.0 - ((sphere_linear_depth - camera_near) / (camera_far - camera_near)); // Convert to depth buffer value
	DEPTH = clamp(depth, 0.0, 1.0);
	
	if (CAMERA_VISIBLE_LAYERS == 2u) { // Depth layer
		discard;
	}
	
	if (CAMERA_VISIBLE_LAYERS == 4u) { // Normal layer
		discard;
	}
	
	if (CAMERA_VISIBLE_LAYERS == 8u){ // Thickness layer
		ALBEDO = vec3(1);
		ALPHA = 0.05;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
