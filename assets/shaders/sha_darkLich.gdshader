shader_type canvas_item;
// Dark Lich - passthrough shader (boss-specific, used as placeholder for palette swaps)

void fragment() {
	COLOR = COLOR * texture(TEXTURE, UV);
}
