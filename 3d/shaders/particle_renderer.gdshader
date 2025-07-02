shader_type spatial;
render_mode unshaded;

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
	
	vec2 center_offset = POINT_COORD - vec2(0.5); // vec2(0.5) is the center
	float distance_from_center = length(center_offset);
	if (length(center_offset) > 0.5) discard;
	
	if (CAMERA_VISIBLE_LAYERS == 2u) { // Depth Layer
		float depth = (distance(CAMERA_POSITION_WORLD, world_pos) - 0.05) / (4000.0 - 0.05); // Numbers are main camera near (0.05) and far (4000.0) values
		ALBEDO = vec3(depth);
	}
	
	if (CAMERA_VISIBLE_LAYERS == 4u) { // Normal Layer
        float sphere_radius = 0.5;
        float z = sqrt(max(0.0, sphere_radius * sphere_radius - distance_from_center * distance_from_center));
        // Step 2: Create local normal (pointing outward from sphere center)
        vec3 local_normal = normalize(vec3(center_offset.x, center_offset.y, z));
        // Step 3: Transform to world space
        vec3 world_normal = normalize((MODEL_MATRIX * vec4(local_normal, 0.0)).xyz);
        // Step 4: Pack normal to 0-1 range for output
        ALBEDO = world_normal * 0.5 + 0.5;
	}
	
	if (CAMERA_VISIBLE_LAYERS == 8u) { // Thickness Layer
		ALBEDO = vec3(0,1,0);
	}
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
