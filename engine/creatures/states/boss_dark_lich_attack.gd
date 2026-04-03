class_name BossDarkLichAttack
extends State
## Dark Lich ATTACK state - replaces fsm_mob_darkLich_attack from GMS2
## HANDS phase melee attack with hand collision areas.

var checked_hitbox: bool = false
var circle_radius: float = 30.0
var hand_offset: float = 40.0

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return

	creature.velocity = Vector2.ZERO
	checked_hitbox = false

	# Set attack animation
	creature.set_default_facing_animations(
		mob.spr_attack_up_ini, mob.spr_attack_right_ini,
		mob.spr_attack_down_ini, mob.spr_attack_left_ini,
		mob.spr_attack_up_end, mob.spr_attack_right_end,
		mob.spr_attack_down_end, mob.spr_attack_left_end
	)
	creature.set_default_facing_index()
	creature.image_speed = mob.img_speed_attack

func execute(_delta: float) -> void:
	var timer := get_timer()

	# Check for hand collisions after animation progresses
	if timer > 20 / 60.0 and not checked_hitbox:
		checked_hitbox = true
		# Check collision with players near both hand positions
		var hand1_pos: Vector2 = creature.global_position + Vector2(-hand_offset, 10)
		var hand2_pos: Vector2 = creature.global_position + Vector2(hand_offset, 10)

		for player in GameManager.get_alive_players():
			if player is Creature and is_instance_valid(player):
				var dist1: float = player.global_position.distance_to(hand1_pos)
				var dist2: float = player.global_position.distance_to(hand2_pos)
				if dist1 < circle_radius or dist2 < circle_radius:
					var attack_type: int = Constants.AttackType.WEAPON
					if randi() % 2 == 0:
						attack_type = Constants.AttackType.FAINT
					DamageCalculator.perform_attack(player, creature, attack_type)

	# Finish when animation ends
	if creature.animate_sprite(creature.image_speed, true):
		if randi() % 2 == 0:
			switch_to("DLFade")
		else:
			switch_to("DLStand")

func exit() -> void:
	creature.velocity = Vector2.ZERO
