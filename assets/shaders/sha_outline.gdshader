shader_type canvas_item;
// Outline expansion shader

uniform float pixel_w = 0.01;
uniform float pixel_h = 0.01;

void fragment() {
	vec2 offset_x = vec2(pixel_w, 0.0);
	vec2 offset_y = vec2(0.0, pixel_h);

	float alpha = texture(TEXTURE, UV).a;
	alpha = max(alpha, texture(TEXTURE, UV + offset_x).a);
	alpha = max(alpha, texture(TEXTURE, UV - offset_x).a);
	alpha = max(alpha, texture(TEXTURE, UV + offset_y).a);
	alpha = max(alpha, texture(TEXTURE, UV - offset_y).a);

	COLOR = COLOR * texture(TEXTURE, UV);
	COLOR.a = alpha;
}
