class_name BossDarkLich
extends Mob
## Dark Lich boss - replaces oMob_darkLich from GMS2
## Two-phase boss: FULLBODY (standing) and HANDS (floating hands attack)
## GMS2: 128x128 combined spritesheet with 83+ frames

enum Phase { FULLBODY, HANDS }

var current_phase: int = Phase.FULLBODY
var phase_time: float = 0.0  # seconds
var max_time_between_phases: float = 30.0  # GMS2: 1800 frames / 60fps = 30 seconds

# Cast tracking (GMS2: castTimes, castTimesLimit)
var cast_times: int = 0
var cast_times_limit: int = 3  # Random 2-3 per stand cycle
var insta_cast: bool = false
var attacked_times: int = 0
var max_attack_times: int = 3

# Lumina weakness (GMS2: weaponMultiplier[LUMINA]=3, magicMultiplier[LUMINA]=5)
var lumina_weapon_multiplier: float = 3.0
var lumina_magic_multiplier: float = 5.0

# Skills the Dark Lich can cast (GMS2: 15 spells shuffled) — set in _ready
var _shuffled_skills: Array = []

# Phase-specific sprite ranges (GMS2: Create_0.gml exact frame indices)
# spr_darkLich: 16 columns, 128x128, ~84 frames
var phase_sprite_config: Dictionary = {
	Phase.FULLBODY: {
		# GMS2: standRightIni=0..End=3, standLeftIni=5..End=8, standFrontIni=10..End=13
		"stand_right_ini": 0, "stand_right_end": 3,
		"stand_left_ini": 5, "stand_left_end": 8,
		"stand_front_ini": 10, "stand_front_end": 13,
		# GMS2: waistIni=15..waistEnd=18 (body/waist overlay for composite draw)
		"waist_ini": 15, "waist_end": 18,
		# GMS2: 5 cast animations per skill type (castIni[0-4]..castEnd[0-4])
		"cast_ini_0": 20, "cast_end_0": 22,   # castIni[0]=20, castEnd[0]=22
		"cast_ini_1": 24, "cast_end_1": 29,   # castIni[1]=24, castEnd[1]=29
		"cast_ini_2": 31, "cast_end_2": 37,   # castIni[2]=31, castEnd[2]=37
		"cast_ini_3": 39, "cast_end_3": 41,   # castIni[3]=39, castEnd[3]=41
		"cast_ini_4": 43, "cast_end_4": 49,   # castIni[4]=43, castEnd[4]=49
		# GMS2: hurtIni=72..hurtEnd=80 (all directional hurt frames)
		"hurt_ini": 72, "hurt_end": 80,
	},
	Phase.HANDS: {
		# GMS2: handsMove1Ini=51..End=53 (hands idle movement, no head)
		"stand_ini": 51, "stand_end": 53,
		# GMS2: handsCast1Ini=55..End=58 (hands attack/cast type 1)
		"attack_ini": 55, "attack_end": 58,
		# GMS2: handsCast2Ini=59..End=65 (hands attack/cast type 2)
		"attack2_ini": 59, "attack2_end": 65,
		# GMS2: handsMove2Ini=67..End=70 (hands movement with head visible)
		"stand_head_ini": 67, "stand_head_end": 70,
		# GMS2: hurtIni=72..hurtEnd=80 (shared with fullbody)
		"hurt_ini": 72, "hurt_end": 80,
		# GMS2: hurt2Ini=82..hurt2End=83 (hands-specific hurt)
		"hurt2_ini": 82, "hurt2_end": 83,
	},
}

# Waist/body overlay sprite (GMS2: composite draw — waist behind, main sprite on top)
var waist_sprite: Sprite2D = null
var _waist_sheet: Texture2D = null

