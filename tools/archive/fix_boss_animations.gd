@tool
extends EditorScript

## Adds directional aliases to boss .tres files so the bridge system works.
## Run from Godot Editor: Script > Run (Ctrl+Shift+X)

func _run() -> void:
	print("=== Fixing Boss Animations ===")
	_fix_dark_lich()
	_fix_mana_beast()
	print("=== Done ===")

func _fix_dark_lich() -> void:
	var path := "res://assets/animations/bosses/dark_lich/dark_lich.tres"
	var sf: SpriteFrames = load(path)
	if not sf:
		push_error("Could not load: " + path)
		return

	# Add directional aliases for fullbody_stand
	# fullbody_stand_front → fullbody_stand_up, fullbody_stand_down
	_copy_animation(sf, "fullbody_stand_front", "fullbody_stand_up")
	_copy_animation(sf, "fullbody_stand_front", "fullbody_stand_down")

	# Directional aliases for hurt (all directions same)
	_copy_animation(sf, "hurt", "hurt_up")
	_copy_animation(sf, "hurt", "hurt_right")
	_copy_animation(sf, "hurt", "hurt_down")
	_copy_animation(sf, "hurt", "hurt_left")

	# Directional aliases for hurt2
	_copy_animation(sf, "hurt2", "hurt2_up")
	_copy_animation(sf, "hurt2", "hurt2_right")
	_copy_animation(sf, "hurt2", "hurt2_down")
	_copy_animation(sf, "hurt2", "hurt2_left")

	# Directional aliases for hands_stand (all directions same)
	_copy_animation(sf, "hands_stand", "hands_stand_up")
	_copy_animation(sf, "hands_stand", "hands_stand_right")
	_copy_animation(sf, "hands_stand", "hands_stand_down")
	_copy_animation(sf, "hands_stand", "hands_stand_left")

	# Directional aliases for hands_attack
	_copy_animation(sf, "hands_attack", "hands_attack_up")
	_copy_animation(sf, "hands_attack", "hands_attack_right")
	_copy_animation(sf, "hands_attack", "hands_attack_down")
	_copy_animation(sf, "hands_attack", "hands_attack_left")

	# Directional aliases for hands_attack2
	_copy_animation(sf, "hands_attack2", "hands_attack2_up")
	_copy_animation(sf, "hands_attack2", "hands_attack2_right")
	_copy_animation(sf, "hands_attack2", "hands_attack2_down")
	_copy_animation(sf, "hands_attack2", "hands_attack2_left")

	# Directional aliases for hands_head_stand
	_copy_animation(sf, "hands_head_stand", "hands_head_stand_up")
	_copy_animation(sf, "hands_head_stand", "hands_head_stand_right")
	_copy_animation(sf, "hands_head_stand", "hands_head_stand_down")
	_copy_animation(sf, "hands_head_stand", "hands_head_stand_left")

	# Cast animations: no direction needed (cast is non-directional)
	# but add _up aliases so bridge can find them
	for i in range(5):
		var src := "cast_%d" % i
		if sf.has_animation(src):
			_copy_animation(sf, src, "%s_up" % src)
			_copy_animation(sf, src, "%s_right" % src)
			_copy_animation(sf, src, "%s_down" % src)
			_copy_animation(sf, src, "%s_left" % src)

	# fullbody_waist directional aliases (all same)
	_copy_animation(sf, "fullbody_waist", "fullbody_waist_up")
	_copy_animation(sf, "fullbody_waist", "fullbody_waist_right")
	_copy_animation(sf, "fullbody_waist", "fullbody_waist_down")
	_copy_animation(sf, "fullbody_waist", "fullbody_waist_left")

	ResourceSaver.save(sf, path)
	print("  Fixed Dark Lich: " + path)

func _fix_mana_beast() -> void:
	var path := "res://assets/animations/bosses/mana_beast/mana_beast.tres"
	var sf: SpriteFrames = load(path)
	if not sf:
		push_error("Could not load: " + path)
		return

	# Mana Beast animations are non-directional. Add directional aliases for bridge.
	var anims_to_alias := [
		"aux_fireball_going", "aux_fireball_prepare", "aux_fireball_wait",
		"aux_coming", "aux_side",
		"front_stand", "front_hurt",
		"fire",
	]
	for anim_name in anims_to_alias:
		if sf.has_animation(anim_name):
			for dir in ["_up", "_right", "_down", "_left"]:
				_copy_animation(sf, anim_name, anim_name + dir)

	ResourceSaver.save(sf, path)
	print("  Fixed Mana Beast: " + path)

## Copy an animation (frames, speed, loop) to a new name
func _copy_animation(sf: SpriteFrames, src_name: String, dst_name: String) -> void:
	if not sf.has_animation(src_name):
		return
	if sf.has_animation(dst_name):
		return  # Already exists
	sf.add_animation(dst_name)
	sf.set_animation_speed(dst_name, sf.get_animation_speed(src_name))
	sf.set_animation_loop(dst_name, sf.get_animation_loop(src_name))
	for i in range(sf.get_frame_count(src_name)):
		var tex: Texture2D = sf.get_frame_texture(src_name, i)
		var duration: float = sf.get_frame_duration(src_name, i)
		sf.add_frame(dst_name, tex, duration)
