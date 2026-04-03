class_name SceneEvent
extends Node2D
## Base scene/event system - replaces oSce_* objects from GMS2
## Scene events are step-based cutscene controllers
## GMS2: game.scenesLoaded prevents scenes from replaying

signal scene_finished

var scene_step: int = 0
var timer: float = 0.0
var scene_running: bool = false
var auto_start: bool = true
var _waiting_for_players: bool = false
## True when scene timer is paused because a dialog is showing.
## Child classes MUST check this in their _process() to avoid re-executing step logic
## while the timer is frozen (GDScript: super._process return doesn't stop child code).
var _dialog_paused: bool = false
## Set this to a unique ID to prevent the scene from replaying after completion
var scene_persistence_id: String = ""

func _ready() -> void:
	# Check if this scene has already been completed (GMS2: game.scenesLoaded)
	if scene_persistence_id != "" and GameManager.is_scene_completed(scene_persistence_id):
		# Scene already played, skip it
		queue_free()
		return

	if auto_start:
		# GMS2: Create runs before Step, but in Godot StartingPoint uses call_deferred
		# to spawn players. Wait for players to exist before starting the scene.
		if GameManager.players.is_empty():
			_waiting_for_players = true
		else:
			start_scene()

func _process(delta: float) -> void:
	# Wait for players to be spawned (deferred) before starting scene
	if _waiting_for_players:
		if not GameManager.players.is_empty():
			_waiting_for_players = false
			start_scene()
		return

	_dialog_paused = false
	if scene_running:
		# GMS2: game.dialog_paused — scene timer pauses while dialog is showing.
		# NOTE: this 'return' only exits the BASE _process(). Child classes that call
		# super._process(delta) will continue executing. Children MUST check
		# _dialog_paused to avoid re-running step logic with a frozen timer.
		if DialogManager.is_showing():
			_dialog_paused = true
			return
		timer += delta

func start_scene() -> void:
	scene_running = true
	scene_step = 0
	timer = 0.0
	GameManager.scene_running = true
	# GMS2: startAnimationScene() — lock players immediately so AI states
	# never execute during the cutscene. Without this, there's a race condition:
	# state_machine (_physics_process) runs before the scene (_process), allowing
	# 1-2 frames of AI transitions (IAStand→IAGuard→IAFollow) before the scene's
	# own lock_all_players() call.
	lock_all_players()
	# GMS2: startAnimationScene() calls hideHud()
	if GameManager.hud:
		GameManager.hud.hide_hud()

func end_scene() -> void:
	scene_running = false
	GameManager.scene_running = false
	# GMS2: endAnimationScene() - full cleanup
	if GameManager.hud:
		GameManager.hud.show_hud()

	# Restore all actors to stand/dead state + unlock (GMS2: with(oActor) { unlock...; changeStateStandDead(); })
	for player in GameManager.players:
		if is_instance_valid(player) and player is Actor:
			var actor: Actor = player as Actor
			actor.unlock_movement_input()
			actor.unlock_input()
			actor.velocity = Vector2.ZERO
			if actor.state_machine_node:
				if actor.is_dead:
					if actor.state_machine_node.has_state("Dead"):
						actor.state_machine_node.switch_state("Dead")
				elif actor.player_controlled:
					if actor.state_machine_node.has_state("Stand"):
						actor.state_machine_node.switch_state("Stand")
				else:
					if actor.state_machine_node.has_state("IAStand"):
						actor.state_machine_node.switch_state("IAStand")

	# GMS2: cameraSet(getPartyLeader()) + cameraBind(getPartyLeader())
	var leader: Node = GameManager.get_party_leader()
	if leader:
		camera_set(leader)
		camera_bind(leader)

	# Mark as completed if persistence is enabled
	if scene_persistence_id != "":
		GameManager.set_scene_completed(scene_persistence_id)
	scene_finished.emit()

func is_scene_step(step: int, min_timer: float = 0.0) -> bool:
	return scene_step == step and timer >= min_timer

func add_step() -> void:
	scene_step += 1
	timer = 0.0

func step_on_dialog_finished() -> void:
	if not DialogManager.is_showing():
		add_step()

