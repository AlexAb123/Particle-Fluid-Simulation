#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Positions {
    vec2 positions[];  // Direct array
};

layout(set = 0, binding = 1, std430) restrict buffer Velocities {
    vec2 velocities[];
};

layout(set = 0, binding = 3, std430) restrict buffer Params {
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

layout(binding = 3, rgba16f) uniform image2D particle_data;

// The code we want to execute in each invocation
void main() {

    int index = int(gl_GlobalInvocationID.x);

    if (index >= params.particle_count) {
        return;
    }

    positions[index].x += velocities[index].x / 100;
    positions[index].y += velocities[index].y / 100;

    ivec2 pixel_coord = ivec2(index % params.image_size, index / params.image_size);
    
    // vec4 because it stores RGBA
    vec4 particle_info = vec4(
        positions[index].x,
        positions[index].y,
        velocities[index].x * velocities[index].x + velocities[index].y * velocities[index].y,
        0.0 // unused for now
    );

    imageStore(particle_data, pixel_coord, particle_info);
}