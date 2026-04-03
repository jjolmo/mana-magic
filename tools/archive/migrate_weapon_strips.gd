@tool
extends EditorScript

## Generates weapon strip .tres with the SAME named animations as the actor .tres.
## This allows the weapon strip to play in sync with the character via AnimatedSprite2D.
##
## Two-pass: Run once to cut strips, wait for reimport, run again to build .tres.

const CHARACTERS := ["randi", "purim", "popoie"]
const WEAPONS := ["sword", "axe", "spear", "javelin", "bow", "boomerang", "whip"]
const COLS := 18
const FW := 46
const FH := 46

func _run() -> void:
	print("=== Weapon Strip Migration ===")
	var anim_defs := _get_actor_animation_defs()

	for character in CHARACTERS:
		for weapon in WEAPONS:
			var sheet_path := "res://assets/sprites/sheets/spr_weaponStrip_%s_%s.png" % [character, weapon]
			if not ResourceLoader.exists(sheet_path):
				continue

			print("  Processing: %s_%s" % [character, weapon])
			var sheet := _load_image(sheet_path)
			if not sheet:
				continue

			var out_dir := "res://assets/animations/weapon_strips/%s_%s" % [character, weapon]
			DirAccess.make_dir_recursive_absolute(out_dir)

			var anim_list := []
			for def in anim_defs:
				var anim_name: String = def["name"]
				var frames: Array = def["frames"]
				var fps: float = def.get("fps", 6.0)
				var loop: bool = def.get("loop", false)

				# Skip animations whose frames exceed the sheet size
				var max_frame: int = 0
				for f in frames:
					if f > max_frame:
						max_frame = f
				var sheet_total: int = (sheet.get_width() / FW) * (sheet.get_height() / FH)
				if max_frame >= sheet_total:
					continue

				var strip_path := "%s/%s.png" % [out_dir, anim_name]
				_save_strip(sheet, frames, strip_path)

				anim_list.append({
					"name": anim_name,
					"strip_path": strip_path,
					"frame_count": frames.size(),
					"fps": fps,
					"loop": loop,
				})

			# Build SpriteFrames
			var sf := SpriteFrames.new()
			if sf.has_animation("default"):
				sf.remove_animation("default")
			var missing := 0
			for anim in anim_list:
				sf.add_animation(anim["name"])
				sf.set_animation_speed(anim["name"], maxf(anim["fps"], 1.0))
				sf.set_animation_loop(anim["name"], anim["loop"])
				var strip_tex: Texture2D = load(anim["strip_path"])
				if not strip_tex:
					missing += 1
					continue
				for i in range(anim["frame_count"]):
					var atlas := AtlasTexture.new()
					atlas.atlas = strip_tex
					atlas.region = Rect2(i * FW, 0, FW, FH)
					atlas.filter_clip = true
					sf.add_frame(anim["name"], atlas)

			var tres_path := "%s/%s_%s_strip.tres" % [out_dir, character, weapon]
			ResourceSaver.save(sf, tres_path)
			if missing > 0:
				print("    %d strips not imported yet — run again" % missing)
			else:
				print("    Saved with %d animations" % anim_list.size())

	EditorInterface.get_resource_filesystem().scan()
	print("=== Done ===")

func _save_strip(sheet: Image, frame_indices: Array, out_path: String) -> void:
	var count := frame_indices.size()
	if count == 0:
		return
	var strip := Image.create(FW * count, FH, false, sheet.get_format())
	for i in range(count):
		var idx: int = frame_indices[i]
		var col: int = idx % COLS
		var row: int = idx / COLS
		var src_rect := Rect2i(col * FW, row * FH, FW, FH)
		strip.blit_rect(sheet, src_rect, Vector2i(i * FW, 0))
	strip.save_png(out_path)

func _load_image(path: String) -> Image:
	var tex: Texture2D = load(path)
	if not tex:
		return null
	return tex.get_image()

func _frame_range(ini: int, end: int) -> Array:
	var arr := []
	for i in range(ini, end + 1):
		arr.append(i)
	return arr

