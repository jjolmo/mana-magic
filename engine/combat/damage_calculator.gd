class_name DamageCalculator
extends RefCounted
## Damage calculation - full port of performAttack() from GMS2

static func perform_attack(target: Creature, source: Creature, attack_type: int, element: int = -1, skill_level: int = 0) -> Dictionary:
	var result := {
		"damage": 0,
		"is_critical": false,
		"is_miss": false,
		"is_parry": false,
		"source": source,
		"target": target,
		"attack_type": attack_type,
	}

	if not is_instance_valid(target) or not is_instance_valid(source):
		return result

	# Check invulnerability
	if target.is_invulnerable:
		result.is_miss = true
		return result

	# GMS2: isBusy check - skip damage if target is already in HIT/HIT2/SUMMON state
	if target.state_machine_node:
		var cur_state: String = target.state_machine_node.current_state_name
		if cur_state in ["Hit", "Hit2", "Summon"]:
			result.is_miss = true
			return result

	# GMS2: maxHitsStackable = 1 - only 1 pending damage allowed
	if target.damage_stack.size() >= 1:
		result.is_miss = true
		return result

	# Check frozen/petrified/engulfed (no damage from physical attacks)
	# GMS2: if (type == ATTACKTYPE_WEAPON && (targetFrozen || targetPetrified || targetEngulfed)) return 0
	if attack_type == Constants.AttackType.WEAPON:
		if target.has_status(Constants.Status.FROZEN) or \
		   target.has_status(Constants.Status.PETRIFIED) or \
		   target.has_status(Constants.Status.ENGULFED):
			result.is_parry = true
			return result

	var damage: float = 0.0

	match attack_type:
		Constants.AttackType.WEAPON, Constants.AttackType.ETEREAL, Constants.AttackType.FAINT:
			# GMS2: WEAPON, ETEREAL, FAINT all use weapon damage formula (STR-CON)
			damage = _calc_weapon_damage(target, source, result)
		Constants.AttackType.MAGIC:
			damage = _calc_magic_damage(target, source, element, skill_level)
		Constants.AttackType.ELEMENTAL:
			damage = _calc_elemental_damage(target, source, element, skill_level)
		Constants.AttackType.DRAIN, Constants.AttackType.DRAIN_HEALTH:
			damage = _calc_drain_health_damage(target, source, element, skill_level)
		Constants.AttackType.DRAIN_MAGIC:
			damage = _calc_drain_magic_damage(target, source, element, skill_level)
		Constants.AttackType.ULTIMATE:
			# GMS2: calculates (STR + gear) * 4, then overwrites to flat 200
			damage = 200.0
		_:
			damage = _calc_weapon_damage(target, source, result)

	# GMS2: critical check applies to ALL attack types (after damage calc)
	if damage > 0:
		var crit_rate: float = source.get_critical_rate()
		if randf() * 100.0 <= crit_rate:
			result.is_critical = true
			var crit_mult: float = float(source.attribute.get("criticalMultiplier", 2.0))
			damage *= crit_mult

	# GMS2: DRAIN_MAGIC halved after crit (before oscillation)
	if attack_type == Constants.AttackType.DRAIN_MAGIC and damage > 0:
		damage /= 2.0

	# GMS2: rollRandomOscillation(damageDone, source.attribute.randomDamagePercent)
	var rdp: float = source.attribute.get("randomDamagePercent", 15.0)
	var rnd_pct: float = randf_range(-rdp, rdp) / 100.0
	damage += damage * rnd_pct

	# GMS2: Wall redirects magic to a random creature on the CASTER'S team (spell bounce)
	# Unless source has pierceMagic (Mana Beast)
	if attack_type == Constants.AttackType.MAGIC and target.has_status(Constants.Status.WALL):
		var pierce: bool = source.get("pierce_magic") if source.get("pierce_magic") != null else false
		if not pierce:
			var redirected: Creature = _get_random_creature_on_team(source)
			if redirected and is_instance_valid(redirected):
				target = redirected
				result.target = target

	# GMS2: Lucid Barrier causes full MISS/PARRY for non-ethereal attacks
	# Only ATTACKTYPE_ETEREAL bypasses Lucid Barrier
	if target.has_status(Constants.Status.LUCID_BARRIER) and \
	   attack_type != Constants.AttackType.ETEREAL:
		result.is_parry = true
		_spawn_text_number(target, "BLOCK", Color(0.5, 0.8, 1.0))
		return result

	# Clamp damage
	damage = clamp(damage, 0, Constants.DAMAGE_LIMIT)

	# GMS2: drain clamping (after damage limit, before application)
	if attack_type in [Constants.AttackType.DRAIN, Constants.AttackType.DRAIN_HEALTH]:
		damage = minf(damage, float(target.attribute.hp))
	elif attack_type == Constants.AttackType.DRAIN_MAGIC:
		damage = minf(damage, float(target.attribute.mp))

	result.damage = roundi(damage)

	# Apply damage to target
	if result.damage > 0 and not result.is_miss and not result.is_parry:
		# GMS2: source.lastCreatureAttacked = target (in performAttack)
		source.last_creature_attacked = target

		if attack_type == Constants.AttackType.DRAIN_MAGIC:
			# GMS2: DRAIN_MAGIC removes MP directly, does NOT go into HP damage stack
			# reduce_mp() handles its own floating text display
			target.reduce_mp(result.damage)
		else:
			target.apply_damage(result.damage)

			# GMS2: cache push direction (source→target) for knockback/facing in hit states
			var push_dir: Vector2 = Vector2.DOWN
			if is_instance_valid(source) and is_instance_valid(target):
				push_dir = (target.global_position - source.global_position).normalized()
				if push_dir.length() < 0.1:
					push_dir = Vector2.DOWN

			# Add to damage stack for hit reaction
			target.damage_stack.append({
				"damage": result.damage,
				"source": source,
				"attack_type": attack_type,
				"is_critical": result.is_critical,
				"push_dir": push_dir,
			})

			# Spawn floating damage number (GMS2: oBTL_counter)
			_spawn_damage_number(target, result.damage, result.is_critical, attack_type)

			# GMS2: applyWeaponAtunementEffect - saber proc on weapon hits
			if attack_type == Constants.AttackType.WEAPON:
				_apply_weapon_atunement(target, source, result.damage)

	elif result.is_miss:
		_spawn_text_number(target, "MISS", Color(0.7, 0.7, 0.7))
	elif result.is_parry:
		_spawn_text_number(target, "BLOCK", Color(0.5, 0.8, 1.0))

	return result

