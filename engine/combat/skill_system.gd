class_name SkillSystem
extends RefCounted
## Magic/skill casting system - replaces skill_generic and castMagic from GMS2
## Now instantiates SkillEffect scenes for visual feedback instead of applying effects directly.

const SKILL_EFFECT_SCENE: PackedScene = preload("res://scenes/effects/skill_effect.tscn")
const SKILL_PROJECTILE_SCENE: PackedScene = preload("res://scenes/effects/skill_projectile.tscn")

## Skills that use projectile system instead of direct animation
## Note: fireball uses SkillEffect custom handler (_step_fireball) for GMS2-accurate homing projectiles
const PROJECTILE_SKILLS: Array[String] = ["gemMissile"]

## Number of projectiles per skill
const PROJECTILE_COUNTS: Dictionary = {
	"gemMissile": 3,
}

static func cast_skill(skill_name: String, source: Creature, target: Creature, level: int = 0, target_all: bool = false) -> Dictionary:
	var skill_data: Dictionary = Database.get_skill(skill_name)
	if skill_data.is_empty():
		push_warning("Skill not found: " + skill_name)
		return {"success": false, "reason": "not_found"}

	# GMS2: Check if source can cast (silenced, pygmized, transformed, frozen, etc.)
	if source.is_magic_blocked():
		MusicManager.play_sfx("snd_parry")
		return {"success": false, "reason": "magic_blocked"}

	# Check MP cost
	var mp_cost: int = skill_data.get("mp", 0)
	if source.attribute.mp < mp_cost:
		MusicManager.play_sfx("snd_parry")
		return {"success": false, "reason": "no_mp"}

	# Check if skill is enabled
	if not skill_data.get("enabled", true):
		return {"success": false, "reason": "disabled"}

	# Consume MP
	source.reduce_mp(mp_cost)

	var target_type: String = skill_data.get("target", "ALLY")
	var target_qty: String = skill_data.get("targetQuantity", "TARGET_QUANTITY_ONE")

	# Resolve targets based on target type and user selection
	# GMS2: TARGET_QUANTITY_ALL means the user CAN select all, not that it always targets all.
	# If the user selected a single target (target_all == false), treat as TARGET_QUANTITY_ONE.
	var targets: Array = _resolve_targets(source, target, target_type, target_qty, target_all)

	# Spawn visual effects for all targets
	var valid_target_count: int = 0
	for t in targets:
		if is_instance_valid(t):
			valid_target_count += 1
	for t in targets:
		if not is_instance_valid(t):
			continue
		_spawn_skill_effect(skill_data, source, t, level, valid_target_count)

	# Grant deity EXP to source (if actor)
	_grant_deity_exp(skill_data, source)

	return {"success": true, "skill": skill_data, "targets": targets}


static func _spawn_skill_effect(skill_data: Dictionary, source: Creature, target: Creature, level: int, target_count: int = 1) -> void:
	var sname: String = skill_data.get("name", "")

	# Check if this skill uses projectiles
	if sname in PROJECTILE_SKILLS:
		_spawn_projectile_skill(skill_data, source, target, level)
		return

	# Standard skill effect: animation over target, then apply effect
	var effect: SkillEffect = SKILL_EFFECT_SCENE.instantiate() as SkillEffect
	effect.setup(source, target, skill_data, level)
	effect.total_affected_targets = target_count

	# Add to the game world (same parent as creatures)
	var world: Node = source.get_parent()
	if world:
		world.add_child(effect)
	else:
		source.get_tree().current_scene.add_child(effect)


