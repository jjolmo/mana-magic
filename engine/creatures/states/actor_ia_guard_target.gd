class_name ActorIAGuardTarget
extends State
## AI GUARD TARGET state - replaces fsm_ia_guard_target from GMS2
## AI has spotted a target and maintains guard distance. Approaches or evades.
## Transitions to IAPrepareAttack when ready, IAGuard if target lost.
## GMS2: distanceToGuardTarget based on weaponRadius + strategyPatternApproachKeepAway

var target: Node = null
var evading: bool = false
var timer_try_attack: float = 0.0
var timer_limit_try_attack: float = 1.0
var timer_check_enemy: float = 0.0
var timer_limit_check_enemy: float = 1.0
var distance_to_guard: float = 40.0
var start_wait: float = 0.333
var check_new_target: bool = false  # GMS2: evasive pattern (strategy 4) switches targets
var timer_avoid: float = 0.0  # GMS2: timerAvoid for hop-skip evade ("trompicones")
var evade_direction: Vector2 = Vector2.ZERO  # Saved evade direction
var timer_check_leader_guard: float = 0.0  # GMS2: timer_checkLeaderGuard

# GMS2 constants
const MIN_GUARD_DISTANCE: float = 80.0  # Minimum distance to keep from target after attacking
const FOLLOW_DISTANCE: float = 100.0
const EVADE_SPEED: float = 2.8  # GMS2: moveGuardStepSpeed = attribute.runMax = 2.8
const TIMER_AVOID_LIMIT: float = 20.0 / 60.0  # GMS2: timerAvoidLimit = 20 frames

