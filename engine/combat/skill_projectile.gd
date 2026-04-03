class_name SkillProjectile
extends Node2D
## Projectile for skills like fireball, gemMissile - replaces oSkill_fireball_projectile from GMS2
## Has 3 phases: Delay → Movement (curving toward target) → Impact (explosion animation)

signal projectile_hit

# Setup
var origin_pos: Vector2
var target_pos: Vector2
var target_creature: Creature
var execution_delay: float = 0.0  # seconds before appearing
var projectile_id: int = 0  # 0, 1, or 2 for multi-projectile skills
var origin_direction: float = 0.0  # initial angle in radians
var skill_name: String = ""

# Movement — GMS2 homing uses sign(dsin(target-dir))*dirSpeed, not lerp
var speed_max: float = 5.0  # GMS2: projectileMaxSpeed = 5 (fireball), 6 (quick balls)
var speed_min: float = 1.5  # GMS2: projectileMinSpeed = 1.5
var current_speed: float = 5.0
var direction_angle: float = 0.0  # current flight direction in degrees (GMS2 uses degrees)
var collision_radius: float = 24.0
var max_lifetime: float = 3.0  # seconds before force-hit (180 frames / 60)
var _dir_speed: float = 0.5  # GMS2: dirSpeed starts at dirSpeedMin
var _dir_speed_min: float = 0.5  # GMS2: dirSpeedMin = 0.5
var _dir_speed_max: float = 4.0  # GMS2: dirSpeedMax = 4 (fireball), 9 (quick balls)
var _same_target: bool = true  # GMS2: sameTarget (true for single-target skills)

# Phase tracking
enum Phase { DELAY, MOVING, IMPACT }
var phase: Phase = Phase.DELAY
var phase_timer: float = 0.0

# Sprites
var projectile_sprite: Sprite2D
var projectile_frames: Array[Texture2D] = []
var impact_frames: Array[Texture2D] = []
var current_anim_frame: int = 0
var anim_timer: float = 0.0
var anim_speed: float = 0.0167  # seconds per frame (set from sprite DB)
var impact_anim_speed: float = 0.0667  # seconds per frame for impact (set from sprite DB)

# Impact
var impact_sprite_key: String = ""

# GMS2 gemMissile specific state
var _is_gem_missile: bool = false
var _gem_smoke_frames: Array[Texture2D] = []
var _gem_bullet_frames: Array[Texture2D] = []
var _gem_spark_frames: Array[Texture2D] = []
var _gem_phase: int = 0  # 0=smoke, 1=rise+fall, 2=impact approach
var _gem_smoke_loops: int = 0
var _gem_origin: Vector2
var _gem_fall_delay: float = 0.0
var _gem_fall_subimage: int = 2
var _gem_velocity: Vector2 = Vector2.ZERO
var _gem_direction_to_center: float = 0.0
var _gem_spark1_spawned: bool = false
var _gem_fall_triggered: bool = false
var _gem_spark2_spawned: bool = false
var _gem_smoke_anim_speed: float = 0.0667
const _GEM_SMOKE_RANDOM: float = 8.0
const _GEM_SMOKE_LOOP_LIMIT: int = 3
const _GEM_BULLET_SPEED: float = 12.0


func _ready() -> void:
	# GMS2: projectiles created on lyr_animations (depth -14000), always in front of creatures
	z_index = 1000

	projectile_sprite = Sprite2D.new()
	projectile_sprite.name = "ProjectileSprite"
	add_child(projectile_sprite)

	global_position = origin_pos
	# GMS2 uses degrees for direction; origin_direction comes in radians from callers
	direction_angle = rad_to_deg(origin_direction)
	visible = false

	# Set per-skill speed parameters (GMS2 Create_0.gml)
	# Note: airBlast and moonEnergy now use SkillEffect custom handlers
	match skill_name:
		"fireball":
			speed_max = 5.0; speed_min = 1.5
			_dir_speed_max = 4.0
		_:
			speed_max = 5.0; speed_min = 1.5
			_dir_speed_max = 4.0
	current_speed = speed_max
	_dir_speed = _dir_speed_min

	_load_projectile_sprites()


