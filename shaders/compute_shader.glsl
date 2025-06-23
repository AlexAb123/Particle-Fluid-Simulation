#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Positions {
    float data[];
}
positions;

layout(set = 0, binding = 1, std430) restrict buffer Velocities {
    float data[];
}
velocities;

layout(std430, set = 0, binding = 2) buffer Params {
	uint particle_count;
    float screen_width;
    float screen_height;
    float smoothing_radius;
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

layout(rgba16f, set = 0, binding = 3) restrict writeonly uniform image2D particle_data;

// The code we want to execute in each invocation
void main() {

    int index = int(gl_GlobalInvocationID.x);

    if (index > params.particle_count) {
        return;
    }

    int x = index * 2;
    int y = index * 2 + 1;

    positions.data[x] = params.image_size;
    positions.data[y] += velocities.data[y];

/*     int image_size = int(ceil(sqrt(float(particle_count))));
    ivec2 pixel_coord = ivec2(index % image_size, index / image_size);
    
    // Store position.xy in RG, velocity angle in B, and any other data in A
    vec4 particle_info = vec4(
        positions[index].x,
        positions[index].y, 
        atan(velocities[index].y, velocities[index].x), // velocity angle
        0.0 // unused for now
    );
    
    imageStore(particle_data, pixel_coord, particle_info); */
}