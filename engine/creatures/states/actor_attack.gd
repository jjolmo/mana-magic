class_name ActorAttack
extends State
## Actor ATTACK state - replaces fsm_actor_attack from GMS2

var attack_chain: int = 1
var missed_combo: bool = false
var charging_counter: float = 0.0
var charging_counter_max: float = 1.0
var attack_end: bool = false
var _chain_started: bool = false  # Used to run once-per-chain init (replaces timer == 1 check)
var weapon_id: int = 0
var weapon_attack_type: int = Constants.WeaponAttackType.SLASH
var attack_kind: int = 0
var hitbox: Node = null
var weapon_sprite: WeaponAttackSprite = null

func enter() -> void:
	var actor := creature as Actor
	attack_chain = 1
	missed_combo = false
	charging_counter = 0.0
	charging_counter_max = actor.base_charging_counter / 60.0
	actor.attribute.walkSpeed = actor.attribute.walkSpeedAttacking1
	attack_end = false
	weapon_id = actor.equipped_weapon_id

	# Play weapon sound
	var weapon_name := actor.get_weapon_name()
	MusicManager.play_sfx("snd_%s" % weapon_name)

	actor.disable_shader()

	# Determine attack type based on weapon and randomness
	attack_kind = roundi(randf_range(0, 2))
	if actor.control_is_moving:
		attack_kind += 1
	else:
		attack_kind -= 1

	# GMS2: Only the spear overrides weaponAttackTypeEquiped dynamically based on
	# attackKind. For all other weapons, the animation type comes from the equipment
	# database (set via setPlayerEquipment → actor.weapon_attack_type).
	if weapon_id == Constants.Weapon.SPEAR:
		if attack_kind <= 0:
			weapon_attack_type = Constants.WeaponAttackType.PIERCE
		elif attack_kind == 1:
			weapon_attack_type = Constants.WeaponAttackType.SLASH
		else:
			weapon_attack_type = Constants.WeaponAttackType.SWING
	else:
		weapon_attack_type = actor.weapon_attack_type

	# Set attack animation ranges (so animate_sprite uses attack frames, not walk frames)
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

	# Create hitbox (melee) or projectile (ranged)
	if weapon_id in [Constants.Weapon.BOW, Constants.Weapon.BOOMERANG, Constants.Weapon.JAVELIN]:
		Projectile.spawn(actor, weapon_id, creature.facing)
	else:
		_create_hitbox(actor)

	# Spawn weapon attack overlay sprite (GMS2: drawWeaponAttack)
	weapon_sprite = WeaponAttackSprite.spawn(actor, weapon_id, creature.facing, attack_kind, 0)

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	var timer := get_timer()

	# Detect hits with hitbox
	_detect_damage()

	# GMS2: applyWeaponAtunementEffect (Luna saber) can switch the actor to
	# StaticAnimation mid-attack via apply_healed_pose(). If the state machine
	# already moved away from Attack, stop executing attack logic so we don't
	# overwrite the new state's frame/animation (e.g., healed pose frame 195-198).
	if state_machine.current_state != self:
		return

	# Handle attack chain animations
	if attack_chain == 1:
		_check_attack_finished(actor)
	elif attack_chain == 2:
		if not _chain_started:
			_chain_started = true
			creature.image_speed = GameManager.weapon_image_attack_speed[weapon_id]
			creature.set_facing_frame(
				actor.subimg_attack_up_ini[weapon_attack_type],
				actor.subimg_attack_right_ini[weapon_attack_type],
				actor.subimg_attack_down_ini[weapon_attack_type],
				actor.subimg_attack_left_ini[weapon_attack_type]
			)
			_create_hitbox(actor)
			_free_weapon_sprite()
			weapon_sprite = WeaponAttackSprite.spawn(actor, weapon_id, creature.facing, attack_kind, 0)
		_check_attack_finished(actor)
	elif attack_chain == 3:
		if not _chain_started:
			_chain_started = true
			actor.attribute.walkSpeed = actor.attribute.walkSpeedAttacking2
			creature.image_speed = actor.img_speed_attack_combo3
			creature.set_facing_frame(
				actor.subimg_attack_up_ini[weapon_attack_type],
				actor.subimg_attack_right_ini[weapon_attack_type],
				actor.subimg_attack_down_ini[weapon_attack_type],
				actor.subimg_attack_left_ini[weapon_attack_type]
			)
			_create_hitbox(actor)
			_free_weapon_sprite()
			weapon_sprite = WeaponAttackSprite.spawn(actor, weapon_id, creature.facing, attack_kind, 32)
		_check_attack_finished(actor)
		if timer > 40.0 / 60.0:
			attack_end = true

	# Lunge forward during combo attacks
	if timer >= 5.0 / 60.0 and timer <= 15.0 / 60.0 and attack_chain >= 2:
		var dir: Vector2 = creature.get_facing_direction()
		var _test_pos := actor.velocity
		actor.velocity = dir * actor.attribute.walkSpeed * 60.0
		actor.move_and_slide()

	# Check for combo input
	if not actor.is_movement_input_locked() and actor.control_attack_pressed and not missed_combo:
		if timer > 10.0 / 60.0 and attack_chain < 3:
			charging_counter = 0
			charging_counter_max += 20.0 / 60.0
			attack_chain += 1
			_chain_started = false
			state_machine.state_timer = 0.0
		else:
			missed_combo = true

	# Timeout check
	var timeout: float
	if attack_chain > 1:
		timeout = 25.0 / 60.0
	else:
		timeout = GameManager.weapon_end_anim_timeout[weapon_id] / 60.0

	# GMS2: During cutscenes (movement_input_locked), let the attack animation play
	# out instead of exiting immediately. Matches ActorIAAttack behavior (lines 96-99).
	if actor.is_movement_input_locked():
		actor.velocity = Vector2.ZERO
		creature.animate_sprite(-1.0, true)
		# Check if animation reached the end frame to exit the attack state
		var end_frame: int
		match creature.facing:
			Constants.Facing.UP: end_frame = actor.subimg_attack_up_end[weapon_attack_type]
			Constants.Facing.RIGHT: end_frame = actor.subimg_attack_right_end[weapon_attack_type]
			Constants.Facing.DOWN: end_frame = actor.subimg_attack_down_end[weapon_attack_type]
			Constants.Facing.LEFT: end_frame = actor.subimg_attack_left_end[weapon_attack_type]
			_: end_frame = actor.subimg_attack_down_end[weapon_attack_type]
		if creature.current_frame >= end_frame:
			actor.change_state_stand_dead()
		return

	if timer >= timeout and attack_chain < 3:
		attack_end = true

	if attack_end:
		actor.start_overheating()
		actor.change_state_stand_dead()

