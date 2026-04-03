class_name DestructibleAsset
extends StaticBody2D
## Destructible world asset - replaces oMobAsset from GMS2
## Blocks player movement until attacked with a valid weapon, then switches
## to destroyed sprite and disables collision. Does NOT use Creature hierarchy.

## Textures: intact (frame 0) and destroyed (frame 1+)
@export var intact_texture: Texture2D
@export var destroyed_texture: Texture2D

## Which weapon types can destroy this asset (Constants.Weapon enum values)
@export var vulnerable_weapons: Array[int] = []

## Timer before visual destruction (frames after being hit)
@export var destroy_delay: int = 10

## Sound effect on destruction
@export var destroy_sound: String = ""

## Whether this asset has been attacked
var attacked: bool = false
var changed: bool = false
var _timer: float = 0.0

## Sprite and collision references
var _sprite: Sprite2D
var _collision: CollisionShape2D


func _ready() -> void:
	# Setup sprite child
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	if intact_texture:
		_sprite.texture = intact_texture
	add_child(_sprite)

	# Setup collision shape - will be configured by subclasses or scene
	_collision = $CollisionShape2D if has_node("CollisionShape2D") else null

	# Set collision layer to 4 (same as mobs) so hitboxes can detect us
	collision_layer = 4
	collision_mask = 0  # We don't need to detect anything, we just block

	# Y-sorting
	z_index = int(global_position.y)


func _process(delta: float) -> void:
	if attacked and not changed:
		_timer += delta
		if _timer > destroy_delay / 60.0:
			_change_to_destroyed()


## Called by WeaponHitbox when a weapon hit is detected
func on_weapon_hit(source: Node, weapon_id: int) -> void:
	if attacked or changed:
		return

	# Check if this weapon can destroy this asset
	if vulnerable_weapons.size() > 0 and weapon_id not in vulnerable_weapons:
		return

	attacked = true
	_timer = 0.0


func _change_to_destroyed() -> void:
	changed = true

	# Switch to destroyed texture
	if destroyed_texture and _sprite:
		_sprite.texture = destroyed_texture

	# Play destruction sound
	if not destroy_sound.is_empty():
		MusicManager.play_sfx(destroy_sound)

	# Disable collision so player can pass through
	if _collision:
		_collision.set_deferred("disabled", true)
	else:
		# Try to find any collision shape child
		for child in get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
