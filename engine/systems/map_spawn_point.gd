class_name MapSpawnPoint
extends Marker2D
## Spawn point marker - replaces oTeleport/oStartingPoint teleportName from GMS2
## Place in rooms to define where players spawn when arriving from a specific exit.

## Unique name for this spawn point (matched by MapChangeArea.target_spawn_point)
@export var point_name: String = "default"
