class_name WeaponHitbox
extends Area2D
## Weapon hitbox - replaces oWeaponHitbox from GMS2
## Also displays weapon sprite animation (replaces oTemporalSprite)

var source_creature: Creature
var weapon_id: int = 0
var weapon_attack_type: int = 0
var damaged_creatures: Array = []
var lifetime: float = 0.0
var max_lifetime: float = 0.5  # 30 frames / 60fps

# Weapon sprite animation
var weapon_sprite: Sprite2D
var weapon_frames: Array[Texture2D] = []
var wpn_frame_ini: int = 0
var wpn_frame_end: int = 0
var wpn_frame_current: float = 0.0
var wpn_image_speed: float = 0.4
var single_sprite: bool = false

var collision_shape: CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	# GMS2: getTargetKind() — actors target mobs, mobs target actors
	# Actor hitbox: detect layer 3 (mobs + destructibles = 4)
	# Mob hitbox: detect layer 2 (actors = 2)
	if source_creature is Mob:
		collision_mask = 2  # Layer 2 = actors only
	else:
		collision_mask = 4  # Layer 3 = mobs + destructibles only
	if not weapon_sprite:
		weapon_sprite = $Sprite2D

func setup(source: Creature, wpn_id: int, atk_type: int) -> void:
	source_creature = source
	weapon_id = wpn_id
	weapon_attack_type = atk_type
	damaged_creatures.clear()
	# Resolve children early (setup is called before _ready/add_child)
	weapon_sprite = $Sprite2D
	collision_shape = $CollisionShape2D

	if collision_shape and not collision_shape.shape:
		collision_shape.shape = RectangleShape2D.new()

	# Position and size are set per-weapon per-facing in _position_hitbox()
	_position_hitbox()

	# Setup weapon sprite visual
	_setup_weapon_sprite()


## GMS2 weapon hitbox data (bbox size and offset from origin per facing direction).
## Derived from GMS2 sprite .yy files: bbox dimensions and sprite origins.
## Rotating weapons (spear, whip) have singleSprite=true and use image_angle rotation.
## Non-rotating weapons (sword, axe, knuckles) use directional frames with the same bbox.
##
## GMS2 bbox / origin data:
##   Sword:    bbox 95x95, origin (54,60)  → center offset (-7, -13)
##   Axe:      bbox 95x95, origin (54,60)  → center offset (-7, -13)
##   Spear:    bbox 57x93, origin (46,92)  → center offset (-18, -46) — rotated per facing
##   Whip:     bbox 59x83, origin (46,92)  → center offset (-17, -51) — rotated per facing
##   Knuckles: bbox 92x92, origin (-27,17) → center offset (73, 29)
##   Bow:      bbox 0x0 (no collision)
##
## For Godot we use these as RectangleShape2D (no per-pixel masks), with the collision_shape
## positioned at the rotated center offset. The Area2D itself stays at the creature position.