# Palette swap cycling (GMS2: Draw_0 → ani_palleteSwap)
var pal_color_index: int = 0
var _pal_step_timer: float = 0.0
var _pal_shader: Shader = null
var _pal_material: ShaderMaterial = null        # head palette → main sprite
var _pal_waist_material: ShaderMaterial = null   # body palette → waist sprite
# GMS2: separate palettes for body (waist) and head (main sprite)
var _pal_body_tex: Texture2D = null             # body palette (normal)
var _pal_body_magic_tex: Texture2D = null       # body palette (magic)
var _pal_head_tex: Texture2D = null             # head palette (normal)
var _pal_head_magic_tex: Texture2D = null       # head palette (magic)
var _pal_hands_tex: Texture2D = null            # hands only (4x40)
var _pal_hands_magic_tex: Texture2D = null      # handsMagic only (4x40)
var _pal_head_death_tex: Texture2D = null       # head death palette
var _death_palette_mode: bool = false           # GMS2: switches to death palette in DEAD state
const PAL_WIDTH: int = 4  # 4 palette columns
const PAL_WIDTH_DEATH: int = 9  # GMS2: palleteWidth = 9 for death palette
const PAL_SPEED_NORMAL: float = 9.0 / 60.0  # Swap every 9 frames at 60fps = 0.15s
const PAL_SPEED_MAGIC: float = 3.0 / 60.0  # Swap every 3 frames at 60fps = 0.05s
## GMS2: ani_palleteSwapAnimation speed=0.1 → advance pal_color_index every ~10 frames
const PAL_SPEED_DEATH: float = 10.0 / 60.0

# Boss death callback signal
signal boss_defeated

func _ready() -> void:
	super._ready()
	creature_is_boss = true
	pushable = false
	mob_name = "Dark Lich"
	display_name = "Dark Lich"
	add_to_group("bosses")
	# GMS2: pierceMagic = true (cannot be blocked)
	pierce_magic = true
	# Skills the Dark Lich can cast (GMS2: 15 spells shuffled)
	skill_list = [
		"freezeBeam", "petrifyBeam", "confuseHoops", "leadenGlare", "freeze",
		"earthSlide", "thunderbolt", "darkForce", "dispelMagic", "evilGate",
		"pygmusGlare", "sleepGas", "poisonGas", "balloonRing", "energyAbsorb"
	]
	add_to_group("mobs")

	# GMS2 stats (level 60)
	attribute["hp"] = 3000
	attribute["maxHP"] = 3000
	attribute["mp"] = 999
	attribute["maxMP"] = 999
	attribute["strength"] = 80
	attribute["constitution"] = 60
	attribute["intelligence"] = 90
	attribute["wisdom"] = 70
	attribute["level"] = 60

	# GMS2: not pushable, trespassable, does not pause when casting
	passive = false

	# GMS2: Dark Lich overrides oMob's img_speed values
	# state_imgSpeedStand = 0.1, state_imgSpeedCast = 0.1, state_imgSpeedAttack = 0.2
	img_speed_attack = 0.2

	# Load sprite sheet
	_init_boss_sprite()

	# Shuffle skill list
	_shuffle_skills()

	# Start in FULLBODY phase
	_apply_phase_sprites()

	# Initialize palette swap shader (GMS2: pal_swap_init_system)
	_init_palette_swap()

	# Set initial frame explicitly — StateMachine._ready() runs BEFORE this _ready()
	# (child nodes init first in Godot), so DLStand.enter() fires before the spritesheet
	# is loaded. Force the correct initial frame now that everything is initialized.
	set_frame(phase_sprite_config[Phase.FULLBODY]["stand_front_ini"])

func _init_boss_sprite() -> void:
	## Try AnimatedSprite2D from .tres (new system)
	var anim_lib_path := "res://assets/animations/bosses/dark_lich/dark_lich.tres"
	if ResourceLoader.exists(anim_lib_path):
		var sf: SpriteFrames = load(anim_lib_path)
		if sf:
			# Keep frame metadata for palette shader compatibility
			frame_width = 128
			frame_height = 128
			sprite_columns = 16
			setup_animated_sprite(sf, Vector2(64, 64))
			_build_dark_lich_frame_map()
			# Waist overlay stays as Sprite2D (palette shader needs it)
			_init_waist_sprite()
			return

	## Fallback: legacy Sprite2D system
	var tex: Texture2D = load("res://assets/sprites/sheets/spr_darkLich.png")
	if tex:
		var meta_path := "res://assets/sprites/sheets/spr_darkLich.json"
		var columns: int = 10
		if FileAccess.file_exists(meta_path):
			var f := FileAccess.open(meta_path, FileAccess.READ)
			if f:
				var json := JSON.new()
				if json.parse(f.get_as_text()) == OK:
					var data: Dictionary = json.data
					columns = data.get("columns", 10)
				f.close()
		set_sprite_sheet(tex, columns, 128, 128, Vector2(64, 64))
	_init_waist_sprite()

