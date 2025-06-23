shader_type particles;

uniform sampler2D particle_data;

void process() {
	// Called every frame on existing particles (according to the Fixed FPS property).
	
	// TRANSFORM[3] is the position row of the TRANSFORM matrix
	TRANSFORM[3].xy = particle_position;
}

void start() {
	// Called when a particle is spawned.
}