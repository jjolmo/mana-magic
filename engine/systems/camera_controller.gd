class_name CameraController
extends Camera2D
## Camera system - replaces oCamera from GMS2

enum Action { NONE, WALK, MOVE_MOTION, SHAKE }

var action: int = Action.NONE
var following: Node2D = null
var pixels_moved: float = 0.0
var pixels_to_move: float = 0.0
var direction_to_move: int = Constants.Facing.UP
var movement_speed: float = 5.0
var camera_shake_var: bool = false
var movement_type: int = 0 # 0=updown, 1=leftright

# Motion move
var motion_target: Vector2 = Vector2.ZERO
var motion_initial: Vector2 = Vector2.ZERO
var motion_distance: float = 0.0
var motion_distance_initial: float = 0.0
var motion_speed: float = 26.0  # GMS2: CAMERA_MOTION_SPEED = 26
var motion_bind_on_finish: Node2D = null

# Shake
var shake_intensity: float = 2.0
var shake_timer: float = 0.0
var shake_duration: float = 0.0

# GMS2: CAMERA_H_BORDER_DEFAULT = 96, CAMERA_V_BORDER_DEFAULT = 96
# Dead zone dimensions in pixels. Camera doesn't move until target exits this zone.
const H_BORDER: float = 96.0
const V_BORDER: float = 96.0

# Whether dead zone (camera_bind) mode is active
var _use_deadzone: bool = false

func _ready() -> void:
	enabled = true
	# We handle all following logic manually (direct snap or dead zone).
	# Disable Godot's built-in drag/smoothing to avoid conflicts.
	position_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false

func _process(delta: float) -> void:
	# Follow target every frame (including during shake)
	if following and is_instance_valid(following):
		if _use_deadzone:
			_follow_with_deadzone()
		else:
			# Direct follow (camera_set mode) — snap to target, rounded to integers
			# to prevent sub-pixel jitter with snap_2d_transforms_to_pixel enabled.
			var new_pos: Vector2 = following.global_position
			new_pos = _clamp_to_limits(new_pos)
			global_position = new_pos.round()
	if action == Action.NONE:
		return

	match action:
		Action.WALK:
			_process_walk(delta)
		Action.MOVE_MOTION:
			_process_motion(delta)
		Action.SHAKE:
			_process_shake(delta)

func _process_walk(delta: float) -> void:
	if pixels_moved < pixels_to_move:
		var step: float = movement_speed * delta * 60.0
		var move := Vector2.ZERO
		match direction_to_move:
			Constants.Facing.UP: move = Vector2(0, -step)
			Constants.Facing.RIGHT: move = Vector2(step, 0)
			Constants.Facing.DOWN: move = Vector2(0, step)
			Constants.Facing.LEFT: move = Vector2(-step, 0)
		global_position += move
		pixels_moved += step
	else:
		action = Action.NONE
		pixels_moved = 0.0
		pixels_to_move = 0.0

func _process_motion(delta: float) -> void:
	motion_distance = global_position.distance_to(motion_target)
	var pct := 0.0
	if motion_distance_initial > 0:
		pct = ceili((motion_distance * 100.0) / motion_distance_initial)

	if pct > 0:
		var dir := (motion_target - global_position).normalized()
		global_position += dir * motion_speed * delta * 60.0

	if pct <= 30 and motion_distance_initial > 0:
		var t := pct / 30.0
		motion_speed = lerp(0.05, 10.0, t)

	if global_position.distance_to(motion_target) < 2.0:
		global_position = motion_target.round()
		action = Action.NONE
		if motion_bind_on_finish and is_instance_valid(motion_bind_on_finish):
			camera_set(motion_bind_on_finish)
			motion_bind_on_finish = null

func _process_shake(delta: float) -> void:
	shake_timer += delta
	var tilt := shake_intensity if camera_shake_var else -shake_intensity
	camera_shake_var = not camera_shake_var
	offset = Vector2(tilt, 0) if movement_type == 1 else Vector2(0, tilt)

	if shake_duration > 0 and shake_timer >= shake_duration:
		camera_stop()

# Public API
func camera_set(target: Node2D) -> void:
	## GMS2: cameraSet — direct follow, no smoothing, no dead zone.
	## Camera snaps to target every frame. Room bounds enforced by camera limits.
	following = target
	action = Action.NONE
	_use_deadzone = false
	# Auto-detect room bounds from TileMapLayer
	_auto_set_limits()

func camera_bind(target: Node2D) -> void:
	## GMS2: cameraBind — dead zone follow with hborder/vborder.
	## Camera only moves when target exits the dead zone area.
	## hspeed/vspeed = -1 in GMS2 means instant catch-up (no smoothing).
	following = target
	_use_deadzone = true
	_auto_set_limits()

func camera_unbind() -> void:
	## GMS2: cameraUnbind sets view_hborder=0, view_vborder=0 (disables dead zone)
	following = null
	_use_deadzone = false

