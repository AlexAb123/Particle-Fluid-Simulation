shader_type canvas_item;

render_mode unshaded;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.

	if (COLOR.a == 0.0) discard;
	else {
		float thickness = COLOR.a;
		COLOR.a *= 20.0;
	}

}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
