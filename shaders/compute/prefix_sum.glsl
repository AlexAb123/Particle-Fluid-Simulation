#[compute]
#version 450

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

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in; // Only one invocation per workgroup until a parallel prefix sum algorithm is implemented. Dispatch should use only one thread as well

void main() { // Optimize this buy implementing a prefix sum algorithm that utilizes parallelization. (Blelloch Scan)

    int particle_index = int(gl_GlobalInvocationID.x);

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

/*  
vec2 positions[]
    size = particle_count
    maps particle index to position

uint buckets[]
    size = bucket_count
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