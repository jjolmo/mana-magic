class_name BossManaBeastFireball
extends State
## Mana Beast FIREBALL state - replaces fsm_mob_manaBeast_fireball from GMS2
## 4-phase attack: preparing (fly in), waiting, fireball (spin attack), coming (descend)

enum FireballPhase { PREPARING, WAITING, FIREBALL, COMING }

var phase: int = FireballPhase.PREPARING
var go_fireball: bool = true # true=do fireball, false=skip to coming
var spin_angle: float = 0.0
var _blend_screen_done: bool = false  # GMS2: blendScreenComing flag

# GMS2 path points for pth_manaBeast_going (smooth curve)
# Used in PREPARING phase to fly-in along curved arc
var _path_curve: Curve2D
var _path_progress: float = 0.0
var _path_speed: float = 0.4  # GMS2: path_start(pth_manaBeast_going, 0.4, ...)
var _path_length: float = 0.0
# GMS2: Points 0-2 have speed=100, points 3-5 have speed=150
# At progress > 0.5 (roughly point 3+), use 1.5x speed multiplier
const _PATH_SPEED_FAST_THRESHOLD: float = 0.5
const _PATH_SPEED_FAST_MULTIPLIER: float = 1.5

# GMS2: comingTick = 10, decreases to 2 over 250 frames (tick-based scale updates)
var _coming_tick: float = 10 / 60.0
var _tick_counter: float = 0.0
var _scale_factor: float = 20.0

# PREPARING: flag to only switch to fireballPrepare animation once (GMS2: doAnimateComing)
var _prepare_started: bool = false

# WAITING: ready flag (GMS2: phase_waitingReady)
var _waiting_ready: bool = false
var _waiting_timer: float = 0.0  # GMS2: timer0 in waiting phase

# FIREBALL: timer0 and cumulative scale (GMS2: image_xscale += augmentFireball)
var _fireball_timer: float = 0.0
var _fireball_spin_acc: float = 0.0

# COMING phase
var _coming_start_y: float = 0.0
var _coming_timer: float = 0.0
var _coming_ready: bool = false  # GMS2: phase_comingReady
var _dt: float = 0.0  # cached delta for helper functions

# Colors from GMS2
const FLAMMIE_COLOR := Color(140.0 / 255.0, 81.0 / 255.0, 198.0 / 255.0, 1.0)
const FLAMMIE_FLESH := Color(198.0 / 255.0, 97.0 / 255.0, 57.0 / 255.0, 1.0)

# Desaturation shader (GMS2: enableShader(shc_saturate, amount))
static var _saturate_shader: Shader = null
var _saturate_material: ShaderMaterial = null

func enter() -> void:
	var boss := creature as BossManaBeast
	if not boss:
		return

	boss.phase_time = 0
	creature.velocity = Vector2.ZERO
	spin_angle = 0.0
	_blend_screen_done = false
	_coming_tick = 10 / 60.0
	_tick_counter = 0.0
	_scale_factor = 20.0
	_coming_timer = 0.0
	_prepare_started = false
	_waiting_ready = false
	_waiting_timer = 0.0
	_fireball_timer = 0.0
	_fireball_spin_acc = 0.0
	_coming_ready = false

	# GMS2: goFireball = true is ALWAYS set in state_new (hardcoded)
	# state_payload from SIDE is ignored because state_new overwrites it
	go_fireball = true

	phase = FireballPhase.PREPARING

	# GMS2: starts at camera center with scale 20
	var center: Vector2 = boss.get_camera_center()
	creature.global_position = Vector2(center.x, center.y)
	creature.scale = Vector2(20.0, 20.0)

	# Build the path curve (GMS2: pth_manaBeast_going with kind=1 smooth)
	_build_path_curve(center)
	_path_progress = 0.0

	# Invulnerable during fireball sequence
	creature.is_invulnerable = true
	creature.is_untargetable = true

	# GMS2: image_speed = 0 at state_new
	creature.image_speed = 0.0

	# GMS2: use aux sprite with fireballGoingIni/End
	boss.use_aux_sprite()
	creature.set_frame(boss.aux_fireball_going_ini)

	# GMS2: soundPlay(snd_flammie)
	MusicManager.play_sfx("snd_flammie")

	# GMS2: enableShader(shc_saturate, 0) — initialize desaturation shader
	if _saturate_shader == null:
		_saturate_shader = load("res://assets/shaders/sha_saturate.gdshader")
	_saturate_material = ShaderMaterial.new()
	_saturate_material.shader = _saturate_shader
	_saturate_material.set_shader_parameter("u_amount", 0.0)
	creature.enable_shader(_saturate_material)

