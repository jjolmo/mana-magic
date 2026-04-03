@tool
extends EditorScript

## Generates spear2 and spear3 strip PNGs and .tres files.
## Run TWICE: first to cut PNGs, second after reimport to build .tres.

func _run() -> void:
	var variants := {
		"spear2": {
			"path": "res://assets/sprites/sheets/spr_weapon_spear2.png",
			"fw": 108, "fh": 108, "cols": 10, "ox": 54, "oy": 54,
		},
		"spear3": {
			"path": "res://assets/sprites/sheets/spr_weapon_spear3.png",
			"fw": 108, "fh": 108, "cols": 10, "ox": 53, "oy": 54,
		},
	}
	# Same frame ranges as spear in WEAPON_ATTACK_DATA
	var dir_frames := {
		"attack_up": [0, 1, 2],
		"attack_right": [4, 5, 6],
		"attack_down": [8, 9, 10],
		"attack_left": [12, 13, 14],
	}
	var fps := 8.4  # spear speed: 0.14 * 60

	for vname in variants:
		var cfg: Dictionary = variants[vname]
		var sheet_img := _load_image(cfg["path"])
		if not sheet_img:
			push_error("Could not load: " + cfg["path"])
			continue

		var out_dir := "res://assets/animations/weapons/%s" % vname
		DirAccess.make_dir_recursive_absolute(out_dir)

		var anim_list := []
		for anim_name in dir_frames:
			var frames: Array = dir_frames[anim_name]
			var strip_path := "%s/%s.png" % [out_dir, anim_name]

			# Cut strip
			var strip := Image.create(cfg["fw"] * frames.size(), cfg["fh"], false, sheet_img.get_format())
			for i in range(frames.size()):
				var idx: int = frames[i]
				var col: int = idx % cfg["cols"]
				var row: int = idx / cfg["cols"]
				strip.blit_rect(sheet_img, Rect2i(col * cfg["fw"], row * cfg["fh"], cfg["fw"], cfg["fh"]), Vector2i(i * cfg["fw"], 0))
			strip.save_png(strip_path)

			anim_list.append({
				"name": anim_name,
				"strip_path": strip_path,
				"fw": cfg["fw"], "fh": cfg["fh"],
				"frame_count": frames.size(),
				"fps": fps,
			})

		# Build SpriteFrames
		var sf := SpriteFrames.new()
		if sf.has_animation("default"):
			sf.remove_animation("default")
		var missing := 0
		for anim in anim_list:
			sf.add_animation(anim["name"])
			sf.set_animation_speed(anim["name"], anim["fps"])
			sf.set_animation_loop(anim["name"], false)
			var strip_tex: Texture2D = load(anim["strip_path"])
			if not strip_tex:
				missing += 1
				continue
			for i in range(anim["frame_count"]):
				var atlas := AtlasTexture.new()
				atlas.atlas = strip_tex
				atlas.region = Rect2(i * anim["fw"], 0, anim["fw"], anim["fh"])
				atlas.filter_clip = true
				sf.add_frame(anim["name"], atlas)

		var tres_path := "%s/%s.tres" % [out_dir, vname]
		ResourceSaver.save(sf, tres_path)
		if missing > 0:
			print("  %s: saved (run again after reimport for frames)" % vname)
		else:
			print("  %s: saved with frames OK" % vname)

	EditorInterface.get_resource_filesystem().scan()
	print("Done — run again if strips weren't imported yet")

func _load_image(path: String) -> Image:
	var tex: Texture2D = load(path)
	if not tex:
		return null
	return tex.get_image()
