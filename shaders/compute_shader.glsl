#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Positions {
    float data[];
}
positions;

layout(set = 0, binding = 1, std430) restrict buffer Velocities {
    float data[];
}
velocities;

// The code we want to execute in each invocation
void main() {
    positions.data[gl_GlobalInvocationID.x] += velocities.data[gl_GlobalInvocationID.x];
    positions.data[gl_GlobalInvocationID.x + 1] += velocities.data[gl_GlobalInvocationID.x + 1];
}