func _init_waist_sprite() -> void:
	# Load waist overlay sprite (GMS2: spr_darkLich_waist — drawn behind main sprite)
	_waist_sheet = load("res://assets/sprites/sheets/spr_darkLich_waist.png")
	waist_sprite = get_node_or_null("WaistSprite") as Sprite2D
	if waist_sprite and _waist_sheet:
		waist_sprite.texture = _waist_sheet
		waist_sprite.region_enabled = true
		waist_sprite.centered = false
		waist_sprite.offset = -Vector2(64, 64)
		if not _use_animated_sprite:
			waist_sprite.region_rect = _get_frame_rect(0)

func _build_dark_lich_frame_map() -> void:
	var fb: Dictionary = phase_sprite_config[Phase.FULLBODY]
	var hd: Dictionary = phase_sprite_config[Phase.HANDS]
	_frame_to_anim_map.clear()
	# FULLBODY phase mappings
	_frame_to_anim_map[fb["stand_front_ini"]] = "fullbody_stand"  # 10 → fullbody_stand_up/down/right/left
	_frame_to_anim_map[fb["stand_right_ini"]] = "fullbody_stand"  # 0 → same prefix (bridge resolves _right)
	_frame_to_anim_map[fb["stand_left_ini"]] = "fullbody_stand"   # 5 → same prefix (bridge resolves _left)
	_frame_to_anim_map[fb["waist_ini"]] = "fullbody_waist"
	_frame_to_anim_map[fb["hurt_ini"]] = "hurt"
	# Cast animations
	for i in range(5):
		_frame_to_anim_map[fb["cast_ini_%d" % i]] = "cast_%d" % i
	# HANDS phase mappings
	_frame_to_anim_map[hd["stand_ini"] + 1] = "hands_stand"  # +1 because GMS2 skips frame 51
	_frame_to_anim_map[hd["attack_ini"]] = "hands_attack"
	_frame_to_anim_map[hd["attack2_ini"]] = "hands_attack2"
	_frame_to_anim_map[hd["stand_head_ini"]] = "hands_head_stand"
	_frame_to_anim_map[hd["hurt2_ini"]] = "hurt2"

func _init_palette_swap() -> void:
	_pal_shader = load("res://assets/shaders/shd_pal_swapper.gdshader") as Shader
	if not _pal_shader:
		return
	# Main sprite material (head palette in FULLBODY, hands palette in HANDS)
	_pal_material = ShaderMaterial.new()
	_pal_material.shader = _pal_shader
	# Waist sprite material (body palette, only used in FULLBODY)
	_pal_waist_material = ShaderMaterial.new()
	_pal_waist_material.shader = _pal_shader
	# GMS2: separate body/head palettes for composite draw
	_pal_body_tex = load("res://assets/sprites/palettes/pal_darkLich_body.png")
	_pal_body_magic_tex = load("res://assets/sprites/palettes/pal_darkLich_bodyMagic.png")
	_pal_head_tex = load("res://assets/sprites/palettes/pal_darkLich_head.png")
	_pal_head_magic_tex = load("res://assets/sprites/palettes/pal_darkLich_headMagic.png")
	_pal_hands_tex = load("res://assets/sprites/palettes/pal_darkLich_hands.png")
	_pal_hands_magic_tex = load("res://assets/sprites/palettes/pal_darkLich_handsMagic.png")
	_pal_head_death_tex = load("res://assets/sprites/palettes/pal_darkLich_headDeath.png")
	# Apply initial palette
	_apply_palette_shader()

