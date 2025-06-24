#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Positions {
    vec2 positions[]; 
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
    uint bucket_offsets[]; // Maps bucket index to the index in the particles_by_bucket array in which the particles contained in that bucket begin to be listed in the particles_by_bucket array
};

layout(set = 0, binding = 5, std430) restrict buffer ParticlesByBucket {
    uint particles_by_bucket[]; // Stores particle indices sorted by their bucket indices
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

uint pos_to_bucket_index(vec2 pos) { // Returns the bucket index given the position of the particle
    ivec2 grid_pos = ivec2(pos / params.smoothing_radius);
    return grid_pos.y * params.grid_width + grid_pos.x; // Flattens grid into a one dimensional line
}

void main() {

    uint particle_index = gl_GlobalInvocationID.x;

    if (particle_index < params.particle_count) {
        uint bucket_index = pos_to_bucket_index(positions[particle_index]);
        bucket_indices[particle_index] = bucket_index;
        atomicAdd(bucket_counts[bucket_index], 1); // Increment bucket count for counting sort if this is a valid particle index
    }
}

/*  
vec2 positions[]
    size = particle_count
    maps particle index to position

uint buckets[]
    size = particle_count
    maps particle index to bucket index

uint bucket_counts[]
    size = bucket_count
    maps bucket_index to number of particles contained in that bucket
    created by counting occurences in buckets[]

uint bucket_prefix_sum[]
    size = bucket_count
    maps bucket_index to how many particles are contained in tuat bucket and all buckets before it
    is also used as an offsets array only AFTER doing all the decrements
    created by running a prefix sum on bucket_counts[]

uint output_array[]
    size = particle_count
    same as buckets but sorted. This means you can use offsets array (see below) to quickly find all particles in any given bucket given the bucket_id
    To get sorted array of buckets:
    iterate backwards through bucket_prefix_sum[] (backwards keeps the sort stable)
    take the ith element and place i (the bucket index) in the bucket_prefix_sum[i]th place in the output array
    decrement bucket_prefix_sum[i]

    once all spots in output array is filled and decrements are done, bucket_prefix_sum[] acts as an offsets array
    the offset array (bucket_prefix_sum[]) maps bucket_index to where the first 
*/