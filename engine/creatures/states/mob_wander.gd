class_name MobWander
extends State
## Mob WANDER state - replaces fsm_mob_wander from GMS2

var wander_target: Vector2 = Vector2.ZERO
var wander_duration: float = 1.0  # 60 / 60.0
var run_speed_rnd: float = 0.35  ## GMS2: random_range(0.2, 0.5) per wander cycle

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return

	# Pick random wander direction
	var angle := randf() * TAU

	# GMS2: wall check on spawn — if adjacent to a wall, redirect away from it
	# Uses place_free(x±1, y±1) checks and overrides direction
	var space: PhysicsDirectSpaceState2D = creature.get_world_2d().direct_space_state
	if space:
		var pos: Vector2 = creature.global_position
		var _check_wall := func(offset: Vector2) -> bool:
			var query := PhysicsRayQueryParameters2D.create(pos, pos + offset, creature.collision_mask)
			query.exclude = [creature.get_rid()]
			return space.intersect_ray(query).size() > 0
		# GMS2: degreeDirRight=0, degreeDirLeft=PI, degreeDirDown=~4.54rad, degreeDirUp=PI/2
		if _check_wall.call(Vector2(-2, 0)):  # wall on left → go right
			angle = 0.0
		if _check_wall.call(Vector2(2, 0)):  # wall on right → go left
			angle = PI
		if _check_wall.call(Vector2(0, -2)):  # wall above → go down
			angle = PI * 0.5
		if _check_wall.call(Vector2(0, 2)):  # wall below → go up
			angle = PI * 1.5

	wander_target = creature.global_position + Vector2(cos(angle), sin(angle)) * mob.wander_radius * randf()
	# GMS2: state_timer_max_rnd = random_range(60, 400)
	wander_duration = randf_range(60 / 60.0, 400 / 60.0)
	# GMS2: run_speed_rnd = random_range(0.2, 0.5) — randomized per wander cycle
	run_speed_rnd = randf_range(0.2, 0.5)

	creature.set_default_facing_animations(
		mob.spr_walk_up_ini, mob.spr_walk_right_ini,
		mob.spr_walk_down_ini, mob.spr_walk_left_ini,
		mob.spr_walk_up_end, mob.spr_walk_right_end,
		mob.spr_walk_down_end, mob.spr_walk_left_end
	)
	creature.image_speed = mob.img_speed_walk

func execute(_delta: float) -> void:
	var mob := creature as Mob
	if not mob:
		return

	# Status effects stop wandering
	if mob.is_movement_blocked():
		switch_to("Stand")
		return

	# Check for player in sight (aggro) - GMS2: wander → chase (not directly to attack)
	if not mob.passive and mob.is_player_in_sight():
		mob.current_target = mob.find_nearest_player()
		switch_to("Chase")
		return

	# Move toward wander target
	var dir: Vector2 = (wander_target - creature.global_position)
	if dir.length() > 2.0 and get_timer() < wander_duration:
		dir = dir.normalized()
		# GMS2: CONFUSED status reverses movement direction
		if creature.has_status(Constants.Status.CONFUSED):
			dir = -dir
		creature.facing = creature.get_facing_from_direction(dir)
		# GMS2: run_speed_rnd / attribute.speedDivisor (2.0 when SNARED)
		var speed: float = run_speed_rnd
		if creature.has_status(Constants.Status.SNARED):
			speed *= 0.5
		creature.velocity = dir * speed * 60.0
		(creature as CharacterBody2D).move_and_slide()
		creature.set_default_facing_index()
		creature.animate_sprite()
	else:
		creature.velocity = Vector2.ZERO
		switch_to("Stand")

	# Check damage stack
	if creature.damage_stack.size() > 0:
		switch_to("Hit")

func exit() -> void:
	creature.velocity = Vector2.ZERO
