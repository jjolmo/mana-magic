class_name SpriteUtils
## Shared utilities for loading spritesheets and building SpriteFrames/AtlasTexture arrays.
## Centralizes the "spritesheet + JSON metadata → frames" pattern used across the codebase.

## Load a spritesheet and return an array of AtlasTexture frames.
## JSON sidecar file is expected at the same path with .json extension.
static func load_sheet_frames(sheet_name: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var sheet_path: String = "res://assets/sprites/sheets/%s.png" % sheet_name
	var json_path: String = "res://assets/sprites/sheets/%s.json" % sheet_name

	var sheet: Texture2D = load(sheet_path) as Texture2D
	if not sheet:
		push_warning("SpriteUtils: spritesheet not found: %s" % sheet_path)
		return result

	var fw: int = 16
	var fh: int = 16
	var cols: int = 1
	var total: int = 0

	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var meta: Dictionary = json.data
				fw = int(meta.get("frame_width", 16))
				fh = int(meta.get("frame_height", 16))
				cols = int(meta.get("columns", 1))
				total = int(meta.get("total_frames", 0))
			file.close()

	if cols <= 0:
		cols = 1
	if total <= 0:
		total = (sheet.get_width() / maxi(fw, 1)) * (sheet.get_height() / maxi(fh, 1))

	for i in range(total):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.filter_clip = true
		@warning_ignore("INTEGER_DIVISION")
		atlas.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		result.append(atlas)

	return result


## Build a SpriteFrames resource from a spritesheet with one animation.
## Reads frame dimensions from JSON sidecar file.
## fps_override > 0 overrides the JSON playback_speed.
static func build_sprite_frames(sheet_name: String, anim_name: String = "default",
		fps_override: float = 0.0, loop: bool = false) -> SpriteFrames:
	var sheet_path: String = "res://assets/sprites/sheets/%s.png" % sheet_name
	var json_path: String = "res://assets/sprites/sheets/%s.json" % sheet_name

	var sheet: Texture2D = load(sheet_path) as Texture2D
	if not sheet:
		push_warning("SpriteUtils: spritesheet not found: %s" % sheet_path)
		return null

	var fw: int = 32
	var fh: int = 32
	var cols: int = 1
	var total: int = 0
	var fps: float = 15.0

	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var meta: Dictionary = json.data
				fw = int(meta.get("frame_width", 32))
				fh = int(meta.get("frame_height", 32))
				cols = int(meta.get("columns", 1))
				total = int(meta.get("total_frames", 0))
				fps = float(meta.get("playback_speed", 15.0))
			file.close()

	if cols <= 0:
		cols = 1
	if total <= 0:
		total = (sheet.get_width() / maxi(fw, 1)) * (sheet.get_height() / maxi(fh, 1))
	if fps_override > 0.0:
		fps = fps_override

	var sf := SpriteFrames.new()
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)

	for i in range(total):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.filter_clip = true
		@warning_ignore("INTEGER_DIVISION")
		atlas.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		sf.add_frame(anim_name, atlas)

	return sf


## Build a SpriteFrames from a spritesheet with explicit parameters (no JSON needed).
static func build_sprite_frames_manual(sheet: Texture2D, anim_name: String,
		fw: int, fh: int, cols: int, total: int, fps: float,
		loop: bool = false) -> SpriteFrames:
	if not sheet:
		return null

	var sf := SpriteFrames.new()
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loop)

	for i in range(total):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.filter_clip = true
		@warning_ignore("INTEGER_DIVISION")
		atlas.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		sf.add_frame(anim_name, atlas)

	return sf


## Get sprite origin offset from JSON metadata.
## Returns Vector2 offset to center the sprite at its origin point.
static func get_sheet_offset(sheet_name: String) -> Vector2:
	var json_path: String = "res://assets/sprites/sheets/%s.json" % sheet_name
	if not FileAccess.file_exists(json_path):
		return Vector2.ZERO

	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		return Vector2.ZERO

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return Vector2.ZERO
	file.close()

	var meta: Dictionary = json.data
	var fw: int = int(meta.get("frame_width", 32))
	var fh: int = int(meta.get("frame_height", 32))
	@warning_ignore("INTEGER_DIVISION")
	var ox: int = int(meta.get("xorigin", fw / 2))
	@warning_ignore("INTEGER_DIVISION")
	var oy: int = int(meta.get("yorigin", fh / 2))
	@warning_ignore("INTEGER_DIVISION")
	return Vector2(-ox + fw / 2, -oy + fh / 2)
