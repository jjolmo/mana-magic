class_name MapChangeArea
extends Area2D
## Map transition trigger area - replaces oTeleport from GMS2

@export var target_room: String = ""
## Name of the spawn point marker in the target room (matches MapSpawnPoint.point_name)
@export var target_spawn_point: String = ""
## Direction player walks when entering this teleport (GMS2: moveDirection)
## Used to offset player position from spawn point by 32px in that direction
@export var move_direction: int = -1  # Constants.Facing value, -1 = none

## GMS2: teleportEnable/teleportDisable - can be dynamically enabled/disabled by scene events
var enabled: bool = true
## GMS2: exitOnce flag - prevents immediate re-trigger when player spawns on this area
var _exit_once: bool = false
var _triggered: bool = false

func _ready() -> void:
	# Actors are on collision_layer 2; ensure we detect them
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# GMS2: oTeleport Create_0 - if player starts overlapping, set exitOnce
	# Defer check to allow physics to detect initial overlaps
	call_deferred("_check_initial_overlap")

func _check_initial_overlap() -> void:
	for body in get_overlapping_bodies():
		if body is Actor and body.is_party_leader:
			_exit_once = true
			break

func _on_body_entered(body: Node2D) -> void:
	if _triggered or not enabled or GameManager.scene_running:
		return
	if body is Actor and body.is_party_leader and target_room != "":
		if _exit_once:
			return
		_triggered = true
		# GMS2: lockInput + go_walk(self, moveDirection, 10) during fade-out
		for player in GameManager.players:
			if is_instance_valid(player) and player is Actor:
				if player.has_method("lock_movement_input"):
					player.lock_movement_input()
				# GMS2: go_walk(self, other.moveDirection, 10) - walk 10 tiles through door
				if move_direction >= 0:
					var walk_dist: float = 10.0 * 16.0  # 10 tiles * 16px
					var dir_vec := _facing_to_vector(move_direction)
					var target_pos: Vector2 = player.global_position + dir_vec * walk_dist
					player.facing = move_direction
					player.new_facing = move_direction
					MoveToPosition.go(player, target_pos.x, target_pos.y, false, false, false)
				else:
					player.velocity = Vector2.ZERO
		GameManager.pending_spawn_point = target_spawn_point
		GameManager.pending_spawn_direction = move_direction
		GameManager.change_map(target_room)

func _on_body_exited(body: Node2D) -> void:
	## GMS2: oTeleport - reset exitOnce when ALL players leave the area
	if body is Actor and body.is_party_leader:
		_exit_once = false

static func _facing_to_vector(facing: int) -> Vector2:
	match facing:
		Constants.Facing.UP: return Vector2(0, -1)
		Constants.Facing.RIGHT: return Vector2(1, 0)
		Constants.Facing.DOWN: return Vector2(0, 1)
		Constants.Facing.LEFT: return Vector2(-1, 0)
	return Vector2.ZERO
