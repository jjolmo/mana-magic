shader_type canvas_item;
// Ghost effect - grayscale + alpha adjustment

uniform float u_alpha : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = col.r * 0.4126 + col.g * 0.7152 + col.b * 0.0722;
	COLOR = vec4(vec3(gray), col.a + u_alpha);
}
