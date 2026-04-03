shader_type canvas_item;
// Animated palette swap - oscillating color channel replacement

uniform vec3 u_color_add = vec3(0.0);
uniform int u_color_channel = 0; // 0=R, 1=G, 2=B, 3=all
uniform float u_color_limit : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 OC = texture(TEXTURE, UV);
	vec3 c = OC.rgb * 255.0;

	// Skip dark outline colors (keep original)
	bool is_outline = (abs(c.r - 40.0) < 1.0 && abs(c.g - 40.0) < 1.0 && abs(c.b - 40.0) < 1.0) ||
		(abs(c.r - 74.0) < 1.0 && abs(c.g - 56.0) < 1.0 && abs(c.b - 49.0) < 1.0);

	if (!is_outline) {
		float calc_color;
		float div_color_limit = u_color_limit;

		if (u_color_channel == 0) {
			calc_color = abs(-1.0 - OC.r + u_color_add.r + mod(TIME, 2.0));
			if (calc_color > 1.0) calc_color = 2.0 - calc_color;
			if (div_color_limit > 0.0) calc_color = u_color_limit + calc_color * div_color_limit;
			OC.r = calc_color;
			OC.g = u_color_add.g;
			OC.b = u_color_add.b;
		} else if (u_color_channel == 1) {
			OC.r = u_color_add.r;
			calc_color = abs(-1.0 - OC.g + u_color_add.g + mod(TIME, 2.0));
			if (calc_color > 1.0) calc_color = 2.0 - calc_color;
			if (div_color_limit > 0.0) calc_color = u_color_limit + calc_color * div_color_limit;
			OC.g = calc_color;
			OC.b = u_color_add.b;
		} else if (u_color_channel == 2) {
			OC.r = u_color_add.r;
			OC.g = u_color_add.g;
			calc_color = abs(-1.0 - OC.b + u_color_add.b + mod(TIME, 2.0));
			if (calc_color > 1.0) calc_color = 2.0 - calc_color;
			if (div_color_limit > 0.0) calc_color = u_color_limit + calc_color * div_color_limit;
			OC.b = calc_color;
		} else {
			calc_color = abs(-1.0 - OC.b + u_color_add.b + mod(TIME, 2.0));
			if (calc_color > 1.0) calc_color = 2.0 - calc_color;
			if (div_color_limit > 0.0) calc_color = u_color_limit + calc_color * div_color_limit;
			OC.r = calc_color;
			OC.g = calc_color;
			OC.b = calc_color;
		}
	}

	COLOR = OC;
}