func _position_hitbox() -> void:
	if not source_creature or not collision_shape:
		return

	var shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if not shape:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape

	var shape_size := Vector2(20, 16)
	var shape_offset := Vector2.ZERO
	var facing: int = source_creature.facing

	match weapon_id:
		Constants.Weapon.SWORD:
			# GMS2: bbox 95×95, origin (54,60), directional frames (no rotation)
			# Center offset from origin: (-7, -13) — same for all facings
			shape_size = Vector2(48, 48)
			shape_offset = Vector2(-4, -6)

		Constants.Weapon.AXE:
			# GMS2: bbox 95×95, origin (54,60), directional frames (no rotation)
			shape_size = Vector2(52, 52)
			shape_offset = Vector2(-4, -6)

		Constants.Weapon.SPEAR:
			# GMS2: bbox 57×93, origin (46,92), singleSprite=true (rotates)
			# Base offset (UP): (-18, -46). Rotated for other directions.
			match facing:
				Constants.Facing.UP:
					shape_size = Vector2(28, 56)
					shape_offset = Vector2(-8, -28)
				Constants.Facing.RIGHT:
					shape_size = Vector2(56, 28)
					shape_offset = Vector2(28, -8)
				Constants.Facing.DOWN:
					shape_size = Vector2(28, 56)
					shape_offset = Vector2(8, 28)
				Constants.Facing.LEFT:
					shape_size = Vector2(56, 28)
					shape_offset = Vector2(-28, 8)

		Constants.Weapon.WHIP:
			# GMS2: bbox 59×83, origin (46,92), singleSprite=true (rotates)
			# Base offset (UP): (-17, -51). Rotated for other directions.
			match facing:
				Constants.Facing.UP:
					shape_size = Vector2(30, 48)
					shape_offset = Vector2(-8, -24)
				Constants.Facing.RIGHT:
					shape_size = Vector2(48, 30)
					shape_offset = Vector2(24, -8)
				Constants.Facing.DOWN:
					shape_size = Vector2(30, 48)
					shape_offset = Vector2(8, 24)
				Constants.Facing.LEFT:
					shape_size = Vector2(48, 30)
					shape_offset = Vector2(-24, 8)

		Constants.Weapon.KNUCKLES:
			# GMS2: bbox 92×92, origin (-27,17) — close-range punches
			shape_size = Vector2(36, 36)
			shape_offset = Vector2.ZERO
			match facing:
				Constants.Facing.UP:
					shape_offset = Vector2(0, -16)
				Constants.Facing.RIGHT:
					shape_offset = Vector2(16, 0)
				Constants.Facing.DOWN:
					shape_offset = Vector2(0, 16)
				Constants.Facing.LEFT:
					shape_offset = Vector2(-16, 0)

		Constants.Weapon.JAVELIN:
			# Projectile — small hitbox, direction-dependent
			match facing:
				Constants.Facing.UP:
					shape_size = Vector2(8, 40)
					shape_offset = Vector2(0, -20)
				Constants.Facing.RIGHT:
					shape_size = Vector2(40, 8)
					shape_offset = Vector2(20, 0)
				Constants.Facing.DOWN:
					shape_size = Vector2(8, 40)
					shape_offset = Vector2(0, 20)
				Constants.Facing.LEFT:
					shape_size = Vector2(40, 8)
					shape_offset = Vector2(-20, 0)

		Constants.Weapon.BOOMERANG:
			# Projectile — medium hitbox
			shape_size = Vector2(16, 16)
			match facing:
				Constants.Facing.UP:
					shape_offset = Vector2(0, -16)
				Constants.Facing.RIGHT:
					shape_offset = Vector2(16, 0)
				Constants.Facing.DOWN:
					shape_offset = Vector2(0, 16)
				Constants.Facing.LEFT:
					shape_offset = Vector2(-16, 0)

		Constants.Weapon.BOW:
			# GMS2: bbox 0×0 — no melee collision (arrow is a projectile)
			shape_size = Vector2(8, 8)
			shape_offset = Vector2.ZERO

		_:
			shape_size = Vector2(24, 24)
			match facing:
				Constants.Facing.UP:
					shape_offset = Vector2(0, -16)
				Constants.Facing.RIGHT:
					shape_offset = Vector2(16, 0)
				Constants.Facing.DOWN:
					shape_offset = Vector2(0, 16)
				Constants.Facing.LEFT:
					shape_offset = Vector2(-16, 0)

	shape.size = shape_size
	collision_shape.position = shape_offset

func _setup_weapon_sprite() -> void:
	# Weapon attack animation is handled by WeaponAttackSprite (spawned by attack states).
	# The hitbox's $Sprite2D is not used for rendering — hide it.
	if weapon_sprite:
		weapon_sprite.visible = false

func _get_weapon_sprite_dir() -> String:
	match weapon_id:
		Constants.Weapon.SWORD: return "spr_weapon_sword"
		Constants.Weapon.AXE: return "spr_weapon_axe"
		Constants.Weapon.BOW: return "spr_weapon_bow"
		Constants.Weapon.BOOMERANG: return "spr_weapon_boomerang"
		Constants.Weapon.JAVELIN: return "spr_weapon_javelin"
		Constants.Weapon.WHIP: return "spr_weapon_whip"
		Constants.Weapon.SPEAR:
			match weapon_attack_type:
				Constants.WeaponAttackType.PIERCE: return "spr_weapon_spear"
				Constants.WeaponAttackType.SLASH: return "spr_weapon_spear2"
				_: return "spr_weapon_spear3"
	return ""


