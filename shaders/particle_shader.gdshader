shader_type particles;

uniform sampler2D particle_data;

void process() {
	// Called every frame on existing particles (according to the Fixed FPS property).

	// TRANSFORM[3] is the position row of the TRANSFORM matrix
    TRANSFORM[3][0] = 400.0;  // x position
    TRANSFORM[3][1] = 300.0;  // y position
}

void start() {
	// Called when a particle is spawned.
}