# Helper: lock all player movement AND input during cutscenes
func lock_all_players() -> void:
	for player in GameManager.players:
		if is_instance_valid(player):
			player.lock_movement_input()
			# Also lock input so _read_input() doesn't capture keypresses
			# between cutscene dialog pages (prevents NPC interaction triggers).
			if player is Actor:
				(player as Actor).lock_input()
			# Force non-leader actors OUT of AI states during cutscenes.
			# Without this, there's a race condition: state_machine runs in
			# _physics_process (before _process), so IAStand→IAGuard can fire
			# before lock_all_players() is called from the scene's _process.
			# Switching to Stand ensures AI behavior is fully stopped.
			if player is Actor:
				var actor := player as Actor
				if not actor.player_controlled and actor.state_machine_node:
					if actor.state_machine_node.has_state("Stand"):
						actor.state_machine_node.switch_state("Stand")

func unlock_all_players() -> void:
	for player in GameManager.players:
		if is_instance_valid(player):
			player.unlock_movement_input()
			if player is Actor:
				(player as Actor).unlock_input()

# Helper: make player look in a direction
func look_at_direction(player: Node, direction: int) -> void:
	if is_instance_valid(player) and player is Creature:
		player.facing = direction
		player.new_facing = direction

# Helper: line up party behind leader
func line_up(direction: int) -> void:
	if GameManager.players.size() < 2:
		return
	var leader: Node2D = GameManager.players[0]
	if not is_instance_valid(leader):
		return
	var offset := Vector2.ZERO
	match direction:
		Constants.Facing.UP: offset = Vector2(0, 16)
		Constants.Facing.DOWN: offset = Vector2(0, -16)
		Constants.Facing.LEFT: offset = Vector2(16, 0)
		Constants.Facing.RIGHT: offset = Vector2(-16, 0)
	for i in range(1, GameManager.players.size()):
		if is_instance_valid(GameManager.players[i]):
			GameManager.players[i].global_position = leader.global_position + offset * i

# Helper: move a node toward a target position smoothly
func move_toward_position(node: Node2D, target_pos: Vector2, speed: float) -> bool:
	## Returns true when the node has reached the target
	if not is_instance_valid(node):
		return true
	var dist := node.global_position.distance_to(target_pos)
	if dist < speed:
		node.global_position = target_pos
		return true
	node.global_position = node.global_position.move_toward(target_pos, speed)
	return false

# Helper: move a creature to position with walk/run animation (GMS2: go_moveToPosition)
# Call each frame from a scene step; returns true when creature reaches destination
func go_move_to_position(creature: Creature, x_pos: float, y_pos: float, p_running: bool = false, check_collisions: bool = true, keep_state: bool = false) -> bool:
	return MoveToPosition.go(creature, x_pos, y_pos, p_running, check_collisions, keep_state)

# Helper: stop movement for a creature (GMS2: stopMovementMotion)
func stop_movement(creature: Creature) -> void:
	MoveToPosition.stop(creature)

# =====================================================================
# Camera helpers for cutscenes (GMS2: cameraMove/cameraSet/cameraBind/cameraUnbind)
# =====================================================================

func _get_camera() -> CameraController:
	var root: Node = get_tree().current_scene
	if root:
		var cam: Node = root.find_child("CameraController", true, false)
		if cam is CameraController:
			return cam as CameraController
	return null

## Set explicit camera limits matching GMS2 room dimensions.
## Use after camera_set/camera_bind to override auto-detected TileMapLayer bounds.
func camera_set_limits(left: int, top: int, right: int, bottom: int) -> void:
	var cam := _get_camera()
	if cam:
		cam.limit_left = left
		cam.limit_top = top
		cam.limit_right = right
		cam.limit_bottom = bottom

## GMS2: cameraMove(direction, pixels, speed) - pan camera in a direction
func camera_move(direction: int, pixels: float, speed: float = 3.0) -> void:
	var cam := _get_camera()
	if cam:
		cam.camera_move(direction, pixels, speed)

## GMS2: cameraSet(follower) - set camera to follow a target smoothly
func camera_set(target: Node2D) -> void:
	var cam := _get_camera()
	if cam:
		cam.following = target
		cam.action = CameraController.Action.NONE

