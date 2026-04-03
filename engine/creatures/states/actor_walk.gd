class_name ActorWalk
extends State
## Actor WALK state - replaces fsm_actor_walk from GMS2

var moving_image_speed: float = 0.3
var snared: bool = false
var moving_flag: bool = false
var changed_speed: bool = false

func enter() -> void:
	var actor := creature as Actor
	snared = actor.has_status(Constants.Status.SNARED)
	moving_flag = false
	changed_speed = false
	actor.control_is_running = false
	actor.running_steps = 0.0

	if snared:
		actor.attribute.walkSpeed = actor.walk_charging_speed
		moving_image_speed = actor.img_speed_walk_charging
		_set_walk_charge_animations(actor)
	else:
		if actor.control_run_held and not actor.overheating and not actor.has_status(Constants.Status.CONFUSED):
			actor.attribute.walkSpeed = actor.run_speed
			moving_image_speed = actor.img_speed_run
			_set_run_animations(actor)
			actor.control_is_running = true
			moving_flag = true
		else:
			actor.attribute.walkSpeed = actor.walk_speed
			moving_image_speed = actor.img_speed_walk
			_set_walk_animations(actor)

	creature.set_default_facing_index()

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	snared = actor.has_status(Constants.Status.SNARED)

	# Check if run state changed
	if not snared and actor.control_run_held != moving_flag and not actor.has_status(Constants.Status.CONFUSED):
		changed_speed = true
		moving_flag = actor.control_run_held

	if (actor.control_is_moving or actor.control_run_held) and not actor.is_movement_input_locked():
		if not snared:
			if actor.control_run_held and not actor.has_status(Constants.Status.CONFUSED):
				if changed_speed and not actor.overheating:
					moving_image_speed = actor.img_speed_run
					actor.attribute.walkSpeed = actor.run_speed
					_set_run_animations(actor)
					actor.running_steps = 0.0
					actor.control_is_running = true
					# GMS2: lockRunningDirection(state_facing) on walk→run transition
					actor.lock_running_direction(actor.facing)
			else:
				moving_image_speed = actor.img_speed_walk
				if changed_speed and not actor.overheating:
					actor.start_overheating()
					actor.attribute.walkSpeed = actor.walk_speed
					_set_walk_animations(actor)
					actor.control_is_running = false

			if changed_speed:
				creature.set_default_facing_index()
				changed_speed = false

		# Apply movement
		_apply_movement(actor, delta)

		if GameManager.ring_menu_opened:
			return
	else:
		switch_to("Stand")
		return

	if not actor.change_state:
		# Check for attack
		if actor.control_attack_pressed and not actor.is_actor_dead():
			switch_to("Attack")
			return

		# Check for menu — GMS2: ring menu can be opened while walking
		if InputManager.is_menu_pressed() and not actor.is_action_blocked():
			ActorStand._open_ring_menu(actor)

		# Actor swap (Shift key) handled in actor._physics_process()

		# GMS2: weapon gauge only charges in ChargingWeapon/Pushing states
		actor.overheat_controller(false)

	creature.animate_sprite(moving_image_speed)

	# GMS2: performRunningStepSounds - play footstep every 25 frames while running
	if actor.control_is_running and not actor.is_dead:
		actor.running_steps += delta
		if actor.running_steps > 25.0 / 60.0:
			MusicManager.play_sfx("snd_running")
			actor.running_steps = 0.0

func _apply_movement(actor: Actor, _delta: float) -> void:
	var move_dir := Vector2.ZERO

	# GMS2: CONFUSED status reverses directional controls (Up↔Down, Left↔Right)
	var confused: bool = actor.has_status(Constants.Status.CONFUSED)
	var up_held: bool = actor.control_down_held if confused else actor.control_up_held
	var down_held: bool = actor.control_up_held if confused else actor.control_down_held
	var left_held: bool = actor.control_right_held if confused else actor.control_left_held
	var right_held: bool = actor.control_left_held if confused else actor.control_right_held

	if up_held:
		move_dir.y -= 1
		actor.new_facing = Constants.Facing.UP
	if down_held:
		move_dir.y += 1
		actor.new_facing = Constants.Facing.DOWN
	if left_held:
		move_dir.x -= 1
		actor.new_facing = Constants.Facing.LEFT
	if right_held:
		move_dir.x += 1
		actor.new_facing = Constants.Facing.RIGHT

	actor.facing = actor.new_facing

	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
		# GMS2: walkingDiagonalSpeedTilt = 1.25 — reduce speed when moving diagonally
		var speed: float = actor.attribute.walkSpeed
		if move_dir.x != 0 and move_dir.y != 0:
			speed /= 1.25
		actor.velocity = move_dir * speed * 60.0
		actor.move_and_slide()

		# GMS2: playerCollisionController — push NPCs and mobs on collision
		for i in range(actor.get_slide_collision_count()):
			var col := actor.get_slide_collision(i)
			if not col:
				continue
			var collider := col.get_collider()
			if collider is NPC:
				var npc: NPC = collider as NPC
				if npc.is_pushable:
					npc.velocity = move_dir * actor.attribute.walkSpeed * 60.0
					npc.move_and_slide()
			elif collider is Mob:
				var mob: Mob = collider as Mob
				if mob.pushable:
					mob.velocity = move_dir * actor.attribute.walkSpeed * 60.0
					mob.move_and_slide()

func _set_walk_animations(actor: Actor) -> void:
	creature.set_default_facing_animations(
		actor.spr_walk_up_ini, actor.spr_walk_right_ini,
		actor.spr_walk_down_ini, actor.spr_walk_left_ini,
		actor.spr_walk_up_end, actor.spr_walk_right_end,
		actor.spr_walk_down_end, actor.spr_walk_left_end
	)

func _set_run_animations(actor: Actor) -> void:
	creature.set_default_facing_animations(
		actor.spr_run_up_ini, actor.spr_run_right_ini,
		actor.spr_run_down_ini, actor.spr_run_left_ini,
		actor.spr_run_up_end, actor.spr_run_right_end,
		actor.spr_run_down_end, actor.spr_run_left_end
	)

func _set_walk_charge_animations(actor: Actor) -> void:
	creature.set_default_facing_animations(
		actor.spr_walk_charge_up_ini, actor.spr_walk_charge_right_ini,
		actor.spr_walk_charge_down_ini, actor.spr_walk_charge_left_ini,
		actor.spr_walk_charge_up_end, actor.spr_walk_charge_right_end,
		actor.spr_walk_charge_down_end, actor.spr_walk_charge_left_end
	)
