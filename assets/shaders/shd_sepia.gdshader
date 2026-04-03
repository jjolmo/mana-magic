shader_type canvas_item;
// Sepia tone filter

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec3 sepia;
	sepia.r = dot(col.rgb, vec3(0.393, 0.769, 0.189));
	sepia.g = dot(col.rgb, vec3(0.349, 0.686, 0.168));
	sepia.b = dot(col.rgb, vec3(0.272, 0.534, 0.131));
	COLOR = vec4(sepia, col.a);
}
