class_name Projectile
extends Area2D
## Ranged weapon projectile (GMS2: oWeaponHitbox_bow / _boomerang / _javelin)
## Handles flight movement, arc trajectory, return (boomerang), and damage detection.

enum ProjectileType { BOW, BOOMERANG, JAVELIN }

# Configuration
var projectile_type: int = ProjectileType.BOW
var source_creature: Creature = null
var facing: int = Constants.Facing.DOWN
var weapon_attack_type: int = Constants.WeaponAttackType.BOW

# Movement
var shot_power: float = 6.0
var shot_distance: float = 0.0
var shot_distance_limit: float = 13.0
var max_height: float = 15.0
var shot_power_momentum: float = 0.0

# Boomerang return phase
var _phase: int = 0  # 0=outgoing, 1=returning

# Arc tracking
var _peak_y: float = 0.0
var _fall_dist: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO

# Damage tracking
var _damaged_creatures: Array = []
var _destroy_timer: float = 0.0
var _visible_delay: float = 0.0
var _delay_counter: float = 0.0

# Sprite
var _sprite: Sprite2D = null
var _sprite_sheet: Texture2D = null
var _frame_width: int = 0
var _frame_height: int = 0
var _columns: int = 10
var _origin: Vector2 = Vector2.ZERO
var _current_frame: int = 0
var _anim_speed: float = 0.0
var _frame_accumulator: float = 0.0

# Projectile configs per type
const CONFIG := {
	ProjectileType.BOW: {
		"speed": 6.0,
		"distance": 78.0,  # 13 tiles * 6
		"max_height": 15.0,
		"visible_delay": 30,
		"sprite": "spr_projectile_bow",
		"anim_speed": 0.0,  # Static
	},
	ProjectileType.BOOMERANG: {
		"speed": 8.2,
		"distance": 30.0,  # GMS2: shotDistanceLimit=30 (decel starts after 30px, total ~103px)
		"max_height": 0.0,
		"visible_delay": 15,
		"sprite": "spr_projectile_boomerang",
		"anim_speed": 0.5,  # Rotating
	},
	ProjectileType.JAVELIN: {
		"speed": 4.2,
		"distance": 84.0,  # 20 tiles * 4.2
		"max_height": 30.0,
		"visible_delay": 0,
		"sprite": "spr_projectile_javelin",
		"anim_speed": 0.0,  # Static
	},
}

## Direction frame mapping: { facing: frame_index } for each projectile sprite
const FACING_FRAMES := {
	ProjectileType.BOW: {
		Constants.Facing.UP: 0,
		Constants.Facing.RIGHT: 1,
		Constants.Facing.DOWN: 2,
		Constants.Facing.LEFT: 3,
	},
	ProjectileType.BOOMERANG: {
		Constants.Facing.UP: 0,
		Constants.Facing.RIGHT: 0,
		Constants.Facing.DOWN: 0,
		Constants.Facing.LEFT: 0,
	},
	ProjectileType.JAVELIN: {
		Constants.Facing.UP: 0,
		Constants.Facing.RIGHT: 0,
		Constants.Facing.DOWN: 0,
		Constants.Facing.LEFT: 0,
	},
}

