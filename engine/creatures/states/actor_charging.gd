class_name ActorCharging
extends State
## Actor CHARGING state - replaces fsm_actor_charging from GMS2
## Player holds attack button to charge weapon gauge (0-110)
## On release, transitions to a powered attack

var stop_charging_sound: bool = false
var sound_charge_step: float = 0.0

func enter() -> void:
	var actor := creature as Actor
	if not actor:
		switch_to("Stand")
		return

	actor.weapon_gauge = 0.0
	actor.charge_ready_played = false
	stop_charging_sound = false
	sound_charge_step = 0.0

	# Set charging walk animation
	creature.set_default_facing_animations(
		actor.spr_walk_charge_up_ini, actor.spr_walk_charge_right_ini,
		actor.spr_walk_charge_down_ini, actor.spr_walk_charge_left_ini,
		actor.spr_walk_charge_up_end, actor.spr_walk_charge_right_end,
		actor.spr_walk_charge_down_end, actor.spr_walk_charge_left_end
	)
	creature.set_default_facing_index()
	creature.image_speed = actor.img_speed_walk_charging
	actor.attribute.walkSpeed = actor.walk_charging_speed

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# Check if attack is still held
	if Input.is_action_pressed("attack"):
		# Charge weapon gauge
		if actor.weapon_gauge < actor.weapon_gauge_max_base:
			actor.weapon_gauge += 60.0 * delta
		else:
			# Gauge full - weapon level ready
			actor.show_weapon_level = true
			var weapon_name := actor.get_weapon_name()
			var current_lvl: int = actor.equipment_current_level.get(weapon_name, 1)
			var max_lvl: int = actor.equipment_levels.get(weapon_name, 0) + 1

			if current_lvl < max_lvl:
				# Advance to next charge level
				actor.equipment_current_level[weapon_name] = current_lvl + 1
				actor.weapon_gauge = 0.0
				stop_charging_sound = false
				actor.charge_ready_played = false
			else:
				# At max level - play ready sound once
				stop_charging_sound = true
				if not actor.charge_ready_played:
					# GMS2: soundPlay(sound_weaponChargeReady)
					MusicManager.play_sfx("snd_weaponChargeReady")
					actor.charge_ready_played = true

		# Charging loop sound (GMS2: soundPlayOverlap(sound_weaponCharging) every 25 frames)
		if sound_charge_step >= 0.417 and not stop_charging_sound:
			MusicManager.play_sfx("snd_weaponCharging")
			sound_charge_step = 0.0
		sound_charge_step += delta

		# Allow movement while charging (at reduced speed)
		if actor.control_is_moving:
			var dir := Vector2.ZERO
			if actor.control_up_held: dir.y -= 1
			if actor.control_down_held: dir.y += 1
			if actor.control_left_held: dir.x -= 1
			if actor.control_right_held: dir.x += 1
			dir = dir.normalized()

			actor.velocity = dir * actor.walk_charging_speed * 60.0
			actor.move_and_slide()
			creature.animate_sprite()

			# Update facing
			if dir != Vector2.ZERO:
				actor.facing = actor.get_facing_from_direction(dir)
				actor.new_facing = actor.facing
		else:
			actor.velocity = Vector2.ZERO
			creature.set_default_facing_index()

	else:
		# Attack released - GMS2: releaseChargedAttack if chargeReadyPlayed, else reset
		if actor.charge_ready_played:
			# Fully charged at max level - trigger weapon power attack
			actor.release_charged_attack()
		else:
			# Released before fully charged - reset gauge and return to stand
			actor.weapon_gauge = 0.0
			actor.show_weapon_level = false
			actor.change_state_stand_dead()

	# Process overheat during charging (GMS2: overheatController every frame)
	actor.overheat_controller(false)

	# Check for damage
	if creature.attacked:
		actor.weapon_gauge = 0.0
		actor.show_weapon_level = false

func exit() -> void:
	var actor := creature as Actor
	if actor:
		actor.attribute.walkSpeed = actor.walk_speed
		# Reset walk animation ranges
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)
