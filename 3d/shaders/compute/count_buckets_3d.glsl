#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

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
    float density_kernel_factor;
    float near_density_kernel_factor;
    float viscosity_kernel_factor;
    float mouse_force_radius;
}
params;

layout(set = 0, binding = 1, std430) restrict buffer BucketIndices {
    uint bucket_indices[]; // Maps particle index to bucket index. buckets[4] stores the bucket index that the particle with index 4 is in
};

layout(set = 0, binding = 2, std430) restrict buffer BucketCounts {
    uint bucket_counts[];
};

layout(set = 0, binding = 6, std430) restrict buffer Positions {
    vec3 positions[]; 
};

uint pos_to_bucket_index(vec3 pos) { // Returns the bucket index given the position of the particle
    ivec3 grid_pos = ivec3(pos / params.smoothing_radius);
    return (grid_pos.z * params.grid_width * params.grid_height) +
            (grid_pos.y * params.grid_width) +
            grid_pos.x;
}

void main() {

    uint particle_index = gl_GlobalInvocationID.x;

    if (particle_index >= params.particle_count) {
        return;
    }

    uint bucket_index = pos_to_bucket_index(positions[particle_index]);
    
    bucket_indices[particle_index] = bucket_index;
    atomicAdd(bucket_counts[bucket_index], 1); // Increment bucket count for counting sort if this is a valid particle index
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