static func _spawn_projectile_skill(skill_data: Dictionary, source: Creature, target: Creature, level: int) -> void:
	var sname: String = skill_data.get("name", "")
	var count: int = PROJECTILE_COUNTS.get(sname, 1)
	var world: Node = source.get_parent()
	if not world:
		world = source.get_tree().current_scene

	# Create a coordinator effect that waits for all projectiles to hit
	var coordinator := SkillProjectileCoordinator.new()
	coordinator.setup(source, target, skill_data, level, count)
	world.add_child(coordinator)

	# Spawn projectiles with different starting angles
	var base_angle: float = source.global_position.angle_to_point(target.global_position)
	var spread: float = PI / 3.0  # 60 degrees spread

	for i in count:
		var proj: SkillProjectile = SKILL_PROJECTILE_SCENE.instantiate() as SkillProjectile
		var angle_offset: float = 0.0
		if count > 1:
			angle_offset = spread * (float(i) / float(count - 1) - 0.5)
		var proj_angle: float = base_angle + angle_offset

		proj.setup(
			source.global_position + Vector2(0, -10),
			target.global_position + Vector2(0, -10),
			target,
			i * 8.0 / 60.0,  # stagger delay (8 frames apart, converted to seconds)
			i,
			proj_angle,
			sname
		)
		proj.projectile_hit.connect(coordinator._on_projectile_hit)
		world.add_child(proj)


static func _resolve_targets(source: Creature, primary_target: Creature, target_type: String, target_qty: String, target_all: bool = false) -> Array:
	## GMS2: target types are relative to the caster's perspective.
	## "ALLY" = same side as caster, "ENEMY" = opposite side.
	## Skills are defined from the player perspective, so when a mob casts them,
	## ALLY/ENEMY must be inverted.
	##
	## GMS2: TARGET_QUANTITY_ALL means the skill CAN target all, but the user can also
	## select a single target. Only expand to all if user chose "All" (target_all == true)
	## or if the skill is TARGET_QUANTITY_ONLY_ALL (always all, no single selection).
	var source_is_player: bool = source is Actor and not source.is_npc
	var targets: Array = []
	match target_qty:
		"TARGET_QUANTITY_SELF":
			targets.append(source)
		"TARGET_QUANTITY_ALL":
			# GMS2: For player-cast skills, target_all reflects user's ring menu choice.
			# For mob/boss-cast skills (no ring menu), always expand to all targets.
			var should_target_all: bool = target_all or not source_is_player
			if should_target_all:
				# Expand to all valid targets
				if target_type == "ALLY":
					if source_is_player:
						targets = GameManager.get_alive_players()
					else:
						targets = source.get_tree().get_nodes_in_group("mobs")
				elif target_type == "ENEMY":
					if source_is_player:
						targets = source.get_tree().get_nodes_in_group("mobs")
					else:
						targets = GameManager.get_alive_players()
				else:
					targets.append(primary_target)
			else:
				# Player selected a single target in ring menu - respect that choice
				targets.append(primary_target)
		"TARGET_QUANTITY_ONLY_ALL":
			# Always target all (no single selection allowed)
			if target_type == "ALLY":
				if source_is_player:
					targets = GameManager.get_alive_players()
				else:
					targets = source.get_tree().get_nodes_in_group("mobs")
			elif target_type == "ENEMY":
				if source_is_player:
					targets = source.get_tree().get_nodes_in_group("mobs")
				else:
					targets = GameManager.get_alive_players()
			else:
				targets.append(primary_target)
		"TARGET_QUANTITY_DEAD":
			targets = GameManager.get_dead_players()
		_:  # TARGET_QUANTITY_ONE or default
			targets.append(primary_target)
	return targets


static func _grant_deity_exp(data: Dictionary, source: Creature) -> void:
	if not source is Actor:
		return
	var deity_name: String = data.get("deity", "")
	if deity_name.is_empty():
		return
	var element_idx: int = -1
	match deity_name:
		"Undine": element_idx = Constants.Element.UNDINE
		"Gnome": element_idx = Constants.Element.GNOME
		"Sylphid": element_idx = Constants.Element.SYLPHID
		"Salamando": element_idx = Constants.Element.SALAMANDO
		"Shade": element_idx = Constants.Element.SHADE
		"Luna": element_idx = Constants.Element.LUNA
		"Lumina": element_idx = Constants.Element.LUMINA
		"Dryad": element_idx = Constants.Element.DRYAD
	if element_idx >= 0:
		var actor := source as Actor
		if element_idx < actor.deity_levels.size():
			if actor.deity_levels[element_idx] < 8:
				actor.deity_levels[element_idx] += 1
