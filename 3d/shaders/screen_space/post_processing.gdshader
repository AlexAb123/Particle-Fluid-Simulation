shader_type canvas_item;

render_mode unshaded;

void vertex() {
}

void fragment() {
	COLOR.a *= 5.0;
	COLOR.rg = vec2(0);
	COLOR.b = 0.75;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
