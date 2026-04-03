class_name ActorIAFollowRunning
extends State
## AI-controlled actor FOLLOW RUNNING state - replaces fsm_actor_ia_follow_running from GMS2
## GMS2: motionPlannerController calls planToTarget EVERY FRAME with running flag.
## Direct movement toward target, matching GMS2's effective behavior.

var follow_speed: float = 2.8
var follow_distance: float = 25.0  # GMS2: iaDistanceObservationBetweenPlayer = 25 (must be < IAGuard trigger for hysteresis)

func enter() -> void:
	var actor := creature as Actor
	follow_speed = actor.run_speed
	# GMS2: runningSteps = -(8*identifier) for staggered footstep timing (converted to seconds)
	var player_index: int = GameManager.players.find(actor)
	actor.running_steps = -(8.0 / 60.0) * maxi(0, player_index)
	creature.set_default_facing_animations(
		actor.spr_run_up_ini, actor.spr_run_right_ini,
		actor.spr_run_down_ini, actor.spr_run_left_ini,
		actor.spr_run_up_end, actor.spr_run_right_end,
		actor.spr_run_down_end, actor.spr_run_left_end
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

	if actor.is_party_leader:
		switch_to("Stand")
		return

	actor.overheat_controller(false)

	if actor.damage_stack.size() > 0:
		switch_to("Hit")
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

	# GMS2: if guardTargetId stopped running, switch to walk follow
	if leader is Actor and not (leader as Actor).control_is_running:
		if dist > follow_distance:
			switch_to("IAFollow")
		else:
			switch_to("IAGuard")
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

	# GMS2: performRunningStepSounds(true) - staggered footstep sounds for followers
	if not actor.is_dead:
		actor.running_steps += delta
		if actor.running_steps > 25.0 / 60.0:
			MusicManager.play_sfx("snd_running")
			actor.running_steps = 0.0

	creature.animate_sprite(actor.img_speed_run)
