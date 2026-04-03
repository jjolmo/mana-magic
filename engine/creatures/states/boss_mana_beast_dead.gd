class_name BossManaBeastDead
extends State
## Mana Beast DEAD state - replaces fsm_mob_manaBeast_dead from GMS2
## Spawns boss explosion with rotate+shrink, then transitions to rom_end
## GMS2: animateSprite(state_imgSpeedStand) + ani_earthSlide() every frame
##       musicStop(1500) at state_timer == 120

var _explosion_spawned: bool = false
var _music_stopped: bool = false
var _shader_applied: bool = false

func enter() -> void:
	creature.is_dead = true
	creature.velocity = Vector2.ZERO
	creature.is_invulnerable = true
	creature.damage_stack.clear()
	creature.modulate = Color.WHITE
	creature.scale = Vector2.ONE
	creature.rotation = 0.0
	_music_stopped = false
	_shader_applied = false

	MusicManager.play_sfx("snd_bossExplode")

	# GMS2: ani_earthSlide() — apply white palette swap shader
	# Uses sha_palleteSwap with channel=3 (all/white), oscillates automatically via TIME
	var boss := creature as BossManaBeast
	if boss and boss._earth_slide_material:
		creature.enable_shader(boss._earth_slide_material)
		_shader_applied = true

	# Spawn boss explosion effect (GMS2: oAni_bossExplode2)
	if not _explosion_spawned:
		_explosion_spawned = true
		BossExplosion.spawn_mana_beast_explosion(creature)

	# Emit boss_defeated signal
	if creature.has_signal("boss_defeated"):
		creature.boss_defeated.emit()

func execute(_delta: float) -> void:
	var boss := creature as BossManaBeast
	if not boss:
		return

	var timer := get_timer()

	# GMS2: animateSprite(state_imgSpeedStand) — keep animating during death
	creature.animate_sprite(boss.img_speed_stand, true)

	# GMS2: ani_earthSlide() runs every frame — shader handles the oscillation via TIME uniform
	# No per-frame modulate toggling needed; sha_palleteSwap.gdshader cycles automatically

	# GMS2: musicStop(1500) at state_timer >= 2.0s (was 120 frames) — fade music over 1.5 seconds
	if timer >= 120 / 60.0 and not _music_stopped:
		_music_stopped = true
		# fade_speed = 1.0/1.5 ≈ 0.667 → volume goes from 1→0 in 1.5 seconds
		MusicManager.stop(0.667)
