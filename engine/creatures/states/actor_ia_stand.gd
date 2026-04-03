class_name ActorIAStand
extends State
## AI-controlled actor STAND state - replaces fsm_actor_ia_stand from GMS2
## GMS2: immediately transitions to IA_GUARD every frame (line 14)

func enter() -> void:
	creature.attacked = false
	creature.attacking = null
	creature.image_speed = 0  # GMS2: standing actors do not animate
	creature.set_facing_frame(
		creature.spr_stand_up,
		creature.spr_stand_right,
		creature.spr_stand_down,
		creature.spr_stand_left
	)

func execute(_delta: float) -> void:
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

	# Process damage stack
	if actor.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# GMS2: fsm_ia_stand immediately transitions to state_IA_GUARD
	# IAGuard handles following, enemy scanning, and combat initiation
	switch_to("IAGuard")