func _build_path_curve(center: Vector2) -> void:
	## Build a Curve2D from GMS2's pth_manaBeast_going path points
	_path_curve = Curve2D.new()
	var offset: Vector2 = center - Vector2(160, 280)  # Approximate center of path

	var points: Array[Vector2] = [
		Vector2(114.5, 310.0) + offset,
		Vector2(177.5, 345.0) + offset,
		Vector2(200.5, 281.0) + offset,
		Vector2(198.36, 270.55) + offset,
		Vector2(179.56, 258.15) + offset,
		Vector2(160.56, 276.55) + offset,
	]

	for i in range(points.size()):
		_path_curve.add_point(points[i])

	_path_length = _path_curve.get_baked_length()

func execute(delta: float) -> void:
	_dt = delta
	var boss := creature as BossManaBeast
	if not boss:
		return

	var timer := get_timer()

	match phase:
		FireballPhase.PREPARING:
			_phase_preparing(timer, boss)
		FireballPhase.WAITING:
			_phase_waiting(timer, boss)
		FireballPhase.FIREBALL:
			_phase_fireball(timer, boss)
		FireballPhase.COMING:
			_phase_coming(timer, boss)

func _phase_preparing(timer: float, boss: BossManaBeast) -> void:
	# GMS2: Desaturation shader progresses during entire PREPARING
	if _saturate_material:
		_saturate_material.set_shader_parameter("u_amount", -clampf(timer / (200.0 / 60.0) * 0.5, 0.0, 0.5))

	# GMS2: at path_position > 0.75, switch to prepare animation + drift to center
	if _path_progress > 0.75:
		# GMS2: animateSprite(state_imgSpeedComing, true) — only after 0.75
		creature.animate_sprite(0.1, true)

		if not _prepare_started:
			# GMS2: doAnimateComing flag — switch sprite ONCE
			_prepare_started = true
			creature.scale = Vector2(0.8, 0.8)
			creature.set_frame(boss.aux_fireball_prepare_ini)
			creature.image_speed = 0.1
			creature.set_default_facing_animations(
				boss.aux_fireball_prepare_ini, boss.aux_fireball_prepare_ini,
				boss.aux_fireball_prepare_ini, boss.aux_fireball_prepare_ini,
				boss.aux_fireball_prepare_end, boss.aux_fireball_prepare_end,
				boss.aux_fireball_prepare_end, boss.aux_fireball_prepare_end
			)
		else:
			# GMS2: drift toward center X at 1px/frame = 60px/s (only leftward in GMS2)
			var center: Vector2 = boss.get_camera_center()
			if creature.global_position.x > center.x:
				creature.global_position.x -= 60.0 * _dt

		# GMS2: when path_position == 1.0 → transition to WAITING
		if _path_progress >= 1.0:
			phase = FireballPhase.WAITING
			_waiting_ready = false
			_waiting_timer = 0.0
			go_fireball = true  # GMS2: goFireball = true at path end
	else:
		# Before 0.75: follow path + tick-based scaling (NO animation)
		if _path_curve and _path_length > 0:
			# GMS2: points 0-2 speed=100, points 3-5 speed=150
			var current_speed: float = _path_speed
			if _path_progress > _PATH_SPEED_FAST_THRESHOLD:
				current_speed *= _PATH_SPEED_FAST_MULTIPLIER
			_path_progress += current_speed / _path_length
			_path_progress = clampf(_path_progress, 0.0, 1.0)
			var path_pos: Vector2 = _path_curve.sample_baked(_path_progress * _path_length)
			creature.global_position = path_pos

		# GMS2: Scale using ease_out_quart(state_timer, 5, -4.95, 250/60)
		if _scale_factor > 0.15:
			var t_norm: float = clampf(timer / (250.0 / 60.0), 0.0, 1.0)
			_scale_factor = -4.95 * (1.0 - pow(1.0 - t_norm, 4)) + 5.0

		# Decrease comingTick every 25/60 seconds (from 10/60 down to 2/60)
		# Use timer-based check instead of modulo
		var _tick_decrease_interval: float = 25 / 60.0
		var tick_decrease_count: int = int(timer / _tick_decrease_interval)
		_coming_tick = maxf(2 / 60.0, (10 - tick_decrease_count) / 60.0)

		_tick_counter += _dt
		if _tick_counter >= _coming_tick:
			_tick_counter = 0.0
			creature.scale = Vector2(_scale_factor, _scale_factor)

	# Safety timeout
	if timer >= 250 / 60.0 and _path_progress < 1.0:
		phase = FireballPhase.WAITING
		_waiting_ready = false
		_waiting_timer = 0.0

