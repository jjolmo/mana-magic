class_name RabbigteChase
extends State
## Rabbigte CHASE state - replaces fsm_rabbigte_followActor from GMS2
## Uses rabite's follow behavior with higher bounce (4) + bounce angle rotation + castRandomSkill.
## GMS2: fsm_rabite_followActor(4); castRandomSkill(); fsm_rabbigte_bounceAngle();

enum Phase { WAIT, SELECT_POSITION, GO_POSITION }

var phase: int = Phase.WAIT
var waiting_timer: float = 0.0
var waiting_timer_limit: float = 1.0  # 60 / 60.0
var target: Node = null
var distance_to_attack: float = 50.0
var _old_zsp: float = 0.0

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return

	target = mob.current_target
	if not is_instance_valid(target):
		target = mob.find_nearest_player()
	if not is_instance_valid(target):
		switch_to("RabbigteWander")
		return

	phase = Phase.WAIT
	waiting_timer = 0.0
	_old_zsp = 0.0
	distance_to_attack = mob.attack_distance_jump  # Boss always uses jump attack distance
	_set_walk_jump_anim(mob)
	creature.image_speed = mob.img_speed_walk

func execute(delta: float) -> void:
	var mob := creature as Mob
	if not mob:
		return

	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	if mob.is_movement_blocked():
		creature.velocity = Vector2.ZERO
		return

	# Target dead → find new target or wander
	if not is_instance_valid(target) or target.is_dead:
		target = mob.find_nearest_player()
		if not is_instance_valid(target):
			switch_to("RabbigteWander")
			return

	match phase:
		Phase.WAIT:
			creature.velocity = Vector2.ZERO
			creature.animate_sprite()
			waiting_timer += delta
			if waiting_timer > waiting_timer_limit:
				# GMS2: waitingTimer is NOT reset here — only on state entry.
				# After the initial 60-frame wait, hops continuously.
				# Low HP → avoid
				if creature.attribute.hpPercent < 20.0:
					switch_to("RabiteAvoid")
					return
				phase = Phase.SELECT_POSITION

		Phase.SELECT_POSITION:
			_set_walk_jump_anim(mob)
			var dir: Vector2 = (target.global_position - creature.global_position).normalized()
			creature.facing = creature.get_facing_from_direction(dir)
			creature.velocity = dir * randf_range(0.2, 1.0) * 60.0
			# Boss bounce (timer-based)
			_do_boss_bounce(mob, delta)
			phase = Phase.GO_POSITION

		Phase.GO_POSITION:
			(creature as CharacterBody2D).move_and_slide()
			creature.animate_sprite()
			# Check distance to target while hopping
			var dist: float = creature.global_position.distance_to(target.global_position)
			if dist < distance_to_attack:
				mob.current_target = target
				switch_to("RabiteAttack")
				return
			# Wait for landing
			if creature.z_height <= 0 and creature.z_velocity == 0 and get_timer() > 10 / 60.0:
				creature.velocity = Vector2.ZERO
				phase = Phase.WAIT

	# Boss bounce runs every frame (GMS2: fsm_bounce)
	_do_boss_bounce(mob, delta)
	# Cast skills during chase (GMS2: castRandomSkill)
	mob.cast_random_skill()
	# Bounce angle rotation (GMS2: fsm_rabbigte_bounceAngle)
	_do_bounce_angle(mob)

	# Timeout: give up after a long chase
	if get_timer() > 600 / 60.0:
		switch_to("RabbigteWander")

func exit() -> void:
	creature.velocity = Vector2.ZERO
	# Reset rotation on exit
	if creature.sprite:
		creature.sprite.rotation = 0

func _set_walk_jump_anim(mob: Mob) -> void:
	creature.set_default_facing_animations(
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end
	)

func _do_boss_bounce(mob: Mob, dt: float = 0.0) -> void:
	## GMS2: fsm_bounce for bosses — timer-based jump every 0.25s (was 15 frames) with yscale squash
	if creature.z_height <= 0:
		mob.boss_bounce_timer += dt
		if mob.boss_bounce_timer > 0.25:
			creature.z_velocity = mob.boss_bounce_value
			mob.boss_bounce_timer = 0.0
		var add_scale: float = absf(mob.boss_bounce_timer - 0.125) / 0.25
		if creature.sprite:
			creature.sprite.scale.y = 1.0 + add_scale - 0.2
	else:
		if creature.sprite:
			creature.sprite.scale.y = 1.0

func _do_bounce_angle(mob: Mob) -> void:
	## GMS2: fsm_rabbigte_bounceAngle — rotate sprite based on z velocity
	if not creature.sprite:
		return
	var zsp: float = creature.z_velocity
	# Frame selection: if falling, use mid-jump frame; otherwise grounded
	if _old_zsp - zsp < zsp:
		creature.set_frame(mob.spr_walk_jump_ini + 1)  # Frame 3 (mid-jump)
	else:
		creature.set_frame(mob.spr_walk_jump_ini)  # Frame 2 (grounded)
	_old_zsp = zsp

	# Rotation based on facing direction (GMS2: image_angle = ±(zsp*6)+1)
	var angle_factor: float = zsp * 6.0 + 1.0
	if creature.facing == Constants.Facing.UP or creature.facing == Constants.Facing.RIGHT:
		creature.sprite.rotation = deg_to_rad(-angle_factor)
	else:
		creature.sprite.rotation = deg_to_rad(angle_factor)
