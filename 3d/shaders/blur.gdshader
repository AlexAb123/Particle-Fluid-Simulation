shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D viewport_texture;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	if (COLOR.x > 0.0) {
		COLOR = vec4(1,0,0,.5);
	}
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
