class_name RabiteAttack
extends State
## Rabite ATTACK state - replaces fsm_rabite_attack from GMS2
## Multi-phase attack: select position → approach → bite OR jump attack
## Uses damage-on-collision during attack phases.

enum Phase { SELECT_POSITION, GO_POSITION, ATTACK_BITE, ATTACK_JUMP }
enum AttackKind { BITE, JUMP }

var phase: int = Phase.SELECT_POSITION
var target: Node = null
var attack_kind: int = AttackKind.BITE
var move_target: Vector2 = Vector2.ZERO
var attack_started_time: float = 0.0

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return

	target = mob.current_target
	if not is_instance_valid(target) or target.is_dead:
		switch_to("RabiteWander")
		return

	# Bosses always jump; non-bosses random 50/50
	if mob.creature_is_boss:
		attack_kind = AttackKind.JUMP
	else:
		attack_kind = AttackKind.BITE if randf() >= 0.5 else AttackKind.JUMP

	phase = Phase.SELECT_POSITION
	attack_started_time = 0.0
	creature.damage_on_collision = false

func execute(_delta: float) -> void:
	var mob := creature as Mob
	if not mob:
		return

	# Check damage stack
	if creature.damage_stack.size() > 0:
		creature.damage_on_collision = false
		switch_to("Hit")
		return

	# Target dead
	if not is_instance_valid(target) or target.is_dead:
		creature.damage_on_collision = false
		if mob.creature_is_boss:
			var new_target := GameManager.get_random_alive_player()
			if new_target:
				mob.current_target = new_target
				switch_to("RabiteChase")
			else:
				switch_to("RabiteWander")
		else:
			switch_to("RabiteWander")
		return

	match phase:
		Phase.SELECT_POSITION:
			_phase_select_position(mob)

		Phase.GO_POSITION:
			_phase_go_position(mob)

		Phase.ATTACK_BITE:
			_phase_attack_bite(mob)

		Phase.ATTACK_JUMP:
			_phase_attack_jump(mob)

func exit() -> void:
	creature.velocity = Vector2.ZERO
	creature.damage_on_collision = false

# --- Phases ---

func _phase_select_position(mob: Mob) -> void:
	## Pick approach position: nearest cardinal point around target
	var best_pos := _get_shortest_side(target.global_position,
		mob.attack_distance_bite if attack_kind == AttackKind.BITE else mob.attack_distance_jump)
	move_target = best_pos

	# Start hop toward approach position
	_set_walk_jump_anim(mob)
	var dir: Vector2 = (move_target - creature.global_position).normalized()
	creature.facing = creature.get_facing_from_direction(dir)
	creature.velocity = dir * randf_range(0.2, 1.0) * 60.0
	# Positive z_velocity = going up
	if creature.z_height <= 0:
		creature.z_velocity = 2.5
	phase = Phase.GO_POSITION
	attack_started_time = get_timer()

func _phase_go_position(mob: Mob) -> void:
	## Move toward approach position, then execute attack
	(creature as CharacterBody2D).move_and_slide()
	creature.animate_sprite()

	# Wait for landing
	if creature.z_height > 0:
		return

	creature.velocity = Vector2.ZERO
	var dist_to_target: float = creature.global_position.distance_to(target.global_position)

	# If bite took too long (>180 frames = 3.0s), escalate to jump
	if attack_kind == AttackKind.BITE and (get_timer() - attack_started_time) > 180 / 60.0:
		attack_kind = AttackKind.JUMP
		phase = Phase.SELECT_POSITION
		return

	# Check if close enough to attack
	var attack_range := mob.attack_distance_bite if attack_kind == AttackKind.BITE else mob.attack_distance_jump
	if dist_to_target <= attack_range or mob.creature_is_boss:
		mob.look_at_target(target)
		if attack_kind == AttackKind.BITE:
			_start_bite(mob)
		else:
			_start_jump(mob)
	else:
		# Not close enough, reposition
		phase = Phase.SELECT_POSITION

