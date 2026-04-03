class_name ActorIAFollow
extends State
## AI-controlled actor FOLLOW state - replaces fsm_actor_ia_follow from GMS2
## GMS2: motionPlannerController calls planToTarget EVERY FRAME, making movement
## effectively direct (always toward target's current position). Pathfinding grid
## only matters for obstacle avoidance. We replicate this with direct movement +
## move_and_slide for wall sliding.

var follow_speed: float = 1.8
var follow_distance: float = 25.0  # GMS2: iaDistanceObservationBetweenPlayer = 25 (must be < IAGuard trigger for hysteresis)
var _stuck_timer: float = 0.0
var _last_position := Vector2.ZERO
var _enemy_check_timer: float = 0.0  # GMS2: checks for enemies every 0.5s while following
const ENEMY_CHECK_INTERVAL: float = 0.5
const ENEMY_DETECT_DISTANCE: float = 60.0  # GMS2: iaDistanceToAct

func enter() -> void:
	var actor := creature as Actor
	# GMS2: checks SNARED status on entry and halves speed
	follow_speed = actor.walk_speed
	if actor.has_status(Constants.Status.SNARED):
		follow_speed *= 0.5
	_stuck_timer = 0.0
	_last_position = actor.global_position
	_enemy_check_timer = 0.0
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

	# GMS2: AI movement is blocked during cutscenes (lock_all_players)
	if actor.movement_input_locked:
		actor.velocity = Vector2.ZERO
		return

	# If we became the leader, switch to player-controlled Stand
	if actor.is_party_leader:
		switch_to("Stand")
		return

	actor.overheat_controller(false)

	# Process damage stack
	if actor.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# GMS2: getTargetsInRange every 0.5s - detect enemies while following
	_enemy_check_timer += delta
	if _enemy_check_timer >= ENEMY_CHECK_INTERVAL:
		_enemy_check_timer = 0.0
		if _has_nearby_enemy(ENEMY_DETECT_DISTANCE):
			switch_to("IAGuard")
			return

	# GMS2: follow actorFollowingId (previous actor in chain), not the leader directly
	var follow_target: Node = actor.actor_following
	if not follow_target or not is_instance_valid(follow_target):
		follow_target = GameManager.get_party_leader()
	var leader: Node = GameManager.get_party_leader()
	if not follow_target or not is_instance_valid(follow_target):
		switch_to("IAStand")
		return

	var dist: float = actor.global_position.distance_to(follow_target.global_position)

	# Close enough, go to guard (skip IAStand bounce to avoid animation flicker)
	if dist <= follow_distance:
		switch_to("IAGuard")
		return

	# GMS2: if guardTargetId.control_isRunning → switch to running follow
	if leader and is_instance_valid(leader) and leader is Actor and (leader as Actor).control_is_running:
		switch_to("IAFollowRunning")
		return

	# --- Direct movement toward target (GMS2: planToTarget replans every frame) ---
	var move_dir: Vector2 = (follow_target.global_position - actor.global_position).normalized()

	# GMS2: walkingDiagonalSpeedTilt = 1.25 — reduce speed when moving diagonally
	var speed: float = follow_speed
	if move_dir.x != 0 and move_dir.y != 0:
		speed /= 1.25

	actor.facing = actor.get_facing_from_direction(move_dir)
	actor.velocity = move_dir * speed * 60.0
	actor.move_and_slide()

	creature.animate_sprite(actor.img_speed_walk)

func _has_nearby_enemy(max_dist: float) -> bool:
	## GMS2: getTargetsInRange - check if any alive enemy is within detection range
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob is Creature and not mob.is_dead and is_instance_valid(mob):
			if creature.global_position.distance_to(mob.global_position) < max_dist:
				return true
	return false
