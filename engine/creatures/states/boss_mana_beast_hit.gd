class_name BossManaBeastHit
extends State
## Mana Beast HIT state - replaces fsm_mob_manaBeast_hit from GMS2
## Damage queue processor, handles damage stack one at a time

var performing_damage: bool = false

func enter() -> void:
	creature.velocity = Vector2.ZERO
	performing_damage = false

func execute(_delta: float) -> void:
	var timer := get_timer()

	if not performing_damage:
		if creature.damage_stack.size() > 0:
			performing_damage = true
			var dmg_data: Variant = creature.damage_stack.pop_front()
			if dmg_data is Dictionary:
				creature.apply_damage(dmg_data.get("damage", 0))
			if creature.is_dead:
				switch_to("MBDead")
				return
		else:
			# No more damage to process, return to stand
			switch_to("MBStand")
			return

	# Wait 1.0 second between damage applications (was 60 frames)
	if timer >= 60 / 60.0 and performing_damage:
		MusicManager.play_sfx("snd_hurt")
		performing_damage = false
		state_machine.state_timer = 0.0

func exit() -> void:
	creature.velocity = Vector2.ZERO
