class_name ActorDead
extends State
## Actor DEAD state - replaces fsm_actor_dead from GMS2
## Handles: death flag, status clear, input transfer, collision disable,
## ghost shader, reaper effect, game over check, and revive restore.

static var _reaper_script: GDScript = null
static var _ghost_shader: Shader = null

func enter() -> void:
	# --- Core death state (GMS2: fsm_actor_dead state_new) ---
	creature.is_dead = true
	creature.velocity = Vector2.ZERO
	creature.state_protect = true
	creature.attribute.hp = 0
	creature.attribute.hpPercent = 0.0

	# Clear all statuses (GMS2: dispelBuffs + cureAilments)
	creature.dispel_buffs()
	creature.cure_ailments()

	# Clear damage stack (GMS2: ds_queue_clear(battle_damageStack))
	creature.damage_stack.clear()

	# GMS2: deleteSkillAnimations - clean up orphaned skill effects targeting this creature
	_cleanup_skill_effects()

	# Transfer player input to next alive actor (GMS2: switchPlayerInput)
	if creature.player_controlled and GameManager.is_party_alive():
		GameManager.swap_actor()

	# Disable collision (GMS2: solid = false)
	# Store original values for restore on revive
	_saved_collision_layer = creature.collision_layer
	_saved_collision_mask = creature.collision_mask
	creature.collision_layer = 0
	creature.collision_mask = 0

	# Apply ghost shader (GMS2: enableShader(shc_ghost))
	if _ghost_shader == null:
		_ghost_shader = load("res://assets/shaders/sha_ghost.gdshader") as Shader
	if _ghost_shader:
		var ghost_mat := ShaderMaterial.new()
		ghost_mat.shader = _ghost_shader
		creature.enable_shader(ghost_mat)
	else:
		# Fallback: semi-transparent modulate
		creature.modulate = Color(0.5, 0.5, 0.5, 0.7)

	# GMS2: dead actor shows standing ghost sprite — set the stand frame
	# so the ghost is visible (hit animation may have left current_frame
	# past the valid spritesheet range, rendering as invisible)
	creature.image_speed = 0
	creature.set_facing_frame(
		creature.spr_stand_up,
		creature.spr_stand_right,
		creature.spr_stand_down,
		creature.spr_stand_left
	)

	# Spawn reaper death animation (GMS2: oMisc_reaper)
	_spawn_reaper()

	# Game over check (GMS2: if getNumberAlivePlayers() <= 0)
	if GameManager.get_alive_players().size() <= 0:
		_trigger_game_over()

var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0

func _spawn_reaper() -> void:
	if _reaper_script == null:
		_reaper_script = load("res://engine/effects/reaper_effect.gd") as GDScript
	if _reaper_script:
		_reaper_script.spawn(creature)

func _trigger_game_over() -> void:
	var scene_root: Node = creature.get_tree().current_scene if creature.get_tree() else null
	if not scene_root:
		return
	var game_over_node := SceneGameOver.new()
	scene_root.add_child(game_over_node)

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

func execute(_delta: float) -> void:
	# Stay in dead state until revived
	if not creature.is_dead:
		# Restore collision (GMS2: solid = true on revive)
		creature.collision_layer = _saved_collision_layer
		creature.collision_mask = _saved_collision_mask
		# Remove ghost shader
		creature.disable_shader()
		creature.modulate = Color.WHITE
		creature.state_protect = false
		switch_to("Stand")
