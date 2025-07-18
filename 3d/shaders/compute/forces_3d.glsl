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

layout(binding = 1, rgba16f) uniform image2D particle_data;

layout(set = 0, binding = 5, std430) restrict buffer BucketOffsets {
    uint bucket_offsets[]; // Maps bucket index to the index in the particles_by_bucket array in which the particles contained in that bucket begin to be listed in the particles_by_bucket array
};

layout(set = 0, binding = 6, std430) restrict buffer Positions {
    vec3 positions[];
};

layout(set = 0, binding = 8, std430) restrict buffer Velocities {
    vec3 velocities[];
};

layout(set = 0, binding = 10, std430) restrict buffer Densities {
    float densities[];
};

layout(set = 0, binding = 12, std430) restrict buffer NearDensities {
    float near_densities[];
};

layout(push_constant, std430) uniform PushConstant {
    float delta;
    float mouse_force_strength;
    float mouse_pos_x;
    float mouse_pos_y;
    float mouse_pos_z;
    float pad1;
    float pad2;
    float pad3;
}
push_constant;

const float PI = 3.14159265359;
const float epsilon = 0.001;

uint grid_pos_to_bucket_index(ivec3 grid_pos) { // Flattens grid into a one dimensional line
    return (grid_pos.z * params.grid_width * params.grid_height) +
            (grid_pos.y * params.grid_width) +
            grid_pos.x;
}

ivec3 pos_to_grid_pos(vec3 pos) {
    return ivec3(pos / params.smoothing_radius);
}

float density_to_pressure(float density) {
    return (density - params.target_density) * params.pressure_multiplier; // Can also clamp to 0 so there aren't any attractive forces (attractive forces don't really play well and can look odd)
}

float near_density_to_near_pressure(float near_density) {
    return near_density * params.near_pressure_multiplier;
}

float density_kernel(float dst) {
	if (dst >= params.smoothing_radius) {
		return 0;
    }
	return pow(params.smoothing_radius - dst, 2) * params.density_kernel_factor;
}

float density_kernel_derivative(float dst) {
	if (dst >= params.smoothing_radius) {
		return 0;
    }
	return -2 * (params.smoothing_radius - dst) * params.density_kernel_factor;
}

float near_density_kernel_derivative(float dst) {
    if (dst >= params.smoothing_radius) {
        return 0;
	}
    return -3 * pow(params.smoothing_radius - dst, 2) * params.near_density_kernel_factor;
}

float viscosity_kernel(float dst) // Poly6 Kernel
{
	if (dst >= params.smoothing_radius) {
		return 0;
    }
    return pow(pow(params.smoothing_radius, 2) - pow(dst, 2), 3) * params.viscosity_kernel_factor;
}

