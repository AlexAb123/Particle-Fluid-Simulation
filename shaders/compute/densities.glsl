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
    uint cell_count;
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

// The code we want to execute in each invocation
void main() {

    int particle_index = int(gl_GlobalInvocationID.x);

    if (particle_index >= params.particle_count) {
        return;
    }

    bucket_index = bucket_indices[particle_index]
}