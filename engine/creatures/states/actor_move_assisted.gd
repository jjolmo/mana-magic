class_name ActorMoveAssisted
extends State
## Actor MOVE ASSISTED state - replaces fsm_move_assisted from GMS2
## Scripted movement from a queue of (direction, distance, speed) triples.
## Used for cutscene/scripted actor movement.

var move_direction: int = 0
var move_distance: float = 0.0
var move_speed: float = 0.0
var finished_move: bool = true
var distance_reached: float = 0.0
var distance_top: float = 0.0

func enter() -> void:
	var actor := creature as Actor
	finished_move = true
	distance_reached = 0.0

	# Set walk animation
	creature.set_default_facing_animations(
		actor.spr_walk_up_ini, actor.spr_walk_right_ini,
		actor.spr_walk_down_ini, actor.spr_walk_left_ini,
		actor.spr_walk_up_end, actor.spr_walk_right_end,
		actor.spr_walk_down_end, actor.spr_walk_left_end
	)
	creature.set_default_facing_index()

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	if actor.move_queue.size() > 0 or not finished_move:
		if finished_move:
			# Dequeue next movement command (direction, distance, speed)
			if actor.move_queue.size() >= 3:
				move_direction = actor.move_queue.pop_front()
				move_distance = actor.move_queue.pop_front()
				move_speed = actor.move_queue.pop_front()
			else:
				actor.move_queue.clear()
				switch_to("Stand")
				return

			finished_move = false
			distance_reached = 0.0
			distance_top = move_distance / maxf(0.1, move_speed)

			creature.image_speed = actor.img_speed_walk
			creature.facing = move_direction
			creature.set_default_facing_index()

		# Continue moving
		if distance_reached < distance_top:
			var dir := Vector2.ZERO
			match move_direction:
				Constants.Facing.UP: dir = Vector2.UP
				Constants.Facing.RIGHT: dir = Vector2.RIGHT
				Constants.Facing.DOWN: dir = Vector2.DOWN
				Constants.Facing.LEFT: dir = Vector2.LEFT

			creature.velocity = dir * move_speed * 60.0
			(creature as CharacterBody2D).move_and_slide()
			distance_reached += delta
		else:
			finished_move = true

		creature.animate_sprite()
	else:
		# No more movements in queue
		creature.velocity = Vector2.ZERO
		switch_to("Stand")

func exit() -> void:
	creature.velocity = Vector2.ZERO
