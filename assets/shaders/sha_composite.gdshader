shader_type canvas_item;
// Composite blend with color uniform - keeps dark outline unchanged

uniform vec4 u_color : source_color = vec4(0.0);

void fragment() {
	vec4 OC = texture(TEXTURE, UV);
	vec3 c = OC.rgb * 255.0;

	// Keep dark outline colors unchanged
	if ((abs(c.r - 40.0) < 1.0 && abs(c.g - 40.0) < 1.0 && abs(c.b - 40.0) < 1.0) ||
		(abs(c.r - 74.0) < 1.0 && abs(c.g - 56.0) < 1.0 && abs(c.b - 49.0) < 1.0)) {
		COLOR = vec4(49.0/255.0, 44.0/255.0, 33.0/255.0, OC.a);
	} else {
		COLOR = vec4(OC.r + u_color.r, OC.g + u_color.g, OC.b + u_color.b, OC.a + u_color.a);
	}
}
