shader_type canvas_item;

render_mode unshaded, blend_add;

uniform sampler2D depth_texture;
uniform sampler2D normal_texture;
uniform sampler2D thickness_texture;

void vertex() {
	
}

void fragment() {
	COLOR.a *= 3.0;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
