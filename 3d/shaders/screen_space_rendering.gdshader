shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D particle_data;
uniform sampler2D gradient_texture: repeat_disable;
uniform int particle_count;
uniform float particle_size;
uniform int image_size;
uniform vec3 origin;

varying vec4 data;

void vertex() {
	int index = int(VERTEX.x);
	VERTEX.x = float(index);
    POINT_SIZE = 10.0;
	
	ivec2 pixel_coord = ivec2(index % image_size, index / image_size);
	data = texelFetch(particle_data, pixel_coord, 0);

	vec3 pos = data.xyz;
	
	// Set particle position
	VERTEX.xyz = pos;

}

void fragment() {
	ALBEDO = texture(gradient_texture, vec2(data.w/450.0, 0.5)).rgb;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
