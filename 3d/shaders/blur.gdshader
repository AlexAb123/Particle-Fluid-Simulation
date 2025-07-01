shader_type canvas_item;

uniform sampler2D depth_map: repeat_disable;
uniform sampler2D normal_map: repeat_disable;
uniform sampler2D thickness_map: repeat_disable;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.

	if (COLOR == vec4(0, 0, 0, 0)) discard;
	float thickness = COLOR.a;

}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
