@tool
extends EditorScript

## Migration script: splits big sprite sheets into individual animation strips
## and generates SpriteFrames .tres resources.
##
## TWO-PASS WORKFLOW:
##   Pass 1: Run this script → cuts strips PNGs from sprite sheets
##   (Wait for Godot to reimport the new PNGs)
##   Pass 2: Run this script again → generates .tres from the imported strips
##
## Run from Godot Editor: Script > Run (Ctrl+Shift+X)

# ─── Helpers ────────────────────────────────────────────────────────────────────

## Extract frames from a sheet Image and save as a horizontal strip PNG.
func _save_strip(sheet: Image, columns: int, fw: int, fh: int,
		frame_indices: Array, out_path: String) -> String:
	var count := frame_indices.size()
	if count == 0:
		return ""
	var strip := Image.create(fw * count, fh, false, sheet.get_format())
	for i in range(count):
		var idx: int = frame_indices[i]
		var col: int = idx % columns
		var row: int = idx / columns
		var src_rect := Rect2i(col * fw, row * fh, fw, fh)
		strip.blit_rect(sheet, src_rect, Vector2i(i * fw, 0))
	var err := strip.save_png(out_path)
	if err != OK:
		push_error("Failed to save strip: %s (error %d)" % [out_path, err])
		return ""
	return out_path

## Build a SpriteFrames resource from animation definitions using STRIP textures.
## Each animation: { "name", "strip_path", "fw", "fh", "frame_count", "fps", "loop" }
## strip_path must point to an already-imported PNG strip.
func _build_sprite_frames(animations: Array, _origin: Vector2) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var _tex_cache: Dictionary = {}
	var missing_strips: int = 0

	for anim in animations:
		var anim_name: String = anim["name"]
		var strip_path: String = anim["strip_path"]
		var fw: int = anim["fw"]
		var fh: int = anim["fh"]
		var frame_count: int = anim["frame_count"]
		var fps: float = anim.get("fps", 6.0)
		var loop: bool = anim.get("loop", false)

		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, maxf(fps, 1.0))
		sf.set_animation_loop(anim_name, loop)

		# Load the strip texture (must be already imported by Godot)
		var strip_tex: Texture2D
		if _tex_cache.has(strip_path):
			strip_tex = _tex_cache[strip_path]
		else:
			strip_tex = load(strip_path)
			if strip_tex:
				_tex_cache[strip_path] = strip_tex
			else:
				missing_strips += 1
				continue

		for i in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = strip_tex
			atlas.region = Rect2(i * fw, 0, fw, fh)
			atlas.filter_clip = true
			sf.add_frame(anim_name, atlas)

	if missing_strips > 0:
		push_warning("  %d strips not yet imported — run script again after reimport" % missing_strips)
	return sf

## Ensure directory exists
func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)

## Load an image from res:// path
func _load_image(path: String) -> Image:
	var tex: Texture2D = load(path)
	if not tex:
		push_error("Could not load texture: %s" % path)
		return null
	return tex.get_image()

## Convert image_speed (frames per 1/60s step) to FPS
func _speed_to_fps(image_speed: float) -> float:
	return image_speed * 60.0

## Create a range array [ini, ini+1, ..., end] inclusive
func _frame_range(ini: int, end: int) -> Array:
	var arr := []
	for i in range(ini, end + 1):
		arr.append(i)
	return arr

# ─── Main ───────────────────────────────────────────────────────────────────────

func _run() -> void:
	print("=== Sprite Sheet Migration: Starting ===")

	_migrate_actors()
	_migrate_mobs()
	_migrate_npcs()
	_migrate_weapon_attacks()
	_migrate_weapon_strips()
	_migrate_boss_dark_lich()
	_migrate_boss_mana_beast()

	# Force reimport so Godot picks up the new PNGs
	EditorInterface.get_resource_filesystem().scan()

	print("=== Sprite Sheet Migration: Complete ===")

# ─── Actors ─────────────────────────────────────────────────────────────────────

func _migrate_actors() -> void:
	var actors := {
		"randi": "res://assets/sprites/sheets/spr_actor_randi.png",
		"purim": "res://assets/sprites/sheets/spr_actor_purim.png",
		"popoie": "res://assets/sprites/sheets/spr_actor_popoie.png",
	}
	var cols := 18
	var fw := 46
	var fh := 46
	var origin := Vector2(22, 35)
	var dirs := ["up", "right", "down", "left"]

	# Animation definitions: name_prefix → { dir → [ini, end], speed, loop }
	var anim_defs := _get_actor_animation_defs()

	for actor_name in actors:
		print("  Processing actor: %s" % actor_name)
		var sheet := _load_image(actors[actor_name])
		if not sheet:
			continue

		var out_dir := "res://assets/animations/actors/%s" % actor_name
		_ensure_dir(out_dir)

		var sheet_path: String = actors[actor_name]
		var anim_list := []

		for def in anim_defs:
			var anim_name: String = def["name"]
			var frames: Array = def["frames"]
			var fps: float = def.get("fps", 6.0)
			var loop: bool = def.get("loop", false)

			var strip_filename := "%s/%s.png" % [out_dir, anim_name]
			_save_strip(sheet, cols, fw, fh, frames, strip_filename)

			anim_list.append({
				"name": anim_name,
				"strip_path": strip_filename,
				"fw": fw, "fh": fh,
				"frame_count": frames.size(),
				"fps": fps,
				"loop": loop,
			})

		var sf := _build_sprite_frames(anim_list, origin)
		var tres_path := "%s/%s.tres" % [out_dir, actor_name]
		var err := ResourceSaver.save(sf, tres_path)
		if err == OK:
			print("    Saved: %s (%d animations)" % [tres_path, anim_list.size()])
		else:
			push_error("    Failed to save: %s" % tres_path)

