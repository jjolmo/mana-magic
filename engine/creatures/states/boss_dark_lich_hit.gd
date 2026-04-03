class_name BossDarkLichHit
extends State
## Dark Lich HIT state - replaces fsm_mob_darkLich_hit from GMS2
## Damage processing with phase-aware hurt animations.

var performing_damage: bool = false
var enemy_dead: bool = false

func enter() -> void:
	var boss := creature as BossDarkLich
	if not boss:
		return

	performing_damage = false
	enemy_dead = false

	# GMS2: HANDS phase uses hurt2 frames (82-83), FULLBODY uses hurt (72-80)
	var config: Dictionary = boss.phase_sprite_config.get(boss.current_phase, {})
	var hurt_ini: int
	var hurt_end: int
	if boss.current_phase == BossDarkLich.Phase.HANDS:
		hurt_ini = config.get("hurt2_ini", 82)
		hurt_end = config.get("hurt2_end", 83)
	else:
		hurt_ini = config.get("hurt_ini", 72)
		hurt_end = config.get("hurt_end", 80)
	creature.set_default_facing_animations(
		hurt_ini, hurt_ini, hurt_ini, hurt_ini,
		hurt_end, hurt_end, hurt_end, hurt_end
	)
	creature.set_default_facing_index()
	creature.image_speed = (creature as Mob).img_speed_attack

func execute(_delta: float) -> void:
	if enemy_dead:
		return

	if not performing_damage:
		if creature.damage_stack.size() > 0:
			performing_damage = true
			var dmg_data: Variant = creature.damage_stack.pop_front()
			if dmg_data is Dictionary:
				creature.apply_damage(dmg_data.get("damage", 0))
			if creature.is_dead:
				switch_to("Dead")
				return
		else:
			switch_to("DLStand")
			return

	# GMS2: animateSprite(image_speed, phase == PHASE_FULLBODY)
	# FULLBODY stops on last frame, HANDS loops
	var boss := creature as BossDarkLich
	var stop_last: bool = boss != null and boss.current_phase == BossDarkLich.Phase.FULLBODY
	creature.animate_sprite(-1.0, stop_last)

	# After some time, check for more damage or return to stand
	if get_timer() >= 120 / 60.0 and not enemy_dead:
		if creature.damage_stack.size() > 0:
			if creature.is_dead:
				switch_to("Dead")
			else:
				performing_damage = false
				MusicManager.play_sfx("snd_hurt")
				state_machine.state_timer = 0.0
		else:
			switch_to("DLStand")

func exit() -> void:
	creature.velocity = Vector2.ZERO
