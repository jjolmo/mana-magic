class_name ActorPushing
extends State
## Actor PUSHING state - replaces fsm_actor_pushing from GMS2
## Pushing objects or walking with charged weapon. Slower movement with push animation.

var moving_flag: bool = false
var using_weapon_charge: bool = false

func enter() -> void:
	var actor := creature as Actor
	moving_flag = false
	using_weapon_charge = actor.weapon_gauge > 0

	if not using_weapon_charge:
		# Normal push movement
		actor.attribute.walkSpeed = actor.walk_pushing_speed
		creature.set_default_facing_animations(
			actor.spr_push_up_ini, actor.spr_push_right_ini,
			actor.spr_push_down_ini, actor.spr_push_left_ini,
			actor.spr_push_up_end, actor.spr_push_right_end,
			actor.spr_push_down_end, actor.spr_push_left_end
		)
		creature.set_default_facing_index()
	else:
		# Weapon charge walk
		actor.attribute.walkSpeed = actor.walk_charging_speed
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

	if not using_weapon_charge:
		# Push movement
		if actor.control_is_moving:
			var dir := Vector2.ZERO
			if actor.control_up_held: dir.y -= 1; actor.new_facing = Constants.Facing.UP
			if actor.control_down_held: dir.y += 1; actor.new_facing = Constants.Facing.DOWN
			if actor.control_left_held: dir.x -= 1; actor.new_facing = Constants.Facing.LEFT
			if actor.control_right_held: dir.x += 1; actor.new_facing = Constants.Facing.RIGHT
			actor.facing = actor.new_facing

			if dir.length() > 0:
				dir = dir.normalized()
				actor.velocity = dir * actor.walk_pushing_speed * 60.0
				actor.move_and_slide()
			creature.animate_sprite(actor.img_speed_push)
		else:
			switch_to("Stand")
			return
	else:
		# Weapon charge walk animation
		if actor.control_is_moving:
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

	# Check if no longer pushing (no collision with creature ahead)
	if not Input.is_action_pressed("attack"):
		if using_weapon_charge:
			switch_to("ChargingWeapon")
		else:
			actor.change_state_stand_dead()
		return

	# Attack input
	if actor.control_attack_pressed and not actor.is_actor_dead():
		switch_to("Attack")
		return

	# Release charged attack
	if Input.is_action_just_released("attack") and actor.weapon_gauge >= actor.weapon_gauge_max_base:
		actor.release_charged_attack()

	actor.weapon_level_controller()
	actor.overheat_controller(false)

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