func _get_actor_animation_defs() -> Array:
	var defs := []
	var dirs_data := {
		"up": {}, "right": {}, "down": {}, "left": {}
	}

	# Stand (single frame)
	defs.append({"name": "stand_up", "frames": [0], "fps": 1, "loop": false})
	defs.append({"name": "stand_right", "frames": [1], "fps": 1, "loop": false})
	defs.append({"name": "stand_down", "frames": [2], "fps": 1, "loop": false})
	defs.append({"name": "stand_left", "frames": [3], "fps": 1, "loop": false})

	# Walk (img_speed=0.2 → 12fps)
	defs.append({"name": "walk_up", "frames": _frame_range(5, 10), "fps": 12, "loop": true})
	defs.append({"name": "walk_right", "frames": _frame_range(12, 17), "fps": 12, "loop": true})
	defs.append({"name": "walk_down", "frames": _frame_range(19, 24), "fps": 12, "loop": true})
	defs.append({"name": "walk_left", "frames": _frame_range(26, 31), "fps": 12, "loop": true})

	# Walk charging (img_speed=0.1 → 6fps)
	defs.append({"name": "walk_charging_up", "frames": _frame_range(38, 39), "fps": 6, "loop": true})
	defs.append({"name": "walk_charging_right", "frames": _frame_range(41, 42), "fps": 6, "loop": true})
	defs.append({"name": "walk_charging_down", "frames": _frame_range(44, 45), "fps": 6, "loop": true})
	defs.append({"name": "walk_charging_left", "frames": _frame_range(47, 48), "fps": 6, "loop": true})

	# Run (img_speed=0.15 → 9fps)
	defs.append({"name": "run_up", "frames": _frame_range(83, 88), "fps": 9, "loop": true})
	defs.append({"name": "run_right", "frames": _frame_range(90, 95), "fps": 9, "loop": true})
	defs.append({"name": "run_down", "frames": _frame_range(97, 102), "fps": 9, "loop": true})
	defs.append({"name": "run_left", "frames": _frame_range(104, 109), "fps": 9, "loop": true})

	# Hit (img_speed=0.15 → 9fps)
	defs.append({"name": "hit_up", "frames": _frame_range(111, 116), "fps": 9, "loop": false})
	defs.append({"name": "hit_right", "frames": _frame_range(118, 123), "fps": 9, "loop": false})
	defs.append({"name": "hit_down", "frames": _frame_range(125, 130), "fps": 9, "loop": false})
	defs.append({"name": "hit_left", "frames": _frame_range(132, 137), "fps": 9, "loop": false})

	# Hit2/Faint (img_speed=0.08 → 4.8fps)
	defs.append({"name": "hit2_up", "frames": _frame_range(139, 141), "fps": 4.8, "loop": false})
	defs.append({"name": "hit2_right", "frames": _frame_range(139, 141), "fps": 4.8, "loop": false})
	defs.append({"name": "hit2_down", "frames": _frame_range(147, 149), "fps": 4.8, "loop": false})
	defs.append({"name": "hit2_left", "frames": _frame_range(147, 149), "fps": 4.8, "loop": false})

	# Recover
	defs.append({"name": "recover_up", "frames": _frame_range(141, 145), "fps": 6, "loop": false})
	defs.append({"name": "recover_right", "frames": _frame_range(141, 145), "fps": 6, "loop": false})
	defs.append({"name": "recover_down", "frames": _frame_range(149, 153), "fps": 6, "loop": false})
	defs.append({"name": "recover_left", "frames": _frame_range(149, 153), "fps": 6, "loop": false})

	# Push (img_speed=0.1 → 6fps)
	defs.append({"name": "push_up", "frames": _frame_range(155, 156), "fps": 6, "loop": false})
	defs.append({"name": "push_right", "frames": _frame_range(158, 159), "fps": 6, "loop": false})
	defs.append({"name": "push_down", "frames": _frame_range(161, 162), "fps": 6, "loop": false})
	defs.append({"name": "push_left", "frames": _frame_range(164, 165), "fps": 6, "loop": false})

	# Summon/Cast
	defs.append({"name": "summon_up", "frames": _frame_range(167, 172), "fps": 6, "loop": false})
	defs.append({"name": "summon_right", "frames": _frame_range(174, 179), "fps": 6, "loop": false})
	defs.append({"name": "summon_down", "frames": _frame_range(181, 186), "fps": 6, "loop": false})
	defs.append({"name": "summon_left", "frames": _frame_range(188, 193), "fps": 6, "loop": false})

	# Healed (single frame)
	defs.append({"name": "healed_up", "frames": [195], "fps": 1, "loop": false})
	defs.append({"name": "healed_right", "frames": [196], "fps": 1, "loop": false})
	defs.append({"name": "healed_down", "frames": [197], "fps": 1, "loop": false})
	defs.append({"name": "healed_left", "frames": [198], "fps": 1, "loop": false})

	# Parry (single frame)
	defs.append({"name": "parry_up", "frames": [200], "fps": 1, "loop": false})
	defs.append({"name": "parry_right", "frames": [201], "fps": 1, "loop": false})
	defs.append({"name": "parry_down", "frames": [202], "fps": 1, "loop": false})
	defs.append({"name": "parry_left", "frames": [203], "fps": 1, "loop": false})

	# Parry2 (single frame)
	defs.append({"name": "parry2_up", "frames": [200], "fps": 1, "loop": false})
	defs.append({"name": "parry2_right", "frames": [204], "fps": 1, "loop": false})
	defs.append({"name": "parry2_down", "frames": [202], "fps": 1, "loop": false})
	defs.append({"name": "parry2_left", "frames": [205], "fps": 1, "loop": false})

	# Avoid/Dodge
	defs.append({"name": "avoid_up", "frames": _frame_range(207, 211), "fps": 6, "loop": false})
	defs.append({"name": "avoid_right", "frames": _frame_range(207, 211), "fps": 6, "loop": false})
	defs.append({"name": "avoid_down", "frames": _frame_range(213, 217), "fps": 6, "loop": false})
	defs.append({"name": "avoid_left", "frames": _frame_range(213, 217), "fps": 6, "loop": false})

	# Attack animations (5 weapon types × 4 directions)
	# weapon_image_attack_speed: [0.24, 0.17, 0.14, 0.24, 0.20, 0.08, 0.08, 0.24, 0.0]
	# Attack types: PIERCE=0, SLASH=1, SWING=2, BOW=3, THROW=4
	var attack_types := ["pierce", "slash", "swing", "bow", "throw"]
	var attack_up_ini   := [235, 219, 251, 267, 285]
	var attack_up_end   := [237, 221, 253, 269, 287]
	var attack_right_ini := [239, 223, 255, 271, 289]
	var attack_right_end := [241, 225, 257, 274, 291]
	var attack_down_ini  := [243, 227, 259, 276, 293]
	var attack_down_end  := [245, 229, 261, 278, 295]
	var attack_left_ini  := [247, 231, 263, 280, 297]
	var attack_left_end  := [249, 233, 265, 283, 299]
	# Default attack speed = 14.4 fps (0.24 * 60)
	var attack_fps := 14.4

	for t in range(attack_types.size()):
		var type_name: String = attack_types[t]
		defs.append({"name": "attack_%s_up" % type_name, "frames": _frame_range(attack_up_ini[t], attack_up_end[t]), "fps": attack_fps, "loop": false})
		defs.append({"name": "attack_%s_right" % type_name, "frames": _frame_range(attack_right_ini[t], attack_right_end[t]), "fps": attack_fps, "loop": false})
		defs.append({"name": "attack_%s_down" % type_name, "frames": _frame_range(attack_down_ini[t], attack_down_end[t]), "fps": attack_fps, "loop": false})
		defs.append({"name": "attack_%s_left" % type_name, "frames": _frame_range(attack_left_ini[t], attack_left_end[t]), "fps": attack_fps, "loop": false})

	# Cutscene
	defs.append({"name": "cutscene_no", "frames": _frame_range(301, 304), "fps": 6, "loop": false})
	defs.append({"name": "cutscene_yes", "frames": _frame_range(306, 307), "fps": 6, "loop": false})

	# Fall up (single frame used in hit sequences)
	defs.append({"name": "fall_up", "frames": [115], "fps": 1, "loop": false})

	return defs