func exit() -> void:
	if hitbox and is_instance_valid(hitbox):
		hitbox.queue_free()
		hitbox = null
	_free_weapon_sprite()
	# Restore walk animation ranges
	var actor := creature as Actor
	if actor:
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)

func _free_weapon_sprite() -> void:
	if weapon_sprite and is_instance_valid(weapon_sprite):
		weapon_sprite.queue_free()
		weapon_sprite = null

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
					# Award weapon EXP on successful hit
					if not result.is_miss and not result.is_parry and creature is Actor:
						var actor := creature as Actor
						actor.add_weapon_experience(actor.get_weapon_name(), 1)

func _check_attack_finished(actor: Actor) -> void:
	# Check if animation reached end frame
	var _end_frame: int
	match creature.facing:
		Constants.Facing.UP: _end_frame = actor.subimg_attack_up_end[weapon_attack_type]
		Constants.Facing.RIGHT: _end_frame = actor.subimg_attack_right_end[weapon_attack_type]
		Constants.Facing.DOWN: _end_frame = actor.subimg_attack_down_end[weapon_attack_type]
		Constants.Facing.LEFT: _end_frame = actor.subimg_attack_left_end[weapon_attack_type]
		_: _end_frame = actor.subimg_attack_down_end[weapon_attack_type]

	creature.animate_sprite(-1.0, true)