func _get_actor_animation_defs() -> Array:
	var defs := []

	# Stand
	defs.append({"name": "stand_up", "frames": [0], "fps": 1, "loop": false})
	defs.append({"name": "stand_right", "frames": [1], "fps": 1, "loop": false})
	defs.append({"name": "stand_down", "frames": [2], "fps": 1, "loop": false})
	defs.append({"name": "stand_left", "frames": [3], "fps": 1, "loop": false})

	# Walk
	defs.append({"name": "walk_up", "frames": _frame_range(5, 10), "fps": 12, "loop": true})
	defs.append({"name": "walk_right", "frames": _frame_range(12, 17), "fps": 12, "loop": true})
	defs.append({"name": "walk_down", "frames": _frame_range(19, 24), "fps": 12, "loop": true})
	defs.append({"name": "walk_left", "frames": _frame_range(26, 31), "fps": 12, "loop": true})

	# Walk charging
	defs.append({"name": "walk_charging_up", "frames": _frame_range(38, 39), "fps": 6, "loop": true})
	defs.append({"name": "walk_charging_right", "frames": _frame_range(41, 42), "fps": 6, "loop": true})
	defs.append({"name": "walk_charging_down", "frames": _frame_range(44, 45), "fps": 6, "loop": true})
	defs.append({"name": "walk_charging_left", "frames": _frame_range(47, 48), "fps": 6, "loop": true})

	# Run
	defs.append({"name": "run_up", "frames": _frame_range(83, 88), "fps": 9, "loop": true})
	defs.append({"name": "run_right", "frames": _frame_range(90, 95), "fps": 9, "loop": true})
	defs.append({"name": "run_down", "frames": _frame_range(97, 102), "fps": 9, "loop": true})
	defs.append({"name": "run_left", "frames": _frame_range(104, 109), "fps": 9, "loop": true})

	# Hit
	defs.append({"name": "hit_up", "frames": _frame_range(111, 116), "fps": 9, "loop": false})
	defs.append({"name": "hit_right", "frames": _frame_range(118, 123), "fps": 9, "loop": false})
	defs.append({"name": "hit_down", "frames": _frame_range(125, 130), "fps": 9, "loop": false})
	defs.append({"name": "hit_left", "frames": _frame_range(132, 137), "fps": 9, "loop": false})

	# Hit2
	defs.append({"name": "hit2_up", "frames": _frame_range(139, 141), "fps": 4.8, "loop": false})
	defs.append({"name": "hit2_right", "frames": _frame_range(139, 141), "fps": 4.8, "loop": false})
	defs.append({"name": "hit2_down", "frames": _frame_range(147, 149), "fps": 4.8, "loop": false})
	defs.append({"name": "hit2_left", "frames": _frame_range(147, 149), "fps": 4.8, "loop": false})

	# Recover
	defs.append({"name": "recover_up", "frames": _frame_range(141, 145), "fps": 6, "loop": false})
	defs.append({"name": "recover_right", "frames": _frame_range(141, 145), "fps": 6, "loop": false})
	defs.append({"name": "recover_down", "frames": _frame_range(149, 153), "fps": 6, "loop": false})
	defs.append({"name": "recover_left", "frames": _frame_range(149, 153), "fps": 6, "loop": false})

	# Push
	defs.append({"name": "push_up", "frames": _frame_range(155, 156), "fps": 6, "loop": false})
	defs.append({"name": "push_right", "frames": _frame_range(158, 159), "fps": 6, "loop": false})
	defs.append({"name": "push_down", "frames": _frame_range(161, 162), "fps": 6, "loop": false})
	defs.append({"name": "push_left", "frames": _frame_range(164, 165), "fps": 6, "loop": false})

	# Summon
	defs.append({"name": "summon_up", "frames": _frame_range(167, 172), "fps": 6, "loop": false})
	defs.append({"name": "summon_right", "frames": _frame_range(174, 179), "fps": 6, "loop": false})
	defs.append({"name": "summon_down", "frames": _frame_range(181, 186), "fps": 6, "loop": false})
	defs.append({"name": "summon_left", "frames": _frame_range(188, 193), "fps": 6, "loop": false})

	# Healed
	defs.append({"name": "healed_up", "frames": [195], "fps": 1, "loop": false})
	defs.append({"name": "healed_right", "frames": [196], "fps": 1, "loop": false})
	defs.append({"name": "healed_down", "frames": [197], "fps": 1, "loop": false})
	defs.append({"name": "healed_left", "frames": [198], "fps": 1, "loop": false})

	# Parry
	defs.append({"name": "parry_up", "frames": [200], "fps": 1, "loop": false})
	defs.append({"name": "parry_right", "frames": [201], "fps": 1, "loop": false})
	defs.append({"name": "parry_down", "frames": [202], "fps": 1, "loop": false})
	defs.append({"name": "parry_left", "frames": [203], "fps": 1, "loop": false})

	# Parry2
	defs.append({"name": "parry2_up", "frames": [200], "fps": 1, "loop": false})
	defs.append({"name": "parry2_right", "frames": [204], "fps": 1, "loop": false})
	defs.append({"name": "parry2_down", "frames": [202], "fps": 1, "loop": false})
	defs.append({"name": "parry2_left", "frames": [205], "fps": 1, "loop": false})

	# Avoid
	defs.append({"name": "avoid_up", "frames": _frame_range(207, 211), "fps": 6, "loop": false})
	defs.append({"name": "avoid_right", "frames": _frame_range(207, 211), "fps": 6, "loop": false})
	defs.append({"name": "avoid_down", "frames": _frame_range(213, 217), "fps": 6, "loop": false})
	defs.append({"name": "avoid_left", "frames": _frame_range(213, 217), "fps": 6, "loop": false})

	return defs