# ─── Mobs ───────────────────────────────────────────────────────────────────────

func _migrate_mobs() -> void:
	var mob_configs := _get_mob_configs()

	for mob_name in mob_configs:
		print("  Processing mob: %s" % mob_name)
		var config: Dictionary = mob_configs[mob_name]
		var sheet := _load_image(config["texture"])
		if not sheet:
			continue

		var cols: int = config["columns"]
		var fw: int = config["fw"]
		var fh: int = config["fh"]
		var origin := Vector2(config["origin_x"], config["origin_y"])
		var out_dir := "res://assets/animations/mobs/%s" % mob_name
		_ensure_dir(out_dir)

		var sheet_path: String = config["texture"]
		var anim_list := []
		var anims: Array = config["animations"]

		for anim in anims:
			var anim_name: String = anim["name"]
			var frames: Array = anim["frames"]
			var fps: float = anim.get("fps", 6.0)
			var loop: bool = anim.get("loop", false)

			var strip_path := "%s/%s.png" % [out_dir, anim_name]
			_save_strip(sheet, cols, fw, fh, frames, strip_path)

			anim_list.append({
				"name": anim_name,
				"strip_path": strip_path,
				"fw": fw, "fh": fh,
				"frame_count": frames.size(),
				"fps": fps,
				"loop": loop,
			})

		var sf := _build_sprite_frames(anim_list, origin)
		var tres_path := "%s/%s.tres" % [out_dir, mob_name]
		var err := ResourceSaver.save(sf, tres_path)
		if err == OK:
			print("    Saved: %s (%d animations)" % [tres_path, anim_list.size()])
		else:
			push_error("    Failed to save: %s" % tres_path)

