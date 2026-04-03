class_name BossManaBeastStand
extends State
## Mana Beast STAND state - replaces fsm_mob_manaBeast_stand from GMS2
## 3-phase idle: appears (descend), stand (cast spells), going (scale up & leave)

enum StandPhase { APPEARS, STAND, GOING }

var phase: int = StandPhase.APPEARS
var appear_direction: float = 1.0 # 1=descend from above, -1=ascend from below
var appear_target_y: float = 0.0
var stand_timer: float = 0.0  # GMS2: timer_changePhase (counts up to 30.0 seconds)
var going_timer: float = 0.0
var _going_scale_tick: float = 0.0

# GMS2: timer_cast — separate counter for lucentBeam interval (resets after each cast)
var _cast_timer: float = 0.0
var _cast_limit: float = 8.0  # 480 / 60.0 = 8.0 seconds

# GMS2: Wall is recast when it expires; timer_changePhase -= 2*60 each recast
var _wall_active: bool = false
var _stand_set_invulnerable: bool = false  # GMS2: stand_setInvulnerable flag

# GOING phase screen blend
var _doing_flash: bool = false
var _color_flash_timer: float = 0.0
var _dt: float = 0.0  # cached delta for helper functions

# Colors
const FLAMMIE_FLESH := Color(198.0 / 255.0, 97.0 / 255.0, 57.0 / 255.0, 1.0)

func enter() -> void:
	var boss := creature as BossManaBeast
	if not boss:
		return

	phase = StandPhase.APPEARS
	boss.phase_time = 0
	creature.velocity = Vector2.ZERO
	going_timer = 0.0
	stand_timer = 0.0
	_going_scale_tick = 0.0
	_color_flash_timer = 0.0
	_doing_flash = false
	_wall_active = false
	_stand_set_invulnerable = false

	# GMS2: randomize cast interval between 8-12 seconds (was 480-720 frames), set once
	_cast_limit = randf_range(480 / 60.0, 720 / 60.0)
	_cast_timer = 0.0

	# Use camera center for positioning (GMS2: getCameraCenter())
	var center: Vector2 = boss.get_camera_center()

	# GMS2: Determine appear direction and position
	# comingSide = rollCoin(); if comingSide → y = center+250 else y = center-250
	var coming_side: bool = randi() % 2 == 0
	if coming_side:
		# GMS2: comingSide true → start BELOW (center+250), move UP to center-10
		creature.global_position.y = center.y + 250.0
		appear_target_y = center.y - 10.0
		appear_direction = -1.0  # Move upward
	else:
		# GMS2: comingSide false → start ABOVE (center-250), move DOWN to center+10
		creature.global_position.y = center.y - 250.0
		appear_target_y = center.y + 10.0
		appear_direction = 1.0  # Move downward

	creature.global_position.x = center.x

	# GMS2: image_xscale = 2; image_yscale = 2 in state_new
	creature.scale = Vector2(2.0, 2.0)

	# Start invulnerable + untargetable during appear
	creature.is_invulnerable = true
	creature.is_untargetable = true

	# GMS2: Switch to front sprite for STAND
	boss.use_front_sprite()
	creature.image_speed = boss.img_speed_stand

func execute(delta: float) -> void:
	_dt = delta
	var boss := creature as BossManaBeast
	if not boss:
		return

	var timer := get_timer()

	# GMS2: if (state_timer > 120) — entire stand logic waits 2.0 seconds (was 120 frames)
	if timer <= 120 / 60.0:
		return

	# GMS2: animateSprite(state_imgSpeedStand) runs every frame after 120
	creature.animate_sprite(creature.image_speed, true)

	match phase:
		StandPhase.APPEARS:
			_phase_appears(timer, boss)
		StandPhase.STAND:
			_phase_stand(timer, boss)
		StandPhase.GOING:
			_phase_going(timer, boss)

	# GMS2: fsm_mob_manaBeast_hit() is called at the end of stand (unified hit processing)
	_process_damage_stack(boss)

func _process_damage_stack(_boss: BossManaBeast) -> void:
	## GMS2: fsm_mob_manaBeast_hit() — inlined hit logic, processes damage_stack
	if creature.damage_stack.size() > 0 and not creature.is_invulnerable:
		var dmg_data: Variant = creature.damage_stack.pop_front()
		if dmg_data is Dictionary:
			creature.apply_damage(dmg_data.get("damage", 0))
			MusicManager.play_sfx("snd_hurt")
		if creature.is_dead:
			switch_to("MBDead")

func _phase_appears(_timer: float, _boss: BossManaBeast) -> void:
	# GMS2: Move at 0.4 pixels per frame toward target (0.4 * 60 = 24.0 px/s)
	if appear_direction > 0:
		# Moving DOWN (started above)
		creature.global_position.y += 24.0 * _dt
		if creature.global_position.y >= appear_target_y:
			_arrive_at_stand()
	else:
		# Moving UP (started below)
		creature.global_position.y -= 24.0 * _dt
		if creature.global_position.y <= appear_target_y:
			_arrive_at_stand()

