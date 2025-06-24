#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Positions {
    vec2 positions[];  // Direct array
};

layout(set = 0, binding = 1, std430) restrict buffer BucketIndices {
    uint bucket_indices[]; // Maps particle index to bucket index. buckets[4] stores the bucket index that the particle with index 4 is in
};

layout(set = 0, binding = 2, std430) restrict buffer BucketCounts {
    uint bucket_counts[];
};

layout(set = 0, binding = 3, std430) restrict buffer BucketPrefixSum {
    uint bucket_prefix_sum[];
};

layout(set = 0, binding = 4, std430) restrict buffer BucketOffsets {
    uint bucket_offsets[];
};

layout(set = 0, binding = 5, std430) restrict buffer SortedBuckets {
    uint sorted_buckets[];
};

layout(set = 0, binding = 6, std430) restrict buffer Params {
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

layout(set = 0, binding = 7, std430) restrict buffer Velocities {
    vec2 velocities[];
};


layout(binding = 3, rgba16f) uniform image2D particle_data;

uint grid_pos_to_bucket_index(ivec2 grid_pos) {
    return grid_pos.y * params.grid_width + grid_pos.x; // Flattens grid into a one dimensional line
}

ivec2 pos_to_grid_pos(vec2 pos) {
    return ivec2(pos / params.smoothing_radius);
}

// The code we want to execute in each invocation
void main() {

    uint particle_index = gl_GlobalInvocationID.x;

    if (particle_index >= params.particle_count) {
        return;
    }

    uint bucket_index = bucket_indices[particle_index]; // The bucket that this particle is contained in

    ivec2 grid_pos = pos_to_grid_pos(positions[particle_index]);

    for (int dx = -1; dx <= 1; dx++) {

        for (int dy = -1; dy <= 1; dy++) {

            ivec2 neighbour_grid_pos = grid_pos + ivec2(dx, dy);

            if (neighbour_grid_pos.x < 0 || neighbour_grid_pos.y < 0 || neighbour_grid_pos.x >= int(params.grid_width) || neighbour_grid_pos.y >= int(params.grid_height)) {
                continue; // Continue if neighbour_grid_pos is out of bounds
            }

            uint neighbour_bucket_index = grid_pos_to_bucket_index(neighbour_grid_pos);
            uint start = bucket_offsets[neighbour_bucket_index];
            uint end = neighbour_bucket_index + 1 < params.bucket_count ? bucket_offsets[neighbour_bucket_index + 1] : params.particle_count; // End at the next offset if it exists, else end at the end of the sorted_buckets array (size of sorted_buckets array is particle_count)

            // Iterate over all particle indices in neighbour_bucket_index
            for (uint i = start; i < end; i++) {

                uint neighbour_index = sorted_buckets[i];

            }

        }
    }
}