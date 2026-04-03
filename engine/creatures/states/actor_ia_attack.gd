class_name ActorIAAttack
extends State
## AI ATTACK state - replaces fsm_ia_attack from GMS2
## Executes weapon attack, creates hitbox, detects hits.

var target: Node = null
var weapon_id: int = 0
var weapon_attack_type: int = Constants.WeaponAttackType.SLASH
var attack_kind: int = 0
var attack_hit_successful: bool = false
var timer_end_attack: float = 0.0
var weapon_timeout: float = 0.417
var hitbox: Node = null
var goto_near_player: bool = false

func enter() -> void:
	var actor := creature as Actor
	if not actor:
		switch_to("IAGuard")
		return

	target = state_machine.get_state_var(0, null)
	goto_near_player = state_machine.get_state_var(1, false)

	if not is_instance_valid(target):
		switch_to("IAGuard")
		return

	weapon_id = actor.equipped_weapon_id
	attack_hit_successful = false
	timer_end_attack = 0.0
	creature.attacking = target

	# Determine attack type
	attack_kind = randi_range(0, 2)
	# GMS2: Only the spear overrides weaponAttackTypeEquiped dynamically.
	# All other weapons use the value from equipment data (actor.weapon_attack_type).
	if weapon_id == Constants.Weapon.SPEAR:
		if attack_kind <= 0:
			weapon_attack_type = Constants.WeaponAttackType.PIERCE
		elif attack_kind == 1:
			weapon_attack_type = Constants.WeaponAttackType.SLASH
		else:
			weapon_attack_type = Constants.WeaponAttackType.SWING
	else:
		weapon_attack_type = actor.weapon_attack_type

	# Play weapon sound
	var weapon_name := actor.get_weapon_name()
	MusicManager.play_sfx("snd_%s" % weapon_name)
	creature.disable_shader()

	# Face target
	var dir: Vector2 = (target.global_position - creature.global_position)
	if dir.length() > 1.0:
		creature.facing = creature.get_facing_from_direction(dir)

	# Set attack animation
	creature.set_default_facing_animations(
		actor.subimg_attack_up_ini[weapon_attack_type],
		actor.subimg_attack_right_ini[weapon_attack_type],
		actor.subimg_attack_down_ini[weapon_attack_type],
		actor.subimg_attack_left_ini[weapon_attack_type],
		actor.subimg_attack_up_end[weapon_attack_type],
		actor.subimg_attack_right_end[weapon_attack_type],
		actor.subimg_attack_down_end[weapon_attack_type],
		actor.subimg_attack_left_end[weapon_attack_type]
	)
	creature.set_facing_frame(
		actor.subimg_attack_up_ini[weapon_attack_type],
		actor.subimg_attack_right_ini[weapon_attack_type],
		actor.subimg_attack_down_ini[weapon_attack_type],
		actor.subimg_attack_left_ini[weapon_attack_type]
	)
	creature._frame_accumulator = 0.0
	creature.image_speed = GameManager.weapon_image_attack_speed[weapon_id]

	weapon_timeout = GameManager.weapon_end_anim_timeout[weapon_id] / 60.0

	# Create hitbox (melee) or projectile (ranged)
	if weapon_id in [Constants.Weapon.BOW, Constants.Weapon.BOOMERANG, Constants.Weapon.JAVELIN]:
		Projectile.spawn(actor, weapon_id, creature.facing)
	else:
		_create_hitbox(actor)

	# Spawn weapon attack overlay sprite (GMS2: drawWeaponAttack)
	WeaponAttackSprite.spawn(actor, weapon_id, creature.facing, attack_kind, 0)

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# GMS2: AI movement is blocked during cutscenes (lock_all_players)
	if actor.movement_input_locked:
		actor.velocity = Vector2.ZERO
		return

	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# Check target validity
	if not is_instance_valid(target) or target.is_dead:
		switch_to("IAGuard")
		return

	timer_end_attack += delta

	# Detect damage with hitbox
	_detect_damage()

	# GMS2: applyWeaponAtunementEffect (Luna saber) can switch the actor to
	# StaticAnimation mid-attack via apply_healed_pose(). If the state machine
	# already moved away from IAAttack, stop executing attack logic so we don't
	# overwrite the new state's frame/animation (e.g., healed pose frame 195-198).
	if state_machine.current_state != self:
		return

	# Animate attack
	creature.animate_sprite(-1.0, true)

	if timer_end_attack > weapon_timeout:
		if not attack_hit_successful:
			MusicManager.play_sfx("snd_parry")
			if goto_near_player:
				switch_to("IAGuard")
			else:
				state_machine.set_state_var(0, target)
				switch_to("IAPrepareAttack")
		else:
			if goto_near_player:
				switch_to("IAGuard")
			else:
				state_machine.set_state_var(0, target)
				switch_to("IAGuardTarget")

		# GMS2: startOverheating() — sets overheat=0 and begins fill-up
		actor.start_overheating()

func exit() -> void:
	if hitbox and is_instance_valid(hitbox):
		hitbox.queue_free()
		hitbox = null
	creature.velocity = Vector2.ZERO
	creature.attacking = null
	var actor := creature as Actor
	if actor:
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)

func _create_hitbox(actor: Actor) -> void:
	if hitbox and is_instance_valid(hitbox):
		hitbox.queue_free()

	var hitbox_scene: PackedScene = preload("res://scenes/effects/weapon_hitbox.tscn")
	hitbox = hitbox_scene.instantiate()
	hitbox.setup(actor, weapon_id, weapon_attack_type)
	actor.get_parent().add_child(hitbox)
	hitbox.global_position = actor.global_position

func _detect_damage() -> void:
	if hitbox and hitbox.has_method("get_overlapping_creatures"):
		for body in hitbox.get_overlapping_creatures():
			# GMS2: getTargetKind() — actors can only hit mobs, not other actors
			if body is Mob and body != creature and not body.is_invulnerable:
				if not body.attacked:
					var result: Dictionary = DamageCalculator.perform_attack(body, creature, Constants.AttackType.WEAPON)
					body.attacked = true
					if not result.is_miss and not result.is_parry:
						attack_hit_successful = true
						# Award weapon EXP on successful hit
						if creature is Actor:
							var actor := creature as Actor
							actor.add_weapon_experience(actor.get_weapon_name(), 1)
