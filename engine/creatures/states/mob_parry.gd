class_name MobParry
extends State
## Mob PARRY state - replaces fsm_mob_parry from GMS2
## Brief parry/stun animation. Plays parry sound, animates for N frames, returns to Stand.

var parry_time: float = 0.5  # 30 / 60.0

func enter() -> void:
	creature.velocity = Vector2.ZERO
	parry_time = 0.5

	if creature is Mob and (creature as Mob).snd_parry != "":
		MusicManager.play_sfx((creature as Mob).snd_parry)
	else:
		MusicManager.play_sfx("snd_parry")

func execute(_delta: float) -> void:
	creature.animate_sprite()

	if get_timer() > parry_time:
		switch_to("Stand")

func exit() -> void:
	creature.velocity = Vector2.ZERO