func _start_bite(mob: Mob) -> void:
	## Initiate bite attack (GMS2: PHASE_ATTACK_BITE)
	creature.set_default_facing_animations(
		mob.spr_attack_up_ini, mob.spr_attack_right_ini,
		mob.spr_attack_down_ini, mob.spr_attack_left_ini,
		mob.spr_attack_up_end, mob.spr_attack_right_end,
		mob.spr_attack_down_end, mob.spr_attack_left_end
	)
	creature.image_speed = 0.1
	creature.set_default_facing_index()
	creature.damage_on_collision = true
	MusicManager.play_sfx("snd_bite")
	phase = Phase.ATTACK_BITE

func _start_jump(mob: Mob) -> void:
	## Initiate jump attack (GMS2: PHASE_ATTACK_JUMP)
	creature.set_default_facing_animations(
		mob.spr_attack2_up_ini, mob.spr_attack2_right_ini,
		mob.spr_attack2_down_ini, mob.spr_attack2_left_ini,
		mob.spr_attack2_up_end, mob.spr_attack2_right_end,
		mob.spr_attack2_down_end, mob.spr_attack2_left_end
	)
	creature.image_speed = 0.2
	creature.set_default_facing_index()
	creature.damage_on_collision = true
	# Jump toward target (positive z_velocity = going up)
	creature.z_velocity = 2.5
	var dir: Vector2 = (target.global_position - creature.global_position).normalized()
	creature.velocity = dir * mob.jump_attack_speed * 60.0
	MusicManager.play_sfx("snd_rabiteJump")
	phase = Phase.ATTACK_JUMP

func _phase_attack_bite(mob: Mob) -> void:
	## Bite attack: deal contact damage, wait for animation end
	creature.animate_sprite()
	# Apply damage via perform_attack if in range
	if get_timer() > 15 / 60.0 and creature.damage_on_collision:
		if is_instance_valid(target):
			var dist: float = creature.global_position.distance_to(target.global_position)
			if dist < mob.attack_distance_bite:
				DamageCalculator.perform_attack(target, creature, Constants.AttackType.WEAPON)
		creature.damage_on_collision = false

	# Animation done
	if get_timer() > 30 / 60.0:
		_finish_attack(mob)

func _phase_attack_jump(mob: Mob) -> void:
	## Jump attack: move through air, deal damage on landing
	(creature as CharacterBody2D).move_and_slide()
	creature.animate_sprite()

	# Wait for landing (z_velocity == 0 after _update_z_axis resets on ground)
	if creature.z_height <= 0 and creature.z_velocity == 0 and get_timer() > 10 / 60.0:
		creature.velocity = Vector2.ZERO
		# Deal damage on landing
		if creature.damage_on_collision and is_instance_valid(target):
			var dist: float = creature.global_position.distance_to(target.global_position)
			if dist < mob.attack_distance_jump * 0.5:
				DamageCalculator.perform_attack(target, creature, Constants.AttackType.WEAPON)
		creature.damage_on_collision = false
		_finish_attack(mob)

func _finish_attack(mob: Mob) -> void:
	if mob.creature_is_boss:
		var new_target := GameManager.get_random_alive_player()
		if new_target:
			mob.current_target = new_target
			# Rabbigte uses its own chase state with bounce angle + castRandomSkill
			var chase_state: String = "RabbigteChase" if mob.skill_list.size() > 0 else "RabiteChase"
			switch_to(chase_state)
		else:
			var wander_state: String = "RabbigteWander" if mob.skill_list.size() > 0 else "RabiteWander"
			switch_to(wander_state)
	else:
		switch_to("RabiteWander")

# --- Helpers ---

func _get_shortest_side(target_pos: Vector2, radius: float) -> Vector2:
	## GMS2: getShortestSideOfTarget - find nearest cardinal approach point
	var candidates: Array[Vector2] = [
		target_pos + Vector2(0, -radius),   # Above
		target_pos + Vector2(radius, 0),    # Right
		target_pos + Vector2(0, radius),    # Below
		target_pos + Vector2(-radius, 0),   # Left
	]
	var best: Vector2 = target_pos
	var best_dist: float = INF
	for pos in candidates:
		var d: float = creature.global_position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = pos
	return best

func _set_walk_jump_anim(mob: Mob) -> void:
	creature.set_default_facing_animations(
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end
	)
