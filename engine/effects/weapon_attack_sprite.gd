class_name WeaponAttackSprite
extends Sprite2D
## Temporary weapon attack sprite overlay (GMS2: oTemporalSprite + drawWeaponAttack)
## Spawned during attack states to show the weapon swing/thrust/etc.
## Auto-animates and auto-destroys when animation completes.

var master: Creature = null
var follow_master: bool = true
var subimg_start: int = 0
var subimg_end: int = 0
var anim_speed: float = 0.24
var destroy_timer: float = 0.0
var _timer: float = 0.0
var _frame_accumulator: float = 0.0
var _current_frame: int = 0
var _columns: int = 10
var _frame_width: int = 74
var _frame_height: int = 74
var _origin: Vector2 = Vector2(37, 37)
var _is_single_sprite: bool = false
var accel_on_frame: int = -1  # Frame at which animation speed accelerates (GMS2: accelOnFrame)
var _accel_applied: bool = false

# AnimatedSprite2D mode (new system)
var _use_animated: bool = false
var _animated_sprite: AnimatedSprite2D = null
var _destroy_after_anim: bool = false

## Weapon attack frame ranges per weapon per direction
## Format: { weapon_name: { "width":w, "height":h, "origin":Vector2, "columns":c,
##   "up":[ini,end], "right":[ini,end], "down":[ini,end], "left":[ini,end] } }
const WEAPON_ATTACK_DATA := {
	"sword": {
		"frames": {"up": [0,2], "right": [4,6], "down": [8,10], "left": [12,14]},
	},
	"axe": {
		"frames": {"up": [0,3], "right": [5,8], "down": [10,13], "left": [15,18]},
	},
	"spear": {
		"frames": {"up": [0,2], "right": [4,6], "down": [8,10], "left": [12,14]},
		"single_sprite": true,
	},
	"spear2": {
		"frames": {"up": [0,2], "right": [4,6], "down": [8,10], "left": [12,14]},
	},
	"spear3": {
		"frames": {"up": [0,2], "right": [4,6], "down": [8,10], "left": [12,14]},
	},
	"bow": {
		"frames": {"up": [0,4], "right": [6,11], "down": [12,17], "left": [18,22]},
	},
	"boomerang": {
		"frames": {"up": [0,1], "right": [3,4], "down": [6,7], "left": [9,10]},
	},
	"javelin": {
		"frames": {"up": [0,0], "right": [2,2], "down": [4,4], "left": [6,6]},
	},
	"whip": {
		"frames": {"up": [0,2], "right": [0,2], "down": [0,2], "left": [0,2]},
		"single_sprite": true,
	},
	"knucles": {
		"frames": {"up": [0,2], "right": [4,6], "down": [8,10], "left": [12,14]},
	},
	"none": {
		"frames": {"up": [0,2], "right": [4,6], "down": [8,10], "left": [12,14]},
	},
}

## Resolve the correct weapon sprite name based on weapon_id and attack_kind
static func get_weapon_sprite_name(weapon_id: int, attack_kind: int = 0) -> String:
	match weapon_id:
		Constants.Weapon.SWORD: return "sword"
		Constants.Weapon.AXE: return "axe"
		Constants.Weapon.SPEAR:
			if attack_kind <= 0: return "spear"
			elif attack_kind == 1: return "spear2"
			else: return "spear3"
		Constants.Weapon.BOW: return "bow"
		Constants.Weapon.BOOMERANG: return "boomerang"
		Constants.Weapon.JAVELIN: return "javelin"
		Constants.Weapon.WHIP: return "whip"
		Constants.Weapon.KNUCKLES: return "knucles"
		Constants.Weapon.NONE: return "none"
	return "sword"

## Setup and spawn the weapon attack sprite
func setup(p_master: Creature, weapon_id: int, facing: int, attack_kind: int = 0, p_destroy_timer: int = 0) -> void:
	master = p_master
	destroy_timer = p_destroy_timer / 60.0 if p_destroy_timer > 0 else 0.0

	var sprite_name: String = get_weapon_sprite_name(weapon_id, attack_kind)

	# Try AnimatedSprite2D from .tres (new system)
	var tres_path: String = "res://assets/animations/weapons/%s/%s.tres" % [sprite_name, sprite_name]
	if ResourceLoader.exists(tres_path):
		if _setup_animated(tres_path, weapon_id, facing, sprite_name):
			return

	# Fallback: legacy Sprite2D system
	_setup_legacy(sprite_name, weapon_id, facing)

