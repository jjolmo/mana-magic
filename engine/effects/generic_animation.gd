class_name GenericAnimation
extends Node2D
## One-shot sprite animation that plays and auto-destroys.
## Replaces oAnimator / go_animation from GMS2.
## Usage: GenericAnimation.play_at(parent, position, texture, columns, fw, fh, start, end, speed)

var sprite: Sprite2D
var anim_texture: Texture2D
var columns: int = 1
var frame_width: int = 32
var frame_height: int = 32
var frame_start: int = 0
var frame_end: int = 0
var current_frame: int = 0
var anim_speed: float = 0.3
var _accumulator: float = 0.0
var loops: int = 1
var _current_loop: int = 0
## GMS2: attachToObject - follow another node with offset
var attach_to: Node2D = null
var attach_x_offset: float = 0.0
var attach_y_offset: float = 0.0

## GMS2: destroyOnTime - destroy after N seconds regardless of animation
## -1 = destroy when animation ends (default loop behavior)
## -2 = never auto-destroy (manual control)
## N > 0 = destroy after N seconds (converted from 60fps frames)
var destroy_on_time: float = -1.0
var _destroy_timer: float = 0.0

## Sprite origin offset (GMS2 sprites have custom origins)
var sprite_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# GMS2: created on lyr_animations (depth -14000), always above creatures
	z_index = 1000
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.offset = sprite_offset
	add_child(sprite)
	if anim_texture:
		sprite.texture = anim_texture
		sprite.region_enabled = true
		current_frame = frame_start
		_update_region()


func _process(delta: float) -> void:
	# Follow attached object
	if attach_to:
		if is_instance_valid(attach_to):
			global_position = attach_to.global_position + Vector2(attach_x_offset, attach_y_offset)
		else:
			queue_free()
			return

	# GMS2: ring menu pauses all object Step events — freeze timer + animation
	if GameManager.ring_menu_opened:
		return

	# GMS2: destroyOnTime - fixed-duration timer independent of animation
	if destroy_on_time > 0.0:
		_destroy_timer += delta
		if _destroy_timer >= destroy_on_time:
			queue_free()
			return

	_accumulator += anim_speed * delta * 60.0
	if _accumulator >= 1.0:
		_accumulator -= 1.0
		current_frame += 1
		if current_frame > frame_end:
			if destroy_on_time < 0.0 and destroy_on_time > -1.5:
				# Default (-1): destroy when animation completes (respect loops)
				_current_loop += 1
				if _current_loop >= loops:
					queue_free()
					return
			# If destroy_on_time > 0 or -2, loop animation
			current_frame = frame_start
		_update_region()


func _update_region() -> void:
	if not sprite or not anim_texture:
		return
	var col: int = current_frame % columns
	@warning_ignore("INTEGER_DIVISION")
	var row: int = current_frame / columns
	sprite.region_rect = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)


## Static helper: create and play a one-shot animation at a position
static func play_at(parent: Node, pos: Vector2, texture: Texture2D,
		cols: int, fw: int, fh: int, start: int, end: int,
		speed: float = 0.3, loop_count: int = 1) -> GenericAnimation:
	var anim := GenericAnimation.new()
	anim.anim_texture = texture
	anim.columns = cols
	anim.frame_width = fw
	anim.frame_height = fh
	anim.frame_start = start
	anim.frame_end = end
	anim.anim_speed = speed
	anim.loops = loop_count
	anim.global_position = pos
	parent.add_child(anim)
	return anim

## Static helper: create an animation attached to an object with offset
## GMS2: instance_create_pre(x, y, layer, oGenericAnimation, sprite, image_speed,
##        destroyOnTime, image_index, attachToObject, attachXOffset, attachYOffset)
static func play_attached(parent: Node, target: Node2D, texture: Texture2D,
		cols: int, fw: int, fh: int, start: int, end: int,
		speed: float = 0.3, time_limit: int = -1,
		x_offset: float = 0.0, y_offset: float = 0.0,
		offset: Vector2 = Vector2.ZERO) -> GenericAnimation:
	var anim := GenericAnimation.new()
	anim.anim_texture = texture
	anim.columns = cols
	anim.frame_width = fw
	anim.frame_height = fh
	anim.frame_start = start
	anim.frame_end = end
	anim.anim_speed = speed
	anim.destroy_on_time = time_limit if time_limit < 0 else time_limit / 60.0
	anim.attach_to = target
	anim.attach_x_offset = x_offset
	anim.attach_y_offset = y_offset
	anim.sprite_offset = offset
	if time_limit == -2 or time_limit > 0.0:
		anim.loops = 9999  # Loop until timer/manual destroy
	anim.global_position = target.global_position + Vector2(x_offset, y_offset)
	parent.add_child(anim)
	return anim