func _ready() -> void:
	collision_layer = 0
	# GMS2: actors target mobs, mobs target actors (same as hitbox.gd)
	if source_creature is Mob:
		collision_mask = 2  # Layer 2 = actors only
	else:
		collision_mask = 4  # Layer 3 = mobs only

	# Create collision shape
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var col_shape := CollisionShape2D.new()
	col_shape.shape = shape
	add_child(col_shape)

	# Create sprite
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)

	# Apply config
	var cfg: Dictionary = CONFIG.get(projectile_type, CONFIG[ProjectileType.BOW])
	shot_power = cfg.get("speed", 6.0)
	shot_distance_limit = cfg.get("distance", 78.0)
	max_height = cfg.get("max_height", 15.0)
	_visible_delay = cfg.get("visible_delay", 0) / 60.0
	_anim_speed = cfg.get("anim_speed", 0.0)
	shot_power_momentum = shot_power

	# Load sprite sheet
	var sprite_name: String = cfg.get("sprite", "spr_projectile_bow")
	var sheet_path: String = "res://assets/sprites/sheets/%s.png" % sprite_name
	var json_path: String = sheet_path.replace(".png", ".json")

	if ResourceLoader.exists(sheet_path):
		_sprite_sheet = load(sheet_path)
		_sprite.texture = _sprite_sheet
		_sprite.region_enabled = true

		# Load metadata
		if FileAccess.file_exists(json_path):
			var f := FileAccess.open(json_path, FileAccess.READ)
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK:
				var meta: Dictionary = json.data
				_frame_width = meta.get("frame_width", 32)
				_frame_height = meta.get("frame_height", 32)
				_columns = meta.get("columns", 10)
				_origin = Vector2(meta.get("xorigin", _frame_width / 2), meta.get("yorigin", _frame_height / 2))
		_sprite.offset = -_origin

		# Set initial frame based on facing
		var frame_map: Dictionary = FACING_FRAMES.get(projectile_type, {})
		_current_frame = frame_map.get(facing, 0)
		_set_region(_current_frame)
	else:
		_sprite.visible = false

	# Rotation for boomerang (up/down rotated 90 deg)
	if projectile_type == ProjectileType.BOOMERANG:
		if facing in [Constants.Facing.UP, Constants.Facing.DOWN]:
			_sprite.rotation_degrees = 90

	# Rotation for javelin (up/down rotated 90 deg)
	if projectile_type == ProjectileType.JAVELIN:
		if facing in [Constants.Facing.UP, Constants.Facing.DOWN]:
			_sprite.rotation_degrees = 90

	# _start_pos is set by spawn() AFTER global_position is assigned
	_sprite.visible = _visible_delay == 0

	# Z ordering: use Y position like creatures do (creature.gd _update_draw_order)
	z_index = int(global_position.y) + 1

	# Connect signals
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Y-based draw order (same as creature._update_draw_order)
	z_index = int(global_position.y) + 1
	# GMS2: ring menu pauses all combat logic
	if GameManager.ring_menu_opened:
		return

	# GMS2: visibility delay — ALL movement gated by timer > startTime
	# Arrow/javelin waits at source position during delay, then moves visible
	if _delay_counter < _visible_delay:
		_delay_counter += delta
		if _delay_counter >= _visible_delay:
			_sprite.visible = true
		return

	match projectile_type:
		ProjectileType.BOW:
			_process_bow(delta)
		ProjectileType.BOOMERANG:
			_process_boomerang(delta)
		ProjectileType.JAVELIN:
			_process_javelin(delta)

	# Animate sprite
	if _anim_speed > 0.0:
		_frame_accumulator += _anim_speed * delta * 60.0
		if _frame_accumulator >= 1.0:
			_frame_accumulator -= 1.0
			_current_frame += 1
			if _sprite_sheet:
				var total_frames: int = _columns
				if _current_frame >= total_frames:
					_current_frame = 0
				_set_region(_current_frame)

func _process_bow(delta: float) -> void:
	if shot_distance < shot_distance_limit:
		var move: float = shot_power * delta * 60.0
		shot_distance += move
		match facing:
			Constants.Facing.UP:
				position.y -= move
			Constants.Facing.RIGHT:
				position.x += move
				position.y = _start_pos.y + _get_arc_y_offset()
			Constants.Facing.DOWN:
				position.y += move
			Constants.Facing.LEFT:
				position.x -= move
				position.y = _start_pos.y + _get_arc_y_offset()
	else:
		# GMS2: image_index = state_facing + 4 (hit/destroy sprite)
		if _destroy_timer == 0.0:
			var destroy_frame: int = FACING_FRAMES.get(projectile_type, {}).get(facing, 0) + 4
			_set_region(destroy_frame)
		_destroy_timer += delta
		if _destroy_timer > 30.0 / 60.0:
			queue_free()

