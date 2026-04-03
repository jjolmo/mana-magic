class_name RabiteWander
extends State
## Rabite WANDER state - replaces fsm_rabite_wandering from GMS2
## Phase-based hop movement: wait → pick direction → hop until landing → repeat
## Returns to spawn if stuck. Transitions to Chase on aggro, Avoid on low HP.
## GMS2: fsm_bounce() runs EVERY frame in ALL phases — rabite always bounces.
## GMS2: GO_POSITION stops on landing (z >= 0), NOT on distance limit.

enum Phase { WAIT, SELECT_POSITION, GO_POSITION, RETURN_SPAWN }

var phase: int = Phase.WAIT
var waiting_timer: float = 0.0
var waiting_timer_limit: float = 1.0  # 60 / 60.0
var aggro_cooldown_limit: float = 2.0  # 120 / 60.0
var move_speed_limit: float = 1.0
var bounce_value: float = 2.5

# Return-to-spawn tracking (GMS2: saveCoordZone)
var _return_timer: float = 0.0
var _return_timer_limit: float = 10.0  # 600 / 60.0
var _last_position: Vector2 = Vector2.ZERO
var _min_distance_to_return: float = 10.0

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return
	phase = Phase.WAIT
	waiting_timer = 0.0
	aggro_cooldown_limit = randf_range(120 / 60.0, 240 / 60.0)
	_return_timer = 0.0
	_last_position = creature.global_position
	_set_walk_jump_anim(mob)
	creature.image_speed = mob.img_speed_walk
	creature.velocity = Vector2.ZERO

func execute(delta: float) -> void:
	var mob := creature as Mob
	if not mob:
		return

	# Check damage stack
	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# Status effects stop action
	if mob.is_movement_blocked():
		creature.velocity = Vector2.ZERO
		return

	# Return-to-spawn check every 10 seconds (was 600 frames)
	_return_timer += delta
	if _return_timer >= _return_timer_limit:
		_return_timer = 0.0
		if creature.global_position.distance_to(_last_position) < _min_distance_to_return:
			# Stuck, return to spawn
			phase = Phase.RETURN_SPAWN
		_last_position = creature.global_position

	# Aggro check
	if get_timer() > aggro_cooldown_limit and not mob.passive:
		if mob.is_player_in_sight():
			mob.current_target = mob.find_nearest_player()
			if mob.current_target:
				switch_to("RabiteChase")
				return

	match phase:
		Phase.WAIT:
			creature.velocity = Vector2.ZERO
			# GMS2: animation continues during WAIT (image_speed is always active)
			creature.animate_sprite()
			waiting_timer += delta
			if waiting_timer > waiting_timer_limit:
				# GMS2: waitingTimer is NOT reset here — only on state entry
				# and RETURN_SPAWN. After the initial 60-frame wait, the rabite
				# hops continuously (waitingTimer stays > limit on subsequent
				# WAIT entries, so SELECT_POSITION triggers immediately).
				# Low HP → avoid
				if creature.attribute.hpPercent < 20.0:
					switch_to("RabiteAvoid")
					return
				phase = Phase.SELECT_POSITION

		Phase.SELECT_POSITION:
			# Pick random direction and hop (GMS2: moveSpeed=random(0.2, moveSpeedLimit))
			_set_walk_jump_anim(mob)
			var angle := randf() * TAU
			var dir := Vector2(cos(angle), sin(angle))
			creature.facing = creature.get_facing_from_direction(dir)
			creature.velocity = dir * randf_range(0.2, move_speed_limit) * 60.0
			phase = Phase.GO_POSITION

		Phase.GO_POSITION:
			(creature as CharacterBody2D).move_and_slide()
			creature.animate_sprite()
			# GMS2: if (z >= 0) { speed = 0; phase = PHASE_WAIT; }
			# Stop ONLY on landing — no distance limit. Movement lasts one full
			# bounce cycle (~40 frames), traveling 8-40px depending on speed.
			if creature.z_height <= 0 and creature.z_velocity == 0:
				creature.velocity = Vector2.ZERO
				creature.set_default_facing_index()
				phase = Phase.WAIT

		Phase.RETURN_SPAWN:
			# Move back to initial spawn position
			var spawn_pos: Vector2 = mob.initial_position
			var dir: Vector2 = (spawn_pos - creature.global_position)
			if dir.length() < 5.0:
				creature.velocity = Vector2.ZERO
				phase = Phase.WAIT
			else:
				dir = dir.normalized()
				creature.facing = creature.get_facing_from_direction(dir)
				creature.velocity = dir * move_speed_limit * 60.0
				(creature as CharacterBody2D).move_and_slide()
				creature.animate_sprite()

	# GMS2: fsm_bounce() runs AFTER phase logic every frame in ALL phases.
	# This ensures the rabite continuously hops even while standing still.
	_do_bounce()

func exit() -> void:
	creature.velocity = Vector2.ZERO

func _set_walk_jump_anim(mob: Mob) -> void:
	## Use walk-jump frames (2-4) for all directions (rabite has non-directional sprites)
	creature.set_default_facing_animations(
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end
	)

func _do_bounce() -> void:
	## Continuous bounce: start a new hop when on ground (GMS2: fsm_bounce)
	## Runs in ALL phases — rabite always bounces (positive z_velocity = up)
	## GMS2 uses fixed bounceValue (not random) for consistent rhythmic hop
	if creature.z_height <= 0 and creature.z_velocity == 0:
		creature.z_velocity = bounce_value