func _arrive_at_stand() -> void:
	## Transition from APPEARS to STAND
	creature.global_position.y = appear_target_y
	phase = StandPhase.STAND
	stand_timer = 0.0
	_cast_timer = 0.0
	_stand_set_invulnerable = false

	# GMS2: with(oActor) { ignoreCollisionSightDetection = true }
	# Actors skip raycast sight check so AI companions can target the flying boss
	_set_actors_ignore_sight(true)

	# GMS2: Cast wall on self (infinite duration via level 8)
	SkillSystem.cast_skill("wall", creature, creature, 8)
	# GMS2: attribute.statusListTimer[STATUS_BUFF_WALL] = -1 (infinite)
	# Setting to 0 means permanent (_update_status_timers only counts down when > 0)
	if Constants.Status.WALL < creature.status_timers.size():
		creature.status_timers[Constants.Status.WALL] = 0
	_wall_active = true

func _phase_stand(_timer: float, _boss: BossManaBeast) -> void:
	stand_timer += _dt
	_cast_timer += _dt

	# GMS2: Become vulnerable once (stand_setInvulnerable flag)
	if not _stand_set_invulnerable:
		creature.is_invulnerable = false
		creature.is_untargetable = false
		_stand_set_invulnerable = true

	# GMS2: Check if Wall buff has expired; recast and penalize timer
	if _wall_active and not creature.has_status(Constants.Status.WALL):
		_wall_active = false

	if not _wall_active:
		# GMS2: timer_changePhase -= 2*60 when Wall needs recast (2 seconds)
		stand_timer = maxf(0.0, stand_timer - 2.0)
		SkillSystem.cast_skill("wall", creature, creature, 8)
		# Make infinite again
		if Constants.Status.WALL < creature.status_timers.size():
			creature.status_timers[Constants.Status.WALL] = 0
		_wall_active = true

	# GMS2: Cast lucentBeam using separate _cast_timer > _cast_limit (resets after cast)
	if _cast_timer > _cast_limit:
		var players: Array = GameManager.get_alive_players()
		if players.size() > 0:
			var target_player: Node = players[randi() % players.size()]
			if is_instance_valid(target_player):
				SkillSystem.cast_skill("lucentBeam", creature, target_player, 8)
		_cast_timer = 0.0  # GMS2: timer_cast = 0 (reset counter, limit stays the same)

	# GMS2: Transition to going phase after 30 seconds (was 1800 frames)
	if stand_timer >= 30.0:
		phase = StandPhase.GOING
		going_timer = 0.0
		_going_scale_tick = 0.0
		_doing_flash = false
		_color_flash_timer = 0.0
		# GMS2: scale stays at 2x2 from state_new; ease_in_power starts at 2 and ramps to 42
		# Do NOT reset scale here — scaleFactor=0.2 in GMS2 was just a variable init, not image_xscale

		# Make invulnerable during going
		creature.is_invulnerable = true
		creature.is_untargetable = true

		# GMS2: with(oActor) { ignoreCollisionSightDetection = false }
		_set_actors_ignore_sight(false)

func _phase_going(_timer: float, _boss: BossManaBeast) -> void:
	going_timer += _dt

	if _doing_flash:
		# GMS2: FLAMMIE_FLESH screen blend for 0.5 seconds (was 30 frames), then transition
		_color_flash_timer += _dt
		if _color_flash_timer >= 30 / 60.0:
			# GMS2: go_blendScreenOff(0)
			if GameManager.map_transition:
				GameManager.map_transition.fade_in(1, FLAMMIE_FLESH)
			creature.scale = Vector2.ONE
			creature.visible = false  # GMS2: becomes invisible before SIDE
			switch_to("MBSide")
		return

	# GMS2: Scale up every 5/60 seconds using ease_in_power(timer0, 2, 40, 3.0s, 8)
	_going_scale_tick += _dt
	if _going_scale_tick >= 5 / 60.0:
		_going_scale_tick = 0.0
		var t_norm: float = clampf(going_timer / (180.0 / 60.0), 0.0, 1.0)
		var ease_val: float = pow(t_norm, 8)  # power 8
		var target_scale: float = 2.0 + ease_val * 40.0
		creature.scale = Vector2(target_scale, target_scale)

	# GMS2: Transition when image_xscale > 40
	var current_scale: float = creature.scale.x
	if current_scale > 40.0 and not _doing_flash:
		_doing_flash = true
		_color_flash_timer = 0.0
		# GMS2: go_blendScreenOn(COLOR_FLAMMIE_FLESH, 1, 0, depthLayerObjects2)
		if GameManager.map_transition:
			GameManager.map_transition.blend_screen_on(FLAMMIE_FLESH, 1.0)

func exit() -> void:
	creature.velocity = Vector2.ZERO
	creature.visible = true

func _set_actors_ignore_sight(value: bool) -> void:
	## GMS2: with(oActor) { ignoreCollisionSightDetection = value }
	## When true, AI companions skip raycast checks and can always target the flying boss.
	for player in GameManager.players:
		if is_instance_valid(player) and player is Actor:
			(player as Actor).ignore_collision_sight_detection = value
