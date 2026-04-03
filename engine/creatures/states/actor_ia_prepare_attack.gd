class_name ActorIAPrepareAttack
extends State
## AI PREPARE ATTACK state - replaces fsm_ia_prepare_attack from GMS2
## Three modes: WAIT (check if target being attacked), ADVANCE (move toward target),
## CHECK_ATTACK (verify attack range and commit to attack)
## GMS2: uses motionPlannerController for pathing, drawHitboxAttack for hit simulation

enum Mode { WAIT, ADVANCE, CHECK_ATTACK }

var target: Node = null
var mode: int = Mode.WAIT
var timer_moving: float = 0.0
var timer_limit_moving: float = 0.167
var timer_check_attacked: float = 0.0
var timer_limit_check_attacked: float = 0.25
var timer_force_attack: float = 0.0
var timer_limit_force_attack: float = 0.5
var distance_to_guard: float = 20.0
var movement_speed: float = 1.5
var force_attack: bool = false


func enter() -> void:
	var actor := creature as Actor
	creature.velocity = Vector2.ZERO
	mode = Mode.WAIT
	timer_moving = 0.0
	timer_check_attacked = 0.0
	timer_force_attack = 0.0
	timer_limit_moving = randf_range(8.0 / 60.0, 15.0 / 60.0)
	timer_limit_check_attacked = randf_range(10.0 / 60.0, 20.0 / 60.0)
	timer_limit_force_attack = 0.5
	movement_speed = 1.5

	# Get target from state var
	target = state_machine.get_state_var(0, null)
	force_attack = state_machine.get_state_var(1, false)

	if not is_instance_valid(target) or target.is_dead:
		creature.attacking = null
		switch_to("IAGuard")
		return

	# Set attacking for target conflict detection
	creature.attacking = target

	_look_at_target()

	# Set charge walk animation
	if actor:
		creature.set_default_facing_animations(
			actor.spr_walk_charge_up_ini, actor.spr_walk_charge_right_ini,
			actor.spr_walk_charge_down_ini, actor.spr_walk_charge_left_ini,
			actor.spr_walk_charge_up_end, actor.spr_walk_charge_right_end,
			actor.spr_walk_charge_down_end, actor.spr_walk_charge_left_end
		)

	# GMS2: distanceToGuardTarget = weaponRadius[weaponId] (full radius for guard),
	# but the advance→CHECK_ATTACK cutoff uses weaponRadius/2 (line 185 in GMS2).
	# CHECK_ATTACK then multiplies by 1.5 for the final commit check.
	if actor:
		distance_to_guard = actor.weapon_radius / 2.0
		if distance_to_guard < 15.0:
			distance_to_guard = 15.0
	else:
		distance_to_guard = 20.0

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# GMS2: AI movement is blocked during cutscenes (lock_all_players)
	if actor.movement_input_locked:
		actor.velocity = Vector2.ZERO
		return

	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	actor.overheat_controller(false)

	# GMS2: AI cannot attack while overheating - return to guard and wait
	if actor.overheating:
		creature.attacking = null
		switch_to("IAGuard")
		return

	# Check target validity
	if not is_instance_valid(target) or target.is_dead:
		creature.attacking = null
		switch_to("IAGuard")
		return

	if mode == Mode.WAIT:
		timer_check_attacked += delta
		timer_force_attack += delta

		# GMS2: isTargetBeingAttacked(target) — wait if any ally attacking same target
		if timer_check_attacked > timer_limit_check_attacked:
			timer_check_attacked = 0.0

			if _is_target_being_attacked():
				timer_force_attack += delta
			else:
				mode = Mode.ADVANCE
				_look_at_target()

		# Force advance after timeout
		if timer_force_attack > timer_limit_force_attack:
			mode = Mode.ADVANCE
			_look_at_target()

	elif mode == Mode.ADVANCE:
		timer_moving += delta

		# Direct movement toward target (GMS2: planToTarget replans every frame)
		var dist: float = creature.global_position.distance_to(target.global_position)
		if dist > distance_to_guard:
			var dir: Vector2 = (target.global_position - creature.global_position).normalized()
			var speed: float = movement_speed
			# GMS2: walkingDiagonalSpeedTilt = 1.25
			if dir.x != 0 and dir.y != 0:
				speed /= 1.25
			creature.facing = creature.get_facing_from_direction(dir)
			creature.velocity = dir * speed * 60.0
			(creature as CharacterBody2D).move_and_slide()
			creature.animate_sprite(actor.img_speed_run)
		else:
			# Close enough - check attack
			creature.velocity = Vector2.ZERO
			_look_at_target()
			mode = Mode.CHECK_ATTACK

		# Stuck detection (GMS2: 120 frame timeout = 2.0s)
		if timer_moving > 2.0:
			creature.attacking = null
			actor.change_state_stand_dead()
			return

		if force_attack:
			mode = Mode.CHECK_ATTACK

	elif mode == Mode.CHECK_ATTACK:
		_look_at_target()

		# Check if we're in range (GMS2: drawHitboxAttack simulation)
		var dist: float = creature.global_position.distance_to(target.global_position)
		if dist <= distance_to_guard * 1.5 or force_attack:
			# Commit to attack
			state_machine.set_state_var(0, target)
			switch_to("IAAttack")
		else:
			# Not in range - go back to guard target
			state_machine.set_state_var(0, target)
			switch_to("IAGuardTarget")

func exit() -> void:
	creature.velocity = Vector2.ZERO
	var actor := creature as Actor
	if actor:
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)

func _look_at_target() -> void:
	if is_instance_valid(target):
		var dir: Vector2 = (target.global_position - creature.global_position)
		if dir.length() > 1.0:
			creature.facing = creature.get_facing_from_direction(dir)

func _is_target_being_attacked() -> bool:
	## GMS2: isTargetBeingAttacked(target) — checks if ANY ally is attacking this target
	for player in GameManager.get_alive_players():
		if player == creature:
			continue
		if player is Creature:
			var ally: Creature = player as Creature
			if is_instance_valid(ally.attacking) and ally.attacking == target:
				return true
	return false
