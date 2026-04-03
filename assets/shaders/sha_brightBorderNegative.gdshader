shader_type canvas_item;
// GMS2: sha_brightBorderNegative — border glows while rest goes grayscale
// NOTE: Prefer using sha_brightBorder.gdshader with negative=true uniform.
// This file kept for compatibility.

uniform float u_fTime : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	vec4 pixel_color = texture(TEXTURE, UV);
	vec3 c = pixel_color.rgb * 255.0;

	if ((abs(c.r - 40.0) < 1.0 && abs(c.g - 40.0) < 1.0 && abs(c.b - 40.0) < 1.0) ||
		(abs(c.r - 74.0) < 1.0 && abs(c.g - 56.0) < 1.0 && abs(c.b - 49.0) < 1.0)) {
		pixel_color.rgb /= max(pixel_color.a, 0.001);
		pixel_color.rgb += 1.0 - abs(-1.0 + mod(u_fTime, 2.0));
		pixel_color.rgb *= pixel_color.a;
		COLOR = pixel_color;
	} else {
		vec3 lum = vec3(0.299, 0.287, 0.114);
		COLOR = vec4(vec3(dot(pixel_color.rgb, lum)), pixel_color.a);
	}
}