static func _calc_weapon_damage(target: Creature, source: Creature, result: Dictionary) -> float:
	# GMS2: source_totalAttack = getStrength(source) + gear[STRENGTH]
	#        target_totalDefense = getConstitution(target) + gear[CONSTITUTION]
	#        damageDone = (source_totalAttack * attackMultiplier) - (target_totalDefense * attackDivisor)
	var str_val := float(source.get_strength()) + float(source.attribute.gear.get("strength", 0))
	var con_val := float(target.get_constitution()) + float(target.attribute.gear.get("constitution", 0))

	var damage: float = (str_val * source.attribute.attackMultiplier) - (con_val * source.attribute.attackDivisor)
	damage = max(1, damage)

	# Weapon level & overheat (actors only, GMS2: !source.creatureIsMob)
	if source is Actor:
		var actor := source as Actor

		# GMS2: damageDone = damageDone * overheat / overheatTotal
		if actor.attribute.overheat > 0:
			var oh_total: float = actor.attribute.get("overheatTotal", 100.0)
			damage = damage * actor.attribute.overheat / oh_total

		# GMS2: damageDone *= (weaponLevelDamageMultiplier * (level+1)) + 1
		var weapon_name := actor.get_weapon_name()
		var weapon_level: int = actor.equipment_current_level.get(weapon_name, 0)
		if weapon_level > 0 and damage > 0:
			var wlm: float = actor.attribute.get("weaponLevelDamageMultiplier", 0.6)
			damage *= (wlm * float(weapon_level + 1)) + 1.0

	# GMS2: Holy-class mobs (Mana Beast) are unhittable without MANA_MAGIC status
	# rollHit: if target is holy + source has MANA_MAGIC -> guaranteed hit
	# performAttack: if target is holy mob + source lacks MANA_MAGIC -> forced miss
	var _target_is_holy: bool = (target is Mob and (target as Mob).mob_class_name == "holy")
	if _target_is_holy:
		if source.has_status(Constants.Status.BUFF_MANA_MAGIC):
			pass  # Guaranteed hit, skip roll
		else:
			result.is_miss = true
			return 0

	# Hit check - GMS2 rollHit formula:
	# hitChance = hitBase + (levelDiff * hitMultiplier) + getHitRate(source) - getEvadeRate(target)
	# getHitRate = getCriticalRate/hitCriticalDivisor + getAgility/hitAgilityDivisor
	# getEvadeRate = getCriticalRate/evadeCriticalDivisor + getAgility/evadeAgilityDivisor
	# Defaults: hitBase=100, hitMultiplier=4.5, hitCritDivisor=3, hitAgiDivisor=3,
	#           evadeCritDivisor=9, evadeAgiDivisor=9
	var level_diff: float = float(source.attribute.level) - float(target.attribute.level)
	var hit_rate: float = 100.0 + (level_diff * 4.5)
	hit_rate += source.get_critical_rate() / 3.0 + float(source.get_agility()) / 3.0
	hit_rate -= target.get_critical_rate() / 9.0 + float(target.get_agility()) / 9.0
	# GMS2: no clamping on hitChance — can go negative (always miss) or >100 (always hit)
	if randf() * 100.0 > hit_rate:
		result.is_miss = true
		return 0

	# Saber weapon enchantment: add elemental modifier to weapon attacks
	# GMS2: loops source.elementalAtunement, calls calculateElementalDamage per active element
	# calculateElementalDamage only applies weakness/strength multipliers, no INT bonus
	var saber_element: int = _get_saber_element(source)
	if saber_element >= 0 and saber_element < Constants.ELEMENT_COUNT:
		damage *= target.get_elemental_damage_multiplier(saber_element, Constants.AttackType.WEAPON)

	return damage