void main() {

    uint particle_index = gl_GlobalInvocationID.x;

    if (particle_index >= params.particle_count) {
        return;
    }
    
    vec3 pos = positions[particle_index];
    vec3 velocity = velocities[particle_index];
    float density = max(densities[particle_index], epsilon); // Max with epsilon so we dont divide by 0 if density is really small
    float near_density = max(near_densities[particle_index], epsilon);

    float pressure = density_to_pressure(density);
    float near_pressure = near_density_to_near_pressure(near_density);

    vec3 pressure_force = vec3(0.0, 0.0, 0.0);
    vec3 viscosity_force = vec3(0.0, 0.0, 0.0);
    
    ivec3 grid_pos = pos_to_grid_pos(positions[particle_index]);

    for (int dx = -1; dx <= 1; dx++) {

        for (int dy = -1; dy <= 1; dy++) {

            for (int dz = -1; dz <= 1; dz++) {

                ivec3 neighbour_grid_pos = grid_pos + ivec3(dx, dy, dz);

                if (neighbour_grid_pos.x < 0 || neighbour_grid_pos.y < 0 || neighbour_grid_pos.z < 0 ||
                    neighbour_grid_pos.x >= int(params.grid_width) || neighbour_grid_pos.y >= int(params.grid_height) || neighbour_grid_pos.z >= int(params.grid_depth)) {
                    continue; // Continue if neighbour_grid_pos is out of bounds
                }

                uint neighbour_bucket_index = grid_pos_to_bucket_index(neighbour_grid_pos);
                uint start = bucket_offsets[neighbour_bucket_index];
                uint end = neighbour_bucket_index + 1 < params.bucket_count ? bucket_offsets[neighbour_bucket_index + 1] : params.particle_count; // End at the next offset if it exists, else end at the end of the particles_by_bucket array (size of particles_by_bucket array is particle_count)

                // Iterate over all particle indices in neighbour_bucket_index
                for (uint neighbour_index = start; neighbour_index < end; neighbour_index++) {

                    if (particle_index == neighbour_index) { // Particle doesn't exert forces on itself
                        continue;
                    }
                    float dst = distance(pos, positions[neighbour_index]);
                    if (dst > params.smoothing_radius) {
                        continue;
                    }
                    vec3 neighbour_pos = positions[neighbour_index];
                    float neighbour_density = max(densities[neighbour_index], epsilon);
                    float neighbour_near_density = max(near_densities[neighbour_index], epsilon);

                    vec3 direction = dst == 0 ? vec3(0.0, 1.0, 0.0) : (neighbour_pos - pos) / dst; // Should really be a random direction if dst == 0, but a simple vector like this should work since dst will rarely be 0

                    float shared_pressure = (pressure + density_to_pressure(neighbour_density)) / 2.0;
                    float shared_near_pressure = (near_pressure + near_density_to_near_pressure(neighbour_near_density)) / 2.0;

                    pressure_force += params.particle_mass / neighbour_density * density_kernel_derivative(dst) * shared_pressure * direction;
                    pressure_force += params.particle_mass / neighbour_near_density * near_density_kernel_derivative(dst) * shared_near_pressure * direction;
                        
                    viscosity_force += params.viscosity * (velocities[neighbour_index] - velocity) * viscosity_kernel(dst) / neighbour_density;
                }
            }
        }
    }

    vec3 mouse_force = vec3(0.0);
    vec3 mouse_offset = vec3(push_constant.mouse_pos_x, push_constant.mouse_pos_y, push_constant.mouse_pos_z) - pos;
    if (length(mouse_offset) < params.mouse_force_radius) {
        vec3 mouse_dir = normalize(mouse_offset);
        mouse_force = mouse_dir * push_constant.mouse_force_strength / density;
    }

    pressure_force /= density;
    viscosity_force /= density;
    vec3 gravity_force = vec3(0.0, -params.gravity, 0.0);

    // Update velocity
    velocities[particle_index] += (pressure_force + viscosity_force + mouse_force + gravity_force) * push_constant.delta;

    // Update position
    positions[particle_index] += velocities[particle_index] * push_constant.delta;

    // Handle collisions with the edge of the bounds. Don't let the particles ever be on the edge though, so add or subtract a small number
    if (positions[particle_index].x <= 0) {
        positions[particle_index].x = 0 + epsilon;
        velocities[particle_index].x *= -1 * params.elasticity;
    }
    else if (positions[particle_index].x >= params.bounds_width) {
        positions[particle_index].x = params.bounds_width - epsilon;
        velocities[particle_index].x *= -1 * params.elasticity;
    }
        
    if (positions[particle_index].y <= 0) {
        positions[particle_index].y = 0 + epsilon ;
        velocities[particle_index].y *= -1 * params.elasticity;
    }
    else if (positions[particle_index].y >= params.bounds_height) {
        positions[particle_index].y = params.bounds_height - epsilon;
        velocities[particle_index].y *= -1 * params.elasticity;
    }

    if (positions[particle_index].z <= 0) {
        positions[particle_index].z = 0 + epsilon ;
        velocities[particle_index].z *= -1 * params.elasticity;
    }
    else if (positions[particle_index].z >= params.bounds_depth) {
        positions[particle_index].z = params.bounds_depth - epsilon;
        velocities[particle_index].z *= -1 * params.elasticity;
    }

    // Store particle data to texture for rendering
    ivec2 pixel_coord = ivec2(particle_index % params.image_size, particle_index / params.image_size);
    
    vec4 particle_info = vec4(
        positions[particle_index].x,
        positions[particle_index].y,
        positions[particle_index].z,
        length(velocities[particle_index])
    );

    imageStore(particle_data, pixel_coord, particle_info);
}