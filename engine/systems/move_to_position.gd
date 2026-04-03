class_name MoveToPosition
extends Node
## Scripted movement controller - replaces oMoveToPosition from GMS2
## Moves a creature toward a target position with walk/run animation.
## Returns true from is_finished when the destination is reached.
## Call go() each frame from a cutscene step; it returns true when done.

## Active movement controllers (one per creature)
static var _active_controllers: Dictionary = {}  # creature instance_id → MoveToPosition

var creature: Creature = null
var target_x: float = 0.0
var target_y: float = 0.0
var running: bool = false
var check_collisions: bool = true
var keep_state: bool = false
var lock_facing: bool = false  # GMS2: backwards walk — don't override creature facing
var finished: bool = false

var _initialized: bool = false
var _direction_change_timer: float = 0.0
const DIRECTION_CHANGE_LIMIT: float = 15.0 / 60.0  # GMS2: changeFaceDirection_timerLimit


func _process(delta: float) -> void:
	if finished or not is_instance_valid(creature):
		return

	if creature.paused:
		creature.velocity = Vector2.ZERO
		return

	# Initialize on first active frame
	if not _initialized:
		_initialize()
		_initialized = true

	# Check if destination reached (floor comparison like GMS2)
	var cx: float = floor(creature.global_position.x)
	var cy: float = floor(creature.global_position.y)
	if cx == floor(target_x) and cy == floor(target_y):
		_arrive()
		return

	# Move toward target
	var dir_vec := Vector2(target_x - creature.global_position.x, target_y - creature.global_position.y)
	var dist: float = dir_vec.length()
	var speed: float = creature.attribute.runMax if running else creature.attribute.walkMax

	if dist < speed * delta * 60.0:
		creature.global_position = Vector2(target_x, target_y)
		_arrive()
		return

	dir_vec = dir_vec.normalized()
	creature.velocity = dir_vec * speed * 60.0  # Convert to pixels/second for move_and_slide

	# Update facing direction (throttled like GMS2, skip if lock_facing)
	if not lock_facing:
		_direction_change_timer += delta
		if _direction_change_timer >= DIRECTION_CHANGE_LIMIT:
			_direction_change_timer = 0.0
			creature.facing = _get_facing_from_velocity(dir_vec)
			creature.new_facing = creature.facing

	if check_collisions:
		var motion := creature.velocity * delta
		var collision := creature.move_and_collide(motion)
		if collision:
			var remainder := motion.slide(collision.get_normal())
			if remainder.length_squared() > 0.01:
				creature.move_and_collide(remainder)
			creature.velocity = creature.velocity.slide(collision.get_normal())
	else:
		creature.global_position += dir_vec * speed * delta * 60.0

	# Animate (if not keeping external state)
	if not keep_state:
		creature.animate_sprite()


func _initialize() -> void:
	## Set up animation and speed on first frame (GMS2: timer==1 in oMoveToPosition)
	if not keep_state and creature.has_method("state_machine"):
		# Switch creature to animation state if possible
		pass  # Creature's state doesn't need to change for movement

	# Set initial facing toward target (skip if lock_facing for backwards walk)
	if not lock_facing:
		var dir_to_target := Vector2(target_x - creature.global_position.x, target_y - creature.global_position.y)
		if dir_to_target.length() > 0.5:
			creature.facing = _get_facing_from_velocity(dir_to_target.normalized())
			creature.new_facing = creature.facing

	# Set walk/run animation parameters (frame ranges + speed)
	# Without this, spr_*_ini/end may still be 0→0 (default) if the creature
	# never entered the Walk state (e.g. during cutscenes where MoveToPosition
	# drives movement directly). That causes animate_sprite() to show a single
	# frame — the character slides without animating.
	if not keep_state:
		if creature is Actor:
			var actor := creature as Actor
			if running:
				creature.set_default_facing_animations(
					actor.spr_run_up_ini, actor.spr_run_right_ini,
					actor.spr_run_down_ini, actor.spr_run_left_ini,
					actor.spr_run_up_end, actor.spr_run_right_end,
					actor.spr_run_down_end, actor.spr_run_left_end
				)
			else:
				creature.set_default_facing_animations(
					actor.spr_walk_up_ini, actor.spr_walk_right_ini,
					actor.spr_walk_down_ini, actor.spr_walk_left_ini,
					actor.spr_walk_up_end, actor.spr_walk_right_end,
					actor.spr_walk_down_end, actor.spr_walk_left_end
				)
		if running and "img_speed_run" in creature:
			creature.image_speed = creature.img_speed_run
		elif "img_speed_walk" in creature:
			creature.image_speed = creature.img_speed_walk
		else:
			creature.image_speed = 0.1


