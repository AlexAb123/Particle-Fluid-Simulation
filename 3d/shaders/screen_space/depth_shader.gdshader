shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform sampler2D particle_data;
uniform int particle_count;
uniform float particle_size;
uniform int image_size;
uniform vec3 origin;
uniform float camera_near;
uniform float camera_far;
uniform sampler2D gradient_texture: repeat_disable;

varying vec3 world_pos; // Position of center of sphere in world coordinates
varying vec3 view_pos; // Position of center of sphere in camera coordinates
varying float camera_distance; // Distance from center of sphere to camera
varying vec4 particle_data_point;

void vertex() {
	int index = int(VERTEX.x);
	VERTEX.x = float(index);
	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);
	particle_data_point = texelFetch(particle_data, pixel_coord, 0);
	world_pos = origin + particle_data_point.xyz;
	view_pos = (VIEW_MATRIX * vec4(world_pos, 1.0)).xyz;
	VERTEX.xyz = world_pos;
	camera_distance = distance(CAMERA_POSITION_WORLD, world_pos);
	
	vec4 clip_pos = PROJECTION_MATRIX * vec4(view_pos, 1.0);
	vec2 ndc_pos = clip_pos.xy / clip_pos.w;
	float edge_distance = length(ndc_pos);
	
	float edge_compensation = 1.0 + edge_distance * 0.3; // Particles closer to the edge have a larger point size
	POINT_SIZE = (particle_size / camera_distance) * edge_compensation;
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
		ALBEDO = vec3(depth);
	}

	if (CAMERA_VISIBLE_LAYERS == 4u) { // Normal layer
		discard;
	}

	if (CAMERA_VISIBLE_LAYERS == 8u){ // Thickness layer
		discard;
	}

	if (CAMERA_VISIBLE_LAYERS == 16u){ // Light layer
		discard;
	}
}