class_name ActorChargingWeapon
extends State
## Actor CHARGING WEAPON state - replaces fsm_actor_charging_weapon from GMS2
## Walk while weapon gauge is charged, ready to release powered attack

func enter() -> void:
	var actor := creature as Actor
	if not actor:
		switch_to("Stand")
		return

	actor.attribute.walkSpeed = actor.walk_charging_speed
	actor.show_weapon_level = false

	# Set charging walk animation
	creature.set_default_facing_animations(
		actor.spr_walk_charge_up_ini, actor.spr_walk_charge_right_ini,
		actor.spr_walk_charge_down_ini, actor.spr_walk_charge_left_ini,
		actor.spr_walk_charge_up_end, actor.spr_walk_charge_right_end,
		actor.spr_walk_charge_down_end, actor.spr_walk_charge_left_end
	)
	creature.set_default_facing_index()

func execute(_delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	if GameManager.ring_menu_opened:
		return

	# Weapon level controller
	actor.weapon_level_controller()

	# Handle movement
	if actor.control_is_moving and not actor.is_movement_input_locked():
		var dir := Vector2.ZERO
		if actor.control_up_held: dir.y -= 1; actor.new_facing = Constants.Facing.UP
		if actor.control_down_held: dir.y += 1; actor.new_facing = Constants.Facing.DOWN
		if actor.control_left_held: dir.x -= 1; actor.new_facing = Constants.Facing.LEFT
		if actor.control_right_held: dir.x += 1; actor.new_facing = Constants.Facing.RIGHT
		actor.facing = actor.new_facing

		if dir.length() > 0:
			dir = dir.normalized()
			actor.velocity = dir * actor.walk_charging_speed * 60.0
			actor.move_and_slide()

		creature.animate_sprite(actor.img_speed_walk_charging)
	else:
		creature.set_default_facing_index()

	# Release charged attack when attack button released
	if Input.is_action_just_released("attack"):
		actor.release_charged_attack()

	# Check for damage
	if creature.damage_stack.size() > 0:
		actor.weapon_gauge = 0.0
		actor.show_weapon_level = false
		switch_to("Hit")

func exit() -> void:
	creature.velocity = Vector2.ZERO
	var actor := creature as Actor
	if actor:
		actor.attribute.walkSpeed = actor.walk_speed
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)
