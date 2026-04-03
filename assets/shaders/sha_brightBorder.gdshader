shader_type canvas_item;
// GMS2: sha_brightBorder / sha_brightBorderNegative combined
// Border pixels (RGB 40,40,40 or 74,56,49) get pulsing brightness.
// When negative=true, all other pixels are converted to grayscale.

uniform float u_fTime : hint_range(0.0, 2.0) = 0.0;
uniform bool negative = false;

void fragment() {
	vec4 pixel_color = texture(TEXTURE, UV);
	vec3 c = pixel_color.rgb * 255.0;

	bool is_border = (abs(c.r - 40.0) < 1.0 && abs(c.g - 40.0) < 1.0 && abs(c.b - 40.0) < 1.0) ||
		(abs(c.r - 74.0) < 1.0 && abs(c.g - 56.0) < 1.0 && abs(c.b - 49.0) < 1.0);

	if (is_border) {
		pixel_color.rgb /= max(pixel_color.a, 0.001);
		// Triangle wave 0→1→0 over u_fTime range 0→2
		pixel_color.rgb += 1.0 - abs(-1.0 + mod(u_fTime, 2.0));
		pixel_color.rgb *= pixel_color.a;
		COLOR = pixel_color;
	} else if (negative) {
		// GMS2: sha_brightBorderNegative — grayscale via luminance
		vec3 lum = vec3(0.299, 0.287, 0.114);
		COLOR = vec4(vec3(dot(pixel_color.rgb, lum)), pixel_color.a);
	} else {
		COLOR = pixel_color;
	}
}
