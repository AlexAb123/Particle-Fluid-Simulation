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

layout(set = 0, binding = 2, std430) restrict buffer BucketCounts {
    uint bucket_counts[];
};

void main() {

    uint bucket_index = gl_GlobalInvocationID.x;

    if (bucket_index >= params.bucket_count) {
        return;
    }

    bucket_counts[bucket_index] = 0; // Reset bucket count if this is a valid bucket index
}

/*  
vec2 positions[]
    size = particle_count
    maps particle index to position

uint bucket_indices[]
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
    stores particle indices sorted by their bucket. This means you can use offsets array (see below) to quickly find all particles in any given bucket given the bucket_id
    To get sorted array of buckets:
    iterate backwards through bucket_prefix_sum[] (backwards keeps the sort stable)
    take the ith element and place i (the bucket index) in the bucket_prefix_sum[i]th place in the output array
    decrement bucket_prefix_sum[i]

    once all spots in output array is filled and decrements are done, bucket_prefix_sum[] acts as an offsets array
    the offset array (bucket_prefix_sum[]) maps bucket_index to where the first 
*/