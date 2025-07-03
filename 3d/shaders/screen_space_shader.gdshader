shader_type canvas_item;

render_mode unshaded;

uniform sampler2D depth_texture;
uniform sampler2D normal_texture;
uniform sampler2D thickness_texture;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	
	// Called for every pixel the material is visible on.
	vec4 depth = texture(depth_texture, UV);
	vec4 normal = texture(normal_texture, UV);
	vec4 thickness = texture(thickness_texture, UV);
	
	COLOR = depth;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