func _phase_waiting(_timer: float, boss: BossManaBeast) -> void:
	# GMS2: Initialize waiting phase once (phase_waitingReady flag)
	if not _waiting_ready:
		_waiting_ready = true
		var center: Vector2 = boss.get_camera_center()
		creature.global_position = Vector2(center.x, center.y - 30)
		creature.rotation = 0.0
		creature.scale = Vector2(0.8, 0.8)
		creature.image_speed = 0.1
		boss.use_aux_sprite()
		creature.set_frame(boss.aux_fireball_wait_ini)
		creature.set_default_facing_animations(
			boss.aux_fireball_wait_ini, boss.aux_fireball_wait_ini,
			boss.aux_fireball_wait_ini, boss.aux_fireball_wait_ini,
			boss.aux_fireball_wait_end, boss.aux_fireball_wait_end,
			boss.aux_fireball_wait_end, boss.aux_fireball_wait_end
		)
		# GMS2: enableShader(shc_saturate, -0.50)
		if _saturate_material:
			creature.enable_shader(_saturate_material)
			_saturate_material.set_shader_parameter("u_amount", -0.50)

	# GMS2: animate with fireball_wait frames
	creature.animate_sprite(0.1, true)
	_waiting_timer += _dt

	if _waiting_timer > 180 / 60.0:
		MusicManager.play_sfx("snd_flammie")
		_blend_screen_done = false

		if go_fireball:
			phase = FireballPhase.FIREBALL
			_fireball_timer = 0.0
			creature.disable_shader()
			boss.use_fire_sprite()
			creature.set_frame(0)
			creature.image_speed = 0.0
			creature.scale = Vector2(0.05, 0.05)
		else:
			phase = FireballPhase.COMING
			_coming_ready = false
			_coming_timer = 0.0
			if _saturate_material:
				creature.enable_shader(_saturate_material)
				_saturate_material.set_shader_parameter("u_amount", -0.50)

