class_name ActorIASearchTarget
extends State
## AI SEARCH TARGET state - replaces fsm_ia_search_target from GMS2
## Searches for a new target to attack. Mostly a transition state.
## In GMS2 this was incomplete - implemented with basic target search.

var target: Node = null

func enter() -> void:
	creature.velocity = Vector2.ZERO

	creature.set_facing_frame(
		creature.spr_stand_up, creature.spr_stand_right,
		creature.spr_stand_down, creature.spr_stand_left
	)

	# Get target from state var
	target = state_machine.get_state_var(0, null)

func execute(_delta: float) -> void:
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

	# If no valid target, return to guard
	if not is_instance_valid(target) or target.is_dead:
		switch_to("IAGuard")
		return

	# Search for a better target or go to prepare attack
	var nearest: Node = _find_nearest_enemy(80.0)
	if nearest and is_instance_valid(nearest):
		state_machine.set_state_var(0, nearest)
		switch_to("IAPrepareAttack")
	else:
		switch_to("IAGuard")

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