static func _get_saber_element(source: Creature) -> int:
	## Check if creature has an active saber buff, return element index or -1
	if source.has_status(Constants.Status.BUFF_WEAPON_UNDINE):
		return Constants.Element.UNDINE
	if source.has_status(Constants.Status.BUFF_WEAPON_GNOME):
		return Constants.Element.GNOME
	if source.has_status(Constants.Status.BUFF_WEAPON_SYLPHID):
		return Constants.Element.SYLPHID
	if source.has_status(Constants.Status.BUFF_WEAPON_SALAMANDO):
		return Constants.Element.SALAMANDO
	if source.has_status(Constants.Status.BUFF_WEAPON_SHADE):
		return Constants.Element.SHADE
	if source.has_status(Constants.Status.BUFF_WEAPON_LUNA):
		return Constants.Element.LUNA
	if source.has_status(Constants.Status.BUFF_WEAPON_LUMINA):
		return Constants.Element.LUMINA
	if source.has_status(Constants.Status.BUFF_WEAPON_DRYAD):
		return Constants.Element.DRYAD
	return -1

static func _calc_magic_damage(target: Creature, source: Creature, element: int, skill_level: int) -> float:
	# GMS2: source_totalAttack = INT*2 + gear_INT*2 + (INT/4 * (deityLevel+1))
	#        target_totalDefense = (WIS/4 + gear_WIS) / 4
	var int_val := float(source.get_intelligence())
	var gear_int := float(source.attribute.gear.get("intelligence", 0))
	# skill_level maps to GMS2 deityLevel
	var magic_level_dmg := (int_val / 4.0) * float(skill_level + 1)
	var source_attack := int_val * 2.0 + gear_int * 2.0 + magic_level_dmg

	var wis_val := float(target.get_wisdom())
	var gear_wis := float(target.attribute.gear.get("wisdom", 0))
	var target_defense := (wis_val / 4.0 + gear_wis) / 4.0

	var damage := source_attack - target_defense
	damage = max(1, damage)

	# Elemental modifiers (GMS2: calculateElementalDamage with ATTACKTYPE_MAGIC)
	# GMS2 only applies target weakness/strength, NO source atunement bonus
	if element >= 0 and element < Constants.ELEMENT_COUNT:
		damage *= target.get_elemental_damage_multiplier(element, Constants.AttackType.MAGIC)

	return damage

