class_name BossDarkLichCast
extends State
## Dark Lich CAST state - replaces fsm_mob_darkLich_cast from GMS2
## Spell casting with per-skill animation and cast projectile visuals.

var skill_name: String = ""
var magic_level: int = 1
var target: Node = null
var source: Node = null
var create_cast: bool = false
var choose_skill_animation: int = 0

## GMS2 cast projectile mapping: skill_name → [sprite_sheet_path, anim_speed]
## anim_speed = (playbackSpeed * image_speed) / 60 = frames-per-step at 60fps
## Skills not listed here have no cast projectile (castProjectile = -1 in GMS2)
const CAST_PROJECTILE_MAP: Dictionary = {
	"freezeBeam": ["res://assets/sprites/sheets/spr_darkLich_cast0.png", 0.25],   # 15fps × 1.0 / 60
	"petrifyBeam": ["res://assets/sprites/sheets/spr_darkLich_cast0.png", 0.25],  # same sprite
	"pygmusGlare": ["res://assets/sprites/sheets/spr_darkLich_cast2.png", 0.25],  # 15fps × 1.0 / 60
	"sleepGas": ["res://assets/sprites/sheets/spr_darkLich_cast3.png", 0.2],      # 60fps × 0.2 / 60
	"balloonRing": ["res://assets/sprites/sheets/spr_darkLich_cast4.png", 0.05],  # 15fps × 0.2 / 60
}

## Cast projectile sprite metadata: [frame_width, frame_height, columns, total_frames]
const CAST_SPRITE_META: Dictionary = {
	"res://assets/sprites/sheets/spr_darkLich_cast0.png": [14, 14, 5, 5],
	"res://assets/sprites/sheets/spr_darkLich_cast2.png": [36, 36, 10, 10],
	"res://assets/sprites/sheets/spr_darkLich_cast3.png": [44, 44, 13, 13],
	"res://assets/sprites/sheets/spr_darkLich_cast4.png": [32, 32, 10, 10],
}


func enter() -> void:
	creature.velocity = Vector2.ZERO
	create_cast = false

	# Read state vars: [0]=skillName, [1]=magicLevel, [2]=target, [3]=source
	skill_name = state_machine.get_state_var(0, "")
	magic_level = state_machine.get_state_var(1, 1)
	target = state_machine.get_state_var(2, null)
	source = state_machine.get_state_var(3, creature)

	if skill_name == "":
		switch_to("DLStand")
		return

	# GMS2: Select cast animation index based on skill
	# chooseSkilAnimation: 0=freezeBeam/petrifyBeam, 4=freeze, random(0-4) otherwise
	if skill_name == "freezeBeam" or skill_name == "petrifyBeam":
		choose_skill_animation = 0
	elif skill_name == "freeze":
		choose_skill_animation = 4
	else:
		choose_skill_animation = randi_range(0, 4)

	# Set cast animation using choose_skill_animation index (GMS2: castIni[chooseSkilAnimation])
	var boss := creature as BossDarkLich
	if boss:
		var config: Dictionary = boss.phase_sprite_config.get(BossDarkLich.Phase.FULLBODY, {})
		var cast_ini_key: String = "cast_ini_%d" % choose_skill_animation
		var cast_end_key: String = "cast_end_%d" % choose_skill_animation
		var cast_ini: int = config.get(cast_ini_key, config.get("cast_ini_0", 20))
		var cast_end: int = config.get(cast_end_key, config.get("cast_end_0", 22))
		creature.set_default_facing_animations(
			cast_ini, cast_ini, cast_ini, cast_ini,
			cast_end, cast_end, cast_end, cast_end
		)
		creature.set_default_facing_index()

	# GMS2: image_speed = state_imgSpeedCast = 0.1
	creature.image_speed = 0.1
	MusicManager.play_sfx("snd_lichCast")


func execute(_delta: float) -> void:
	creature.animate_sprite(creature.image_speed, true)

	var timer := get_timer()

	# GMS2: At frame 35, spawn cast projectile visual above the lich
	if timer > 35 / 60.0 and not create_cast:
		create_cast = true
		# GMS2: only if chooseSkilAnimation != 4 (freeze anim) and castProjectile != -1
		if choose_skill_animation != 4 and CAST_PROJECTILE_MAP.has(skill_name):
			_spawn_cast_projectile()

	# GMS2: At frame 60, cast spell and return to stand with state_payload(2) → keyframe 2
	if timer > 60 / 60.0:
		if skill_name != "" and is_instance_valid(target):
			SkillSystem.cast_skill(skill_name, source, target, magic_level)
		switch_to("DLStand", [2])  # 2 = returning from cast, resume at keyframe 2


func _spawn_cast_projectile() -> void:
	## Spawn a one-shot GenericAnimation at (lich.x, lich.y - 40) for the cast visual
	var proj_data: Array = CAST_PROJECTILE_MAP.get(skill_name, [])
	if proj_data.size() < 2:
		return

	var sheet_path: String = proj_data[0]
	var anim_speed: float = proj_data[1]

	var tex: Texture2D = load(sheet_path) as Texture2D
	if not tex:
		return

	var meta: Array = CAST_SPRITE_META.get(sheet_path, [32, 32, 1, 1])
	var fw: int = meta[0]
	var fh: int = meta[1]
	var cols: int = meta[2]
	var total: int = meta[3]

	# GMS2: instance_create_pre(x, y - 40, "lyr_animations", oGenericAnimation, ...)
	var spawn_pos: Vector2 = creature.global_position + Vector2(0, -40)
	GenericAnimation.play_at(
		get_tree().current_scene, spawn_pos,
		tex, cols, fw, fh, 0, total - 1, anim_speed
	)


func exit() -> void:
	creature.velocity = Vector2.ZERO
