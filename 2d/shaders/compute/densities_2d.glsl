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
    float near_pressure_multiplier;
    float target_density;
    float gravity;
    float elasticity;
    float viscosity;
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

layout(set = 0, binding = 8, std430) restrict buffer NearDensities {
    float near_densities[];
};

const float PI = 3.14159265359;

uint grid_pos_to_bucket_index(ivec2 grid_pos) {
    return grid_pos.y * params.grid_width + grid_pos.x; // Flattens grid into a one dimensional line
}

ivec2 pos_to_grid_pos(vec2 pos) {
    return ivec2(pos / params.smoothing_radius) ; 
}

float density_kernel(float dst) {
	if (dst >= params.smoothing_radius) {
		return 0;
    }
	float factor = 6.0 / (pow(params.smoothing_radius, 4) * PI) ;
	return pow(params.smoothing_radius - dst, 2) * factor;
}

float near_density_kernel(float dst) {
    if (dst >= params.smoothing_radius) {
        return 0;
	}
    float factor = 10.0 / (pow(params.smoothing_radius, 5) * PI);
    return pow(params.smoothing_radius - dst, 3) * factor;
}

void main() {

    uint particle_index = gl_GlobalInvocationID.x;

    if (particle_index >= params.particle_count) {
        return;
    }
    if (particle_index >= params.particle_count) {
        return;
    }
    vec2 pos = positions[particle_index];
    float density = 0.0;
    float near_density = 0.0;

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

                // Density calulations
                float dst = distance(pos, positions[neighbour_index]);
                if (dst > params.smoothing_radius) {
                    continue;
                }
                density += density_kernel(dst) * params.particle_mass;
                near_density += near_density_kernel(dst) * params.particle_mass;
            }
        }
    }
    densities[particle_index] = density;
    near_densities[particle_index] = near_density;
}