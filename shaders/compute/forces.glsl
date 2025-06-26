#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Params {
	uint particle_count;
    float screen_width;
    float screen_height;
    float smoothing_radius;
    uint grid_width;
    uint grid_height;
    uint bucket_count;
    float particle_mass; 
    float pressure_multiplier;
    float target_density;
    float gravity;
    float elasticity;
    float viscocity;
    uint steps_per_frame;
    uint image_size;
}
params;

layout(set = 0, binding = 4, std430) restrict buffer BucketOffsets {
    uint bucket_offsets[]; // Maps bucket index to the index in the particles_by_bucket array in which the particles contained in that bucket begin to be listed in the particles_by_bucket array
};

layout(set = 0, binding = 5, std430) restrict buffer ParticlesByBucket {
    uint particles_by_bucket[]; // Stores particle indices sorted by their bucket indices
};

layout(set = 0, binding = 6, std430) restrict buffer Positions {
    vec2 positions[];
};

layout(set = 0, binding = 7, std430) restrict buffer Densities {
    float densities[];
};

layout(set = 0, binding = 8, std430) restrict buffer Pressures {
    float pressures[];
};

layout(set = 0, binding = 9, std430) restrict buffer Velocities {
    vec2 velocities[];
};

layout(binding = 10, rgba16f) uniform image2D particle_data;

layout(push_constant, std430) uniform PushConstant {
    float delta;
    float padding1;
    float padding2;
    float padding3;
} push_constant;

uint grid_pos_to_bucket_index(ivec2 grid_pos) {
    return grid_pos.y * params.grid_width + grid_pos.x; // Flattens grid into a one dimensional line
}

ivec2 pos_to_grid_pos(vec2 pos) {
    return ivec2(pos / params.smoothing_radius);
}

const float PI = 3.14159265359;

float density_kernel(float dst) {
	if (dst >= params.smoothing_radius) {
		return 0;
    }
	float factor = pow(params.smoothing_radius, 3) * PI / 1.5;
	return pow(params.smoothing_radius - dst, 2) / factor;
}

float density_kernel_derivative(float dst) {
	if (dst >= params.smoothing_radius) {
		return 0;
    }
	float factor = pow(params.smoothing_radius, 3) * PI / 1.5;
	return -2 * (params.smoothing_radius - dst) / factor;
}

// The code we want to execute in each invocation
void main() {

    uint particle_index = gl_GlobalInvocationID.x;

    if (particle_index >= params.particle_count) {
        return;
    }
    if (particle_index >= params.particle_count) {
        return;
    }
    vec2 pos = positions[particle_index];
    vec2 velocity = velocities[particle_index];
    float density = densities[particle_index];
    float pressure = pressures[particle_index];
    vec2 pressure_force = vec2(0.0, 0.0);
    vec2 viscocity_force = vec2(0.0, 0.0);
    
    ivec2 grid_pos = pos_to_grid_pos(positions[particle_index]);

    for (int dx = -1; dx <= 1; dx++) {

        for (int dy = -1; dy <= 1; dy++) {

            ivec2 neighbour_grid_pos = grid_pos + ivec2(dx, dy);

            if (neighbour_grid_pos.x < 0 || neighbour_grid_pos.y < 0 || neighbour_grid_pos.x >= int(params.grid_width) || neighbour_grid_pos.y >= int(params.grid_height)) {
                continue; // Continue if neighbour_grid_pos is out of bounds
            }

            uint neighbour_bucket_index = grid_pos_to_bucket_index(neighbour_grid_pos);
            uint start = bucket_offsets[neighbour_bucket_index];
            uint end = neighbour_bucket_index + 1 < params.bucket_count ? bucket_offsets[neighbour_bucket_index + 1] : params.particle_count; // End at the next offset if it exists, else end at the end of the particles_by_bucket array (size of particles_by_bucket array is particle_count)

            // Iterate over all particle indices in neighbour_bucket_index
            for (uint i = start; i < end; i++) {

                uint neighbour_index = particles_by_bucket[i];
                if (particle_index == neighbour_index) { // Particle doesn't exert forces on itself
                    continue;
                }
                float dst = distance(pos, positions[neighbour_index]);
                if (dst > params.smoothing_radius) {
                    continue;
                }
                vec2 neighbour_pos = positions[neighbour_index];
                float neighbour_density = densities[neighbour_index];

                float magnitude = density_kernel_derivative(dst);
                vec2 direction = dst == 0 ? vec2(0.0, 1.0) : (neighbour_pos - pos) / dst; // Should really be a random direction if dst == 0, but a simple vector like this should work since dst will rarely be 0

                float shared_pressure = (pressure + pressures[neighbour_index]) / 2.0;

                pressure_force += params.particle_mass / neighbour_density * magnitude * shared_pressure * direction;
                	
                float influence = density_kernel(dst);

                viscocity_force += params.viscocity * (velocities[neighbour_index] - velocity) * influence / neighbour_density;

            }
        }
    }

    pressure_force /= density;
    viscocity_force /= density;
    vec2 gravity_force = vec2(0, params.gravity);

    // Update velocity
    velocities[particle_index] += (pressure_force + viscocity_force + gravity_force) * push_constant.delta;

    // Update position
    positions[particle_index] += velocities[particle_index] * push_constant.delta;
		
    // Handle collisions with the edge of the screen
    if (positions[particle_index].x < 0) {
        positions[particle_index].x = 0;
        velocities[particle_index].x *= -1 * params.elasticity;
    }
    else if (positions[particle_index].x > params.screen_width) {
        positions[particle_index].x = params.screen_width;
        velocities[particle_index].x *= -1 * params.elasticity;
    }
        
    if (positions[particle_index].y < 0) {
        positions[particle_index].y = 0;
        velocities[particle_index].y *= -1 * params.elasticity;
    }
    else if (positions[particle_index].y > params.screen_height) {
        positions[particle_index].y = params.screen_height;
        velocities[particle_index].y *= -1 * params.elasticity;
    }

    // Store particle data to texture for rendering
    ivec2 pixel_coord = ivec2(particle_index % params.image_size, particle_index / params.image_size);
    vec4 particle_info = vec4(
        positions[particle_index].x,
        positions[particle_index].y,
        length(velocities[particle_index]),
        0.0 // unused for now
    );
    imageStore(particle_data, pixel_coord, particle_info);
}