func _process_boomerang(delta: float) -> void:
	if _phase == 0:
		# Outgoing phase
		var move: float = shot_power_momentum * delta * 60.0
		shot_distance += move
		match facing:
			Constants.Facing.UP:
				position.y -= move
			Constants.Facing.RIGHT:
				position.x += move
			Constants.Facing.DOWN:
				position.y += move
			Constants.Facing.LEFT:
				position.x -= move

		if shot_distance > shot_distance_limit:
			shot_power_momentum -= 0.5 * delta * 60.0
			shot_power_momentum = clampf(shot_power_momentum, 0.0, shot_power)

		if shot_power_momentum <= 0.0:
			_phase = 1
			# GMS2: phase=1 starts with momentum=0, then increments by 0.5 before move
			shot_power_momentum = 0.0
	else:
		# Return phase - move toward source (GMS2: move_towards_point)
		if is_instance_valid(source_creature):
			# GMS2: accelerate first, then move (capped at shotPower)
			shot_power_momentum += 0.5 * delta * 60.0
			shot_power_momentum = clampf(shot_power_momentum, 0.0, shot_power)
			var dir: Vector2 = (source_creature.global_position - global_position).normalized()
			global_position += dir * shot_power_momentum * delta * 60.0

			# GMS2: position_meeting(belongsTo.x, belongsTo.y, self)
			if global_position.distance_to(source_creature.global_position) < 8.0:
				queue_free()
		else:
			queue_free()

func _process_javelin(delta: float) -> void:
	if shot_distance < shot_distance_limit:
		var move: float = shot_power * delta * 60.0
		shot_distance += move
		match facing:
			Constants.Facing.UP:
				position.y -= move
			Constants.Facing.RIGHT:
				position.x += move
				position.y = _start_pos.y + _get_arc_y_offset()
			Constants.Facing.DOWN:
				position.y += move
			Constants.Facing.LEFT:
				position.x -= move
				position.y = _start_pos.y + _get_arc_y_offset()
	else:
		_destroy_timer += delta
		if _destroy_timer > 15.0 / 60.0:
			queue_free()

func _get_arc_y_offset() -> float:
	## Calculate Y offset for parabolic arc (GMS2: getThrownProjectleYPosition)
	if max_height <= 0.0:
		return 0.0

	var half_dist: float = shot_distance_limit / 2.0
	var t: float

	if shot_distance < half_dist:
		# Ascending: ease_out_sine
		t = shot_distance / half_dist
		return -max_height * sin(t * PI / 2.0)
	else:
		# Descending: ease_in_sine
		t = (shot_distance - half_dist) / half_dist
		return -max_height * (1.0 - (1.0 - cos(t * PI / 2.0)))

func _set_region(frame_index: int) -> void:
	if not _sprite or _frame_width == 0:
		return
	var col := frame_index % _columns
	@warning_ignore("INTEGER_DIVISION")
	var row: int = frame_index / _columns
	_sprite.region_rect = Rect2(col * _frame_width, row * _frame_height, _frame_width, _frame_height)

func _on_body_entered(body: Node2D) -> void:
	if body == source_creature:
		return
	if body is Creature and not _damaged_creatures.has(body):
		if not body.is_invulnerable:
			_damaged_creatures.append(body)
			DamageCalculator.perform_attack(body, source_creature, Constants.AttackType.WEAPON)
			# Award weapon EXP
			if source_creature is Actor:
				var actor := source_creature as Actor
				actor.add_weapon_experience(actor.get_weapon_name(), 1)
			# Bow and javelin destroy on hit; boomerang continues
			if projectile_type != ProjectileType.BOOMERANG:
				queue_free()

## Static helper to spawn a projectile
static func spawn(source: Creature, weapon_id: int, p_facing: int) -> Projectile:
	var proj := Projectile.new()
	proj.source_creature = source
	proj.facing = p_facing
	proj.name = "Projectile"

	match weapon_id:
		Constants.Weapon.BOW:
			proj.projectile_type = ProjectileType.BOW
			proj.weapon_attack_type = Constants.WeaponAttackType.BOW
		Constants.Weapon.BOOMERANG:
			proj.projectile_type = ProjectileType.BOOMERANG
			proj.weapon_attack_type = Constants.WeaponAttackType.THROW
		Constants.Weapon.JAVELIN:
			proj.projectile_type = ProjectileType.JAVELIN
			proj.weapon_attack_type = Constants.WeaponAttackType.THROW
		_:
			proj.queue_free()
			return null

	source.get_parent().add_child(proj)
	proj.global_position = source.global_position
	proj._start_pos = proj.position  # Capture start position AFTER global_position is set
	return proj
