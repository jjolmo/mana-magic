shader_type canvas_item;
// Texture-based palette swap (GMS2: shd_pal_swapper)
// Palette format: NxM texture where columns = palette variants, rows = colors to swap
// Column 0 = reference colors (original), columns 1-3 = palette variants

uniform sampler2D palette_texture : filter_nearest, repeat_disable;
uniform vec2 texel_size = vec2(0.01, 0.01);
uniform vec4 palette_uvs = vec4(0.0, 0.0, 1.0, 1.0); // x_start, y_start, x_end, y_end
uniform float palette_index = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);

	if (source.a >= 0.01) {
		// Iterate over palette rows looking for matching reference color (column 0)
		for (float i = palette_uvs.y; i < palette_uvs.w; i += texel_size.y) {
			// Sample center of texel to avoid filtering artifacts
			float row_center = i + texel_size.y * 0.5;
			vec4 pal_color = texture(palette_texture, vec2(palette_uvs.x + texel_size.x * 0.5, row_center));
			if (distance(source.rgb, pal_color.rgb) <= 0.02) {
				// Found matching color — read from the target palette column
				float col_center = palette_uvs.x + texel_size.x * palette_index + texel_size.x * 0.5;
				source = texture(palette_texture, vec2(col_center, row_center));
				break;
			}
		}
	}

	COLOR = source * COLOR;
}
