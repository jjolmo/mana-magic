class_name ReaperEffect
extends Node2D
## Reaper death animation - replaces oMisc_reaper from GMS2
## Animated reaper sprite that follows a dead actor, auto-destroys after ~100 ticks.

const Y_OFFSET: float = -34.0  # GMS2: y = target.y - 34
const DESTROY_TIME: float = 100.0 / 60.0  # 100 ticks at 60fps
const ANIM_FPS: float = 30.0  # GMS2: image_speed=0.5 × 60fps

var target: Node2D = null
var _timer: float = 0.0
var _sprite: AnimatedSprite2D


func setup(p_target: Node2D) -> void:
	target = p_target


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "ReaperSprite"
	var sf := SpriteUtils.build_sprite_frames("spr_reaper", "reaper", ANIM_FPS, true)
	if sf:
		_sprite.sprite_frames = sf
		_sprite.animation = "reaper"
		_sprite.play()
	_sprite.offset = SpriteUtils.get_sheet_offset("spr_reaper")
	add_child(_sprite)

	z_index = 1000  # Render on top

	if is_instance_valid(target):
		global_position = target.global_position
		position.y += Y_OFFSET


func _process(_delta: float) -> void:
	_timer += _delta

	if _timer > DESTROY_TIME:
		queue_free()
		return

	if is_instance_valid(target):
		global_position = target.global_position
		position.y += Y_OFFSET
	else:
		queue_free()
		return


## Static helper to spawn reaper on a dead actor
static func spawn(dead_actor: Node2D) -> ReaperEffect:
	var reaper := ReaperEffect.new()
	reaper.setup(dead_actor)
	dead_actor.get_tree().current_scene.add_child(reaper)
	return reaper