func _get_mob_configs() -> Dictionary:
	var configs := {}
	var mob_fps := 6.0  # img_speed=0.1 → 6fps

	# Slime
	configs["slime"] = {
		"texture": "res://assets/sprites/sheets/spr_mob_slime.png",
		"columns": 8, "fw": 32, "fh": 32, "origin_x": 16, "origin_y": 27,
		"animations": [
			{"name": "walk_up", "frames": _frame_range(0, 4), "fps": mob_fps, "loop": true},
			{"name": "walk_right", "frames": _frame_range(6, 10), "fps": mob_fps, "loop": true},
			{"name": "walk_down", "frames": _frame_range(12, 16), "fps": mob_fps, "loop": true},
			{"name": "walk_left", "frames": _frame_range(18, 22), "fps": mob_fps, "loop": true},
			{"name": "attack_up", "frames": _frame_range(24, 28), "fps": mob_fps, "loop": false},
			{"name": "attack_right", "frames": _frame_range(30, 34), "fps": mob_fps, "loop": false},
			{"name": "attack_down", "frames": _frame_range(36, 40), "fps": mob_fps, "loop": false},
			{"name": "attack_left", "frames": _frame_range(42, 46), "fps": mob_fps, "loop": false},
			{"name": "hit", "frames": [48], "fps": 1, "loop": false},
		]
	}

	# Rabite
	configs["rabite"] = {
		"texture": "res://assets/sprites/sheets/spr_mob_rabite.png",
		"columns": 4, "fw": 32, "fh": 32, "origin_x": 16, "origin_y": 20,
		"animations": [
			{"name": "walk_up", "frames": _frame_range(0, 1), "fps": mob_fps, "loop": true},
			{"name": "walk_right", "frames": _frame_range(0, 1), "fps": mob_fps, "loop": true},
			{"name": "walk_down", "frames": _frame_range(0, 1), "fps": mob_fps, "loop": true},
			{"name": "walk_left", "frames": _frame_range(0, 1), "fps": mob_fps, "loop": true},
			{"name": "walk_jump", "frames": _frame_range(2, 4), "fps": mob_fps, "loop": false},
			{"name": "attack_up", "frames": _frame_range(5, 6), "fps": mob_fps, "loop": false},
			{"name": "attack_right", "frames": _frame_range(5, 6), "fps": mob_fps, "loop": false},
			{"name": "attack_down", "frames": _frame_range(5, 6), "fps": mob_fps, "loop": false},
			{"name": "attack_left", "frames": _frame_range(5, 6), "fps": mob_fps, "loop": false},
			{"name": "attack2_up", "frames": _frame_range(7, 10), "fps": mob_fps, "loop": false},
			{"name": "attack2_right", "frames": _frame_range(7, 10), "fps": mob_fps, "loop": false},
			{"name": "attack2_down", "frames": _frame_range(7, 10), "fps": mob_fps, "loop": false},
			{"name": "attack2_left", "frames": _frame_range(7, 10), "fps": mob_fps, "loop": false},
			{"name": "hit", "frames": [11], "fps": 1, "loop": false},
		]
	}

	# Drago
	configs["drago"] = {
		"texture": "res://assets/sprites/sheets/spr_mob_drago.png",
		"columns": 5, "fw": 32, "fh": 32, "origin_x": 16, "origin_y": 25,
		"animations": [
			{"name": "walk_up", "frames": _frame_range(0, 4), "fps": mob_fps, "loop": true},
			{"name": "walk_right", "frames": _frame_range(5, 9), "fps": mob_fps, "loop": true},
			{"name": "walk_down", "frames": _frame_range(10, 14), "fps": mob_fps, "loop": true},
			{"name": "walk_left", "frames": _frame_range(15, 19), "fps": mob_fps, "loop": true},
			{"name": "attack_up", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "attack_right", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "attack_down", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "attack_left", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "hit", "frames": [20], "fps": 1, "loop": false},
		]
	}

	# Flower
	configs["flower"] = {
		"texture": "res://assets/sprites/sheets/spr_mob_flower.png",
		"columns": 5, "fw": 32, "fh": 32, "origin_x": 16, "origin_y": 25,
		"animations": [
			{"name": "walk_up", "frames": _frame_range(0, 4), "fps": mob_fps, "loop": true},
			{"name": "walk_right", "frames": _frame_range(5, 9), "fps": mob_fps, "loop": true},
			{"name": "walk_down", "frames": _frame_range(10, 14), "fps": mob_fps, "loop": true},
			{"name": "walk_left", "frames": _frame_range(15, 19), "fps": mob_fps, "loop": true},
			{"name": "attack_up", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "attack_right", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "attack_down", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "attack_left", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "hit", "frames": [20], "fps": 1, "loop": false},
		]
	}

	# Succubus
	configs["succubus"] = {
		"texture": "res://assets/sprites/sheets/spr_mob_succubus.png",
		"columns": 5, "fw": 32, "fh": 32, "origin_x": 16, "origin_y": 26,
		"animations": [
			{"name": "walk_up", "frames": _frame_range(0, 4), "fps": mob_fps, "loop": true},
			{"name": "walk_right", "frames": _frame_range(5, 9), "fps": mob_fps, "loop": true},
			{"name": "walk_down", "frames": _frame_range(10, 14), "fps": mob_fps, "loop": true},
			{"name": "walk_left", "frames": _frame_range(15, 19), "fps": mob_fps, "loop": true},
			{"name": "attack_up", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "attack_right", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "attack_down", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "attack_left", "frames": _frame_range(20, 23), "fps": mob_fps, "loop": false},
			{"name": "hit", "frames": [20], "fps": 1, "loop": false},
		]
	}

	# Rabbi (boss rabite - 128x128)
	configs["rabbi"] = {
		"texture": "res://assets/sprites/sheets/spr_mob_rabbi.png",
		"columns": 5, "fw": 128, "fh": 128, "origin_x": 65, "origin_y": 84,
		"animations": [
			{"name": "walk_up", "frames": _frame_range(0, 1), "fps": mob_fps, "loop": true},
			{"name": "walk_right", "frames": _frame_range(0, 1), "fps": mob_fps, "loop": true},
			{"name": "walk_down", "frames": _frame_range(0, 1), "fps": mob_fps, "loop": true},
			{"name": "walk_left", "frames": _frame_range(0, 1), "fps": mob_fps, "loop": true},
			{"name": "walk_jump", "frames": _frame_range(2, 4), "fps": mob_fps, "loop": false},
			{"name": "attack_up", "frames": _frame_range(5, 6), "fps": mob_fps, "loop": false},
			{"name": "attack_right", "frames": _frame_range(5, 6), "fps": mob_fps, "loop": false},
			{"name": "attack_down", "frames": _frame_range(5, 6), "fps": mob_fps, "loop": false},
			{"name": "attack_left", "frames": _frame_range(5, 6), "fps": mob_fps, "loop": false},
			{"name": "attack2_up", "frames": _frame_range(7, 10), "fps": mob_fps, "loop": false},
			{"name": "attack2_right", "frames": _frame_range(7, 10), "fps": mob_fps, "loop": false},
			{"name": "attack2_down", "frames": _frame_range(7, 10), "fps": mob_fps, "loop": false},
			{"name": "attack2_left", "frames": _frame_range(7, 10), "fps": mob_fps, "loop": false},
			{"name": "hit", "frames": [16], "fps": 1, "loop": false},
		]
	}

	return configs

