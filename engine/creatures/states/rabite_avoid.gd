class_name RabiteAvoid
extends State
## Rabite AVOID state - replaces fsm_rabite_avoid from GMS2
## Fear/flee behavior when HP < 20%. Hops away from nearest player.
## If player is very close (<45px), cowers in place instead of fleeing.
## GMS2: fsm_bounce() runs EVERY frame — rabite bounces even while cowering.
## GMS2: GO_POSITION stops on landing (z >= 0), NOT on distance limit.

enum Phase { WAIT, SELECT_POSITION, GO_POSITION }

var phase: int = Phase.WAIT
var waiting_timer: float = 0.0
var waiting_timer_limit: float = 1.0  # 60 / 60.0
var hiding_distance: float = 45.0
var move_speed_limit: float = 1.0
var bounce_value: float = 2.5
var target: Node = null

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return
	phase = Phase.WAIT
	waiting_timer = 0.0
	target = mob.find_nearest_player()
	creature.image_speed = mob.img_speed_walk
	creature.velocity = Vector2.ZERO

func execute(delta: float) -> void:
	var mob := creature as Mob
	if not mob:
		return

	# Check damage stack
	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	if mob.is_movement_blocked():
		creature.velocity = Vector2.ZERO
		return

	# HP recovered → go back to wandering
	if creature.attribute.hpPercent >= 30.0:
		switch_to("RabiteWander")
		return

	match phase:
		Phase.WAIT:
			creature.velocity = Vector2.ZERO
			creature.animate_sprite()
			waiting_timer += delta

			# Re-acquire nearest target
			target = mob.find_nearest_player()

			if waiting_timer > waiting_timer_limit:
				# GMS2: waitingTimer is NOT reset here — only on state entry.
				# After the initial 60-frame wait, the rabite hops continuously.
				if is_instance_valid(target):
					var dist: float = creature.global_position.distance_to(target.global_position)
					if dist <= hiding_distance:
						# Too close: cower in place (GMS2: hurt frame, image_speed=0)
						creature.set_frame(mob.spr_hit_down)
						creature.image_speed = 0
					else:
						# Far enough: flee
						phase = Phase.SELECT_POSITION
				else:
					phase = Phase.SELECT_POSITION

		Phase.SELECT_POSITION:
			target = mob.find_nearest_player()
			if not is_instance_valid(target):
				switch_to("RabiteWander")
				return

			# Hop AWAY from target (opposite direction)
			var dir_away: Vector2 = (creature.global_position - target.global_position).normalized()
			creature.facing = creature.get_facing_from_direction(dir_away)

			# Set walk-jump animation
			creature.set_default_facing_animations(
				mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
				mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
				mob.spr_walk_jump_end, mob.spr_walk_jump_end,
				mob.spr_walk_jump_end, mob.spr_walk_jump_end
			)
			creature.image_speed = mob.img_speed_walk

			creature.velocity = dir_away * randf_range(0.2, move_speed_limit) * 60.0
			phase = Phase.GO_POSITION

		Phase.GO_POSITION:
			(creature as CharacterBody2D).move_and_slide()
			creature.animate_sprite()
			# GMS2: if (z >= 0) { speed = 0; phase = PHASE_WAIT; }
			# Stop ONLY on landing — no distance limit.
			if creature.z_height <= 0 and creature.z_velocity == 0:
				creature.velocity = Vector2.ZERO
				phase = Phase.WAIT

	# GMS2: fsm_bounce() runs AFTER phase logic every frame
	_do_bounce()

func exit() -> void:
	creature.velocity = Vector2.ZERO

func _do_bounce() -> void:
	## Continuous bounce on ground (GMS2: fsm_bounce, positive z_velocity = up)
	## GMS2 uses fixed bounceValue for consistent rhythmic hop
	if creature.z_height <= 0 and creature.z_velocity == 0:
		creature.z_velocity = bounce_value
