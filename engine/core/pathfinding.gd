class_name Pathfinding
## A* grid pathfinding for AI companions - replaces GMS2 mp_grid system.
## GMS2: mp_grid_create(0,0, room_w/16, room_h/16, 16,16) + mp_grid_add_instances(oWall,oMobAsset)
## Called once per room load to build the navigation grid from TileMapLayer collision data.

const CELL_SIZE: int = 16  # GMS2: pathfindingCellWidth/Height = 16

static var _grid: AStarGrid2D = null
static var _grid_origin: Vector2 = Vector2.ZERO
static var _grid_size: Vector2i = Vector2i.ZERO

## Build the pathfinding grid from the current scene's collision TileMapLayers.
## Call this once when a room is loaded (from starting_point or map_transition).
static func setup_from_scene(scene_root: Node) -> void:
	_grid = AStarGrid2D.new()
	_grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN

	# Find all TileMapLayers to determine room bounds
	var tile_layers: Array = scene_root.find_children("*", "TileMapLayer", true, false)
	if tile_layers.is_empty():
		_grid = null
		return

	# Compute room bounds from all tile layers
	var bounds_min := Vector2(INF, INF)
	var bounds_max := Vector2(-INF, -INF)
	for layer in tile_layers:
		var tl: TileMapLayer = layer as TileMapLayer
		if not tl or not tl.tile_set:
			continue
		var used: Rect2i = tl.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var cell_sz: Vector2 = Vector2(tl.tile_set.tile_size)
		var world_min: Vector2 = tl.global_position + Vector2(used.position) * cell_sz
		var world_max: Vector2 = tl.global_position + Vector2(used.position + used.size) * cell_sz
		bounds_min.x = minf(bounds_min.x, world_min.x)
		bounds_min.y = minf(bounds_min.y, world_min.y)
		bounds_max.x = maxf(bounds_max.x, world_max.x)
		bounds_max.y = maxf(bounds_max.y, world_max.y)

	if bounds_min.x >= bounds_max.x or bounds_min.y >= bounds_max.y:
		_grid = null
		return

	_grid_origin = bounds_min
	_grid_size = Vector2i(
		ceili((bounds_max.x - bounds_min.x) / CELL_SIZE),
		ceili((bounds_max.y - bounds_min.y) / CELL_SIZE)
	)
	_grid.region = Rect2i(Vector2i.ZERO, _grid_size)
	_grid.update()

	# Mark cells as solid where collision tiles exist
	# GMS2: mp_grid_add_instances(oWall, false) + mp_grid_add_instances(oMobAsset, false)
	for layer in tile_layers:
		var tl: TileMapLayer = layer as TileMapLayer
		if not tl or not tl.tile_set:
			continue
		# Only consider layers that have physics (collision) tiles
		if tl.tile_set.get_physics_layers_count() == 0:
			continue
		for cell_pos in tl.get_used_cells():
			var tile_data: TileData = tl.get_cell_tile_data(cell_pos)
			if tile_data and tile_data.get_collision_polygons_count(0) > 0:
				# Convert tile cell → pathfinding grid cell
				var cell_sz: Vector2 = Vector2(tl.tile_set.tile_size)
				var world_pos: Vector2 = tl.global_position + Vector2(cell_pos) * cell_sz
				var grid_pos: Vector2i = _world_to_grid(world_pos + cell_sz * 0.5)
				if _is_valid_cell(grid_pos):
					_grid.set_point_solid(grid_pos, true)

	# Also block cells occupied by StaticBody2D children (destructible assets, etc.)
	var static_bodies: Array = scene_root.find_children("*", "StaticBody2D", true, false)
	for body in static_bodies:
		if body is StaticBody2D and body.is_inside_tree():
			var grid_pos: Vector2i = _world_to_grid(body.global_position)
			if _is_valid_cell(grid_pos):
				_grid.set_point_solid(grid_pos, true)


## Get a path from world position A to world position B.
## Returns an array of world-space Vector2 waypoints, or empty if no path.
static func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _grid == null:
		return PackedVector2Array()

	var from_cell: Vector2i = _world_to_grid(from)
	var to_cell: Vector2i = _world_to_grid(to)

	# Clamp to valid range
	from_cell = _clamp_cell(from_cell)
	to_cell = _clamp_cell(to_cell)

	# If start or end is solid, try nearby cells
	if _grid.is_point_solid(from_cell):
		from_cell = _find_nearest_walkable(from_cell)
	if _grid.is_point_solid(to_cell):
		to_cell = _find_nearest_walkable(to_cell)

	if from_cell == to_cell:
		return PackedVector2Array()

	var path: PackedVector2Array = _grid.get_point_path(from_cell, to_cell)

	# Convert grid coords back to world coords (center of each cell)
	var world_path := PackedVector2Array()
	for p in path:
		world_path.append(_grid_to_world(Vector2i(int(p.x), int(p.y))))
	return world_path


## Check if the grid is available (rooms with tilemaps)
static func is_available() -> bool:
	return _grid != null


static func _world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori((world_pos.x - _grid_origin.x) / CELL_SIZE),
		floori((world_pos.y - _grid_origin.y) / CELL_SIZE)
	)


static func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return _grid_origin + Vector2(grid_pos) * CELL_SIZE + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)


static func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _grid_size.x and cell.y < _grid_size.y


static func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, _grid_size.x - 1),
		clampi(cell.y, 0, _grid_size.y - 1)
	)


static func _find_nearest_walkable(cell: Vector2i) -> Vector2i:
	## Spiral search for nearest non-solid cell
	for radius in range(1, 5):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue  # Only check border of each ring
				var test := Vector2i(cell.x + dx, cell.y + dy)
				if _is_valid_cell(test) and not _grid.is_point_solid(test):
					return test
	return cell  # Fallback: return original
