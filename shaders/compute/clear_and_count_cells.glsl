#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Positions {
    vec2 positions[]; 
};

layout(set = 0, binding = 1, std430) restrict buffer Cells {
    uint cells[]; // Maps particle index to cell index. cells[4] stores the cell index that the particle with index 4 is in
};

layout(set = 0, binding = 2, std430) restrict buffer CellCounts {
    uint cell_counts[];
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

uint pos_to_bucket(vec2 pos) {
    ivec2 grid_pos = ivec2(pos / params.smoothing_radius);
    return grid_pos.y * params.grid_width + grid_pos.x; // Flattens grid into a one dimensional line
}

void main() {

    int index = int(gl_GlobalInvocationID.x);


    if (index < params.cell_count) {
        cell_counts[index] = 0; // Reset cell count if this is a valid cell index
    }

    barrier(); // Barrier so that any value in cell_counts is not changed until it has been reset


    if (index < params.particle_count) {
        atomicAdd(cell_counts[pos_to_bucket(positions[index])], 1); // Increment cell count for counting sort if this is a valid particle index
    }
}