static func _calc_elemental_damage(target: Creature, source: Creature, element: int, _skill_level: int) -> float:
	var damage := float(source.get_intelligence()) * 1.5
	if element >= 0 and element < Constants.ELEMENT_COUNT:
		damage *= target.get_elemental_damage_multiplier(element, Constants.AttackType.ELEMENTAL)
	return max(1, damage)

## GMS2 DRAIN_HEALTH: uses magic damage formula.
## Clamping to target HP and source healing handled in perform_attack / skill_effect.gd.
static func _calc_drain_health_damage(target: Creature, source: Creature, element: int, skill_level: int) -> float:
	return _calc_magic_damage(target, source, element, skill_level)

## GMS2 DRAIN_MAGIC: uses magic damage formula.
## Division by 2 and MP clamping handled in perform_attack.
## Source MP restore handled in skill_effect.gd (magicAbsorb).
static func _calc_drain_magic_damage(target: Creature, source: Creature, element: int, skill_level: int) -> float:
	return _calc_magic_damage(target, source, element, skill_level)

static func perform_heal(target: Creature, source: Creature, base_heal: int, skill_level: int = 0) -> int:
	var heal := float(base_heal)
	heal += float(source.get_wisdom()) * 2.0
	heal *= (1.0 + skill_level * 0.15)
	var final_heal := roundi(heal)
	target.apply_heal(final_heal)

	# Spawn floating heal number (GMS2: oBTL_counter HP_GAIN)
	if final_heal > 0 and is_instance_valid(target):
		var scene_root: Node = target.get_tree().current_scene if target.get_tree() else null
		if scene_root:
			FloatingNumber.spawn(scene_root, target, final_heal, FloatingNumber.CounterType.HP_GAIN)

	return final_heal


# --- Floating number helpers (GMS2: oBTL_counter) ---

static func _spawn_damage_number(target: Creature, damage: int, _is_critical: bool, _attack_type: int) -> void:
	if not is_instance_valid(target):
		return
	var scene_root: Node = target.get_tree().current_scene if target.get_tree() else null
	if not scene_root:
		return

	# GMS2: showCounter(target, damage, !target.creatureIsMob)
	# If target is mob → COUNTERTYPE_HP_DONE (white, damage dealt to enemy)
	# If target is player → COUNTERTYPE_HP_LOSS (red, damage received)
	var is_player_target: bool = target is Actor
	var counter_type: int = FloatingNumber.CounterType.HP_LOSS if is_player_target else FloatingNumber.CounterType.HP_DONE
	FloatingNumber.spawn(scene_root, target, damage, counter_type)


static func _spawn_text_number(target: Creature, text: String, text_color: Color) -> void:
	if not is_instance_valid(target):
		return
	var scene_root: Node = target.get_tree().current_scene if target.get_tree() else null
	if not scene_root:
		return
	FloatingNumber.spawn_text(scene_root, target.global_position, text, text_color)


# --- Weapon atunement / saber proc (GMS2: applyWeaponAtunementEffect) ---

