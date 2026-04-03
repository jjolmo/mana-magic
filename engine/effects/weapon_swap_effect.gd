class_name WeaponSwapEffect
extends Node2D
## Visual effect for weapon swap between two party members (GMS2: oSwapWeapons)
## Shows weapon icons rising, crossing paths, and falling to opposite players.
## Duration: 60 frames (~1 second at 60fps).

var actor_a: Actor = null
var actor_b: Actor = null
var icon_a: Texture2D = null  # Weapon icon moving FROM actor_a TO actor_b
var icon_b: Texture2D = null  # Weapon icon moving FROM actor_b TO actor_a

var _time: float = 0.0
var _limit_time: float = 1.0  # 60 frames / 60fps = 1 second
var _max_height: float = 150.0

# Animated positions for each icon
var _icon_a_pos: Vector2 = Vector2.ZERO
var _icon_b_pos: Vector2 = Vector2.ZERO

# Starting positions (actor world positions)
var _start_a: Vector2 = Vector2.ZERO
var _start_b: Vector2 = Vector2.ZERO

# Horizontal movement speeds
var _x_speed_a: float = 0.0
var _x_speed_b: float = 0.0

# Rise phase peak tracking
var _peak_a_y: float = 0.0
var _peak_b_y: float = 0.0
var _fall_dist_a: float = 0.0
var _fall_dist_b: float = 0.0

# Icon draw offset (GMS2: xOffset=-10, yOffset=-15)
const ICON_OFFSET := Vector2(-10, -15)

## Spawn the weapon swap effect
static func create(a: Actor, b: Actor, icon_for_a: Texture2D, icon_for_b: Texture2D) -> WeaponSwapEffect:
	var effect := WeaponSwapEffect.new()
	effect.actor_a = a
	effect.actor_b = b
	effect.icon_a = icon_for_a  # Icon of weapon going TO actor_b
	effect.icon_b = icon_for_b  # Icon of weapon going TO actor_a
	effect.name = "WeaponSwapEffect"

	# GMS2: pauseCreature() + state_switch(state_ANIMATION) on both actors
	a.swapping_weapon = true
	b.swapping_weapon = true
	a.pause_creature()
	b.pause_creature()

	# Play swap sound
	MusicManager.play_sfx("snd_weaponSwap")

	# Add to scene tree
	a.get_parent().add_child(effect)

	return effect

func _ready() -> void:
	# Capture starting positions
	_start_a = actor_a.global_position
	_start_b = actor_b.global_position
	_icon_a_pos = _start_a
	_icon_b_pos = _start_b

	# Calculate horizontal speeds (icons cross to opposite player — pixels per second)
	_x_speed_a = (_start_b.x - _start_a.x) / _limit_time
	_x_speed_b = (_start_a.x - _start_b.x) / _limit_time

	# GMS2: created on lyr_animations (depth -14000), always above creatures
	z_index = 1000

func _process(delta: float) -> void:
	if _time < _limit_time:
		var half: float = _limit_time / 2.0

		# Update horizontal positions
		_icon_a_pos.x = _start_a.x + _x_speed_a * _time
		_icon_b_pos.x = _start_b.x + _x_speed_b * _time

		if _time < half:
			# RISE PHASE: ease_out_sine - fast start, slow at peak
			var t: float = _time / half
			var ease_val: float = sin(t * PI / 2.0)

			_icon_a_pos.y = _start_a.y - _max_height * ease_val
			_icon_b_pos.y = _start_b.y - _max_height * ease_val

			# Save peak positions for fall phase
			_peak_a_y = _icon_a_pos.y
			_peak_b_y = _icon_b_pos.y
			_fall_dist_a = _start_b.y - _peak_a_y
			_fall_dist_b = _start_a.y - _peak_b_y
		else:
			# FALL PHASE: ease_in_sine - slow start, fast at end
			var t: float = (_time - half) / half
			var ease_val: float = 1.0 - cos(t * PI / 2.0)

			_icon_a_pos.y = _peak_a_y + _fall_dist_a * ease_val
			_icon_b_pos.y = _peak_b_y + _fall_dist_b * ease_val

		_time += delta
	else:
			# Animation complete - restore actors
			# GMS2 did pauseCreature() + state_switch(state_ANIMATION) on create,
			# so change_state_stand_dead() was the SECOND switch (which clears paused).
			# Since we skipped the intermediate state_switch, we must clear paused
			# explicitly before the final state switch.
			if is_instance_valid(actor_a):
				actor_a.swapping_weapon = false
				actor_a.paused = false
				actor_a._resume_pause_next_switch = false
				actor_a.change_state_stand_dead()
			if is_instance_valid(actor_b):
				actor_b.swapping_weapon = false
				actor_b.paused = false
				actor_b._resume_pause_next_switch = false
				actor_b.change_state_stand_dead()
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	# Draw icons at their animated world positions relative to this node
	if icon_a:
		var pos_a: Vector2 = _icon_a_pos - global_position + ICON_OFFSET
		draw_texture(icon_a, pos_a)
	if icon_b:
		var pos_b: Vector2 = _icon_b_pos - global_position + ICON_OFFSET
		draw_texture(icon_b, pos_b)
