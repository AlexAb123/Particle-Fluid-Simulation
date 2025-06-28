#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

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

layout(set = 0, binding = 1, std430) restrict buffer BucketIndices {
    uint bucket_indices[]; // Maps particle index to bucket index. buckets[4] stores the bucket index that the particle with index 4 is in
};

layout(set = 0, binding = 3, std430) restrict buffer BucketPrefixSum {
    uint bucket_prefix_sum[];
};

layout(set = 0, binding = 5, std430) restrict buffer ParticlesByBucket {
    uint particles_by_bucket[]; // Stores particle indices sorted by their bucket indices
};

void main() {

    uint particle_index = gl_GlobalInvocationID.x;

    if (particle_index >= params.particle_count) { // Will be assigning values in particles_by_bucket which has length particle_count, so only use indices less than particle_count
        return;
    }

    uint bucket = bucket_indices[particle_index];
    uint previous_bucket_index = atomicAdd(bucket_prefix_sum[bucket], 1);
    particles_by_bucket[previous_bucket_index] = particle_index;
}