func setup(p_origin: Vector2, p_target_pos: Vector2, p_target: Creature,
		p_delay: float, p_id: int, p_direction: float, p_skill_name: String) -> void:
	origin_pos = p_origin
	target_pos = p_target_pos
	target_creature = p_target
	execution_delay = p_delay
	projectile_id = p_id
	origin_direction = p_direction
	skill_name = p_skill_name


func _load_projectile_sprites() -> void:
	# Load projectile sprite frames based on skill name
	var sprite_key: String = ""
	match skill_name:
		"fireball":
			sprite_key = "spr_skill_fireball"
			impact_sprite_key = "spr_skill_fireball2"
		"gemMissile":
			_is_gem_missile = true
			_gem_smoke_frames = _load_frames("spr_skill_gemMissile_smoke")
			_gem_bullet_frames = _load_frames("spr_skill_gemMissile_bullet")
			_gem_spark_frames = _load_frames("spr_skill_gemMissile_spark")
			# GMS2: fallDelay = 4 * projectileId + 1
			_gem_fall_delay = (4.0 * projectile_id + 1.0) / 60.0
			# GMS2: fallSubImage = (projectileId == 1) ? 3 : 2
			_gem_fall_subimage = 3 if projectile_id == 1 else 2
			# Load smoke animation speed
			SkillEffect._ensure_sprite_db()
			var smoke_info: Dictionary = SkillEffect._sprite_db.get("spr_skill_gemMissile_smoke", {})
			var smoke_fps: float = smoke_info.get("playback_speed", 15.0)
			if smoke_fps > 0:
				_gem_smoke_anim_speed = 1.0 / smoke_fps
			# Start with smoke sprite
			if _gem_smoke_frames.size() > 0:
				projectile_sprite.texture = _gem_smoke_frames[0]
			return
		_:
			sprite_key = "spr_skill_" + skill_name
			impact_sprite_key = ""

	projectile_frames = _load_frames(sprite_key)
	if not impact_sprite_key.is_empty():
		impact_frames = _load_frames(impact_sprite_key)

	# Set animation speeds from GMS2 sprite playback_speed
	SkillEffect._ensure_sprite_db()
	var flight_info: Dictionary = SkillEffect._sprite_db.get(sprite_key, {})
	var flight_fps: float = flight_info.get("playback_speed", 60.0)
	if flight_fps > 0:
		anim_speed = 1.0 / flight_fps

	if not impact_sprite_key.is_empty():
		var impact_info: Dictionary = SkillEffect._sprite_db.get(impact_sprite_key, {})
		var impact_fps: float = impact_info.get("playback_speed", 15.0)
		if impact_fps > 0:
			impact_anim_speed = 1.0 / impact_fps

	# Set initial frame
	if projectile_frames.size() > 0:
		projectile_sprite.texture = projectile_frames[0]


func _load_frames(sprite_key: String) -> Array[Texture2D]:
	return SpriteUtils.load_sheet_frames(sprite_key)


func _process(delta: float) -> void:
	# GMS2: ring menu pauses all combat logic
	if GameManager.ring_menu_opened:
		return

	phase_timer += delta

	if _is_gem_missile:
		_process_gem_missile(delta)
	else:
		match phase:
			Phase.DELAY:
				_process_delay()
			Phase.MOVING:
				_process_moving(delta)
			Phase.IMPACT:
				_process_impact(delta)


func _process_delay() -> void:
	if phase_timer >= execution_delay:
		phase = Phase.MOVING
		phase_timer = 0.0
		visible = true
		global_position = origin_pos

		# Play projectile sound
		if skill_name == "fireball":
			MusicManager.play_sfx("snd_skill_fireball")


