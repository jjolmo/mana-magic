class_name ActorIAGuard
extends State
## AI GUARD state - replaces fsm_ia_guard from GMS2
## Idle guard state for AI party members. Periodically searches for enemies.
## Transitions to IAGuardTarget when enemy found, IAFollow if too far from followed actor.
## GMS2: calculatedDistanceToAct = distanceToAct * round((4 - strategyPatternAttackGuard + 1) / attackGuardSightDivisor)
## GMS2: follow distance checks against actorFollowingId (previous actor in chain), NOT the leader.

var timer_search_target: float = 0.0
var timer_limit_search_target: float = 0.5
var timer_search_actor: float = 0.0
var timer_limit_search_actor: float = 0.167
var attacking: Node = null
var calculated_distance_to_act: float = 60.0
var timer_check_leader_guard: float = 0.0  # GMS2: timer_checkLeaderGuard

# GMS2 constants
const BASE_DISTANCE_TO_ACT: float = 60.0
const ATTACK_GUARD_SIGHT_DIVISOR: float = 1.2
const FOLLOW_DISTANCE: float = 30.0  # GMS2: iaDistanceBetweenPlayer = 30 (must be >= IAFollow stop distance for hysteresis)
const TIMER_LIMIT_CHECK_LEADER_GUARD: float = 1.0  # GMS2: timerLimit_checkLeaderGuard = 60 frames = 1.0s

func enter() -> void:
	var actor := creature as Actor
	creature.attacked = false
	creature.attacking = null
	creature.image_speed = 0
	creature.velocity = Vector2.ZERO
	attacking = null

	timer_search_target = 0.0
	timer_limit_search_target = randf_range(20.0 / 60.0, 50.0 / 60.0)
	timer_search_actor = 0.0
	timer_check_leader_guard = 0.0

	# Set stand frame (GMS2: setDefaultFacingIndex on entry)
	# Also set default animations to stand so set_default_facing_index() in execute
	# shows stand frames when facing direction changes.
	creature.set_default_facing_animations(
		creature.spr_stand_up, creature.spr_stand_right,
		creature.spr_stand_down, creature.spr_stand_left,
		creature.spr_stand_up, creature.spr_stand_right,
		creature.spr_stand_down, creature.spr_stand_left
	)
	creature.set_default_facing_index()

	# Calculate sight distance based on strategy pattern
	# GMS2: calculatedDistanceToAct = distanceToAct * round((4 - strategyPatternAttackGuard + 1) / attackGuardSightDivisor)
	if actor:
		var strategy: int = actor.strategy_attack_guard
		calculated_distance_to_act = BASE_DISTANCE_TO_ACT * roundf(float(4 - strategy + 1) / ATTACK_GUARD_SIGHT_DIVISOR)
	else:
		calculated_distance_to_act = BASE_DISTANCE_TO_ACT

	# Handle overheat
	if actor:
		actor.overheat_controller(false)

	# Set search timer already expired so enemies are found on the first execute() frame.
	# Cannot search in enter() because switching to IAGuardTarget from enter() causes
	# infinite recursion (IAGuardTarget.enter() may switch back if target becomes invalid).
	timer_search_target = 9999.0
	timer_limit_search_target = 0.0

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# GMS2: AI movement is blocked during cutscenes (lock_all_players)
	if actor.movement_input_locked:
		actor.velocity = Vector2.ZERO
		return

	# If became leader, switch to player Stand
	if actor.is_party_leader:
		switch_to("Stand")
		return

	# Process damage
	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# GMS2: setDefaultFacingIndex() — updates facing direction sprite selection
	# without resetting the full stand animation (avoids animation flickering)
	creature.set_default_facing_index()

	actor.overheat_controller(false)

	# GMS2: fsm_checkGuardTarget — protect the leader by targeting their attacker
	var guard_target: Node = _check_guard_target(actor, delta)
	if is_instance_valid(guard_target):
		state_machine.set_state_var(0, guard_target)
		switch_to("IAGuardTarget")
		return

	timer_search_target += delta
	timer_search_actor += delta

	# Search for enemies periodically
	if timer_search_target > timer_limit_search_target:
		timer_search_target = 0.0
		timer_limit_search_target = randf_range(20.0 / 60.0, 50.0 / 60.0)

		if not creature.is_dead:
			# GMS2: getAvailableTarget - find nearest enemy not being attacked by allies
			var enemy_near: Node = _find_available_target(calculated_distance_to_act)
			if enemy_near and is_instance_valid(enemy_near):
				var dist: float = creature.global_position.distance_to(enemy_near.global_position)
				if dist < calculated_distance_to_act:
					# Found target - go guard it
					state_machine.set_state_var(0, enemy_near)
					switch_to("IAGuardTarget")
					return

	# Check if should follow actor
	# GMS2: distance_to_object(self.actorFollowingId) > iaDistanceObservationBetweenPlayer
	# Uses actorFollowingId (previous actor in party chain), NOT the party leader.
	# This is critical: companion B follows leader A, companion C follows B.
	# C checks distance to B (nearby), not A (possibly far away).
	if timer_search_actor > timer_limit_search_actor:
		timer_search_actor = 0.0
		var follow_target: Node = actor.actor_following
		if not is_instance_valid(follow_target):
			follow_target = GameManager.get_party_leader()
		if follow_target and is_instance_valid(follow_target):
			var dist: float = creature.global_position.distance_to(follow_target.global_position)
			if dist > FOLLOW_DISTANCE:
				switch_to("IAFollow")
				return

