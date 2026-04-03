class_name BossDarkLichDead
extends State
## Dark Lich DEAD state - replaces fsm_boss_dead from GMS2
## Spawns boss explosion sequence, then triggers post-death cutscene (oSce_darkLich2)

var _explosion_spawned: bool = false
var _music_stop_timer: float = 0.0

func enter() -> void:
	creature.is_dead = true
	creature.velocity = Vector2.ZERO
	creature.is_invulnerable = true
	creature.damage_stack.clear()
	creature.modulate.a = 1.0
	_music_stop_timer = 0.0

	# GMS2: removeBalloon + removeEngulf + deleteSkillAnimations
	creature.dispel_buffs()
	creature.cure_ailments()
	_cleanup_skill_effects()

	# GMS2: set phase-aware hurt animation (HANDS=82-83, FULLBODY=72-80)
	var boss := creature as BossDarkLich
	if boss:
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
		# GMS2: image_speed = state_imgSpeedAttack = 0.2 (not 0.1)
		creature.image_speed = (creature as Mob).img_speed_attack
		# GMS2 Draw_0: switch to death palette (pal_darkLich_headDeath, 9 columns, slow)
		boss.enable_death_palette()

	# GMS2: snd_bossExplode plays later in explosion phase 2, NOT here
	# (the explosion sequence at boss_explosion.gd phase 2 handles it)

	# Spawn boss explosion effect (GMS2: oAni_bossExplode)
	if not _explosion_spawned:
		_explosion_spawned = true
		var explosion := BossExplosion.spawn_dark_lich_explosion(creature)
		if explosion:
			explosion.explosion_finished.connect(_on_explosion_finished)

	# Emit boss_defeated signal
	if creature.has_signal("boss_defeated"):
		creature.boss_defeated.emit()

func execute(delta: float) -> void:
	if not is_instance_valid(creature) or not creature.visible:
		return
	# GMS2: animateSprite(image_speed, phase == PHASE_FULLBODY)
	# FULLBODY stops on last frame, HANDS loops
	var boss := creature as BossDarkLich
	var stop_last: bool = boss != null and boss.current_phase == BossDarkLich.Phase.FULLBODY
	creature.animate_sprite(-1.0, stop_last)
	# GMS2: musicStop(1500) fires after 120 frames, not immediately
	_music_stop_timer += delta
	if _music_stop_timer >= 120 / 60.0:
		MusicManager.stop(0.67)  # 1/1.5s ≈ 0.67 fade speed

func _cleanup_skill_effects() -> void:
	## GMS2: deleteSkillAnimations - destroy active effects targeting this creature
	var world: Node = creature.get_parent()
	if not world:
		return
	for child in world.get_children():
		# Check source/target properties on effect nodes
		var src: Variant = child.get("source") if "source" in child else null
		var tgt: Variant = child.get("target") if "target" in child else null
		if (src == creature or tgt == creature) and child is not BossExplosion:
			child.queue_free()

func _on_explosion_finished() -> void:
	## Spawn post-death cutscene (GMS2: oSce_darkLich2)
	if not is_instance_valid(creature):
		return

	var tree: SceneTree = creature.get_tree()
	if not tree:
		return

	# Enable the exit teleport in the room
	var teleports := tree.get_nodes_in_group("teleport")
	for tp in teleports:
		if tp.has_method("set_enabled"):
			tp.set_enabled(true)
		elif tp is Area2D:
			tp.monitoring = true
			tp.monitorable = true

	# Spawn post-fight cutscene
	var post_scene: SceneEvent = SceneDarkLich2.new()
	tree.current_scene.add_child(post_scene)

	# Now safe to free the creature (BossExplosion only hid it)
	creature.queue_free()