func _apply_palette_shader() -> void:
	var target_sprite: Node2D = animated_sprite if _use_animated_sprite else sprite
	if not _pal_material or not target_sprite:
		return

	# GMS2 Draw_0: Death state uses pal_darkLich_headDeath (9 columns) for everything.
	if _death_palette_mode:
		_apply_death_palette()
		return

	# GMS2 Draw_0: FULLBODY draws waist with body palette THEN main sprite with head palette.
	# HANDS phase only draws main sprite with hands palette.
	var is_magic: bool = current_shader != null  # GMS2: shader != noone
	var main_pal_tex: Texture2D
	var main_pal_height: float

	if current_phase == Phase.HANDS:
		main_pal_tex = _pal_hands_magic_tex if is_magic else _pal_hands_tex
		main_pal_height = 40.0
	else:
		# FULLBODY: main sprite uses HEAD palette
		main_pal_tex = _pal_head_magic_tex if is_magic else _pal_head_tex
		main_pal_height = 40.0

	# Apply head/hands palette to main sprite
	if main_pal_tex:
		_pal_material.set_shader_parameter("palette_texture", main_pal_tex)
		_pal_material.set_shader_parameter("texel_size", Vector2(1.0 / 4.0, 1.0 / main_pal_height))
		_pal_material.set_shader_parameter("palette_uvs", Vector4(0.0, 0.0, 1.0, 1.0))
		_pal_material.set_shader_parameter("palette_index", float(pal_color_index))
		target_sprite.material = _pal_material

	# Apply body palette to waist sprite (FULLBODY only)
	if waist_sprite and current_phase == Phase.FULLBODY:
		var waist_pal_tex: Texture2D = _pal_body_magic_tex if is_magic else _pal_body_tex
		if waist_pal_tex:
			_pal_waist_material.set_shader_parameter("palette_texture", waist_pal_tex)
			_pal_waist_material.set_shader_parameter("texel_size", Vector2(1.0 / 4.0, 1.0 / 40.0))
			_pal_waist_material.set_shader_parameter("palette_uvs", Vector4(0.0, 0.0, 1.0, 1.0))
			_pal_waist_material.set_shader_parameter("palette_index", float(pal_color_index))
			waist_sprite.material = _pal_waist_material

func _apply_death_palette() -> void:
	## GMS2 Draw_0 DEAD: ani_palleteSwapAnimation(pal_darkLich_headDeath, 9, 1, true, 0.1)
	## Uses the death palette (9 columns) for BOTH main sprite and waist (FULLBODY).
	if not _pal_head_death_tex:
		return
	var pal_tex: Texture2D = _pal_head_death_tex
	var pal_height: float = float(_pal_head_death_tex.get_height())
	var pal_width: float = float(PAL_WIDTH_DEATH)

	# Main sprite: death palette
	var target_sprite: Node2D = animated_sprite if _use_animated_sprite else sprite
	_pal_material.set_shader_parameter("palette_texture", pal_tex)
	_pal_material.set_shader_parameter("texel_size", Vector2(1.0 / pal_width, 1.0 / pal_height))
	_pal_material.set_shader_parameter("palette_uvs", Vector4(0.0, 0.0, 1.0, 1.0))
	_pal_material.set_shader_parameter("palette_index", float(pal_color_index))
	if target_sprite:
		target_sprite.material = _pal_material

	# Waist sprite: same death palette (GMS2 FULLBODY draws waist with same palette active)
	if waist_sprite and current_phase == Phase.FULLBODY and waist_sprite.visible:
		_pal_waist_material.set_shader_parameter("palette_texture", pal_tex)
		_pal_waist_material.set_shader_parameter("texel_size", Vector2(1.0 / pal_width, 1.0 / pal_height))
		_pal_waist_material.set_shader_parameter("palette_uvs", Vector4(0.0, 0.0, 1.0, 1.0))
		_pal_waist_material.set_shader_parameter("palette_index", float(pal_color_index))
		waist_sprite.material = _pal_waist_material