static func _apply_weapon_atunement(target: Creature, source: Creature, damage_done: int) -> void:
	## Saber enchantments can proc status effects on weapon hits.
	## GMS2: only Undine/Gnome/Salamando proc statuses; Luna heals source.
	if not is_instance_valid(target) or not is_instance_valid(source):
		return

	# GMS2: saber proc duration uses setCreatureStatus which calculates wisdom-based debuff duration
	var proc_dur: int = Creature.calculate_debuff_duration(target.get_wisdom())

	if source.has_status(Constants.Status.BUFF_WEAPON_UNDINE):
		# GMS2: hitDivisor=3, calcDivisor=3
		if _roll_atunement_proc(source, 3.0, 3.0):
			target.set_status(Constants.Status.FROZEN, proc_dur)

	elif source.has_status(Constants.Status.BUFF_WEAPON_GNOME):
		# GMS2: hitDivisor=4, calcDivisor=3
		if _roll_atunement_proc(source, 4.0, 3.0):
			target.set_status(Constants.Status.PETRIFIED, proc_dur)

	elif source.has_status(Constants.Status.BUFF_WEAPON_SALAMANDO):
		# GMS2: hitDivisor=4, calcDivisor=3
		if _roll_atunement_proc(source, 4.0, 3.0):
			target.set_status(Constants.Status.ENGULFED, proc_dur)

	elif source.has_status(Constants.Status.BUFF_WEAPON_LUNA):
		# GMS2: Luna saber heals source for damage dealt (performHeal DIRECT)
		# GMS2: also shows healed pose for 90 frames + state_STATIC_ANIMATION
		if damage_done > 0:
			source.apply_heal(damage_done)
			var scene_root: Node = source.get_tree().current_scene if source.get_tree() else null
			if scene_root:
				FloatingNumber.spawn(scene_root, source, damage_done, FloatingNumber.CounterType.HP_GAIN)
			# GMS2: state_payload(sprHealed*, 90, image_speed) + state_switch(state_STATIC_ANIMATION)
			apply_healed_pose(source, 90)


static func _roll_atunement_proc(source: Creature, hit_divisor: float, calc_divisor: float) -> bool:
	## GMS2: hit = floor(random_range(0,100))
	##        intCalc = INT / calcDivisor
	##        successHit = hit > (100 / hitDivisor) + intCalc
	var hit: float = floorf(randf() * 100.0)
	var int_calc: float = float(source.get_intelligence()) / calc_divisor
	return hit > (100.0 / hit_divisor) + int_calc

static func _get_random_creature_on_team(source: Creature) -> Creature:
	## GMS2: getRandomCreatureOnTeam - returns random alive creature on the caster's team.
	## Used by Wall spell redirect: bounces magic back to caster's side.
	var candidates: Array[Creature] = []
	if source is Actor:
		# Source is a player - redirect to a random alive player
		for player in GameManager.get_alive_players():
			if player is Creature:
				candidates.append(player as Creature)
	else:
		# Source is a mob - redirect to a random alive mob
		for mob in source.get_tree().get_nodes_in_group("mobs"):
			if mob is Creature and not (mob as Creature).is_dead and is_instance_valid(mob):
				candidates.append(mob as Creature)
	if candidates.is_empty():
		return source  # Fallback: hit the caster
	return candidates[randi() % candidates.size()]


## GMS2: state_payload(sprHealedUp/Right/Down/Left, duration, speed) + state_switch(state_STATIC_ANIMATION)
## Reusable helper to show the "healed" directional pose on any Actor.
## Used by Moon Saber (applyWeaponAtunementEffect), healParty, etc.
static func apply_healed_pose(creature: Creature, duration: int = 90) -> void:
	if not is_instance_valid(creature) or creature.is_dead:
		return
	if not creature.state_machine_node:
		return
	if not creature is Actor:
		return
	# GMS2: canChangeAnim — skip if creature has disabling statuses
	if creature.has_status(Constants.Status.FAINT) or \
	   creature.has_status(Constants.Status.PETRIFIED) or \
	   creature.has_status(Constants.Status.ENGULFED) or \
	   creature.has_status(Constants.Status.BALLOON) or \
	   creature.has_status(Constants.Status.FROZEN):
		return
	var actor := creature as Actor
	creature.state_machine_node.set_state_var(0, actor.spr_healed_up)
	creature.state_machine_node.set_state_var(1, actor.spr_healed_right)
	creature.state_machine_node.set_state_var(2, actor.spr_healed_down)
	creature.state_machine_node.set_state_var(3, actor.spr_healed_left)
	creature.state_machine_node.set_state_var(4, duration)
	creature.state_machine_node.set_state_var(5, creature.image_speed)
	if creature.state_machine_node.has_state("StaticAnimation"):
		creature.state_machine_node.switch_state("StaticAnimation")
