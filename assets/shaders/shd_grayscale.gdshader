shader_type canvas_item;
// Grayscale filter

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float gray = dot(col.rgb, vec3(0.21, 0.71, 0.07));
	COLOR = vec4(vec3(gray), col.a);
}
