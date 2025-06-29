#[compute]
#version 450

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in; // Only one invocation per workgroup until a parallel prefix sum algorithm is implemented. Dispatch should use only one thread as well

layout(set = 0, binding = 0, std430) restrict buffer Params {
	uint particle_count;
    float bounds_width;
    float bounds_height;
    float bounds_depth;
    float smoothing_radius;
    uint grid_width;
    uint grid_height;
    uint grid_depth;
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

layout(set = 0, binding = 2, std430) restrict buffer BucketCounts {
    uint bucket_counts[];
};

layout(set = 0, binding = 3, std430) restrict buffer BucketPrefixSum {
    uint bucket_prefix_sum[];
};

layout(set = 0, binding = 4, std430) restrict buffer BucketOffsets {
    uint bucket_offsets[]; // Maps bucket index to the index in the particles_by_bucket array in which the particles contained in that bucket begin to be listed in the particles_by_bucket array
};

void main() { // Optimize this buy implementing a prefix sum algorithm that utilizes parallelization. (Blelloch Scan)

    uint particle_index = gl_GlobalInvocationID.x;

    if (particle_index > 0) { // Only want to use one invocation
        return;
    }

    uint sum = 0;

    for (uint i = 0; i < params.bucket_count; i++) {
        bucket_prefix_sum[i] = sum;
        bucket_offsets[i] = sum;
        sum += bucket_counts[i];
    }
}