# ─── NPCs ───────────────────────────────────────────────────────────────────────

func _migrate_npcs() -> void:
	var npc_configs := {
		"darkLich": {
			"texture": "res://assets/sprites/sheets/spr_npc_darkLich.png",
			"columns": 5, "fw": 42, "fh": 42, "origin_x": 20, "origin_y": 35,
			"animations": [
				{"name": "stand_up", "frames": [0], "fps": 1, "loop": false},
				{"name": "stand_right", "frames": [1], "fps": 1, "loop": false},
				{"name": "stand_down", "frames": [2], "fps": 1, "loop": false},
				{"name": "stand_left", "frames": [3], "fps": 1, "loop": false},
				{"name": "walk_up", "frames": _frame_range(5, 8), "fps": 6, "loop": true},
				{"name": "walk_right", "frames": _frame_range(10, 13), "fps": 6, "loop": true},
				{"name": "walk_down", "frames": _frame_range(15, 18), "fps": 6, "loop": true},
				{"name": "walk_left", "frames": _frame_range(20, 23), "fps": 6, "loop": true},
			]
		},
		"dyluck": {
			"texture": "res://assets/sprites/sheets/spr_npc_dyluck.png",
			"columns": 5, "fw": 42, "fh": 42, "origin_x": 20, "origin_y": 35,
			"animations": [
				{"name": "stand_up", "frames": [0], "fps": 1, "loop": false},
				{"name": "stand_right", "frames": [1], "fps": 1, "loop": false},
				{"name": "stand_down", "frames": [2], "fps": 1, "loop": false},
				{"name": "stand_left", "frames": [3], "fps": 1, "loop": false},
				{"name": "walk_up", "frames": _frame_range(5, 8), "fps": 6, "loop": true},
				{"name": "walk_right", "frames": _frame_range(10, 13), "fps": 6, "loop": true},
				{"name": "walk_down", "frames": _frame_range(15, 18), "fps": 6, "loop": true},
				{"name": "walk_left", "frames": _frame_range(20, 23), "fps": 6, "loop": true},
			]
		},
		"neko": {
			"texture": "res://assets/sprites/sheets/spr_npc_neko.png",
			"columns": 5, "fw": 32, "fh": 44, "origin_x": 16, "origin_y": 33,
			"animations": [
				{"name": "stand_up", "frames": [0], "fps": 1, "loop": false},
				{"name": "stand_right", "frames": [1], "fps": 1, "loop": false},
				{"name": "stand_down", "frames": [2], "fps": 1, "loop": false},
				{"name": "stand_left", "frames": [3], "fps": 1, "loop": false},
				{"name": "walk_up", "frames": _frame_range(5, 8), "fps": 6, "loop": true},
				{"name": "walk_right", "frames": _frame_range(10, 13), "fps": 6, "loop": true},
				{"name": "walk_down", "frames": _frame_range(15, 17), "fps": 6, "loop": true},
				{"name": "walk_left", "frames": _frame_range(15, 17), "fps": 6, "loop": true},
			]
		},
	}

	for npc_name in npc_configs:
		print("  Processing NPC: %s" % npc_name)
		var config: Dictionary = npc_configs[npc_name]
		var sheet := _load_image(config["texture"])
		if not sheet:
			continue

		var cols: int = config["columns"]
		var fw: int = config["fw"]
		var fh: int = config["fh"]
		var origin := Vector2(config["origin_x"], config["origin_y"])
		var out_dir := "res://assets/animations/npcs/%s" % npc_name
		_ensure_dir(out_dir)

		var sheet_path: String = config["texture"]
		var anim_list := []
		for anim in config["animations"]:
			var strip_path := "%s/%s.png" % [out_dir, anim["name"]]
			_save_strip(sheet, cols, fw, fh, anim["frames"], strip_path)
			anim_list.append({
				"name": anim["name"],
				"strip_path": strip_path,
				"fw": fw, "fh": fh,
				"frame_count": anim["frames"].size(),
				"fps": anim.get("fps", 6.0),
				"loop": anim.get("loop", false),
			})

		var sf := _build_sprite_frames(anim_list, origin)
		var tres_path := "%s/%s.tres" % [out_dir, npc_name]
		ResourceSaver.save(sf, tres_path)
		print("    Saved: %s" % tres_path)

# ─── Weapon Attacks ─────────────────────────────────────────────────────────────