func _process(delta: float) -> void:
	super._process(delta)
	if GameManager.ring_menu_opened:
		return
	phase_time += delta
	# Palette swap cycling (GMS2: Draw_0 → ani_palleteSwap, runs at 60fps)
	if _pal_material:
		var pal_speed: float
		var pal_width: int
		if _death_palette_mode:
			pal_speed = PAL_SPEED_DEATH
			pal_width = PAL_WIDTH_DEATH
		elif current_shader != null:
			pal_speed = PAL_SPEED_MAGIC
			pal_width = PAL_WIDTH
		else:
			pal_speed = PAL_SPEED_NORMAL
			pal_width = PAL_WIDTH
		_pal_step_timer += delta
		if _pal_step_timer >= pal_speed:
			_pal_step_timer -= pal_speed
			# GMS2: skipFirst=true for death → start from 1, cycle 1..8
			var next_index: int = pal_color_index + 1
			if _death_palette_mode:
				if next_index >= pal_width:
					next_index = 1  # skip index 0 (GMS2: skipFirst=true)
			else:
				next_index = next_index % pal_width
			pal_color_index = next_index
			_apply_palette_shader()

func _update_draw_order() -> void:
	## Override: GMS2 FULLBODY uses constant depth = -7000 (drawn in front of everything),
	## HANDS uses depth = -bbox_bottom (normal Y-sorting).
	## Godot z_index max = 4096 (RenderingServer::CANVAS_ITEM_Z_MAX).
	if current_phase == Phase.FULLBODY:
		z_index = 4096  # GMS2: depthFullBody = -7000 (always on top)
	else:
		z_index = clampi(int(global_position.y), -4096, 4096)  # Normal Y-sorting for HANDS

func set_frame(frame_index: int) -> void:
	## Override: sync waist sprite frame with main sprite (GMS2: draw_sprite_ext(waist, image_index))
	super.set_frame(frame_index)
	if waist_sprite and _waist_sheet:
		waist_sprite.region_rect = _get_frame_rect(frame_index)

func switch_phase() -> void:
	## Toggle between FULLBODY and HANDS phases (GMS2: FADE state triggers this)
	if current_phase == Phase.FULLBODY:
		current_phase = Phase.HANDS
	else:
		current_phase = Phase.FULLBODY
	phase_time = 0.0
	cast_times = 0
	attacked_times = 0
	cast_times_limit = randi_range(2, 3)
	_apply_phase_sprites()