func _process_moving(delta: float) -> void:
	# Update target position if creature is still valid
	if is_instance_valid(target_creature):
		target_pos = target_creature.global_position

	# GMS2 homing formula: sign(dsin(target_angle - dir)) * dirSpeed
	# dirSpeed accelerates each frame: dirSpeed += 0.06, clamped to [dirSpeedMin, dirSpeedMax]
	_dir_speed += 0.06 * delta * 60.0
	_dir_speed = clampf(_dir_speed, _dir_speed_min, _dir_speed_max)

	var to_target: Vector2 = target_pos - global_position
	# GMS2 uses degrees for point_direction and dsin
	var target_angle_deg: float = rad_to_deg(to_target.angle())
	# GMS2: point_direction returns angle where 0=right, 90=up (y-inverted)
	# Godot: atan2 returns angle where 0=right, positive=down
	# Both use the same relative difference so sign(dsin()) still works
	var angle_diff: float = target_angle_deg - direction_angle
	var dist: float = to_target.length()

	# GMS2: first 15 frames with same target → sharp initial turn (dirMovement = 9)
	var dir_movement: float
	if _same_target and phase_timer < 15.0 / 60.0 + execution_delay:
		dir_movement = 9.0
	else:
		dir_movement = signf(sin(deg_to_rad(angle_diff))) * _dir_speed

	direction_angle += dir_movement * delta * 60.0

	# GMS2: speed lerp based on distance left
	# sameTarget → fixed 1.5; otherwise lerp(maxSpeed, minSpeed, distanceLeftPercentage)
	if _same_target:
		current_speed = speed_min
	else:
		var dist_pct: float = clampf(1.0 - dist / 200.0, 0.0, 1.0)
		current_speed = lerpf(speed_max, speed_min, dist_pct)

	# Move using direction in degrees
	var move_vec: Vector2 = Vector2.from_angle(deg_to_rad(direction_angle)) * current_speed * delta * 60.0
	global_position += move_vec

	# Animate projectile sprite
	_animate_sprite(projectile_frames, delta)

	# Check collision
	if dist < collision_radius or phase_timer > max_lifetime:
		_enter_impact()


func _enter_impact() -> void:
	phase = Phase.IMPACT
	phase_timer = 0.0
	current_anim_frame = 0

	# Switch to impact sprite and speed
	if impact_frames.size() > 0:
		projectile_sprite.texture = impact_frames[0]
		anim_speed = impact_anim_speed
	elif projectile_frames.size() > 0:
		projectile_sprite.texture = projectile_frames[projectile_frames.size() - 1]

	# Snap to target position
	if is_instance_valid(target_creature):
		global_position = target_creature.global_position + Vector2(0, -10)

	projectile_hit.emit()


func _process_impact(delta: float) -> void:
	if impact_frames.size() > 0:
		anim_timer += delta
		if anim_timer >= anim_speed:
			anim_timer -= anim_speed
			current_anim_frame += 1
			if current_anim_frame >= impact_frames.size():
				queue_free()
				return
			projectile_sprite.texture = impact_frames[current_anim_frame]
	else:
		# No impact animation - just destroy after brief delay
		if phase_timer > 10.0 / 60.0:
			queue_free()


func _animate_sprite(anim_frames: Array[Texture2D], delta: float) -> void:
	if anim_frames.size() <= 1:
		return
	anim_timer += delta
	if anim_timer >= anim_speed:
		anim_timer -= anim_speed
		current_anim_frame = (current_anim_frame + 1) % anim_frames.size()
		projectile_sprite.texture = anim_frames[current_anim_frame]


# =====================================================================
# GEM MISSILE - 3-phase behavior from GMS2 oSkill_gemMissile_projectile
# Phase 0: Smoke animation (random position jitter, loop N times)
# Phase 1: Bullet rises up, then falls toward target
# Phase 2: Continues to target, stops and waits before destroying
# =====================================================================

func _process_gem_missile(delta: float) -> void:
	match phase:
		Phase.DELAY:
			if phase_timer >= execution_delay:
				phase = Phase.MOVING
				phase_timer = 0.0
				visible = true
				global_position = origin_pos
				_gem_origin = origin_pos
				_gem_phase = 0
				_gem_smoke_loops = 0
				current_anim_frame = 0
				anim_timer = 0.0
				anim_speed = _gem_smoke_anim_speed
				MusicManager.play_sfx("snd_skill_gemMissile")
		Phase.MOVING:
			_process_gem_moving(delta)
		Phase.IMPACT:
			# Phase 2: continue falling, stop when reaching target
			_process_gem_impact(delta)


