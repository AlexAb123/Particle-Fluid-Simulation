#[compute]
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

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

layout(set = 0, binding = 6, std430) restrict buffer Positions {
    vec3 positions[];
};
layout(set = 0, binding = 7, std430) restrict buffer SortedPositions {
    vec3 sorted_positions[];
};

layout(set = 0, binding = 8, std430) restrict buffer Velocities {
    vec3 velocities[];
};

layout(set = 0, binding = 9, std430) restrict buffer SortedVelocities {
    vec3 sorted_velocities[];
};

layout(set = 0, binding = 10, std430) restrict buffer Densities {
    float densities[];
};

layout(set = 0, binding = 11, std430) restrict buffer SortedDensities {
    float sorted_densities[];
};

layout(set = 0, binding = 12, std430) restrict buffer NearDensities {
    float near_densities[];
};

layout(set = 0, binding = 13, std430) restrict buffer SortedNearDensities {
    float sorted_near_densities[];
};

void main() {

    uint particle_index = gl_GlobalInvocationID.x;

    if (particle_index >= params.particle_count) { // Will be assigning values in sorted_indices which has length particle_count, so only use indices less than particle_count
        return;
    }

    positions[particle_index] = sorted_positions[particle_index];
    velocities[particle_index] = sorted_velocities[particle_index];
    densities[particle_index] = sorted_densities[particle_index];
    near_densities[particle_index] = sorted_near_densities[particle_index];
}