func _find_available_target(max_dist: float) -> Node:
	## GMS2: getAvailableTarget - find nearest enemy not being attacked by another ally
	## Prioritizes targets by distance, skips those already engaged by other party members
	var candidates: Array = []
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob is Creature and not mob.is_dead and not mob.is_invulnerable and is_instance_valid(mob):
			var dist: float = creature.global_position.distance_to(mob.global_position)
			if dist < max_dist:
				candidates.append({"node": mob, "dist": dist})

	if candidates.is_empty():
		return null

	# Sort by distance (nearest first)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.dist < b.dist)

	# GMS2: Prefer targets not being attacked by allies (skip only non-boss targets)
	# Bosses are always valid targets even if already being attacked
	for c in candidates:
		var mob_is_boss: bool = c.node is Creature and (c.node as Creature).creature_is_boss
		if mob_is_boss or not _is_target_being_attacked(c.node):
			return c.node

	# All targets busy - return nearest anyway
	return candidates[0].node

func _is_target_being_attacked(target: Node) -> bool:
	## GMS2: isTargetBeingAttacked - check if any other party member is attacking this target
	for player in GameManager.players:
		if player != creature and is_instance_valid(player) and player is Creature:
			var p: Creature = player as Creature
			if is_instance_valid(p.attacking) and p.attacking == target:
				return true
	return false

func _check_guard_target(actor: Actor, delta: float) -> Node:
	## GMS2: fsm_checkGuardTarget - AI companions protect the leader
	## When strategyPatternAttackGuard > 0, periodically checks if leader was attacked
	## and switches target to leader's attacker.
	## GMS2 hardcodes strategy=4 making dangerPercentage=100 (leader always "in danger").
	## calcTimerWard = timerLimit(60) * (abs(4-4)+2) = 120 frames = 2 seconds at 60fps.
	if actor.strategy_attack_guard <= 0:
		return null

	timer_check_leader_guard += delta
	# GMS2: calcTimerWard = timerLimit * (abs(4 - strategy) + 2)
	# With hardcoded strategy=4: calcTimerWard = 1.0 * 2 = 2.0s
	var calc_timer_ward: float = TIMER_LIMIT_CHECK_LEADER_GUARD * float(absi(4 - actor.strategy_attack_guard) + 2)
	if timer_check_leader_guard > calc_timer_ward:
		timer_check_leader_guard = 0.0

		# Check if leader's last attacker is a valid target
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