## GMS2: cameraBind(object) - bind camera to target with dead zone borders
func camera_bind(target: Node2D) -> void:
	var cam := _get_camera()
	if cam:
		cam.camera_bind(target)

## GMS2: cameraUnbind() - unbind camera (free position, no dead zone)
func camera_unbind() -> void:
	var cam := _get_camera()
	if cam:
		cam.camera_unbind()

## GMS2: cameraSetCoord(x, y) - snap camera to absolute position without binding
func camera_set_coord(pos: Vector2) -> void:
	var cam := _get_camera()
	if cam:
		cam.camera_set_coord(pos)

## GMS2: cameraMoveMotion(x, y) - smooth eased camera pan to target position
func camera_move_motion(target_pos: Vector2, bind_target: Node2D = null) -> void:
	var cam := _get_camera()
	if cam:
		cam.camera_move_motion(target_pos, 26.0, bind_target)

## GMS2: cameraShake(mode) - start screen shake
## GMS2: cameraShake has NO duration — shakes indefinitely until cameraStop().
func camera_shake(mode: int = Constants.ShakeMode.UP_DOWN, intensity: float = 2.0) -> void:
	var cam := _get_camera()
	if cam:
		cam.camera_shake(0, mode, intensity)

## GMS2: cameraStop() - stop camera movement/shake
func camera_stop() -> void:
	var cam := _get_camera()
	if cam:
		cam.camera_stop()

## GMS2: go_flash(totalFlashes) - binary strobe: white rect every other frame, N times
func go_flash(total_flashes: int = 1) -> void:
	ScreenFlash.create_strobe(get_tree(), total_flashes)

# =====================================================================
# GMS2 go_* scene event helper commands (cutscene choreography)
# =====================================================================

## GMS2: go_look(object, direction) - set facing + stand animation
func go_look(creature: Creature, direction: int) -> void:
	if not is_instance_valid(creature):
		return
	creature.facing = direction
	creature.new_facing = direction
	creature.set_facing_frame(
		creature.spr_stand_up, creature.spr_stand_right,
		creature.spr_stand_down, creature.spr_stand_left
	)

## GMS2: go_walk(object, moveDirection, totalTilesToMove, [backwards])
## Walks a creature N tiles in a direction. Call each frame; returns true when done.
## backwards=true: creature faces OPPOSITE of movement direction (GMS2 behavior).
func go_walk(creature: Creature, direction: int, tiles: float, backwards: bool = false) -> bool:
	var target_pos: Vector2 = _direction_tile_target(creature, direction, tiles)
	if backwards:
		# GMS2: backwards walk faces opposite direction while moving
		var opposite: int = direction
		match direction:
			Constants.Facing.UP: opposite = Constants.Facing.DOWN
			Constants.Facing.DOWN: opposite = Constants.Facing.UP
			Constants.Facing.LEFT: opposite = Constants.Facing.RIGHT
			Constants.Facing.RIGHT: opposite = Constants.Facing.LEFT
		creature.facing = opposite
		creature.new_facing = opposite
	else:
		creature.facing = direction
		creature.new_facing = direction
	# Use existing MoveToPosition system (lock_facing=backwards prevents facing override)
	return MoveToPosition.go(creature, target_pos.x, target_pos.y, false, true, false, backwards)

## GMS2: go_run(object, moveDirection, totalTilesToMove)
## Runs a creature N tiles in a direction. Call each frame; returns true when done.
func go_run(creature: Creature, direction: int, tiles: float) -> bool:
	var target_pos: Vector2 = _direction_tile_target(creature, direction, tiles)
	creature.facing = direction
	creature.new_facing = direction
	return MoveToPosition.go(creature, target_pos.x, target_pos.y, true, true, false)

## GMS2: go_attack(object, moveDirection) - play attack animation facing a direction
func go_attack(creature: Creature, direction: int) -> void:
	if not is_instance_valid(creature):
		return
	creature.facing = direction
	creature.new_facing = direction
	if creature.state_machine_node and creature.state_machine_node.has_state("Attack"):
		creature.state_machine_node.switch_state("Attack")

