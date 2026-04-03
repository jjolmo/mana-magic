class_name BossExplosion
extends Node2D
## Boss explosion animation effect - replaces oAni_bossExplode / oAni_bossExplode2 from GMS2
## Spawns sequential explosions around the boss, then triggers death effects

signal explosion_finished

enum Type { DARK_LICH, MANA_BEAST }

var explosion_type: int = Type.DARK_LICH
var target: Node2D = null
var target_position: Vector2 = Vector2.ZERO
var callback_scene: PackedScene = null  # Post-death scene to spawn (Dark Lich)

var _timer: float = 0.0
var _explosion_positions: Array = []
var _explosion_count: int = 12
var _explosion_threshold: float = 45.0
var _explosions_spawned: int = 0
var _explosion_interval: float = 24.0 / 60.0  # Seconds between explosions
var _explosion_accum: float = 0.0  # Periodic accumulator for explosions
var _phase: int = 0  # Internal phase tracker
var _phase_entered: bool = false  # Flag for one-shot events at phase start
var _explode_sprite: Texture2D = null
var _large_explode_sprite: Texture2D = null
var _fade_platform: Node = null  # ManaFadePlatform reference (Mana Beast room only)

func _ready() -> void:
	# Pre-calculate random explosion positions (GMS2: 12 positions within threshold)
	for i in range(_explosion_count):
		_explosion_positions.append(Vector2(
			randf_range(-_explosion_threshold, _explosion_threshold),
			randf_range(-_explosion_threshold, _explosion_threshold)
		))

	# Load explosion sprites
	_explode_sprite = load("res://assets/sprites/sheets/spr_bossExplode1.png")
	_large_explode_sprite = load("res://assets/sprites/sheets/spr_bossExplode2.png")

	if is_instance_valid(target):
		target_position = target.global_position

	# Find the ManaFadePlatform in the scene (Mana Beast room)
	if explosion_type == Type.MANA_BEAST:
		var scene_root := get_tree().current_scene
		if scene_root:
			_fade_platform = scene_root.get_node_or_null("mana_fade_platform")

func _process(delta: float) -> void:
	_timer += delta

	if explosion_type == Type.DARK_LICH:
		_process_dark_lich(delta)
	else:
		_process_mana_beast(delta)

func _process_dark_lich(delta: float) -> void:
	## GMS2: oAni_bossExplode - sequential explosions, white fade, then callback scene
	match _phase:
		0:  # Spawn small explosions one at a time
			if _explosions_spawned < _explosion_count:
				_explosion_accum += delta
				while _explosion_accum >= _explosion_interval and _explosions_spawned < _explosion_count:
					_explosion_accum -= _explosion_interval
					_spawn_small_explosion(_explosions_spawned)
					_explosions_spawned += 1
					MusicManager.play_sfx("snd_bombExplosion")

				# After 6 explosions: lock players, start animation scene
				if _explosions_spawned == 6 and not _phase_entered:
					_phase_entered = true
					_lock_all_players()
					GameManager.scene_running = true

				# After all 12: move to next phase
				if _explosions_spawned >= _explosion_count:
					_phase = 1
					_timer = 0.0
					_phase_entered = false

			# After 120 frames (2s): trigger gradual white fade (GMS2: go_fadeOut(20, c_white))
			if _timer >= 120.0 / 60.0 and _explosions_spawned >= 6:
				GameManager.map_transition.fade_out(20, Color.WHITE)
				_phase = 1
				_timer = 0.0
				_phase_entered = false

		1:  # Wait, play bomb sound
			if _timer >= 60.0 / 60.0 and not _phase_entered:
				_phase_entered = true
				MusicManager.play_sfx("snd_bombExplosion")
				_phase = 2
				_timer = 0.0
				_phase_entered = false

		2:  # Wait, play big boss explode sound
			if _timer >= 120.0 / 60.0 and not _phase_entered:
				_phase_entered = true
				MusicManager.play_sfx("snd_bossExplode")
				_phase = 3
				_timer = 0.0
				_phase_entered = false

		3:  # Hide boss, fade in from white
			if _timer >= 120.0 / 60.0 and not _phase_entered:
				_phase_entered = true
				if is_instance_valid(target):
					# GMS2: instance_destroy() — but in Godot the Dead state needs the
					# creature alive for the explosion_finished callback.  Hide instead;
					# the Dead state frees it after the callback.
					target.visible = false
					target.set_process(false)
					target.set_physics_process(false)
					target.collision_layer = 0
					target.collision_mask = 0
				GameManager.map_transition.fade_in(16, Color.WHITE)  # GMS2: go_fadeIn(16, c_white)
				_phase = 4
				_timer = 0.0
				_phase_entered = false

		4:  # Spawn large explosion at boss position
			if not _phase_entered:
				_phase_entered = true
				_spawn_large_explosion()
				_phase = 5
				_timer = 0.0
				_phase_entered = false

		5:  # Wait, heal party
			if _timer >= 500.0 / 60.0 and not _phase_entered:
				_phase_entered = true
				_heal_party()
				_phase = 6
				_timer = 0.0
				_phase_entered = false

		6:  # End animation, spawn callback scene
			if _timer >= 60.0 / 60.0 and not _phase_entered:
				_phase_entered = true
				GameManager.scene_running = false
				_unlock_all_players()
				MusicManager.stop()
				explosion_finished.emit()
				queue_free()