func _set_facing_frames() -> void:
	var total: int = weapon_frames.size()
	if total == 0:
		return

	# GMS2 default frame ranges for weapons with directional sprites
	# Sword: up=0-2, right=4-6, down=8-10, left=12-14
	match weapon_id:
		Constants.Weapon.SWORD:
			match source_creature.facing:
				Constants.Facing.UP:
					wpn_frame_ini = 0; wpn_frame_end = 2
				Constants.Facing.RIGHT:
					wpn_frame_ini = 4; wpn_frame_end = 6
				Constants.Facing.DOWN:
					wpn_frame_ini = 8; wpn_frame_end = 10
				Constants.Facing.LEFT:
					wpn_frame_ini = 12; wpn_frame_end = 14
		Constants.Weapon.AXE:
			match source_creature.facing:
				Constants.Facing.UP:
					wpn_frame_ini = 0; wpn_frame_end = 3
				Constants.Facing.RIGHT:
					wpn_frame_ini = 5; wpn_frame_end = 8
				Constants.Facing.DOWN:
					wpn_frame_ini = 10; wpn_frame_end = 13
				Constants.Facing.LEFT:
					wpn_frame_ini = 15; wpn_frame_end = 18
		Constants.Weapon.BOOMERANG:
			match source_creature.facing:
				Constants.Facing.UP:
					wpn_frame_ini = 0; wpn_frame_end = 1
				Constants.Facing.RIGHT:
					wpn_frame_ini = 3; wpn_frame_end = 4
				Constants.Facing.DOWN:
					wpn_frame_ini = 6; wpn_frame_end = 7
				Constants.Facing.LEFT:
					wpn_frame_ini = 9; wpn_frame_end = 10
		Constants.Weapon.JAVELIN:
			match source_creature.facing:
				Constants.Facing.UP:
					wpn_frame_ini = 0; wpn_frame_end = 0
				Constants.Facing.RIGHT:
					wpn_frame_ini = 2; wpn_frame_end = 2
				Constants.Facing.DOWN:
					wpn_frame_ini = 4; wpn_frame_end = 4
				Constants.Facing.LEFT:
					wpn_frame_ini = 6; wpn_frame_end = 6
		Constants.Weapon.BOW:
			match source_creature.facing:
				Constants.Facing.UP:
					wpn_frame_ini = 0; wpn_frame_end = 4
				Constants.Facing.RIGHT:
					wpn_frame_ini = 6; wpn_frame_end = 11
				Constants.Facing.DOWN:
					wpn_frame_ini = 12; wpn_frame_end = 17
				Constants.Facing.LEFT:
					wpn_frame_ini = 18; wpn_frame_end = 22
		_:
			# Single sprite or unknown: use all frames for all directions
			wpn_frame_ini = 0
			wpn_frame_end = total - 1

func _update_weapon_frame() -> void:
	var frame_idx: int = int(wpn_frame_current)
	if frame_idx >= 0 and frame_idx < weapon_frames.size() and weapon_frames[frame_idx] != null:
		weapon_sprite.texture = weapon_frames[frame_idx]
		weapon_sprite.visible = true
	else:
		weapon_sprite.visible = false

func _process(delta: float) -> void:
	# Follow source creature every frame for smooth visuals
	if is_instance_valid(source_creature):
		global_position = source_creature.global_position
		_position_hitbox()

	# GMS2: ring menu pauses all combat logic
	if GameManager.ring_menu_opened:
		return

	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()
		return

	# Animate weapon sprite
	if weapon_sprite and weapon_sprite.visible and weapon_frames.size() > 0:
		wpn_frame_current += wpn_image_speed * delta * 60.0
		if int(wpn_frame_current) > wpn_frame_end:
			weapon_sprite.visible = false
		else:
			_update_weapon_frame()

func _on_body_entered(body: Node2D) -> void:
	if body == source_creature:
		return
	# Destructible assets (bushes, rocks, etc.) - handled here since no attack state polls these
	if body.has_method("on_weapon_hit") and not damaged_creatures.has(body):
		damaged_creatures.append(body)
		body.on_weapon_hit(source_creature, weapon_id)
		return
	# Creature damage is handled by the attack state's _detect_damage() to avoid double-hits

func get_overlapping_creatures() -> Array:
	var bodies: Array = []
	for body in super.get_overlapping_bodies():
		if body is Creature and body != source_creature:
			bodies.append(body)
	return bodies
