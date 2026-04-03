class_name ItemHealEffect
extends Node2D
## Item healing animation - replaces oSkill_candy/oSkill_chocolate/etc from GMS2
## Plays spr_skill_cureWater animation at target, applies heal on completion,
## applies sha_palleteSwap shader to target during effect.

var target: Creature = null
var healing_type: String = "hp_add"  # "hp_add" or "mp_add"
var heal_value: int = 0

var _timer: float = 0.0

var _anim_sprite: AnimatedSprite2D = null
var _sound_played: bool = false
var _heal_applied: bool = false
var _shader_applied: bool = false
var _target_frozen: bool = false
var _target_original_material: Material = null

static var _cure_water_tex: Texture2D = null
static var _palette_swap_shader: Shader = null
const _FRAME_COUNT: int = 33
const _FRAME_W: int = 128
const _FRAME_H: int = 128
const _COLUMNS: int = 11

func _ready() -> void:
	if not _cure_water_tex:
		_cure_water_tex = load("res://assets/sprites/sheets/spr_skill_cureWater.png")

	if not _cure_water_tex or not is_instance_valid(target):
		queue_free()
		return

	# Position at target (GMS2: x=target.x, y=target.y-10)
	global_position = target.global_position + Vector2(0, -10)
	z_index = 1000  # GMS2: created on lyr_animations (depth -14000), always above creatures

	# GMS2: item heals call pauseCreature() unconditionally + state_switch(state_ANIMATION)
	_freeze_target()

	# Build animated sprite from sheet
	_anim_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("heal")
	frames.set_animation_speed("heal", 60.0)
	frames.set_animation_loop("heal", false)

	for i in range(_FRAME_COUNT):
		var col: int = i % _COLUMNS
		var row: int = i / _COLUMNS
		var atlas := AtlasTexture.new()
		atlas.atlas = _cure_water_tex
		atlas.region = Rect2(col * _FRAME_W, row * _FRAME_H, _FRAME_W, _FRAME_H)
		frames.add_frame("heal", atlas)

	_anim_sprite.sprite_frames = frames
	_anim_sprite.animation = "heal"
	_anim_sprite.play("heal")
	_anim_sprite.animation_finished.connect(_on_animation_finished)
	add_child(_anim_sprite)

func _process(delta: float) -> void:
	_timer += delta

	# GMS2: after frame 20, slow animation to 0.3 speed
	if _anim_sprite and _anim_sprite.frame >= 20:
		_anim_sprite.speed_scale = 0.3

		# Play snd_cure once (GMS2: soundPlay(snd_cure))
		if not _sound_played:
			MusicManager.play_sfx("snd_cure")
			_sound_played = true

		# GMS2: ani_cureWater palette swap on target
		if not _shader_applied:
			_apply_target_shader()

	# Follow target position
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -10)

func _on_animation_finished() -> void:
	# Apply healing (GMS2: performHeal at end of animation)
	if not _heal_applied and is_instance_valid(target):
		_heal_applied = true

		if healing_type == "hp_add":
			target.apply_heal(heal_value)
		elif healing_type == "mp_add":
			target.attribute.mp = mini(target.attribute.mp + heal_value, target.attribute.maxMP)
			target.refresh_mp_percent()
		# GMS2: HP heal = HP_GAIN (sky blue), MP heal = MP_GAIN (green)
		var counter_type: int = FloatingNumber.CounterType.MP_GAIN if healing_type == "mp_add" else FloatingNumber.CounterType.HP_GAIN
		FloatingNumber.spawn(target, target, heal_value, counter_type)

	_remove_target_shader()
	# Healed pose is now triggered universally from creature.apply_heal() —
	# no manual _apply_healed_pose() call needed here.
	_unfreeze_target()
	queue_free()



func _freeze_target() -> void:
	if is_instance_valid(target) and target.state_machine_node:
		if target.state_machine_node.has_state("Animation"):
			_target_frozen = true
			target.pause_creature()
			target.state_machine_node.switch_state("Animation")


func _unfreeze_target() -> void:
	if _target_frozen and is_instance_valid(target) and target.state_machine_node:
		# Don't override healed pose — apply_heal() already triggered StaticAnimation
		if target.state_machine_node.current_state_name == "StaticAnimation":
			return
		# Use Actor's routing (player → Stand/Walk, AI → IAGuard/IAStand)
		if target is Actor:
			(target as Actor).change_state_stand_dead()
		elif target.is_dead:
			if target.state_machine_node.has_state("Dead"):
				target.state_machine_node.switch_state("Dead")
		else:
			if target.state_machine_node.has_state("Stand"):
				target.state_machine_node.switch_state("Stand")


func _apply_target_shader() -> void:
	if not is_instance_valid(target) or not target.sprite:
		return
	if _palette_swap_shader == null:
		_palette_swap_shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
	if _palette_swap_shader == null:
		return

	# GMS2: ani_cureWater() → GREEN channel, (0,0,1.0), limit=0.4
	# Same palette swap for both HP and MP items (GMS2 uses ani_cureWater for all heal items)
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = _palette_swap_shader
	shader_mat.set_shader_parameter("u_color_channel", 1)  # GREEN
	shader_mat.set_shader_parameter("u_color_add", Vector3(0.0, 0.0, 1.0))
	shader_mat.set_shader_parameter("u_color_limit", 0.4)

	_target_original_material = target.sprite.material
	target.sprite.material = shader_mat
	_shader_applied = true


func _remove_target_shader() -> void:
	if not _shader_applied:
		return
	_shader_applied = false
	if is_instance_valid(target) and target.sprite:
		target.sprite.material = _target_original_material
	_target_original_material = null


static func spawn(p_target: Creature, p_type: String, p_value: int) -> ItemHealEffect:
	if not is_instance_valid(p_target):
		return null
	var effect := ItemHealEffect.new()
	effect.target = p_target
	effect.healing_type = p_type
	effect.heal_value = p_value
	p_target.get_tree().current_scene.add_child(effect)
	return effect