## GMS2: go_animation(object, animationType, faceDirection) - play cutscene pose.
## Animations: ANIMATION_NEGATE_RIGHT=0 (head shake, 40 frames),
##             ANIMATION_FALL_UP=1 (sad pose, static),
##             ANIMATION_AFIRMATE=2 (head nod, 600 frames).
## Returns a Dictionary with "finished" key that becomes true when done.
func go_animation(creature: Creature, animation_type: int, face_direction: int) -> Dictionary:
	if not is_instance_valid(creature) or not (creature is Actor):
		return {"finished": true}
	var actor := creature as Actor
	var anim_id: int = creature.get_instance_id()

	# Check for existing animation tracker
	if _animation_trackers.has(anim_id):
		var tracker: Dictionary = _animation_trackers[anim_id]
		# Advance animation timer with delta time
		var anim_delta: float = get_process_delta_time()
		tracker["timer"] += anim_delta
		if tracker["timer"] < tracker["duration"]:
			creature.animate_sprite(actor.img_speed_walk)
		if tracker["timer"] >= tracker["duration"]:
			# Animation finished: restore stand pose
			creature.image_speed = actor.img_speed_walk
			creature.set_default_facing_animations(
				actor.spr_walk_up_ini, actor.spr_walk_right_ini,
				actor.spr_walk_down_ini, actor.spr_walk_left_ini,
				actor.spr_walk_up_end, actor.spr_walk_right_end,
				actor.spr_walk_down_end, actor.spr_walk_left_end
			)
			creature.set_facing_frame(
				actor.spr_stand_up, actor.spr_stand_right,
				actor.spr_stand_down, actor.spr_stand_left
			)
			tracker["finished"] = true
			_animation_trackers.erase(anim_id)
		return tracker

	# Create new animation
	creature.facing = face_direction
	creature.new_facing = face_direction
	var duration: float = 40.0 / 60.0
	match animation_type:
		0:  # ANIMATION_NEGATE_RIGHT: head shake (40 frames = 0.667s)
			duration = 40.0 / 60.0
			creature.set_default_facing_animations(
				actor.spr_look_no_ini, actor.spr_look_no_ini,
				actor.spr_look_no_ini, actor.spr_look_no_ini,
				actor.spr_look_no_end, actor.spr_look_no_end,
				actor.spr_look_no_end, actor.spr_look_no_end
			)
			creature.image_speed = actor.img_speed_walk
		1:  # ANIMATION_FALL_UP: sad/depressed pose (frame 115, static)
			duration = 9999.0  # Stays until manually cleared or scene advances
			creature.image_speed = 0
			creature.current_frame = actor.spr_fall_up
		2:  # ANIMATION_AFIRMATE: head nod (frames 306-307, 600 frames = 10s)
			duration = 600.0 / 60.0
			creature.set_default_facing_animations(
				actor.spr_look_yes_ini, actor.spr_look_yes_ini,
				actor.spr_look_yes_ini, actor.spr_look_yes_ini,
				actor.spr_look_yes_end, actor.spr_look_yes_end,
				actor.spr_look_yes_end, actor.spr_look_yes_end
			)
			creature.image_speed = actor.img_speed_walk
	var tracker: Dictionary = {"finished": false, "timer": 0.0, "duration": duration, "type": animation_type}
	_animation_trackers[anim_id] = tracker
	return tracker

## Active cutscene animation trackers (keyed by creature instance_id)
var _animation_trackers: Dictionary = {}

## Stop a cutscene animation on a creature (GMS2: destroy oAnimator)
func stop_animation(creature: Creature) -> void:
	if is_instance_valid(creature):
		var anim_id: int = creature.get_instance_id()
		if _animation_trackers.has(anim_id):
			_animation_trackers.erase(anim_id)
		if creature is Actor:
			var actor := creature as Actor
			creature.image_speed = actor.img_speed_walk
			creature.set_default_facing_animations(
				actor.spr_walk_up_ini, actor.spr_walk_right_ini,
				actor.spr_walk_down_ini, actor.spr_walk_left_ini,
				actor.spr_walk_up_end, actor.spr_walk_right_end,
				actor.spr_walk_down_end, actor.spr_walk_left_end
			)

