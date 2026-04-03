class_name RabiteChase
extends State
## Rabite CHASE state - replaces fsm_rabite_followActor from GMS2
## Hops toward target player. Transitions to Attack when close, Avoid on low HP.
## GMS2: fsm_bounce() runs EVERY frame — rabite bounces even while waiting.
## GMS2: GO_POSITION stops on landing (z >= 0), NOT on distance limit.

enum Phase { WAIT, SELECT_POSITION, GO_POSITION }

var phase: int = Phase.WAIT
var waiting_timer: float = 0.0
var waiting_timer_limit: float = 1.0  # 60 / 60.0 = 1.0 second
var target: Node = null
var distance_to_attack: float = 50.0
var bounce_value: float = 2.5

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return

	target = mob.current_target
	if not is_instance_valid(target):
		target = mob.find_nearest_player()
	if not is_instance_valid(target):
		switch_to("RabiteWander")
		return

	phase = Phase.WAIT
	waiting_timer = 0.0
	distance_to_attack = mob.attack_distance_bite if not mob.creature_is_boss else mob.attack_distance_jump
	_set_walk_jump_anim(mob)
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

	# Target dead → find new target or wander
	if not is_instance_valid(target) or target.is_dead:
		target = mob.find_nearest_player()
		if not is_instance_valid(target):
			switch_to("RabiteWander")
			return

	match phase:
		Phase.WAIT:
			creature.velocity = Vector2.ZERO
			# GMS2: animation continues during WAIT
			creature.animate_sprite()
			waiting_timer += delta
			if waiting_timer > waiting_timer_limit:
				# GMS2: waitingTimer is NOT reset here — only on state entry.
				# After the initial 60-frame wait, the rabite hops continuously.
				# Low HP → avoid
				if creature.attribute.hpPercent < 20.0:
					switch_to("RabiteAvoid")
					return
				phase = Phase.SELECT_POSITION

		Phase.SELECT_POSITION:
			_set_walk_jump_anim(mob)
			# Hop toward target (GMS2: move_towards_point to target)
			var dir: Vector2 = (target.global_position - creature.global_position).normalized()
			creature.facing = creature.get_facing_from_direction(dir)
			creature.velocity = dir * randf_range(0.2, 1.0) * 60.0
			phase = Phase.GO_POSITION

		Phase.GO_POSITION:
			(creature as CharacterBody2D).move_and_slide()
			creature.animate_sprite()
			# Check distance to target while hopping → attack if close
			var dist: float = creature.global_position.distance_to(target.global_position)
			if dist < distance_to_attack:
				mob.current_target = target
				switch_to("RabiteAttack")
				return
			# GMS2: if (z >= 0) { speed = 0; phase = PHASE_WAIT; }
			# Stop ONLY on landing — no distance limit.
			if creature.z_height <= 0 and creature.z_velocity == 0:
				creature.velocity = Vector2.ZERO
				phase = Phase.WAIT

	# GMS2: fsm_bounce() runs AFTER phase logic every frame
	_do_bounce()

	# Timeout: give up after a long chase → back to wander
	if get_timer() > 600 / 60.0:
		switch_to("RabiteWander")

func exit() -> void:
	creature.velocity = Vector2.ZERO

func _set_walk_jump_anim(mob: Mob) -> void:
	creature.set_default_facing_animations(
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end
	)

func _do_bounce() -> void:
	## Continuous bounce on ground (GMS2: fsm_bounce, positive z_velocity = up)
	## GMS2 uses fixed bounceValue for consistent rhythmic hop
	if creature.z_height <= 0 and creature.z_velocity == 0:
		creature.z_velocity = bounce_value
