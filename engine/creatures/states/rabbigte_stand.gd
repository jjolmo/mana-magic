class_name RabbigteStand
extends State
## Rabbigte STAND state - replaces fsm_rabbigte_stand from GMS2
## Immediately switches to chase on finding a target. Only lasts 1 frame.

func enter() -> void:
	creature.velocity = Vector2.ZERO

func execute(_delta: float) -> void:
	var mob := creature as Mob
	if not mob:
		return

	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# GMS2: getRandomPlayerAlive → immediately chase
	var target: Node = GameManager.get_random_alive_player()
	if target:
		mob.current_target = target
		switch_to("RabbigteChase")
	else:
		switch_to("RabbigteWander")