func enter() -> void:
	var actor := creature as Actor
	creature.velocity = Vector2.ZERO
	creature.attacking = null
	evading = false
	timer_try_attack = 0.0
	timer_check_enemy = 0.0
	timer_limit_try_attack = randf_range(40.0 / 60.0, 80.0 / 60.0)
	timer_limit_check_enemy = randf_range(40.0 / 60.0, 80.0 / 60.0)
	start_wait = 0.333
	check_new_target = false
	timer_avoid = 0.0
	evade_direction = Vector2.ZERO
	timer_check_leader_guard = 0.0

	# Get target from state var or find one
	target = state_machine.get_state_var(0, null)
	if not is_instance_valid(target):
		target = _find_nearest_enemy(80.0)
		if not is_instance_valid(target):
			switch_to("IAGuard")
			return

	# Track what we're guarding against (for target conflict detection)
	creature.attacking = target

	# Face target
	_look_at_target()

	# Set stand frame
	creature.set_facing_frame(
		creature.spr_stand_up, creature.spr_stand_right,
		creature.spr_stand_down, creature.spr_stand_left
	)

	# Calculate guard distance based on weapon radius + strategy pattern
	# GMS2: distanceToGuardTarget = weaponRadius[weaponId], clamped to minimunDistanceToGuardTarget
	# Then: calculatedDistance = (distanceToGuardTarget * (strategy - 2)) - distanceToGuardTarget
	# Final: distanceToGuardTarget += calculatedDistance, clamped to >= 0
	if actor:
		var base_dist: float = actor.weapon_radius
		if base_dist < MIN_GUARD_DISTANCE:
			base_dist = MIN_GUARD_DISTANCE

		var strategy: int = actor.strategy_approach_keep_away
		var calc_dist: float = (base_dist * float(strategy - 2)) - base_dist
		distance_to_guard = maxf(0.0, base_dist + calc_dist)

		# GMS2: strategy 4 = evasive, constantly switches targets
		if strategy == 4:
			check_new_target = true
	else:
		distance_to_guard = MIN_GUARD_DISTANCE

	# GMS2: Proactive retreat — when entering guard target (e.g. after attacking),
	# immediately start moving away if too close, at full run speed.
	# GMS2: motion_set(plannedDirectionToTarget, moveGuardStepSpeed)
	if is_instance_valid(target):
		var dist: float = creature.global_position.distance_to(target.global_position)
		if dist < distance_to_guard:
			evading = true
			evade_direction = (creature.global_position - target.global_position).normalized()
			creature.velocity = evade_direction * EVADE_SPEED * 60.0
			(creature as CharacterBody2D).move_and_slide()
			creature.facing = creature.get_facing_from_direction(-evade_direction)

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# GMS2: AI movement is blocked during cutscenes (lock_all_players)
	if actor.movement_input_locked:
		actor.velocity = Vector2.ZERO
		return

	if actor.is_party_leader:
		switch_to("Stand")
		return

	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	actor.overheat_controller(false)

	# GMS2: fsm_checkGuardTarget — protect the leader by targeting their attacker
	var guard_target: Node = _check_guard_target(actor, delta)
	if is_instance_valid(guard_target) and guard_target != target:
		target = guard_target
		creature.attacking = target

	# Check if target is still valid
	if not is_instance_valid(target) or target.is_dead:
		creature.attacking = null
		switch_to("IAGuard")
		return

	# Check if should follow actor (too far from followed actor in chain)
	# GMS2: uses actorFollowingId (previous actor in party chain), NOT the leader.
	var follow_target: Node = actor.actor_following
	if not is_instance_valid(follow_target):
		follow_target = GameManager.get_party_leader()
	if follow_target and is_instance_valid(follow_target):
		var dist_to_follow: float = creature.global_position.distance_to(follow_target.global_position)
		if dist_to_follow > FOLLOW_DISTANCE:
			creature.attacking = null
			switch_to("IAFollow")
			return

	var timer := get_timer()
	if timer < start_wait:
		return

	timer_check_enemy += delta
	timer_try_attack += delta

	# Periodically check distance and recalculate
	if timer_check_enemy > timer_limit_check_enemy:
		timer_check_enemy = 0.0
		timer_limit_check_enemy = randf_range(40.0 / 60.0, 80.0 / 60.0)
		_look_at_target()

		# GMS2: evasive pattern (strategy 4) - search for new targets
		if check_new_target:
			var new_target: Node = _find_unattacked_enemy(80.0)
			if new_target and new_target != target:
				target = new_target
				creature.attacking = target

		var dist_to_target: float = creature.global_position.distance_to(target.global_position)

		# Evade if too close
		if dist_to_target < distance_to_guard:
			evading = true
			evade_direction = (creature.global_position - target.global_position).normalized()
			creature.velocity = evade_direction * EVADE_SPEED * 60.0
			(creature as CharacterBody2D).move_and_slide()
			creature.facing = creature.get_facing_from_direction(-evade_direction)
			timer_avoid = 0.0

	# GMS2: hop-skip evade pattern ("move by trompicones")
	# First half: walk charge animation at half speed
	# Second half: stand ready at speed 0
	if evading:
		var dist_to_target: float = creature.global_position.distance_to(target.global_position)
		if dist_to_target >= distance_to_guard:
			# Far enough, stop evading
			evading = false
			timer_avoid = 0.0
			creature.velocity = Vector2.ZERO
			creature.set_facing_frame(
				creature.spr_stand_up, creature.spr_stand_right,
				creature.spr_stand_down, creature.spr_stand_left
			)
			_look_at_target()
		else:
			# GMS2: timerAvoidLimit=20; first half walk, second half stand
			if timer_avoid < TIMER_AVOID_LIMIT / 2:
				# Walk phase: walk charge animation at half speed
				creature.set_default_facing_animations(
					actor.spr_walk_charge_up_ini, actor.spr_walk_charge_right_ini,
					actor.spr_walk_charge_down_ini, actor.spr_walk_charge_left_ini,
					actor.spr_walk_charge_up_end, actor.spr_walk_charge_right_end,
					actor.spr_walk_charge_down_end, actor.spr_walk_charge_left_end
				)
				creature.animate_sprite(actor.img_speed_run)
				creature.velocity = evade_direction * (EVADE_SPEED / 2.0) * 60.0
				(creature as CharacterBody2D).move_and_slide()
			elif timer_avoid < TIMER_AVOID_LIMIT:
				# Stand phase: stand ready, no movement
				creature.set_facing_frame(
					creature.spr_stand_up, creature.spr_stand_right,
					creature.spr_stand_down, creature.spr_stand_left
				)
				creature.velocity = Vector2.ZERO
			else:
				# Reset cycle
				timer_avoid = 0.0
			timer_avoid += delta

	# Ready to attack? (GMS2: strategy 4 = evasive, doesn't attack, only evades)
	if not evading and not actor.overheating and timer_try_attack > timer_limit_try_attack:
		if actor.strategy_approach_keep_away < 4:
			state_machine.set_state_var(0, target)
			switch_to("IAPrepareAttack")
			return
		else:
			# Evasive: reset timer, keep guarding (GMS2: strategy 4 doesn't attack)
			timer_try_attack = 0.0
			timer_limit_try_attack = randf_range(40.0 / 60.0, 80.0 / 60.0)

