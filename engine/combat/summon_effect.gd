class_name SummonEffect
extends Node2D
## Deity summon visual effect - replaces oSummon from GMS2
## Two-phase animation: spark intro (spr_magic_summon) → deity sprite (spr_magic_[deity])
## After deity animation completes + delay, triggers SkillSystem.cast_skill() and self-destructs.

## Phase constants
enum Phase { SPARK, DEITY, DONE }

## Setup data (set via setup() before adding to tree)
var source: Creature
var target: Creature
var skill_name: String = ""
var deity_name: String = ""  # "Undine", "Gnome", etc.
var magic_level: int = 0
var target_all: bool = false  # GMS2: selectedTarget == -1 → apply to all valid targets

## Animation state
var phase: int = Phase.SPARK
var spark_frames: Array[Texture2D] = []
var deity_frames: Array[Texture2D] = []
var current_frame_idx: int = 0
var frame_timer: float = 0.0
# GMS2: oSummon sets image_speed=0.9, sprites have playbackSpeed=15.0 (FPS mode)
# Effective FPS = playbackSpeed * image_speed = 15.0 * 0.9 = 13.5 FPS
# Time per frame = 1.0 / 13.5 ≈ 0.0741 seconds
var animation_speed: float = 1.0 / 13.5
var deity_anim_speed: float = 1.0 / 13.5
var timer: float = 0.0  # delta-accumulated timer (seconds)

## Sprite
var effect_sprite: Sprite2D
var spark_offset: Vector2 = Vector2.ZERO
var deity_offset: Vector2 = Vector2.ZERO

## Shared sprite DB (reuse SkillEffect's)
# GMS2: oSummon timer > 110 at 60fps = 1.833 seconds; spawned at actor tick 30 (0.5s)
const EFFECT_APPLY_TIME: float = 110.0 / 60.0  # 1.833 seconds (matches GMS2 timer > 110)

## Deity name mapping from element index
const DEITY_NAMES: Array[String] = [
	"undine", "gnome", "sylphid", "salamando",
	"shade", "luna", "lumina", "dryad"
]


func setup(p_source: Creature, p_target: Creature, p_skill_name: String, p_deity_index: int, p_level: int, p_target_all: bool = false) -> void:
	source = p_source
	target = p_target
	skill_name = p_skill_name
	magic_level = p_level
	target_all = p_target_all
	if p_deity_index >= 0 and p_deity_index < DEITY_NAMES.size():
		deity_name = DEITY_NAMES[p_deity_index]


func _ready() -> void:
	SkillEffect._ensure_sprite_db()
	effect_sprite = Sprite2D.new()
	effect_sprite.name = "SummonSprite"
	add_child(effect_sprite)
	z_index = 1000  # Draw on top

	_load_spark_frames()
	_load_deity_frames()

	# Start with spark phase
	phase = Phase.SPARK
	current_frame_idx = 0
	frame_timer = 0.0
	timer = 0.0

	if spark_frames.size() > 0:
		effect_sprite.texture = spark_frames[0]
		effect_sprite.offset = spark_offset
	elif deity_frames.size() > 0:
		# No spark frames available, skip directly to deity
		_switch_to_deity()


func _process(delta: float) -> void:
	if phase == Phase.DONE:
		return
	# GMS2: ring menu pauses all combat logic
	if GameManager.ring_menu_opened:
		return

	timer += delta

	match phase:
		Phase.SPARK:
			_animate_spark(delta)
		Phase.DEITY:
			_animate_deity(delta)

	# Apply magic effect after delay (GMS2: timer > 110 at 60fps = 1.833s)
	if timer >= EFFECT_APPLY_TIME and phase != Phase.DONE:
		_apply_and_destroy()


func _animate_spark(delta: float) -> void:
	if spark_frames.size() == 0:
		_switch_to_deity()
		return

	frame_timer += delta
	if frame_timer >= animation_speed:
		frame_timer -= animation_speed
		current_frame_idx += 1

		if current_frame_idx >= spark_frames.size():
			# Spark finished → switch to deity
			_switch_to_deity()
			return

		if current_frame_idx < spark_frames.size():
			effect_sprite.texture = spark_frames[current_frame_idx]


var _deity_anim_stopped: bool = false

func _animate_deity(delta: float) -> void:
	if deity_frames.size() == 0 or _deity_anim_stopped:
		return

	frame_timer += delta
	if frame_timer >= deity_anim_speed:
		frame_timer -= deity_anim_speed
		current_frame_idx += 1

		if current_frame_idx >= deity_frames.size():
			# GMS2: image_speed = 0 → stop on last frame (does NOT loop)
			current_frame_idx = deity_frames.size() - 1
			_deity_anim_stopped = true

		if current_frame_idx < deity_frames.size():
			effect_sprite.texture = deity_frames[current_frame_idx]


func _switch_to_deity() -> void:
	phase = Phase.DEITY
	current_frame_idx = 0
	frame_timer = 0.0

	if deity_frames.size() > 0:
		effect_sprite.texture = deity_frames[0]
		effect_sprite.offset = deity_offset
	else:
		# No deity frames available either - just wait for timer
		effect_sprite.visible = false


func _apply_and_destroy() -> void:
	phase = Phase.DONE

	# Cast the spell through the skill system
	if skill_name != "" and is_instance_valid(source) and is_instance_valid(target):
		SkillSystem.cast_skill(skill_name, source, target, magic_level, target_all)

	queue_free()


func _load_spark_frames() -> void:
	var sprite_key: String = "spr_magic_summon"
	spark_frames = SpriteUtils.load_sheet_frames(sprite_key)
	spark_offset = SpriteUtils.get_sheet_offset(sprite_key)

	# GMS2: oSummon overrides image_speed=0.9; sprite playbackSpeed is in FPS mode
	SkillEffect._ensure_sprite_db()
	var sprite_info: Dictionary = SkillEffect._sprite_db.get(sprite_key, {})
	var playback_fps: float = sprite_info.get("playback_speed", 15.0)
	animation_speed = 1.0 / (playback_fps * 0.9)


func _load_deity_frames() -> void:
	if deity_name.is_empty():
		return

	var sprite_key: String = "spr_magic_" + deity_name
	deity_frames = SpriteUtils.load_sheet_frames(sprite_key)
	if deity_frames.is_empty():
		push_warning("SummonEffect: No sprite data for deity '%s'" % deity_name)
		return

	deity_offset = SpriteUtils.get_sheet_offset(sprite_key)

	# GMS2: oSummon overrides image_speed=0.9; sprite playbackSpeed is in FPS mode
	var sprite_info: Dictionary = SkillEffect._sprite_db.get(sprite_key, {})
	var playback_fps: float = sprite_info.get("playback_speed", 15.0)
	deity_anim_speed = 1.0 / (playback_fps * 0.9)