func _migrate_weapon_attacks() -> void:
	var weapons := {
		"sword": {"path": "res://assets/sprites/sheets/spr_weapon_sword.png", "fw": 74, "fh": 74, "cols": 10, "ox": 35, "oy": 51,
			"anims": [
				{"name": "attack_up", "frames": _frame_range(0, 2), "fps": 14.4, "loop": false},
				{"name": "attack_right", "frames": _frame_range(4, 6), "fps": 14.4, "loop": false},
				{"name": "attack_down", "frames": _frame_range(8, 10), "fps": 14.4, "loop": false},
				{"name": "attack_left", "frames": _frame_range(12, 14), "fps": 14.4, "loop": false},
			]},
		"axe": {"path": "res://assets/sprites/sheets/spr_weapon_axe.png", "fw": 72, "fh": 72, "cols": 10, "ox": 36, "oy": 46,
			"anims": [
				{"name": "attack_up", "frames": _frame_range(0, 3), "fps": 10.2, "loop": false},
				{"name": "attack_right", "frames": _frame_range(5, 8), "fps": 10.2, "loop": false},
				{"name": "attack_down", "frames": _frame_range(10, 13), "fps": 10.2, "loop": false},
				{"name": "attack_left", "frames": _frame_range(15, 18), "fps": 10.2, "loop": false},
			]},
		"spear": {"path": "res://assets/sprites/sheets/spr_weapon_spear.png", "fw": 72, "fh": 72, "cols": 4, "ox": 37, "oy": 46,
			"anims": [
				{"name": "attack_up", "frames": _frame_range(0, 2), "fps": 8.4, "loop": false},
				{"name": "attack_right", "frames": _frame_range(0, 2), "fps": 8.4, "loop": false},
				{"name": "attack_down", "frames": _frame_range(0, 2), "fps": 8.4, "loop": false},
				{"name": "attack_left", "frames": _frame_range(0, 2), "fps": 8.4, "loop": false},
			]},
		"bow": {"path": "res://assets/sprites/sheets/spr_weapon_bow.png", "fw": 72, "fh": 72, "cols": 10, "ox": 36, "oy": 46,
			"anims": [
				{"name": "attack_up", "frames": _frame_range(0, 4), "fps": 12, "loop": false},
				{"name": "attack_right", "frames": _frame_range(6, 11), "fps": 12, "loop": false},
				{"name": "attack_down", "frames": _frame_range(12, 17), "fps": 12, "loop": false},
				{"name": "attack_left", "frames": _frame_range(18, 22), "fps": 12, "loop": false},
			]},
		"boomerang": {"path": "res://assets/sprites/sheets/spr_weapon_boomerang.png", "fw": 72, "fh": 72, "cols": 10, "ox": 36, "oy": 46,
			"anims": [
				{"name": "attack_up", "frames": _frame_range(0, 1), "fps": 4.8, "loop": false},
				{"name": "attack_right", "frames": _frame_range(3, 4), "fps": 4.8, "loop": false},
				{"name": "attack_down", "frames": _frame_range(6, 7), "fps": 4.8, "loop": false},
				{"name": "attack_left", "frames": _frame_range(9, 10), "fps": 4.8, "loop": false},
			]},
		"javelin": {"path": "res://assets/sprites/sheets/spr_weapon_javelin.png", "fw": 72, "fh": 72, "cols": 8, "ox": 36, "oy": 46,
			"anims": [
				{"name": "attack_up", "frames": [0], "fps": 14.4, "loop": false},
				{"name": "attack_right", "frames": [2], "fps": 14.4, "loop": false},
				{"name": "attack_down", "frames": [4], "fps": 14.4, "loop": false},
				{"name": "attack_left", "frames": [6], "fps": 14.4, "loop": false},
			]},
		"whip": {"path": "res://assets/sprites/sheets/spr_weapon_whip.png", "fw": 108, "fh": 108, "cols": 4, "ox": 44, "oy": 74,
			"anims": [
				{"name": "attack_up", "frames": _frame_range(0, 2), "fps": 4.8, "loop": false},
				{"name": "attack_right", "frames": _frame_range(0, 2), "fps": 4.8, "loop": false},
				{"name": "attack_down", "frames": _frame_range(0, 2), "fps": 4.8, "loop": false},
				{"name": "attack_left", "frames": _frame_range(0, 2), "fps": 4.8, "loop": false},
			]},
		"knucles": {"path": "res://assets/sprites/sheets/spr_weapon_knucles.png", "fw": 72, "fh": 72, "cols": 10, "ox": 36, "oy": 46,
			"anims": [
				{"name": "attack_up", "frames": _frame_range(0, 2), "fps": 14.4, "loop": false},
				{"name": "attack_right", "frames": _frame_range(4, 6), "fps": 14.4, "loop": false},
				{"name": "attack_down", "frames": _frame_range(8, 10), "fps": 14.4, "loop": false},
				{"name": "attack_left", "frames": _frame_range(12, 14), "fps": 14.4, "loop": false},
			]},
	}

	for weapon_name in weapons:
		print("  Processing weapon attack: %s" % weapon_name)
		var config: Dictionary = weapons[weapon_name]
		var sheet := _load_image(config["path"])
		if not sheet:
			continue

		var out_dir := "res://assets/animations/weapons/%s" % weapon_name
		_ensure_dir(out_dir)

		var anim_list := []
		for anim in config["anims"]:
			var strip_path := "%s/%s.png" % [out_dir, anim["name"]]
			_save_strip(sheet, config["cols"], config["fw"], config["fh"], anim["frames"], strip_path)
			anim_list.append({
				"name": anim["name"],
				"strip_path": strip_path,
				"fw": config["fw"], "fh": config["fh"],
				"frame_count": anim["frames"].size(),
				"fps": anim.get("fps", 14.4),
				"loop": anim.get("loop", false),
			})

		var sf := _build_sprite_frames(anim_list, Vector2(config["ox"], config["oy"]))
		var tres_path := "%s/%s.tres" % [out_dir, weapon_name]
		ResourceSaver.save(sf, tres_path)
		print("    Saved: %s" % tres_path)

