class_name BossManaBeastSide
extends State
## Mana Beast SIDE state - replaces fsm_mob_manaBeast_side from GMS2
## Swift side-to-side charge attack across screen

var direction: int = 1 # 1=start RIGHT move LEFT (GMS2 direction==0), -1=start LEFT move RIGHT
var move_speed: float = 10.0
var hit_dealt: bool = false
var _sound_played: bool = false

func enter() -> void:
	var boss := creature as BossManaBeast
	if not boss:
		return

	boss.phase_time = 0
	creature.velocity = Vector2.ZERO
	hit_dealt = false
	_sound_played = false

	# Random direction (GMS2: rollCoin())
	direction = 1 if randi() % 2 == 0 else -1

	# GMS2: Use camera center for positioning
	var center: Vector2 = boss.get_camera_center()

	# GMS2: Set aux sprite with side animation frames
	boss.use_aux_sprite()
	creature.set_frame(boss.aux_side_ini)
	creature.image_speed = 0.0  # Single frame, no animation

	# GMS2: Scale 2x, flipped based on direction
	# direction==0 (our 1): start at center.x + 350, image_xscale = 2 (NOT flipped), moves LEFT
	# direction==1 (our -1): start at center.x - 350, image_xscale = -2 (flipped), moves RIGHT
	if direction > 0:
		creature.global_position.x = center.x + 350.0
		creature.scale = Vector2(2.0, 2.0)  # GMS2: direction==0 → NOT flipped
	else:
		creature.global_position.x = center.x - 350.0
		creature.scale = Vector2(-2.0, 2.0)  # GMS2: direction==1 → flipped

	creature.global_position.y = center.y

	# Invulnerable during side attack
	creature.is_invulnerable = true
	creature.is_untargetable = true

	# Invisible initially (visible after 60 frames)
	creature.visible = false

func execute(delta: float) -> void:
	var boss := creature as BossManaBeast
	if not boss:
		return

	var timer := get_timer()

	# Invisible for first 1.0 second (was 60 frames)
	if timer < 60 / 60.0:
		return

	# GMS2: Become visible and play sound once (soundPlayed flag)
	if not _sound_played:
		creature.visible = true
		MusicManager.play_sfx("snd_flammie")
		_sound_played = true

	# Move across screen (GMS2: x += (direction==0) ? -moveSpeed : moveSpeed)
	# Our direction 1 = GMS2 direction 0 → move LEFT (x -= 10)
	# Our direction -1 = GMS2 direction 1 → move RIGHT (x += 10)
	if timer < 260 / 60.0:
		creature.global_position.x -= move_speed * direction * 60.0 * delta

		# Hit all players at 1.4s (was frame 84) (GMS2: state_timer > 84)
		if timer > 84 / 60.0 and not hit_dealt:
			hit_dealt = true
			for player in GameManager.get_alive_players():
				if player is Creature and is_instance_valid(player):
					DamageCalculator.perform_attack(player, creature, Constants.AttackType.ETEREAL)
	else:
		# GMS2: state_timer >= 260 / 60.0 → state_payload(0); state_switch(state_FIREBALL)
		creature.scale = Vector2.ONE
		creature.modulate = Color.WHITE
		creature.visible = true
		switch_to("MBFireball")

func exit() -> void:
	creature.velocity = Vector2.ZERO
	creature.modulate = Color.WHITE
	creature.visible = true