func _phase_fireball(_timer: float, boss: BossManaBeast) -> void:
	creature.image_speed = 0.0
	_fireball_timer += _dt

	# GMS2: spin every 5/60 seconds + CUMULATIVE scale
	_fireball_spin_acc += _dt
	if _fireball_spin_acc >= 5 / 60.0:
		_fireball_spin_acc -= 5 / 60.0
		spin_angle -= 0.785398  # -45 degrees
		creature.rotation = spin_angle

		# GMS2: augmentFireball = ease_in_quint(timer0, 0.05, 8, 200/60)
		# image_xscale += augmentFireball (CUMULATIVE addition)
		var t_norm: float = clampf(_fireball_timer / (200.0 / 60.0), 0.0, 1.0)
		var augment: float = 8.0 * pow(t_norm, 5) + 0.05
		creature.scale += Vector2(augment, augment)

	# GMS2: timer0 > 200/60 → red screen flash + damage all players
	if _fireball_timer > 200 / 60.0 and not _blend_screen_done:
		_blend_screen_done = true
		if GameManager.map_transition:
			GameManager.map_transition.blend_screen_on(Color.RED, 1.0)
		for player in GameManager.get_alive_players():
			if player is Creature and is_instance_valid(player):
				DamageCalculator.perform_attack(player, creature, Constants.AttackType.ETEREAL)

	# GMS2: timer0 > 240/60 → goFireball=false, blendScreenOff, back to WAITING
	if _fireball_timer > 240 / 60.0:
		go_fireball = false
		if GameManager.map_transition:
			GameManager.map_transition.fade_in(1, Color.RED)
		_waiting_ready = false
		_waiting_timer = 0.0
		creature.rotation = 0.0
		creature.scale = Vector2(0.8, 0.8)
		boss.use_aux_sprite()
		phase = FireballPhase.WAITING

func _phase_coming(_timer: float, boss: BossManaBeast) -> void:
	# GMS2: Initialize coming phase once (phase_comingReady flag)
	if not _coming_ready:
		creature.image_speed = 0.0
		creature.set_frame(boss.aux_coming_ini)
		boss.use_aux_sprite()
		creature.scale = Vector2(0.1, 0.1)
		_coming_timer = 0.0
		_coming_ready = true
		_coming_start_y = creature.global_position.y
		_blend_screen_done = false
		_tick_counter = 0.0

	_coming_timer += _dt

	# GMS2: Desaturation lift: -0.50 + clamp(timer/(200/60), 0, 0.5)
	if _saturate_material:
		var lift: float = clampf(_coming_timer / (200.0 / 60.0), 0.0, 0.5)
		_saturate_material.set_shader_parameter("u_amount", -0.50 + lift)

	# GMS2: Scale up every 4/60 seconds using ease_in_power(timer0, 0.1, 10, 200/60, 15)
	_tick_counter += _dt
	if _tick_counter >= 4 / 60.0:
		_tick_counter -= 4 / 60.0
		var t_norm: float = clampf(_coming_timer / (200.0 / 60.0), 0.0, 1.0)
		var ease_val: float = pow(t_norm, 15)
		var target_scale: float = 0.1 + ease_val * 10.0
		creature.scale = Vector2(target_scale, target_scale)

	# GMS2: Move DOWNWARD - y = yy + ease_out_quart(timer0, 0, 30, 180/60)
	var move_t: float = clampf(_coming_timer / (180.0 / 60.0), 0.0, 1.0)
	var move_ease: float = 1.0 - pow(1.0 - move_t, 4)
	creature.global_position.y = _coming_start_y + move_ease * 30.0

	# GMS2: timer0 > 240/60: FLAMMIE color screen blend + damage, then → STAND
	if _coming_timer > 240 / 60.0:
		if not _blend_screen_done:
			_blend_screen_done = true
			if GameManager.map_transition:
				GameManager.map_transition.blend_screen_on(FLAMMIE_COLOR, 1.0)
			for player in GameManager.get_alive_players():
				if player is Creature and is_instance_valid(player):
					DamageCalculator.perform_attack(player, creature, Constants.AttackType.ETEREAL)

		# GMS2: go_blendScreenOff(0) + reposition before STAND
		if GameManager.map_transition:
			GameManager.map_transition.fade_in(1, FLAMMIE_COLOR)
		# GMS2: hide transition between coming and stand
		var center: Vector2 = boss.get_camera_center()
		creature.scale = Vector2(2.0, 2.0)
		creature.global_position.x = center.x
		creature.global_position.y = center.y - 250.0
		creature.rotation = 0.0
		creature.disable_shader()
		switch_to("MBStand")

func exit() -> void:
	creature.rotation = 0.0
	creature.modulate = Color.WHITE
	creature.disable_shader()
	_saturate_material = null
