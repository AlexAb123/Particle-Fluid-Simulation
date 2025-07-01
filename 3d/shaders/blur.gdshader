shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	
	if (COLOR == vec4(0, 0, 0, 0)) discard;
	if (COLOR.a < 0.1) COLOR = vec4(0,0,1,1);
	float thickness = COLOR.a;
	
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