func _arrive() -> void:
	## Destination reached
	finished = true
	creature.velocity = Vector2.ZERO
	if not keep_state:
		if "img_speed_stand" in creature:
			creature.image_speed = creature.img_speed_stand
		else:
			creature.image_speed = 0
		# Set proper stand frame so the creature doesn't freeze on a mid-walk frame
		creature.set_facing_frame(
			creature.spr_stand_up, creature.spr_stand_right,
			creature.spr_stand_down, creature.spr_stand_left
		)
	# Remove from active controllers
	if creature and _active_controllers.has(creature.get_instance_id()):
		_active_controllers.erase(creature.get_instance_id())
	queue_free()


func _get_facing_from_velocity(dir: Vector2) -> int:
	if abs(dir.x) >= abs(dir.y):
		return Constants.Facing.RIGHT if dir.x > 0 else Constants.Facing.LEFT
	else:
		return Constants.Facing.DOWN if dir.y > 0 else Constants.Facing.UP


## Static API: call each frame from cutscene, returns true when destination reached
## This is the Godot equivalent of GMS2's go_moveToPosition() function
static func go(p_creature: Creature, x_pos: float, y_pos: float, p_running: bool = false, p_check_collisions: bool = true, p_keep_state: bool = false, p_lock_facing: bool = false) -> bool:
	if not is_instance_valid(p_creature):
		return true

	var cid: int = p_creature.get_instance_id()

	# Check if already at destination
	if floor(p_creature.global_position.x) == floor(x_pos) and floor(p_creature.global_position.y) == floor(y_pos):
		# Clean up existing controller if any
		if _active_controllers.has(cid):
			var ctrl: MoveToPosition = _active_controllers[cid]
			if is_instance_valid(ctrl):
				ctrl._arrive()
			_active_controllers.erase(cid)
		return true

	# Check if controller already exists for this creature
	if _active_controllers.has(cid):
		var ctrl: MoveToPosition = _active_controllers[cid]
		if is_instance_valid(ctrl):
			if ctrl.finished:
				_active_controllers.erase(cid)
				return true
			return false
		else:
			_active_controllers.erase(cid)

	# Create new controller
	var ctrl := MoveToPosition.new()
	ctrl.creature = p_creature
	ctrl.target_x = x_pos
	ctrl.target_y = y_pos
	ctrl.running = p_running
	ctrl.check_collisions = p_check_collisions
	ctrl.keep_state = p_keep_state
	ctrl.lock_facing = p_lock_facing
	_active_controllers[cid] = ctrl
	p_creature.get_tree().current_scene.add_child(ctrl)

	return false


## Static helper: check if a creature has an active (unfinished) movement controller.
## Use from cutscene steps to wait for a walk/run to complete before issuing a new one
## (GMS2 equivalent: !instance_exists(animator)).
static func is_active(p_creature: Creature) -> bool:
	if not is_instance_valid(p_creature):
		return false
	var cid: int = p_creature.get_instance_id()
	if _active_controllers.has(cid):
		var ctrl: MoveToPosition = _active_controllers[cid]
		return is_instance_valid(ctrl) and not ctrl.finished
	return false


## Static helper: stop all active movement for a creature (GMS2: stopMovementMotion)
static func stop(p_creature: Creature) -> void:
	if not is_instance_valid(p_creature):
		return
	var cid: int = p_creature.get_instance_id()
	if _active_controllers.has(cid):
		var ctrl: MoveToPosition = _active_controllers[cid]
		if is_instance_valid(ctrl):
			ctrl.creature.velocity = Vector2.ZERO
			ctrl.queue_free()
		_active_controllers.erase(cid)