func exit() -> void:
	creature.velocity = Vector2.ZERO

func _look_at_target() -> void:
	if is_instance_valid(target):
		var dir: Vector2 = (target.global_position - creature.global_position)
		if dir.length() > 1.0:
			creature.facing = creature.get_facing_from_direction(dir)

func _find_nearest_enemy(max_dist: float) -> Node:
	var nearest: Node = null
	var nearest_dist := max_dist
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob is Creature and not mob.is_dead and is_instance_valid(mob):
			var dist: float = creature.global_position.distance_to(mob.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = mob
	return nearest

func _find_unattacked_enemy(max_dist: float) -> Node:
	## GMS2: evasive pattern searches for enemies not being attacked by allies
	var best: Node = null
	var best_dist := max_dist
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob is Creature and not mob.is_dead and not mob.is_invulnerable and is_instance_valid(mob):
			var dist: float = creature.global_position.distance_to(mob.global_position)
			if dist < best_dist and not _is_target_being_attacked(mob):
				best_dist = dist
				best = mob
	if best == null:
		# Fallback: return nearest enemy even if attacked
		return _find_nearest_enemy(max_dist)
	return best

func _is_target_being_attacked(t: Node) -> bool:
	for player in GameManager.players:
		if player != creature and is_instance_valid(player) and player is Creature:
			var p: Creature = player as Creature
			if is_instance_valid(p.attacking) and p.attacking == t:
				return true
	return false

func _check_guard_target(actor: Actor, delta: float) -> Node:
	## GMS2: fsm_checkGuardTarget - AI companions protect the leader
	## When strategyPatternAttackGuard > 0, periodically checks if leader was attacked
	## and switches target to leader's attacker.
	## GMS2 hardcodes strategy=4 making dangerPercentage=100 (leader always "in danger").
	## calcTimerWard = timerLimit(1.0s) * (abs(4-4)+2) = 2.0s.
	if actor.strategy_attack_guard <= 0:
		return null

	timer_check_leader_guard += delta
	const TIMER_LIMIT: float = 1.0  # GMS2: timerLimit_checkLeaderGuard = 60 frames = 1.0s
	var calc_timer_ward: float = TIMER_LIMIT * float(absi(4 - actor.strategy_attack_guard) + 2)
	if timer_check_leader_guard > calc_timer_ward:
		timer_check_leader_guard = 0.0

		var follow_target: Node = actor.actor_following
		if not is_instance_valid(follow_target):
			follow_target = GameManager.get_party_leader()
		if is_instance_valid(follow_target) and follow_target is Creature:
			var leader: Creature = follow_target as Creature
			if is_instance_valid(leader.last_creature_attacked):
				var attacker: Node = leader.last_creature_attacked
				if attacker is Creature and not (attacker as Creature).is_dead:
					return attacker
	return null
