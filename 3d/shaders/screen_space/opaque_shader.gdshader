shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform sampler2D particle_data;
uniform int particle_count;
uniform float particle_size;
uniform int image_size;
uniform vec3 origin;
uniform float camera_near;
uniform float camera_far;

varying vec3 world_pos; // Position of center of sphere in world coordinates
varying vec3 view_pos; // Position of center of sphere in camera coordinates
varying float camera_distance; // Distance from center of sphere to camera

void vertex() {
	int index = int(VERTEX.x);
	VERTEX.x = float(index);
	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);
	world_pos = origin + texelFetch(particle_data, pixel_coord, 0).xyz;
	view_pos = (VIEW_MATRIX * vec4(world_pos, 1.0)).xyz;
	VERTEX.xyz = world_pos;
	camera_distance = distance(CAMERA_POSITION_WORLD, world_pos);
    POINT_SIZE = particle_size / camera_distance;
}

void fragment() {
	vec2 center_offset = POINT_COORD - vec2(0.5); // vec2(0.5) is the center
	float squared_center_offset = dot(center_offset, center_offset);
	if (squared_center_offset > 0.25) discard;

	// Calculate sphere surface position
	float z_offset = sqrt(0.25 - squared_center_offset); // Solve for z: x^2 + y^2 + z^2 = R^2
	float z_offset_world = z_offset * particle_size / camera_distance; // Transform z_offset into world coordinates
	float sphere_linear_depth = camera_distance - z_offset_world; // Adjust linear depth for rounded surface of the sphere
	float depth = 1.0 - ((sphere_linear_depth - camera_near) / (camera_far - camera_near)); // Convert to depth buffer value
	DEPTH = depth;

	if (CAMERA_VISIBLE_LAYERS == 2u) { // Depth layer
		ALBEDO = vec3(clamp(depth, 0.0, 1.0));
	}

	if (CAMERA_VISIBLE_LAYERS == 4u) { // Normal layer - store world-space normals
		// Calculate the actual 3D world position of this pixel on the sphere surface
		// We need to reconstruct the 3D position from the billboard coordinates

		// Get camera direction to sphere center
		vec3 camera_to_sphere = normalize(world_pos - CAMERA_POSITION_WORLD);

		// Create a consistent world-space coordinate system for the billboard
		// Use fixed world axes instead of camera-relative axes
		vec3 world_up = vec3(0.0, 1.0, 0.0);
		vec3 world_right = normalize(cross(world_up, camera_to_sphere));
		vec3 corrected_up = normalize(cross(camera_to_sphere, world_right));

		// Handle degenerate case when camera_to_sphere is parallel to world_up
		if (length(world_right) < 0.001) {
			world_right = vec3(1.0, 0.0, 0.0);
			corrected_up = vec3(0.0, 0.0, 1.0);
		}

		// Calculate the actual world position of this pixel on the sphere surface
		float sphere_radius = particle_size * 0.5;
		vec3 local_offset = vec3(center_offset.x, center_offset.y, z_offset) * sphere_radius;
		vec3 world_surface_pos = world_pos +
			world_right * local_offset.x +
			corrected_up * local_offset.y +
			camera_to_sphere * local_offset.z;

		// True world-space normal: direction from sphere center to surface point
		vec3 world_normal = normalize(world_surface_pos - world_pos);

		// Store world-space normal
		ALBEDO = world_normal * 0.5 + 0.5; // Encode as RGB [0,1]
	}

	if (CAMERA_VISIBLE_LAYERS == 8u){ // Thickness layer
		discard;
	}
}