func _apply_phase_sprites() -> void:
	## Update animation ranges based on current phase
	# GMS2: waist overlay only drawn during FULLBODY phase
	if waist_sprite:
		waist_sprite.visible = (current_phase == Phase.FULLBODY)
	var config: Dictionary = phase_sprite_config.get(current_phase, {})
	if current_phase == Phase.FULLBODY:
		# GMS2: standRightIni=0..3, standLeftIni=5..8, standFrontIni=10..13
		# UP = front-facing, DOWN = front-facing, RIGHT = right, LEFT = left
		var front_ini: int = config.get("stand_front_ini", 10)
		var front_end: int = config.get("stand_front_end", 13)
		spr_walk_up_ini = front_ini; spr_walk_up_end = front_end
		spr_walk_down_ini = front_ini; spr_walk_down_end = front_end
		spr_walk_right_ini = config.get("stand_right_ini", 0)
		spr_walk_right_end = config.get("stand_right_end", 3)
		spr_walk_left_ini = config.get("stand_left_ini", 5)
		spr_walk_left_end = config.get("stand_left_end", 8)
		# Stand frames = front-facing
		spr_stand_up = front_ini
		spr_stand_down = front_ini
		spr_stand_right = config.get("stand_right_ini", 0)
		spr_stand_left = config.get("stand_left_ini", 5)
		# Hurt frames (GMS2: hurtIni=72)
		spr_hit_up = config.get("hurt_ini", 72)
		spr_hit_right = config.get("hurt_ini", 72)
		spr_hit_down = config.get("hurt_ini", 72)
		spr_hit_left = config.get("hurt_ini", 72)
	else:
		# Hands phase: GMS2 uses handsMove1Ini+1 to handsMove1End (skips frame 51, uses 52-53)
		var stand_ini: int = config.get("stand_ini", 51) + 1  # GMS2: handsMove1Ini + 1
		var stand_end: int = config.get("stand_end", 53)
		spr_walk_up_ini = stand_ini; spr_walk_up_end = stand_end
		spr_walk_right_ini = stand_ini; spr_walk_right_end = stand_end
		spr_walk_down_ini = stand_ini; spr_walk_down_end = stand_end
		spr_walk_left_ini = stand_ini; spr_walk_left_end = stand_end
		spr_stand_up = stand_ini; spr_stand_down = stand_ini
		spr_stand_right = stand_ini; spr_stand_left = stand_ini
		# Attack frames (GMS2: state_sprAttack = 55..65, covers both handsCast1 and handsCast2)
		spr_attack_up_ini = config.get("attack_ini", 55)
		spr_attack_up_end = config.get("attack2_end", 65)  # GMS2: attackEnd = handsCast2End = 65
		spr_attack_right_ini = spr_attack_up_ini; spr_attack_right_end = spr_attack_up_end
		spr_attack_down_ini = spr_attack_up_ini; spr_attack_down_end = spr_attack_up_end
		spr_attack_left_ini = spr_attack_up_ini; spr_attack_left_end = spr_attack_up_end
		# Hurt frames: HANDS phase uses hurt2 (82-83), NOT hurt (72-80)
		spr_hit_up = config.get("hurt2_ini", 82)
		spr_hit_right = config.get("hurt2_ini", 82)
		spr_hit_down = config.get("hurt2_ini", 82)
		spr_hit_left = config.get("hurt2_ini", 82)

	set_default_facing_animations(
		spr_walk_up_ini, spr_walk_right_ini,
		spr_walk_down_ini, spr_walk_left_ini,
		spr_walk_up_end, spr_walk_right_end,
		spr_walk_down_end, spr_walk_left_end
	)
	# Also update palette for new phase
	_apply_palette_shader()

func _shuffle_skills() -> void:
	_shuffled_skills = skill_list.duplicate()
	_shuffled_skills.shuffle()
	_skill_index = 0

func get_next_skill() -> String:
	## Get next skill from shuffled list (re-shuffle when exhausted)
	if _skill_index >= _shuffled_skills.size():
		_shuffle_skills()
	var skill: String = _shuffled_skills[_skill_index]
	_skill_index += 1
	return skill

func get_random_skill() -> String:
	return get_next_skill()

func cast_random_skill(target: Creature = null) -> void:
	var skill_name: String = get_next_skill()
	if target and is_instance_valid(target):
		SkillSystem.cast_skill(skill_name, self, target)

func should_force_phase_change() -> bool:
	return phase_time > max_time_between_phases

func get_elemental_damage_multiplier(element: int, attack_type: int) -> float:
	## Dark Lich: Lumina weakness is 3x for weapons, 5x for magic (GMS2 overrides)
	if element == Constants.Element.LUMINA:
		if attack_type == Constants.AttackType.MAGIC:
			return lumina_magic_multiplier
		else:
			return lumina_weapon_multiplier
	return super.get_elemental_damage_multiplier(element, attack_type)

func look_at_player(target: Node = null) -> void:
	## GMS2: bossLookAtPlayer - face toward the party leader
	if not target:
		target = find_nearest_player()
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position)
	if abs(dir.x) > abs(dir.y):
		if dir.x < 0:
			facing = Constants.Facing.LEFT
		else:
			facing = Constants.Facing.RIGHT
	else:
		facing = Constants.Facing.DOWN  # Default front-facing
	new_facing = facing

func enable_death_palette() -> void:
	## GMS2: switch to pal_darkLich_headDeath (9 columns, slow cycling) during DEAD state
	_death_palette_mode = true
	pal_color_index = 1  # GMS2: skipFirst=true → start at index 1
	_pal_step_timer = 0.0
	_apply_palette_shader()
