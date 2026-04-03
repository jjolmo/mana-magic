shader_type canvas_item;
// Poison effect - swaps skin tone colors to purple/blue

void fragment() {
	vec4 OC = texture(TEXTURE, UV);
	vec3 c = OC.rgb * 255.0;

	// Skin tone group 1 -> blue tint
	if ((abs(c.r - 247.0) < 1.0 && abs(c.g - 186.0) < 1.0 && abs(c.b - 123.0) < 1.0) ||
		(abs(c.r - 214.0) < 1.0 && abs(c.g - 121.0) < 1.0 && abs(c.b - 82.0) < 1.0) ||
		(abs(c.r - 255.0) < 1.0 && abs(c.g - 219.0) < 1.0 && abs(c.b - 173.0) < 1.0) ||
		(abs(c.r - 255.0) < 1.0 && abs(c.g - 178.0) < 1.0 && abs(c.b - 149.0) < 1.0) ||
		(abs(c.r - 248.0) < 1.0 && abs(c.g - 192.0) < 1.0 && abs(c.b - 168.0) < 1.0)) {
		OC.r = 189.0 / 255.0;
		OC.g = 195.0 / 255.0;
		OC.b = 255.0 / 255.0;
	}
	// Skin tone group 2 -> darker blue
	else if ((abs(c.r - 140.0) < 1.0 && abs(c.g - 81.0) < 1.0 && abs(c.b - 57.0) < 1.0) ||
			(abs(c.r - 216.0) < 1.0 && abs(c.g - 127.0) < 1.0 && abs(c.b - 77.0) < 1.0) ||
			(abs(c.r - 208.0) < 1.0 && abs(c.g - 136.0) < 1.0 && abs(c.b - 112.0) < 1.0) ||
			(abs(c.r - 222.0) < 1.0 && abs(c.g - 130.0) < 1.0 && abs(c.b - 90.0) < 1.0)) {
		OC.r = 140.0 / 255.0;
		OC.g = 138.0 / 255.0;
		OC.b = 222.0 / 255.0;
	}

	COLOR = OC;
}