func _process_gem_moving(delta: float) -> void:
	if _gem_phase == 0:
		# SMOKE PHASE: animate smoke, jitter position each loop
		anim_timer += delta
		if anim_timer >= anim_speed and _gem_smoke_frames.size() > 0:
			anim_timer -= anim_speed
			current_anim_frame += 1
			if current_anim_frame >= _gem_smoke_frames.size():
				# Completed one loop
				current_anim_frame = 0
				_gem_smoke_loops += 1
				# Random position jitter
				global_position.x = floorf(randf_range(
					_gem_origin.x - _GEM_SMOKE_RANDOM,
					_gem_origin.x + _GEM_SMOKE_RANDOM))
				global_position.y = floorf(randf_range(
					_gem_origin.y - _GEM_SMOKE_RANDOM,
					_gem_origin.y + _GEM_SMOKE_RANDOM))
			projectile_sprite.texture = _gem_smoke_frames[current_anim_frame]

		if _gem_smoke_loops > _GEM_SMOKE_LOOP_LIMIT:
			# Transition to bullet phase
			_gem_phase = 1
			phase_timer = 0.0
			current_anim_frame = 0
			global_position = _gem_origin
			_gem_velocity = Vector2(0, -_GEM_BULLET_SPEED)  # Move UP
			_gem_spark1_spawned = false
			_gem_fall_triggered = false
			_gem_spark2_spawned = false
			if _gem_bullet_frames.size() > 0:
				projectile_sprite.texture = _gem_bullet_frames[0]

	elif _gem_phase == 1:
		# BULLET RISE + FALL PHASE
		global_position += _gem_velocity * delta * 60.0

		if phase_timer >= 10.0 / 60.0 and not _gem_spark1_spawned:
			_gem_spark1_spawned = true
			# Spawn spark effect (GenericAnimation moving down)
			_spawn_gem_spark(global_position + Vector2(0, 4),
				Vector2(0, _GEM_BULLET_SPEED / 3.0))

		elif phase_timer >= 50.0 / 60.0 + _gem_fall_delay and not _gem_fall_triggered:
			_gem_fall_triggered = true
			# Transition to falling (GMS2: collisioned = true → start fall sequence)
			# Set fall subimage
			if _gem_fall_subimage < _gem_bullet_frames.size():
				projectile_sprite.texture = _gem_bullet_frames[_gem_fall_subimage]
			# Shift first projectile left
			if projectile_id == 0:
				global_position.x -= 40
			# Teleport above target
			if is_instance_valid(target_creature):
				target_pos = target_creature.global_position
			global_position.y = target_pos.y - 150
			# Calculate direction to target and set motion
			var to_target: Vector2 = target_pos - global_position
			_gem_direction_to_center = to_target.angle()
			_gem_velocity = Vector2.from_angle(_gem_direction_to_center) * _GEM_BULLET_SPEED

		elif phase_timer >= 60.0 / 60.0 + _gem_fall_delay and not _gem_spark2_spawned:
			_gem_spark2_spawned = true
			# Spawn second spark (reverse direction)
			_spawn_gem_spark(global_position + Vector2(0, 4),
				Vector2.from_angle(_gem_direction_to_center + PI) * (_GEM_BULLET_SPEED / 3.0))
			# Enter impact approach phase
			phase = Phase.IMPACT
			phase_timer = 0.0


func _process_gem_impact(delta: float) -> void:
	# Continue moving toward target
	global_position += _gem_velocity * delta * 60.0

	if is_instance_valid(target_creature):
		target_pos = target_creature.global_position

	# Stop when reaching target y position
	if global_position.y > target_pos.y - 5:
		_gem_velocity = Vector2.ZERO
		if phase_timer > 15.0 / 60.0:
			projectile_hit.emit()
			queue_free()


func _spawn_gem_spark(spark_pos: Vector2, spark_velocity: Vector2) -> void:
	## Spawn a spark GenericAnimation at the given position with velocity
	if _gem_spark_frames.is_empty():
		return
	var spark := Sprite2D.new()
	spark.name = "GemSpark"
	spark.texture = _gem_spark_frames[0]
	spark.global_position = spark_pos
	spark.z_index = 1000  # GMS2: depth = -10000 on lyr_animations
	get_parent().add_child(spark)

	# Animate and move the spark using a simple tween
	var tween := spark.create_tween()
	tween.set_parallel(true)
	# Move spark
	var end_pos: Vector2 = spark_pos + spark_velocity * 20.0  # ~20 frames of movement
	tween.tween_property(spark, "global_position", end_pos, 20.0 / 60.0)
	# Fade out
	tween.tween_property(spark, "modulate:a", 0.0, 20.0 / 60.0)
	tween.set_parallel(false)
	tween.tween_callback(spark.queue_free)
