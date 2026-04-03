class_name MobDead
extends State
## Mob DEAD state - replaces fsm_mob_dead from GMS2
## GMS2: swaps sprite_index to state_sprDeathAnim (spr_death0/spr_death1),
## plays once at full speed, instance_destroy() on last frame.

var rewards_granted: bool = false
var _death_sprite: AnimatedSprite2D = null

# Death animation sprite sheets (GMS2: state_sprDeathAnim)
# spr_death0: 52x52, 7 frames, 15fps (default for all mobs)
# spr_death1: 52x43, 17 frames, 30fps (rabite variants)
static var _death0_tex: Texture2D = null
static var _death1_tex: Texture2D = null

func enter() -> void:
	creature.is_dead = true
	creature.velocity = Vector2.ZERO
	creature.is_invulnerable = true
	rewards_granted = false

	# GMS2: soundPlay(sound_dead) - plays snd_hitDeath
	MusicManager.play_sfx("snd_hitDeath")

	# GMS2: removeBalloon + removeEngulf - clear visual status effects
	creature.damage_stack.clear()
	creature.dispel_buffs()
	creature.cure_ailments()

	# GMS2: deleteSkillAnimations - clean up orphaned skill effects targeting this creature
	_cleanup_skill_effects()

	# GMS2: disable collision so dead mobs don't block movement
	creature.collision_layer = 0
	creature.collision_mask = 0

	# Grant EXP and money to party
	_grant_rewards()

	# GMS2: sprite_index = state_sprDeathAnim - swap to death animation
	# Hide the creature's normal sprite and spawn a death animation on top
	creature.modulate.a = 0.0  # Hide creature sprite
	_spawn_death_animation()

func execute(_delta: float) -> void:
	# GMS2: when animation reaches image_number-1, instance_destroy()
	# The AnimatedSprite2D handles this via animation_finished signal
	pass

func _spawn_death_animation() -> void:
	## Create an AnimatedSprite2D with the death "poof" animation
	## GMS2: spr_death0 (default) or spr_death1 (rabite)
	var mob := creature as Mob
	var use_death1: bool = mob != null and mob.death_anim_id == 1

	var tex: Texture2D
	var frame_count: int
	var frame_w: int
	var frame_h: int
	var fps: float

	if use_death1:
		if _death1_tex == null:
			_death1_tex = load("res://assets/sprites/sheets/spr_death1.png")
		tex = _death1_tex
		frame_count = 17
		frame_w = 52
		frame_h = 43
		fps = 30.0
	else:
		if _death0_tex == null:
			_death0_tex = load("res://assets/sprites/sheets/spr_death0.png")
		tex = _death0_tex
		frame_count = 7
		frame_w = 52
		frame_h = 52
		fps = 15.0

	if not tex:
		# Fallback: just destroy immediately
		creature.queue_free()
		return

	_death_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("death")
	frames.set_animation_speed("death", fps)
	frames.set_animation_loop("death", false)

	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame("death", atlas)

	_death_sprite.sprite_frames = frames
	_death_sprite.global_position = creature.global_position
	_death_sprite.z_index = creature.z_index + 1
	_death_sprite.animation_finished.connect(_on_death_animation_finished)

	var parent: Node = creature.get_parent()
	if parent:
		parent.add_child(_death_sprite)
		_death_sprite.play("death")

func _on_death_animation_finished() -> void:
	## GMS2: instance_destroy() when last frame reached
	if is_instance_valid(_death_sprite):
		_death_sprite.queue_free()
	creature.queue_free()

func _cleanup_skill_effects() -> void:
	## GMS2: deleteSkillAnimations - destroy any active skill/summon effects
	## targeting or sourced from this creature so they don't play on a corpse.
	var world: Node = creature.get_parent()
	if not world:
		return
	for child in world.get_children():
		if child is SkillEffect:
			var fx: SkillEffect = child as SkillEffect
			if fx.source == creature or fx.target == creature:
				fx.queue_free()
		elif child is SummonEffect:
			var sx: SummonEffect = child as SummonEffect
			if sx.source == creature or sx.target == creature:
				sx.queue_free()
		elif child is SkillProjectile:
			var px: SkillProjectile = child as SkillProjectile
			if px.target_creature == creature:
				px.queue_free()
		elif child is SkillProjectileCoordinator:
			var cx: SkillProjectileCoordinator = child as SkillProjectileCoordinator
			if cx.source == creature or cx.target == creature:
				cx.queue_free()

func _grant_rewards() -> void:
	if rewards_granted:
		return
	rewards_granted = true

	var mob := creature as Mob
	if not mob:
		return

	# Grant EXP to all alive party members
	var exp_amount: int = mob.exp_reward
	var money_amount: int = mob.money_reward

	if exp_amount > 0:
		for player in GameManager.get_alive_players():
			if player is Actor:
				(player as Actor).add_experience(exp_amount)

	# Grant money to party pool
	if money_amount > 0:
		GameManager.add_money(money_amount)