var _mb_fade_triggered: bool = false
var _mb_flash_triggered: bool = false
var _mb_end_triggered: bool = false

func _process_mana_beast(delta: float) -> void:
	## GMS2: oAni_bossExplode2 - explosions, rotate+shrink boss, transition to ending
	match _phase:
		0:  # Spawn explosions, shake boss
			if _explosions_spawned < _explosion_count:
				_explosion_accum += delta
				while _explosion_accum >= _explosion_interval and _explosions_spawned < _explosion_count:
					_explosion_accum -= _explosion_interval
					_spawn_small_explosion(_explosions_spawned)
					_explosions_spawned += 1
					MusicManager.play_sfx("snd_bombExplosion")

				if _explosions_spawned == 6 and not _phase_entered:
					_phase_entered = true
					_lock_all_players()
					GameManager.scene_running = true

			# Shake boss sprite
			if is_instance_valid(target):
				target.position += Vector2(randf_range(-2, 2), randf_range(-2, 2))

			# Mana Fade Platform: start fade-in (GMS2: oManaFadePlatform at tick 10)
			if _timer >= 10.0 / 60.0 and not _mb_fade_triggered and _fade_platform and _fade_platform.has_method("start_fade_in"):
				_mb_fade_triggered = true
				_fade_platform.start_fade_in()

			if _timer >= _explosion_count * _explosion_interval:
				_phase = 1
				_timer = 0.0
				_phase_entered = false

		1:  # Rotate and shrink the boss
			if is_instance_valid(target):
				target.rotation -= deg_to_rad(12) * delta * 60.0
				target.scale -= Vector2(0.01, 0.01) * delta * 60.0
				if target.scale.x <= 0:
					# Hide boss instead of queue_free so the Dead state tree stays alive
					target.visible = false
					target.set_process(false)
					target.set_physics_process(false)
					target.collision_layer = 0
					target.collision_mask = 0
					_phase = 2
					_timer = 0.0
			else:
				_phase = 2
				_timer = 0.0

		2:  # Flash screen, transition to ending
			if not _mb_flash_triggered:
				_mb_flash_triggered = true
				# Yellow flash (GMS2: rgb 255,251,180)
				GameManager.map_transition.blend_screen_on(Color(1.0, 0.984, 0.706), 1.0)
			if _timer >= 120.0 / 60.0 and not _mb_end_triggered:
				_mb_end_triggered = true
				MusicManager.stop()
				# Free the hidden boss creature before room transition
				if is_instance_valid(target):
					target.queue_free()
				# Transition to ending room
				GameManager.map_transition.map_change("rom_end")
				GameManager.scene_running = false
				_unlock_all_players()
				explosion_finished.emit()
				queue_free()

