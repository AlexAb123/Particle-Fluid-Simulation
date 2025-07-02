shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform sampler2D particle_data;
uniform int particle_count;
uniform float particle_size;
uniform int image_size;
uniform vec3 origin;

varying vec3 world_pos;

void vertex() {
	int index = int(VERTEX.x);
	VERTEX.x = float(index);
	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);
	world_pos = origin + texelFetch(particle_data, pixel_coord, 0).xyz;
	VERTEX.xyz = world_pos;
    POINT_SIZE = particle_size / distance(CAMERA_POSITION_WORLD, world_pos) * 500.0;
}

float convert_linear_to_depth_buffer(float linear_depth) {
    // Step 1: Normalize to 0-1 range
    float depth01 = (linear_depth - 0.05) / (4000.0 - 0.05);
    
    // Step 2: For Godot's Reverse Z (4.3+), we need to flip
    // Unity's formula assumes traditional Z-buffer
    // For Reverse Z: near = 1.0, far = 0.0
    
    return 1.0 - depth01;  // Flip for Reverse Z
}

void fragment() {
	
	vec2 center_offset = POINT_COORD - vec2(0.5); // vec2(0.5) is the center
	if (length(center_offset) > 0.5) discard;
	float z_offset = sqrt(0.25 - dot(center_offset, center_offset)); // Solve for z: x^2 + y^2 + z^2 = R^2
	float linear_depth = distance(CAMERA_POSITION_WORLD, world_pos);
     // Adjust linear depth for sphere surface
    float sphere_linear_depth = linear_depth - z_offset * particle_size / distance(CAMERA_POSITION_WORLD, world_pos) * 500.0;
    
    // Convert to depth buffer value
    float depth_buffer_value = convert_linear_to_depth_buffer(sphere_linear_depth);
    
    DEPTH = clamp(depth_buffer_value, 0.0, 1.0);
	
	
	if (CAMERA_VISIBLE_LAYERS == 2u) { // Depth Layer
    	ALBEDO = vec3(depth_buffer_value);
	}
	
	if (CAMERA_VISIBLE_LAYERS == 4u) { // Normal Layer
        vec3 local_normal = normalize(vec3(center_offset.x, center_offset.y, z_offset));
        vec3 world_normal = normalize((MODEL_MATRIX * vec4(local_normal, 0.0)).xyz);
        ALBEDO = world_normal * 0.5 + 0.5;
	}
	
	if (CAMERA_VISIBLE_LAYERS == 8u) { // Thickness Layer
		ALBEDO = vec3(0,1,0);
		ALPHA = 0.01;
	}
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
