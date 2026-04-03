class_name AssetSeed
extends Node2D
## Mana Seed scatter effect - replaces oAsset_seed from GMS2
## Cinematic seed that arcs up and scatters outward, then waits to be "collected"
## by a nearby NPC (the rabite). Used in the rabite cutscene.

## Seed frame textures (loaded in order from spr_manaSeedsSeparated)
const SEED_NAMES: Array[String] = [
	"seed_undine",      # 0 - Undine
	"seed_gnome",       # 1 - Gnome
	"seed_sylphid",     # 2 - Sylphid
	"seed_salamando",   # 3 - Salamando
	"seed_shade",       # 4 - Shade
	"seed_luna",        # 5 - Luna
	"seed_lumina",      # 6 - Lumina
	"seed_dryad",       # 7 - Dryad
]

## Setup
var item_index: int = 0

## Physics (pseudo-3D arc)
var z_height: float = 0.0
var z_velocity: float = 0.0
var z_gravity: float = 0.125  # GMS2: gravSpeed/8 = 1/8 = 0.125
var move_speed: float = 1.0
var move_direction: Vector2 = Vector2.ZERO

## Timer
var timer: float = 0.0

## Node for collecting seeds (set externally)
var collector_node: Node2D = null
var collect_distance: float = 20.0

## Sprite
var _sprite: Sprite2D
var _shadow: Sprite2D


func setup(p_item_index: int) -> void:
	item_index = p_item_index

	# GMS2: motion_set(((240/8)*itemIndex)-15, speed)
	# 240/8 = 30 degrees per seed, offset by -15
	var angle_deg: float = (30.0 * item_index) - 15.0
	var angle_rad: float = deg_to_rad(angle_deg)
	move_direction = Vector2(cos(angle_rad), -sin(angle_rad))  # GMS2 y-axis is inverted

	# Launch upward
	z_velocity = 3.0  # Positive = going up in our system (GMS2 was zsp = -3)


func _ready() -> void:
	# Create sprite
	_sprite = Sprite2D.new()
	_sprite.name = "SeedSprite"
	add_child(_sprite)

	# Load the correct seed frame texture
	if item_index >= 0 and item_index < SEED_NAMES.size():
		var seed_name: String = SEED_NAMES[item_index]
		var tex: Texture2D = load("res://assets/sprites/spr_manaSeedsSeparated/" + seed_name + ".png") as Texture2D
		if tex:
			_sprite.texture = tex

	# Create shadow
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	_shadow.modulate = Color(0, 0, 0, 0.3)
	_shadow.scale = Vector2(0.4, 0.4)
	add_child(_shadow)

	# Use a small circle as shadow (reuse seed texture if available)
	if _sprite.texture:
		_shadow.texture = _sprite.texture

	z_index = 1000


func _process(delta: float) -> void:
	# Visual updates every frame for smooth rendering
	if _sprite:
		_sprite.position.y = -z_height
	if _shadow:
		_shadow.visible = z_height > 2.0

	timer += delta

	# Z-axis physics (gravity pulls seed back down)
	z_velocity -= z_gravity * delta * 60.0
	z_height += z_velocity * delta * 60.0
	if z_height <= 0:
		z_height = 0
		z_velocity = 0

	# Horizontal movement with friction
	if move_speed > 0:
		global_position += move_direction * move_speed * 60.0 * delta
		move_speed -= 0.6 * delta
		if move_speed < 0:
			move_speed = 0

	# After 110 frames (1.833s), check if collector is nearby
	if timer > 110.0 / 60.0:
			if is_instance_valid(collector_node):
				if global_position.distance_to(collector_node.global_position) < collect_distance:
					queue_free()
					return


## Static helper: spawn 8 seeds in a radial burst from a position
static func spawn_seed_burst(spawn_pos: Vector2, parent: Node, collector: Node2D = null) -> Array[AssetSeed]:
	var seeds: Array[AssetSeed] = []
	for i in 8:
		var seed_node := AssetSeed.new()
		seed_node.setup(i)
		seed_node.global_position = spawn_pos
		seed_node.collector_node = collector
		parent.add_child(seed_node)
		seeds.append(seed_node)
	return seeds
