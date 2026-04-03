class_name MobChase
extends State
## Mob CHASE state - replaces fsm_mob_chase from GMS2
## Chases player once spotted. Transitions to Attack when in range, Stand if lost.

var target: Node = null
var chase_timeout: float = 5.0  # 300 frames / 60 = 5.0 seconds
var attack_cooldown: float = 50.0 / 60.0  # Min seconds before can attack (GMS2: attackCooldownMax)

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return

	target = mob.current_target
	if not is_instance_valid(target):
		target = mob.find_nearest_player()

	if not is_instance_valid(target):
		switch_to("Stand")
		return

	mob.look_at_target(target)
	# GMS2: state_timer > floor(random_range(100, 200))
	chase_timeout = randf_range(100 / 60.0, 200 / 60.0)
	attack_cooldown = randf_range(20 / 60.0, 100 / 60.0)  # GMS2: attackCooldownMax = random_range(20,100)

	creature.set_default_facing_animations(
		mob.spr_walk_up_ini, mob.spr_walk_right_ini,
		mob.spr_walk_down_ini, mob.spr_walk_left_ini,
		mob.spr_walk_up_end, mob.spr_walk_right_end,
		mob.spr_walk_down_end, mob.spr_walk_left_end
	)
	# GMS2: state_imgSpeedFollowActor = 0.5 (faster animation during chase)
	creature.image_speed = 0.5

func execute(_delta: float) -> void:
	var mob := creature as Mob
	if not mob:
		return

	# Check damage stack BEFORE movement block — ballooned/frozen mobs can still be hit
	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# Status effects stop chase
	if mob.is_movement_blocked():
		switch_to("Stand")
		return

	# Timeout
	if get_timer() > chase_timeout:
		switch_to("Stand")
		return

	# Check target validity
	if not is_instance_valid(target) or target.is_dead:
		target = mob.find_nearest_player()
		if not is_instance_valid(target):
			switch_to("Stand")
			return

	# Check if in reach range (only after cooldown expires - GMS2: state_timer >= attackCooldownMax)
	# GMS2: isTooMuchNearToActor = distance_to_object(target) < radiusReachTarget (14, not radiusAttack=28)
	if mob.is_in_reach_range(target) and get_timer() >= attack_cooldown:
		mob.current_target = target
		switch_to("Attack")
		return

	# GMS2: Only lose target on LOS failure (collision_line), NOT distance.
	# Once chasing, mob never gives up based on distance alone.
	if not mob.has_line_of_sight(target):
		switch_to("Stand")
		return

	# Move toward target
	mob.look_at_target(target)
	var dir: Vector2 = (target.global_position - creature.global_position).normalized()
	# GMS2: CONFUSED status reverses movement direction (moves away from target)
	if creature.has_status(Constants.Status.CONFUSED):
		dir = -dir
	# GMS2: speed / attribute.speedDivisor (2.0 when SNARED)
	var speed: float = mob.chase_speed
	if creature.has_status(Constants.Status.SNARED):
		speed *= 0.5
	creature.velocity = dir * speed * 60.0
	(creature as CharacterBody2D).move_and_slide()

	creature.animate_sprite()

func exit() -> void:
	creature.velocity = Vector2.ZERO