func _spawn_small_explosion(index: int) -> void:
	## Spawn a small explosion effect at a pre-calculated position
	if index >= _explosion_positions.size():
		return
	var pos: Vector2 = target_position + _explosion_positions[index]
	# GMS2: spr_bossExplode1 playbackSpeed = 20.0 FPS
	var explosion := _create_animated_sprite(_explode_sprite, 8, 30, 28, 20.0)
	if explosion:
		explosion.global_position = pos
		explosion.z_index = 1000  # GMS2: lyr_animations depth -14000
		get_tree().current_scene.add_child(explosion)

func _spawn_large_explosion() -> void:
	## Spawn a large explosion at boss position (spr_bossExplode2)
	# GMS2: spr_bossExplode2 playbackSpeed = 60.0 FPS
	var explosion := _create_animated_sprite(_large_explode_sprite, 106, 256, 74, 60.0)
	if explosion:
		explosion.global_position = target_position
		explosion.z_index = 1000  # GMS2: lyr_animations depth -14000
		get_tree().current_scene.add_child(explosion)

func _create_animated_sprite(tex: Texture2D, total_frames: int, fw: int, fh: int, fps: float = 20.0) -> AnimatedSprite2D:
	## Create an auto-playing animated sprite from a sprite sheet
	if not tex:
		return null
	var anim_sprite := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("explode")
	frames.set_animation_speed("explode", fps)
	frames.set_animation_loop("explode", false)

	# Extract frames from sheet
	var columns: int = maxi(1, tex.get_width() / fw)
	for i in range(total_frames):
		var col: int = i % columns
		var row: int = i / columns
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(col * fw, row * fh, fw, fh)
		frames.add_frame("explode", atlas)

	anim_sprite.sprite_frames = frames
	anim_sprite.animation = "explode"
	anim_sprite.autoplay = "explode"

	# Auto-free when animation ends
	anim_sprite.animation_finished.connect(func(): anim_sprite.queue_free())

	return anim_sprite

func _lock_all_players() -> void:
	for player in GameManager.players:
		if is_instance_valid(player):
			player.velocity = Vector2.ZERO
			if player.has_method("lock_movement_input"):
				player.lock_movement_input()

func _unlock_all_players() -> void:
	for player in GameManager.players:
		if is_instance_valid(player):
			if player.has_method("unlock_movement_input"):
				player.unlock_movement_input()

func _heal_party() -> void:
	## GMS2: healParty() - full heal all alive actors with sound + healed pose animation
	## GMS2: pauseCreature() + state_payload(sprHealed*, 30, speed) + performHeal(FULL) +
	##        state_switch(state_STATIC_ANIMATION) + soundPlay(snd_healParty) per actor
	MusicManager.play_sfx("snd_healParty")
	for player in GameManager.players:
		if is_instance_valid(player) and not player.is_dead:
			player.attribute.hp = player.attribute.maxHP
			player.attribute.mp = player.attribute.maxMP
			player.refresh_hp_percent()
			player.refresh_mp_percent()
			# Spawn heal floating number
			var scene_root: Node = get_tree().current_scene if get_tree() else null
			if scene_root:
				FloatingNumber.spawn(scene_root, player, player.attribute.maxHP, FloatingNumber.CounterType.HP_GAIN)
			# GMS2: healed pose for 30 frames on each healed actor
			DamageCalculator.apply_healed_pose(player, 30)

## Static spawn helpers
static func spawn_dark_lich_explosion(boss: Node2D, callback: PackedScene = null) -> BossExplosion:
	var explosion := BossExplosion.new()
	explosion.explosion_type = Type.DARK_LICH
	explosion.target = boss
	explosion.callback_scene = callback
	boss.get_tree().current_scene.add_child(explosion)
	return explosion

static func spawn_mana_beast_explosion(boss: Node2D) -> BossExplosion:
	var explosion := BossExplosion.new()
	explosion.explosion_type = Type.MANA_BEAST
	explosion.target = boss
	boss.get_tree().current_scene.add_child(explosion)
	return explosion