# ─── Weapon Strips ──────────────────────────────────────────────────────────────

func _migrate_weapon_strips() -> void:
	var characters := ["randi", "purim", "popoie"]
	var weapon_types := ["sword", "axe", "spear", "javelin", "bow", "boomerang", "whip"]
	var cols := 18
	var fw := 46
	var fh := 46

	for character in characters:
		for weapon in weapon_types:
			var sheet_path := "res://assets/sprites/sheets/spr_weaponStrip_%s_%s.png" % [character, weapon]
			var json_path := "res://assets/sprites/sheets/spr_weaponStrip_%s_%s.json" % [character, weapon]

			# Try to load — not all character/weapon combos may exist
			var sheet := _load_image(sheet_path)
			if not sheet:
				continue

			print("  Processing weapon strip: %s_%s" % [character, weapon])

			# Read origin from JSON if available
			var origin := Vector2(22, 35)
			var json_file := FileAccess.open(json_path, FileAccess.READ)
			if json_file:
				var json_text := json_file.get_as_text()
				json_file.close()
				var json := JSON.new()
				if json.parse(json_text) == OK:
					var data: Dictionary = json.data
					origin = Vector2(data.get("xorigin", 22), data.get("yorigin", 35))
					if data.has("columns"):
						cols = int(data["columns"])

			var out_dir := "res://assets/animations/weapon_strips/%s_%s" % [character, weapon]
			_ensure_dir(out_dir)

			# Weapon strips use the same frame layout as the actor.
			# We'll save the entire strip sheet as-is (it syncs frame-by-frame with the actor)
			# and create a simple SpriteFrames with a single "all_frames" animation
			var total_frames: int = (sheet.get_width() / fw) * (sheet.get_height() / fh)
			var all_frames := _frame_range(0, total_frames - 1)

			var strip_path := "%s/strip.png" % out_dir
			# Just copy the original file
			sheet.save_png(strip_path)

			# For weapon strips, we store as a simple resource with metadata
			# (These won't use AnimatedSprite2D — they stay as synced Sprite2D)
			# Save a minimal SpriteFrames using the ORIGINAL sheet texture
			var sf := SpriteFrames.new()
			if sf.has_animation("default"):
				sf.remove_animation("default")
			sf.add_animation("strip")
			sf.set_animation_speed("strip", 1.0)
			sf.set_animation_loop("strip", false)

			var orig_tex: Texture2D = load(sheet_path)
			if orig_tex:
				for i in range(mini(total_frames, 260)):
					var atlas := AtlasTexture.new()
					atlas.atlas = orig_tex
					var col := i % cols
					var row: int = i / cols
					atlas.region = Rect2(col * fw, row * fh, fw, fh)
					sf.add_frame("strip", atlas)

			var tres_path := "%s/%s_%s_strip.tres" % [out_dir, character, weapon]
			ResourceSaver.save(sf, tres_path)
			print("    Saved: %s" % tres_path)

# ─── Boss: Dark Lich ────────────────────────────────────────────────────────────

func _migrate_boss_dark_lich() -> void:
	print("  Processing boss: Dark Lich")
	var sheet := _load_image("res://assets/sprites/sheets/spr_darkLich.png")
	if not sheet:
		return

	# Dark Lich main sheet: 16 columns, 128x128
	var cols := 16
	var fw := 128
	var fh := 128
	var origin := Vector2(64, 64)
	var out_dir := "res://assets/animations/bosses/dark_lich"
	_ensure_dir(out_dir)

	var boss_fps := 6.0
	var anims := [
		# Fullbody phase
		{"name": "fullbody_stand_right", "frames": _frame_range(0, 3), "fps": boss_fps, "loop": true},
		{"name": "fullbody_stand_left", "frames": _frame_range(5, 8), "fps": boss_fps, "loop": true},
		{"name": "fullbody_stand_front", "frames": _frame_range(10, 13), "fps": boss_fps, "loop": true},
		{"name": "fullbody_waist", "frames": _frame_range(15, 18), "fps": boss_fps, "loop": true},
		{"name": "cast_0", "frames": _frame_range(20, 22), "fps": boss_fps, "loop": false},
		{"name": "cast_1", "frames": _frame_range(24, 29), "fps": boss_fps, "loop": false},
		{"name": "cast_2", "frames": _frame_range(31, 37), "fps": boss_fps, "loop": false},
		{"name": "cast_3", "frames": _frame_range(39, 41), "fps": boss_fps, "loop": false},
		{"name": "cast_4", "frames": _frame_range(43, 49), "fps": boss_fps, "loop": false},
		# Hands phase
		{"name": "hands_stand", "frames": _frame_range(51, 53), "fps": boss_fps, "loop": true},
		{"name": "hands_attack", "frames": _frame_range(55, 58), "fps": 12, "loop": false},
		{"name": "hands_attack2", "frames": _frame_range(59, 65), "fps": 12, "loop": false},
		{"name": "hands_head_stand", "frames": _frame_range(67, 70), "fps": boss_fps, "loop": true},
		# Shared
		{"name": "hurt", "frames": _frame_range(72, 80), "fps": boss_fps, "loop": false},
		{"name": "hurt2", "frames": _frame_range(82, 83), "fps": boss_fps, "loop": false},
	]

	var anim_list := []
	for anim in anims:
		var strip_path := "%s/%s.png" % [out_dir, anim["name"]]
		_save_strip(sheet, cols, fw, fh, anim["frames"], strip_path)
		anim_list.append({
			"name": anim["name"],
			"strip_path": strip_path,
			"fw": fw, "fh": fh,
			"frame_count": anim["frames"].size(),
			"fps": anim.get("fps", boss_fps),
			"loop": anim.get("loop", false),
		})

	var sf := _build_sprite_frames(anim_list, origin)
	var tres_path := "%s/dark_lich.tres" % out_dir
	ResourceSaver.save(sf, tres_path)
	print("    Saved: %s" % tres_path)

	# Also migrate waist overlay sheet
	var waist_sheet := _load_image("res://assets/sprites/sheets/spr_darkLich_waist.png")
	if waist_sheet:
		var waist_anims := [
			{"name": "waist", "frames": _frame_range(15, 18), "fps": boss_fps, "loop": true},
		]
		var waist_list := []
		for anim in waist_anims:
			var strip_path := "%s/waist_%s.png" % [out_dir, anim["name"]]
			_save_strip(waist_sheet, cols, fw, fh, anim["frames"], strip_path)
			waist_list.append({
				"name": anim["name"],
				"strip_path": strip_path,
				"fw": fw, "fh": fh,
				"frame_count": anim["frames"].size(),
				"fps": anim.get("fps", boss_fps),
				"loop": anim.get("loop", false),
			})
		var waist_sf := _build_sprite_frames(waist_list, origin)
		ResourceSaver.save(waist_sf, "%s/dark_lich_waist.tres" % out_dir)
		print("    Saved: %s/dark_lich_waist.tres" % out_dir)

