class_name MobSpawner
extends Node2D
## Spawns mobs in a room - replaces GMS2 room instance placement.
## GMS2: Mobs are placed at fixed positions in the room editor. They do NOT respawn
## while the player is in the room — only on room re-entry (scene reload).
## MAX_ACTORS_NUMBER_SCREEN = 6 (global mob cap from defineGeneralParameters.gml)

@export var mob_database_id: int = 0
@export var mob_count: int = 3
@export var spawn_radius: float = 60.0

## GMS2: MAX_ACTORS_NUMBER_SCREEN = 6 - global limit across all spawners
const MAX_MOBS_ON_SCREEN: int = 6

var _spawned_mobs: Array = []

func _ready() -> void:
	var mob_scene: PackedScene = preload("res://scenes/creatures/mob.tscn")
	_spawn_initial(mob_scene)

func _spawn_initial(mob_scene: PackedScene) -> void:
	## GMS2: Mobs are placed once when the room loads. No respawn while in room.
	## Respect global mob cap.
	var current_mob_count: int = get_tree().get_nodes_in_group("mobs").size()

	for i in range(mob_count):
		if current_mob_count >= MAX_MOBS_ON_SCREEN:
			break
		var mob := mob_scene.instantiate() as Mob
		if mob:
			var offset := Vector2(
				randf_range(-spawn_radius, spawn_radius),
				randf_range(-spawn_radius, spawn_radius)
			)
			mob.global_position = global_position + offset
			mob.load_from_database(mob_database_id)
			mob.add_to_group("mobs")
			get_parent().add_child(mob)
			_spawned_mobs.append(mob)
			current_mob_count += 1
