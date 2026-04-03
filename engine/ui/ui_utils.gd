class_name UIUtils
## Static utility class for GMS2-faithful UI rendering.
## Ports drawWindow() and drawSpriteTiledAreaExt() from GMS2.

## Draw a 9-patch window border using a sprite divided into a 3x3 grid.
## GMS2: drawWindow(sprite, x1, y1, width, height, guiScale, alpha, color, subImage)
## The sprite is 24x24 (or NxN), divided into 3x3 sections of 8x8 each.
static func draw_window(canvas: CanvasItem, sprite: Texture2D, x1: float, y1: float,
		w: float, h: float, gui_scale: float, alpha: float,
		color: Color = Color.WHITE, sub_image: int = 0, frame_count: int = 1) -> void:
	if sprite == null:
		return

	var sprite_w: int = sprite.get_width()
	# If this is a sprite sheet with multiple subimages stacked vertically,
	# frame_height = total_height / frame_count, each frame is one 9-patch
	var frame_h: int = sprite.get_height() / frame_count
	var frame_y_offset: int = sub_image * frame_h

	var _size: float = sprite_w / 3.0
	var x2: float = x1 + w
	var y2: float = y1 + h
	var mod_color: Color = Color(color.r, color.g, color.b, alpha)

	# Center fill (stretched)
	var center_src := Rect2(_size, frame_y_offset + _size, 1, 1)
	var center_dst := Rect2(x1 + _size, y1 + _size,
		w - _size * 2 * gui_scale, h - _size * 2 * gui_scale)
	canvas.draw_texture_rect_region(sprite, center_dst, center_src, mod_color)

	# 4 Corners
	var tl_src := Rect2(0, frame_y_offset, _size, _size)
	canvas.draw_texture_rect_region(sprite,
		Rect2(x1, y1, _size * gui_scale, _size * gui_scale), tl_src, mod_color)

	var tr_src := Rect2(_size * 2, frame_y_offset, _size, _size)
	canvas.draw_texture_rect_region(sprite,
		Rect2(x2 - _size, y1, _size * gui_scale, _size * gui_scale), tr_src, mod_color)

	var bl_src := Rect2(0, frame_y_offset + _size * 2, _size, _size)
	canvas.draw_texture_rect_region(sprite,
		Rect2(x1, y2 - _size, _size * gui_scale, _size * gui_scale), bl_src, mod_color)

	var br_src := Rect2(_size * 2, frame_y_offset + _size * 2, _size, _size)
	canvas.draw_texture_rect_region(sprite,
		Rect2(x2 - _size, y2 - _size, _size * gui_scale, _size * gui_scale), br_src, mod_color)

	# 4 Edges (stretched)
	# Left edge
	var le_src := Rect2(0, frame_y_offset + _size, _size, 1)
	canvas.draw_texture_rect_region(sprite,
		Rect2(x1, y1 + _size * gui_scale, _size * gui_scale,
			h - _size * gui_scale - _size), le_src, mod_color)

	# Right edge
	var re_src := Rect2(_size * 2, frame_y_offset + _size, _size, 1)
	canvas.draw_texture_rect_region(sprite,
		Rect2(x2 - _size, y1 + _size * gui_scale, _size * gui_scale,
			h - _size * gui_scale - _size), re_src, mod_color)

	# Top edge
	var te_src := Rect2(_size, frame_y_offset, 1, _size)
	canvas.draw_texture_rect_region(sprite,
		Rect2(x1 + _size * gui_scale, y1,
			w - _size * gui_scale - _size, _size * gui_scale), te_src, mod_color)

	# Bottom edge
	var be_src := Rect2(_size, frame_y_offset + _size * 2, 1, _size)
	canvas.draw_texture_rect_region(sprite,
		Rect2(x1 + _size * gui_scale, y2 - _size,
			w - _size * gui_scale - _size, _size * gui_scale), be_src, mod_color)


## Draw a sprite tiled across a rectangular area with color tint.
## GMS2: drawSpriteTiledAreaExt(sprite, subimg, x, y, x1, y1, x2, y2, color, alpha)
## tile_scale: scales tiles down (e.g. 1.0/3.0 for 96px GMS2 textures in 427×240 Godot viewport)
static func draw_sprite_tiled_area(canvas: CanvasItem, sprite: Texture2D,
		sub_image: int, xx: float, yy: float,
		x1: float, y1: float, x2: float, y2: float,
		color: Color, alpha: float, frame_count: int = 1,
		tile_scale: float = 1.0) -> void:
	if sprite == null:
		return

	var orig_sw: float = sprite.get_width()
	var orig_sh: float = sprite.get_height() / float(frame_count)
	var frame_y_offset: float = sub_image * orig_sh
	var mod_color: Color = Color(color.r, color.g, color.b, alpha)

	# Scaled tile dimensions (how big each tile appears in the viewport)
	var sw: float = orig_sw * tile_scale
	var sh: float = orig_sh * tile_scale

	# Calculate starting tile position using scaled tile sizes
	var start_i: float = x1 - fmod_positive(x1, sw) + fmod_positive(xx * tile_scale, sw)
	if start_i > x1:
		start_i -= sw
	var start_j: float = y1 - fmod_positive(y1, sh) + fmod_positive(yy * tile_scale, sh)
	if start_j > y1:
		start_j -= sh

	var i: float = start_i
	while i <= x2:
		var j: float = start_j
		while j <= y2:
			var left: float = maxf(x1 - i, 0)
			var top: float = maxf(y1 - j, 0)
			var right: float = minf(sw, x2 - i + 1)
			var bottom: float = minf(sh, y2 - j + 1)
			var draw_w: float = right - left
			var draw_h: float = bottom - top

			if draw_w > 0 and draw_h > 0:
				# Map destination coordinates back to source texture coordinates
				var src_left: float = left / tile_scale
				var src_top: float = top / tile_scale
				var src_w: float = draw_w / tile_scale
				var src_h: float = draw_h / tile_scale
				var src_rect := Rect2(src_left, frame_y_offset + src_top, src_w, src_h)
				var dst_rect := Rect2(i + left, j + top, draw_w, draw_h)
				canvas.draw_texture_rect_region(sprite, dst_rect, src_rect, mod_color)

			j += sh
		i += sw


## Helper: positive fmod (GMS2 mod behavior)
static func fmod_positive(a: float, b: float) -> float:
	if b == 0:
		return 0
	var result: float = fmod(a, b)
	if result < 0:
		result += b
	return result