## GMS2: go_fadeOut(fadeTime, [color], [force]) - fade screen to color
func go_fade_out(time_frames: int = 60, color: Color = Color.BLACK) -> void:
	if GameManager.map_transition:
		GameManager.map_transition.fade_out(time_frames, color)

## GMS2: go_fadeIn(fadeTime, [color], [force]) - fade screen from color
func go_fade_in(time_frames: int = 60, color: Color = Color.BLACK) -> void:
	if GameManager.map_transition:
		GameManager.map_transition.fade_in(time_frames, color)

## GMS2: go_fadeOutMagic() - fade to 50% black for magic effects
func go_fade_out_magic() -> void:
	if GameManager.map_transition:
		GameManager.map_transition.fade_out_magic(60)

## GMS2: go_fadeInMagic() - fade back from 50% black
func go_fade_in_magic() -> void:
	if GameManager.map_transition:
		GameManager.map_transition.fade_in_magic(60)

## GMS2: go_blendScreenOn(color, intensity, fadeTime) - apply colored tint overlay
func go_blend_screen_on(color: Color, intensity: float = 1.0, time_frames: int = 0) -> void:
	if GameManager.map_transition:
		if time_frames <= 0:
			GameManager.map_transition.blend_screen_on(color, intensity)
		else:
			# Fade the blend in over time_frames
			GameManager.map_transition.fade_color = color
			GameManager.map_transition.max_fade = intensity
			GameManager.map_transition.min_fade = 0.0
			GameManager.map_transition.fade_speed = intensity / float(time_frames)
			GameManager.map_transition.fade_mode = MapTransition.FadeMode.FADE_OUT
			GameManager.map_transition.animating = true
			GameManager.map_transition._color_rect.visible = true

## GMS2: go_blendScreenOff(fadeTime) - remove colored tint overlay
func go_blend_screen_off(time_frames: int = 30) -> void:
	if GameManager.map_transition:
		GameManager.map_transition.fade_in(time_frames, GameManager.map_transition.fade_color)

## GMS2: go_blendScreenOnOff(color, intensity, fadeTime) - flash tint on then off
func go_blend_screen_on_off(color: Color, intensity: float = 1.0, time_frames: int = 30) -> void:
	if GameManager.map_transition:
		go_blend_screen_on(color, intensity, time_frames)
		# Auto reverse after reaching max
		get_tree().create_timer(float(time_frames) / 60.0).timeout.connect(func():
			go_blend_screen_off(time_frames)
		)

## GMS2: go_separatePlayersByFacing(face) - offset players to prevent sprite flickering
func go_separate_players_by_facing(direction: int) -> void:
	var counted: int = 0
	for i in range(GameManager.players.size()):
		var player: Node2D = GameManager.players[i] as Node2D
		if not is_instance_valid(player):
			counted += 1
			continue
		match direction:
			Constants.Facing.UP: player.global_position.y -= counted
			Constants.Facing.RIGHT: player.global_position.x += counted
			Constants.Facing.DOWN: player.global_position.y += counted
			Constants.Facing.LEFT: player.global_position.x -= counted
		counted += 1

## GMS2: go_lineUp(lineDirection, [placement], [stepBackOnFinish])
## Lines up party members in formation perpendicular to the given direction.
## Creates a LineUpAnimator that runs independently over multiple frames:
## Phase 0: stand ready + find middle player
## Phase 1: non-middle players converge to middle player (running)
## Phase 2: after 30 frames, spread left/right 18px
## Phase 3: (optional) step backward 16px
func go_line_up(direction: int, placement: Array = [], step_back: bool = false) -> void:
	LineUpAnimator.start(direction, placement, step_back)

## Helper: calculate target position from direction + tile count
func _direction_tile_target(creature: Creature, direction: int, tiles: float) -> Vector2:
	var offset := Vector2.ZERO
	var tile_size: float = 16.0  # GMS2 tile = 16px
	match direction:
		Constants.Facing.UP: offset = Vector2(0, -tiles * tile_size)
		Constants.Facing.RIGHT: offset = Vector2(tiles * tile_size, 0)
		Constants.Facing.DOWN: offset = Vector2(0, tiles * tile_size)
		Constants.Facing.LEFT: offset = Vector2(-tiles * tile_size, 0)
	return creature.global_position + offset
