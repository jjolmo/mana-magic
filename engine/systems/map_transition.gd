class_name MapTransition
extends Node
## Map/scene transition system - replaces mapChange/go_fadeIn/go_fadeOut from GMS2

signal fade_completed
signal map_changed(new_scene: String)

enum FadeMode { NONE, FADE_IN, FADE_OUT }

var fade_mode: int = FadeMode.NONE
var fade_alpha: float = 0.0
var fade_speed: float = 1.0 / 60.0  # Alpha change per frame at 60fps
var fade_color: Color = Color.BLACK
var min_fade: float = 0.0
var max_fade: float = 1.0
var go_map: bool = false
var go_map_id: String = ""
var animating: bool = false
var end_animation: bool = false

var _canvas_layer: CanvasLayer
var _color_rect: ColorRect


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	_color_rect = ColorRect.new()
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.visible = false
	_canvas_layer.add_child(_color_rect)

	# Make it cover the full screen
	_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if fade_mode == FadeMode.NONE:
		return

	_do_fade_step(delta)

func _do_fade_step(delta: float) -> void:
	if fade_mode == FadeMode.FADE_OUT:
		fade_alpha += fade_speed * delta * 60.0
		if fade_alpha >= max_fade:
			fade_alpha = max_fade
			animating = false
			if go_map:
				_do_map_change()
				go_map = false
			else:
				fade_mode = FadeMode.NONE
				fade_completed.emit()
	elif fade_mode == FadeMode.FADE_IN:
		fade_alpha -= fade_speed * delta * 60.0
		if fade_alpha <= min_fade:
			fade_alpha = min_fade
			animating = false
			fade_mode = FadeMode.NONE
			_color_rect.visible = false
			fade_completed.emit()

	_color_rect.color = Color(fade_color.r, fade_color.g, fade_color.b, fade_alpha)
	_color_rect.visible = fade_alpha > 0.001

func fade_out(time_frames: int = 60, color: Color = Color.BLACK, _force: bool = false) -> void:
	fade_speed = 1.0 / float(time_frames)
	fade_mode = FadeMode.FADE_OUT
	fade_color = color
	min_fade = 0.0
	max_fade = 1.0
	animating = true
	_color_rect.visible = true

func fade_in(time_frames: int = 60, color: Color = Color.BLACK, _force: bool = false) -> void:
	fade_speed = 1.0 / float(time_frames)
	fade_mode = FadeMode.FADE_IN
	fade_color = color
	min_fade = 0.0
	max_fade = 1.0
	animating = true
	_color_rect.visible = true
	if fade_alpha < max_fade:
		fade_alpha = max_fade

func fade_out_magic(time_frames: int = 60) -> void:
	fade_speed = 1.0 / float(time_frames)
	fade_mode = FadeMode.FADE_OUT
	fade_color = Color.BLACK
	min_fade = 0.0
	max_fade = 0.5
	animating = true
	_color_rect.visible = true

func fade_in_magic(time_frames: int = 60) -> void:
	fade_speed = 1.0 / float(time_frames)
	fade_mode = FadeMode.FADE_IN
	fade_color = Color.BLACK
	min_fade = 0.0
	max_fade = 0.5
	animating = true
	_color_rect.visible = true

func map_change(target_room: String, color: Color = Color.BLACK, with_end_animation: bool = false) -> void:
	fade_speed = 1.0 / 60.0
	fade_mode = FadeMode.FADE_OUT
	fade_color = color
	min_fade = 0.0
	max_fade = 1.0
	animating = true
	go_map = true
	go_map_id = target_room
	end_animation = with_end_animation
	_color_rect.visible = true

func _do_map_change() -> void:
	var scene_path := "res://scenes/rooms/%s.tscn" % go_map_id
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		GameManager.previous_room = GameManager.current_room
		GameManager.current_room = go_map_id
		map_changed.emit(go_map_id)
		# Fade back in after scene loads
		await get_tree().process_frame
		await get_tree().process_frame
		# Rebuild pathfinding grid for new room (GMS2: mp_grid_create on room enter)
		Pathfinding.setup_from_scene(get_tree().current_scene)
		# Setup animated tiles for TileMapLayers in the new room
		TileAnimator.setup_scene(get_tree().current_scene)
		# GMS2: game.linkToTeleport_name - place players at spawn point
		_place_players_at_spawn_point()
		# Autosave after entering new room (wait for players to be ready)
		if GameManager.players.size() > 0:
			SaveManager.save_game(0)  # Slot 0 = autosave
		fade_in(60, fade_color)
	else:
		push_warning("Scene not found: " + scene_path)
		fade_mode = FadeMode.NONE
		animating = false

func _place_players_at_spawn_point() -> void:
	## GMS2: Other_4.gml - find linked teleport by name, place actors at offset position
	var spawn_name: String = GameManager.pending_spawn_point
	var spawn_dir: int = GameManager.pending_spawn_direction
	GameManager.pending_spawn_point = ""
	GameManager.pending_spawn_direction = -1

	if spawn_name.is_empty():
		return

	# Find matching MapSpawnPoint in the loaded scene
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return

	var spawn_markers: Array = scene_root.find_children("*", "MapSpawnPoint", true, false)
	var target_marker: Node2D = null

	for marker in spawn_markers:
		if marker is MapSpawnPoint and marker.point_name == spawn_name:
			target_marker = marker
			break

	# Fallback: try "default" spawn point
	if not target_marker:
		for marker in spawn_markers:
			if marker is MapSpawnPoint and marker.point_name == "default":
				target_marker = marker
				break

	# Fallback: use StartingPoint position (GMS2: oStartingPoint)
	if not target_marker:
		var start_points: Array = scene_root.find_children("*", "StartingPoint", true, false)
		if start_points.size() > 0:
			target_marker = start_points[0] as Node2D
	if not target_marker:
		return

	# GMS2: offset by 32px in move direction from spawn point
	var offset := Vector2.ZERO
	var move_points: float = 32.0
	match spawn_dir:
		Constants.Facing.UP:
			offset.y = -move_points
		Constants.Facing.RIGHT:
			offset.x = move_points
		Constants.Facing.DOWN:
			offset.y = move_points
		Constants.Facing.LEFT:
			offset.x = -move_points

	var spawn_pos: Vector2 = target_marker.global_position + offset

	# Place all actors at spawn position
	for player in GameManager.players:
		if is_instance_valid(player) and player is Actor:
			player.global_position = spawn_pos
			# GMS2: changeStateStandDead() — reset actor to Stand or Dead state on room entry
			# Prevents actors entering new room in stale state (hit, casting, etc.)
			if player.has_method("change_state_stand_dead"):
				player.change_state_stand_dead()
			# Face the move direction
			if spawn_dir >= 0:
				player.facing = spawn_dir
				player.set_facing_frame(
					player.spr_stand_up, player.spr_stand_right,
					player.spr_stand_down, player.spr_stand_left
				)
			# GMS2: unlockInput() after placing players in new room
			if player.has_method("unlock_movement_input"):
				player.unlock_movement_input()

func fade_reset() -> void:
	fade_alpha = 0.0
	fade_mode = FadeMode.NONE
	animating = false
	go_map = false
	go_map_id = ""
	_color_rect.visible = false

func blend_screen_on(color: Color = Color.BLACK, alpha: float = 1.0, _time_frames: int = 1) -> void:
	fade_color = color
	fade_alpha = alpha
	_color_rect.color = Color(color.r, color.g, color.b, alpha)
	_color_rect.visible = true
	fade_mode = FadeMode.NONE

func is_fading() -> bool:
	return animating