# ─── Boss: Mana Beast ───────────────────────────────────────────────────────────

func _migrate_boss_mana_beast() -> void:
	print("  Processing boss: Mana Beast")
	var out_dir := "res://assets/animations/bosses/mana_beast"
	_ensure_dir(out_dir)

	var all_anims := []

	# Aux sprite: 11 columns, 129x84
	var aux_sheet_path := "res://assets/sprites/sheets/spr_manaBeast_aux.png"
	var aux_sheet := _load_image(aux_sheet_path)
	if aux_sheet:
		var aux_cols := 11
		var aux_fw := 129
		var aux_fh := 84
		var aux_anims := [
			{"name": "aux_fireball_going", "frames": [0], "fps": 1, "loop": false},
			{"name": "aux_fireball_prepare", "frames": _frame_range(1, 4), "fps": 6, "loop": false},
			{"name": "aux_fireball_wait", "frames": _frame_range(5, 6), "fps": 6, "loop": true},
			{"name": "aux_coming", "frames": [8], "fps": 1, "loop": false},
			{"name": "aux_side", "frames": [9], "fps": 1, "loop": false},
		]
		for anim in aux_anims:
			var strip_path := "%s/%s.png" % [out_dir, anim["name"]]
			_save_strip(aux_sheet, aux_cols, aux_fw, aux_fh, anim["frames"], strip_path)
			all_anims.append({
				"name": anim["name"],
				"strip_path": strip_path,
				"fw": aux_fw, "fh": aux_fh,
				"frame_count": anim["frames"].size(),
				"fps": anim.get("fps", 6.0),
				"loop": anim.get("loop", false),
			})

	# Front sprite: 6 columns, 128x128
	var front_sheet_path := "res://assets/sprites/sheets/spr_manaBeast_front.png"
	var front_sheet := _load_image(front_sheet_path)
	if front_sheet:
		var front_cols := 6
		var front_fw := 128
		var front_fh := 128
		var front_anims := [
			{"name": "front_stand", "frames": _frame_range(0, 5), "fps": 6, "loop": true},
			{"name": "front_hurt", "frames": _frame_range(4, 5), "fps": 6, "loop": false},
		]
		for anim in front_anims:
			var strip_path := "%s/%s.png" % [out_dir, anim["name"]]
			_save_strip(front_sheet, front_cols, front_fw, front_fh, anim["frames"], strip_path)
			all_anims.append({
				"name": anim["name"],
				"strip_path": strip_path,
				"fw": front_fw, "fh": front_fh,
				"frame_count": anim["frames"].size(),
				"fps": anim.get("fps", 6.0),
				"loop": anim.get("loop", false),
			})

	# Fire sprite: 1 column, 64x64
	var fire_sheet_path := "res://assets/sprites/sheets/spr_manaBeast_fire.png"
	var fire_sheet := _load_image(fire_sheet_path)
	if fire_sheet:
		var fire_anims := [
			{"name": "fire", "frames": [0], "fps": 1, "loop": false},
		]
		for anim in fire_anims:
			var strip_path := "%s/%s.png" % [out_dir, anim["name"]]
			_save_strip(fire_sheet, 1, 64, 64, anim["frames"], strip_path)
			all_anims.append({
				"name": anim["name"],
				"strip_path": strip_path,
				"fw": 64, "fh": 64,
				"frame_count": anim["frames"].size(),
				"fps": 1,
				"loop": false,
			})

	if all_anims.size() > 0:
		var sf := _build_sprite_frames(all_anims, Vector2(64, 64))
		var tres_path := "%s/mana_beast.tres" % out_dir
		ResourceSaver.save(sf, tres_path)
		print("    Saved: %s" % tres_path)