func camera_move(direction: int, pixels: float, speed: float = 5.0) -> void:
	following = null
	action = Action.WALK
	pixels_to_move = pixels
	pixels_moved = 0.0
	direction_to_move = direction
	movement_speed = speed

func camera_shake(duration: int = 30, shake_mode: int = 0, intensity: float = 2.0) -> void:
	# GMS2: camera_set_view_target(camera, noone) detaches the view, but the oCamera
	# object still tracks following.x/y. Keep 'following' so camera_stop() can resume.
	action = Action.SHAKE
	shake_timer = 0.0
	shake_duration = duration / 60.0
	movement_type = shake_mode
	shake_intensity = intensity

func camera_stop() -> void:
	action = Action.NONE
	offset = Vector2.ZERO
	pixels_to_move = 0.0
	pixels_moved = 0.0
	# camera_set/camera_bind mode determines follow behavior, not smoothing

func camera_set_coord(pos: Vector2) -> void:
	camera_unbind()
	global_position = pos.round()

func camera_move_motion(target: Vector2, speed: float = 26.0, bind_target: Node2D = null) -> void:
	following = null
	action = Action.MOVE_MOTION
	motion_target = target
	motion_initial = global_position
	motion_distance_initial = global_position.distance_to(target)
	motion_distance = 0.0
	motion_speed = speed
	motion_bind_on_finish = bind_target

func _follow_with_deadzone() -> void:
	## GMS2: cameraBind — target can move freely inside the dead zone (center area).
	## When target exits the dead zone boundary, camera follows instantly (hspeed/vspeed = -1).
	## Dead zone = viewport center area, inset by H_BORDER/V_BORDER from each edge.
	var target_pos: Vector2 = following.global_position
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_w: float = viewport_size.x * 0.5
	var half_h: float = viewport_size.y * 0.5

	# Dead zone edges (world coordinates)
	var dead_left: float = global_position.x - half_w + H_BORDER
	var dead_right: float = global_position.x + half_w - H_BORDER
	var dead_top: float = global_position.y - half_h + V_BORDER
	var dead_bottom: float = global_position.y + half_h - V_BORDER

	var new_pos: Vector2 = global_position

	# Horizontal: if target exits dead zone left/right, shift camera so target is at edge
	if target_pos.x < dead_left:
		new_pos.x += target_pos.x - dead_left
	elif target_pos.x > dead_right:
		new_pos.x += target_pos.x - dead_right

	# Vertical: if target exits dead zone top/bottom, shift camera so target is at edge
	if target_pos.y < dead_top:
		new_pos.y += target_pos.y - dead_top
	elif target_pos.y > dead_bottom:
		new_pos.y += target_pos.y - dead_bottom

	# Clamp to room limits and round to integers for pixel-perfect rendering
	new_pos = _clamp_to_limits(new_pos)
	global_position = new_pos.round()


func _clamp_to_limits(pos: Vector2) -> Vector2:
	## Clamp camera position so the viewport never exceeds the room limits.
	## GMS2: camera is automatically clamped to room_width/room_height.
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_w: float = viewport_size.x * 0.5
	var half_h: float = viewport_size.y * 0.5
	pos.x = clampf(pos.x, limit_left + half_w, limit_right - half_w)
	pos.y = clampf(pos.y, limit_top + half_h, limit_bottom - half_h)
	return pos


func _auto_set_limits() -> void:
	## Auto-detect room bounds from TileMapLayer nodes and set camera limits.
	## GMS2: camera is clamped to room_width/room_height automatically.
	var scene_root: Node = get_tree().current_scene if get_tree() else null
	if not scene_root:
		return

	var tile_layers: Array = scene_root.find_children("*", "TileMapLayer", true, false)
	if tile_layers.is_empty():
		# No tilemap - remove limits (boss rooms, etc.)
		limit_left = -10000000
		limit_right = 10000000
		limit_top = -10000000
		limit_bottom = 10000000
		return

	# Compute union of all TileMapLayer used rects
	var bounds_min := Vector2(INF, INF)
	var bounds_max := Vector2(-INF, -INF)

	for layer in tile_layers:
		var tl: TileMapLayer = layer as TileMapLayer
		if not tl:
			continue
		var used: Rect2i = tl.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var cell_size: Vector2 = Vector2(tl.tile_set.tile_size) if tl.tile_set else Vector2(16, 16)
		var world_min: Vector2 = tl.global_position + Vector2(used.position) * cell_size
		var world_max: Vector2 = tl.global_position + Vector2(used.position + used.size) * cell_size
		bounds_min.x = minf(bounds_min.x, world_min.x)
		bounds_min.y = minf(bounds_min.y, world_min.y)
		bounds_max.x = maxf(bounds_max.x, world_max.x)
		bounds_max.y = maxf(bounds_max.y, world_max.y)

	if bounds_min.x < bounds_max.x and bounds_min.y < bounds_max.y:
		limit_left = int(bounds_min.x)
		limit_top = int(bounds_min.y)
		limit_right = int(bounds_max.x)
		limit_bottom = int(bounds_max.y)
