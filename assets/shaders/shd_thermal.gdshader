shader_type canvas_item;
// Thermal vision filter

void fragment() {
	vec4 base_colour = texture(TEXTURE, UV);

	vec3 cold = vec3(0.0, 0.0, 1.0);
	vec3 mid = vec3(1.0, 1.0, 0.0);
	vec3 hot = vec3(1.0, 0.0, 0.0);

	float lum = (base_colour.r + base_colour.g + base_colour.b) / 3.0;

	vec3 thermal;
	if (lum < 0.5) {
		thermal = mix(cold, mid, lum / 0.5);
	} else {
		thermal = mix(mid, hot, (lum - 0.5) / 0.5);
	}

	COLOR = vec4(thermal, base_colour.a);
}
