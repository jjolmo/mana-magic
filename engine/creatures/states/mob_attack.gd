class_name MobAttack
extends State
## Mob ATTACK state - replaces fsm_mob_attack from GMS2

var target: Node = null
var attacked: bool = false

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return

	target = mob.current_target
	attacked = false

	if not is_instance_valid(target):
		switch_to("Stand")
		return

	# Face the target
	mob.look_at_target(target)

	# Set attack animation
	creature.set_facing_frame(
		mob.spr_attack_up_ini, mob.spr_attack_right_ini,
		mob.spr_attack_down_ini, mob.spr_attack_left_ini
	)
	creature.image_speed = mob.img_speed_attack

func execute(_delta: float) -> void:
	var mob := creature as Mob
	if not mob:
		return

	# Check damage stack first
	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	var timer := get_timer()

	if timer > 20 / 60.0:
		if not is_instance_valid(target):
			switch_to("Stand")
			return

		# Face the target
		mob.look_at_target(target)
		creature.set_facing_frame(
			mob.spr_attack_up_ini, mob.spr_attack_right_ini,
			mob.spr_attack_down_ini, mob.spr_attack_left_ini
		)

		# Check if in attack range
		var too_near := mob.is_in_attack_range(target)
		if too_near and not attacked:
			DamageCalculator.perform_attack(target, creature, Constants.AttackType.WEAPON)
			attacked = true

		switch_to("Stand")
		return

	# GMS2: setFacingOnAttackFinished - clamp animation to play once then freeze on last frame
	# Animate but stop when reaching attack end frame for current facing
	creature.animate_sprite()
	_clamp_attack_animation(mob)

func _clamp_attack_animation(mob: Mob) -> void:
	## GMS2: setFacingOnAttackFinished() - when animation reaches end frame for current facing,
	## freeze animation (image_speed = 0) and lock to end frame. Prevents looping.
	var end_frame: int = 0
	match creature.facing:
		Constants.Facing.UP:
			end_frame = mob.spr_attack_up_end
		Constants.Facing.RIGHT:
			end_frame = mob.spr_attack_right_end
		Constants.Facing.DOWN:
			end_frame = mob.spr_attack_down_end
		Constants.Facing.LEFT:
			end_frame = mob.spr_attack_left_end
	if creature.current_frame >= end_frame:
		creature.current_frame = end_frame
		creature.set_frame(end_frame)
		creature.image_speed = 0

func exit() -> void:
	creature.velocity = Vector2.ZERO