func _setup_animated(tres_path: String, weapon_id: int, facing: int, sprite_name: String) -> bool:
	var sf: SpriteFrames = load(tres_path)
	if not sf:
		return false

	var dir_name: String
	match facing:
		Constants.Facing.UP: dir_name = "up"
		Constants.Facing.RIGHT: dir_name = "right"
		Constants.Facing.DOWN: dir_name = "down"
		Constants.Facing.LEFT: dir_name = "left"
		_: dir_name = "down"

	var anim_name: String = "attack_%s" % dir_name

	# Single sprite weapons: use attack_up and rotate
	var data: Dictionary = WEAPON_ATTACK_DATA.get(sprite_name, {})
	_is_single_sprite = data.get("single_sprite", false)

	if _is_single_sprite:
		anim_name = "attack_up"

	if not sf.has_animation(anim_name):
		return false

	# Load metadata for origin
	var json_path: String = "res://assets/sprites/sheets/spr_weapon_%s.json" % sprite_name
	if FileAccess.file_exists(json_path):
		var f := FileAccess.open(json_path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(f.get_as_text()) == OK:
			var meta: Dictionary = json.data
			_origin = Vector2(meta.get("xorigin", 37), meta.get("yorigin", 37))

	# Create AnimatedSprite2D
	_use_animated = true
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.sprite_frames = sf
	_animated_sprite.centered = false
	_animated_sprite.offset = -_origin
	add_child(_animated_sprite)

	# Hide the Sprite2D texture but keep the node visible (children need to show)
	texture = null
	region_enabled = false

	# Single sprite rotation
	if _is_single_sprite:
		match facing:
			Constants.Facing.UP:
				_animated_sprite.rotation_degrees = 0
				_animated_sprite.scale.x = 1
			Constants.Facing.RIGHT:
				_animated_sprite.rotation_degrees = 90
				_animated_sprite.scale.x = -1
			Constants.Facing.DOWN:
				_animated_sprite.rotation_degrees = 180
				_animated_sprite.scale.x = -1
			Constants.Facing.LEFT:
				_animated_sprite.rotation_degrees = -90
				_animated_sprite.scale.x = 1

	# Set speed from weapon data
	if weapon_id < GameManager.weapon_image_attack_speed.size():
		anim_speed = GameManager.weapon_image_attack_speed[weapon_id]
	# Convert image_speed to speed_scale: the .tres has fps set, speed_scale multiplies it
	var base_fps: float = sf.get_animation_speed(anim_name)
	var target_fps: float = anim_speed * 60.0
	_animated_sprite.speed_scale = target_fps / maxf(base_fps, 1.0)

	# Whip acceleration: connect frame_changed
	if weapon_id == Constants.Weapon.WHIP:
		accel_on_frame = 2
		_animated_sprite.frame_changed.connect(_on_anim_frame_changed.bind(sf, anim_name))
	_accel_applied = false

	# Connect animation_finished for auto-destroy
	_animated_sprite.animation_finished.connect(_on_anim_finished)

	# Depth
	z_as_relative = false
	z_index = master.z_index + 1

	_animated_sprite.play(anim_name)
	return true

func _on_anim_frame_changed(sf: SpriteFrames, anim_name: String) -> void:
	if accel_on_frame >= 0 and not _accel_applied and _animated_sprite.frame >= accel_on_frame:
		_accel_applied = true
		if Constants.Weapon.SWORD < GameManager.weapon_image_attack_speed.size():
			var new_speed: float = GameManager.weapon_image_attack_speed[Constants.Weapon.SWORD] * 2.0
			var base_fps: float = sf.get_animation_speed(anim_name)
			var target_fps: float = new_speed * 60.0
			_animated_sprite.speed_scale = target_fps / maxf(base_fps, 1.0)

func _on_anim_finished() -> void:
	if destroy_timer > 0.0:
		_destroy_after_anim = true
	else:
		queue_free()

func _setup_legacy(sprite_name: String, weapon_id: int, facing: int) -> void:
	var sheet_path: String = "res://assets/sprites/sheets/spr_weapon_%s.png" % sprite_name
	var json_path: String = sheet_path.replace(".png", ".json")

	# Load sprite sheet
	if ResourceLoader.exists(sheet_path):
		texture = load(sheet_path)
	else:
		visible = false
		return

	# Load metadata
	if FileAccess.file_exists(json_path):
		var f := FileAccess.open(json_path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(f.get_as_text()) == OK:
			var meta: Dictionary = json.data
			_frame_width = meta.get("frame_width", 74)
			_frame_height = meta.get("frame_height", 74)
			_columns = meta.get("columns", 10)
			_origin = Vector2(meta.get("xorigin", _frame_width / 2), meta.get("yorigin", _frame_height / 2))

	region_enabled = true
	centered = false
	offset = -_origin

	# Get frame range for this direction
	var data: Dictionary = WEAPON_ATTACK_DATA.get(sprite_name, {})
	var frames: Dictionary = data.get("frames", {})
	_is_single_sprite = data.get("single_sprite", false)

	var dir_name: String
	match facing:
		Constants.Facing.UP: dir_name = "up"
		Constants.Facing.RIGHT: dir_name = "right"
		Constants.Facing.DOWN: dir_name = "down"
		Constants.Facing.LEFT: dir_name = "left"
		_: dir_name = "down"

	if _is_single_sprite:
		var first_frames: Array = frames.get("up", [0, 2])
		subimg_start = first_frames[0]
		subimg_end = first_frames[1]
		match facing:
			Constants.Facing.UP:
				rotation_degrees = 0
				scale.x = 1
			Constants.Facing.RIGHT:
				rotation_degrees = 90
				scale.x = -1
			Constants.Facing.DOWN:
				rotation_degrees = 180
				scale.x = -1
			Constants.Facing.LEFT:
				rotation_degrees = -90
				scale.x = 1
	else:
		var dir_frames: Array = frames.get(dir_name, [0, 2])
		subimg_start = dir_frames[0]
		subimg_end = dir_frames[1]

	_current_frame = subimg_start
	_set_region(_current_frame)

	# Set attack speed from weapon data
	if weapon_id < GameManager.weapon_image_attack_speed.size():
		anim_speed = GameManager.weapon_image_attack_speed[weapon_id]

	# Whip: accelerate animation after frame 2
	if weapon_id == Constants.Weapon.WHIP:
		accel_on_frame = 2
	_accel_applied = false

	# Depth
	z_as_relative = false
	z_index = master.z_index + 1

	visible = true

func _process(delta: float) -> void:
	if not is_instance_valid(master):
		queue_free()
		return

	# Follow master position
	if follow_master:
		global_position = master.global_position
		position.y -= master.z_height
		z_index = master.z_index + 1
		# Sync shader from master (saber effects)
		if master._saber_active and master._saber_shader:
			if _use_animated and _animated_sprite:
				_animated_sprite.material = master._saber_shader
			else:
				material = master._saber_shader
		elif master.sprite:
			if _use_animated and _animated_sprite:
				_animated_sprite.material = master.sprite.material
			else:
				material = master.sprite.material

	# ─── AnimatedSprite2D mode ───
	if _use_animated:
		# Destroy timer after animation finished
		if _destroy_after_anim:
			_timer += delta
			if _timer >= destroy_timer:
				queue_free()
		return

	# ─── Legacy Sprite2D mode ───
	if not visible:
		queue_free()
		return

	# Check for animation acceleration (whip: speed up after frame 2)
	if accel_on_frame >= 0 and not _accel_applied and _current_frame >= accel_on_frame:
		_accel_applied = true
		if Constants.Weapon.SWORD < GameManager.weapon_image_attack_speed.size():
			anim_speed = GameManager.weapon_image_attack_speed[Constants.Weapon.SWORD] * 2.0

	# Animate (frame-rate independent)
	_frame_accumulator += anim_speed * delta * 60.0
	if _frame_accumulator >= 1.0:
		_frame_accumulator -= 1.0
		_current_frame += 1

	if _current_frame > subimg_end:
		if destroy_timer > 0.0:
			_timer += delta
			_current_frame = subimg_end
			if _timer >= destroy_timer:
				queue_free()
				return
		else:
			queue_free()
			return

	_set_region(_current_frame)

func _set_region(frame_index: int) -> void:
	var col := frame_index % _columns
	@warning_ignore("INTEGER_DIVISION")
	var row: int = frame_index / _columns
	region_rect = Rect2(col * _frame_width, row * _frame_height, _frame_width, _frame_height)

## Static helper to spawn a weapon attack sprite
static func spawn(master_creature: Creature, weapon_id: int, facing: int, attack_kind: int = 0, destroy_timer: int = 0) -> WeaponAttackSprite:
	var sprite := WeaponAttackSprite.new()
	sprite.name = "WeaponAttack"
	sprite.setup(master_creature, weapon_id, facing, attack_kind, destroy_timer)
	master_creature.get_parent().add_child(sprite)
	sprite.global_position = master_creature.global_position
	return sprite
