class_name SceneCutsceneTest
extends SceneEvent
## Interactive test room for all SceneEvent cutscene actions.
## Presents a menu of categories → actions → executes demo → returns to menu.

var _dialog_done: bool = false
var _question_answer: int = -1
var _category: int = -1      # Selected main menu category
var _action: int = -1         # Selected sub-menu action
var _demo_timer: float = 0.0  # Time counter for demos
var _demo_phase: int = 0      # Sub-phase within a demo
var _demo_running: bool = false
var _movement_done: Array[bool] = [false, false, false]
var _saved_positions: Array[Vector2] = []

# Main menu options
const CAT_CAMERA: int = 0
const CAT_SCREEN: int = 1
const CAT_MOVEMENT: int = 2
const CAT_ANIMATION: int = 3
const CAT_DIALOG: int = 4
const CAT_COMBINED: int = 5
const CAT_EXIT: int = 6

const CATEGORIES: Array[String] = ["Camera", "Screen", "Movement", "Animation", "Dialog", "Combined", "Exit"]

const CAMERA_ACTIONS: Array[String] = ["SetCoord", "Move", "Shake", "SmoothPan", "Back"]
const SCREEN_ACTIONS: Array[String] = ["FadeOut/In", "BlendOn/Off", "BlendFlash", "Flash", "Back"]
const MOVEMENT_ACTIONS: Array[String] = ["MoveToPos", "Walk", "Run", "LineUp", "Back"]
const ANIM_ACTIONS: Array[String] = ["Affirmate", "FallUp", "Negate", "LookAll", "Back"]
const DIALOG_ACTIONS: Array[String] = ["Top", "Bottom", "MultiPage", "Question", "Back"]


func _ready() -> void:
	auto_start = true
	scene_persistence_id = ""  # No persistence — always runs
	super._ready()
	DialogManager.dialog_finished.connect(_on_dialog_finished)
	DialogManager.dialog_question_answered.connect(_on_question_answered)


func _on_dialog_finished(_id: String) -> void:
	_dialog_done = true


func _on_question_answered(_id: String, answer: int) -> void:
	_question_answer = answer


func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running or _dialog_paused:
		return

	# === STEP 0: Show main menu ===
	if is_scene_step(0):
		if timer >= 1.0 / 60.0:
			_show_main_menu()
			add_step()

	# === STEP 1: Wait for main menu answer ===
	elif is_scene_step(1):
		if _dialog_done and _question_answer >= 0:
			_category = _question_answer
			_dialog_done = false
			_question_answer = -1

			if _category == CAT_EXIT:
				unlock_all_players()
				end_scene()
				return
			elif _category == CAT_COMBINED:
				# Skip sub-menu, go straight to combined demo
				_action = 0
				_start_demo()
				scene_step = 3
				timer = 0.0
			else:
				add_step()

	# === STEP 2: Show sub-menu for selected category ===
	elif is_scene_step(2):
		if timer >= 1.0 / 60.0:
			_show_sub_menu()
			add_step()

	# === STEP 3: Wait for sub-menu answer / run demo ===
	elif is_scene_step(3):
		if not _demo_running:
			# Waiting for sub-menu answer
			if _dialog_done and _question_answer >= 0:
				_action = _question_answer
				_dialog_done = false
				_question_answer = -1

				var actions: Array[String] = _get_actions_for_category()
				if _action >= actions.size() - 1:
					# "Back" selected → return to main menu
					_return_to_menu()
				else:
					_start_demo()
		else:
			# Demo is running
			_process_demo()

	# === STEP 4: Demo done message ===
	elif is_scene_step(4):
		if timer >= 1.0 / 60.0 and not _dialog_done:
			_dialog_done = false
			DialogManager.show_dialog("test-demo-done", {
				"id": "", "anchor": Constants.DialogAnchor.BOTTOM, "block_controls": true,
			})
		elif _dialog_done:
			_dialog_done = false
			_return_to_menu()


# =====================================================================
# MENU HELPERS
# =====================================================================

func _show_main_menu() -> void:
	_dialog_done = false
	_question_answer = -1
	DialogManager.show_dialog("test-menu-main", {
		"id": "", "anchor": Constants.DialogAnchor.TOP, "block_controls": true,
		"questions": CATEGORIES,
	})


func _show_sub_menu() -> void:
	_dialog_done = false
	_question_answer = -1
	var menu_id: String = ["test-menu-camera", "test-menu-screen", "test-menu-movement",
		"test-menu-animation", "test-menu-dialog"][_category]
	var actions: Array[String] = _get_actions_for_category()
	DialogManager.show_dialog(menu_id, {
		"id": "", "anchor": Constants.DialogAnchor.TOP, "block_controls": true,
		"questions": actions,
	})


func _get_actions_for_category() -> Array[String]:
	match _category:
		CAT_CAMERA: return CAMERA_ACTIONS
		CAT_SCREEN: return SCREEN_ACTIONS
		CAT_MOVEMENT: return MOVEMENT_ACTIONS
		CAT_ANIMATION: return ANIM_ACTIONS
		CAT_DIALOG: return DIALOG_ACTIONS
		_: return ["Back"]


func _return_to_menu() -> void:
	# Restore state and go back to main menu
	_demo_running = false
	_demo_phase = 0
	_demo_timer = 0.0
	var leader: Node = GameManager.get_party_leader()
	if leader:
		camera_set(leader as Node2D)
		camera_bind(leader as Node2D)
	scene_step = 0
	timer = 0.0


func _start_demo() -> void:
	_demo_running = true
	_demo_phase = 0
	_demo_timer = 0.0
	_dialog_done = false
	_movement_done = [false, false, false]
	# Save player positions for restoration
	_saved_positions.clear()
	for p in GameManager.players:
		if is_instance_valid(p):
			_saved_positions.append((p as Node2D).global_position)


func _finish_demo() -> void:
	_demo_running = false
	# Restore player positions
	for i in range(mini(_saved_positions.size(), GameManager.players.size())):
		if is_instance_valid(GameManager.players[i]):
			(GameManager.players[i] as Node2D).global_position = _saved_positions[i]
	# Restore camera
	var leader: Node = GameManager.get_party_leader()
	if leader:
		camera_set(leader as Node2D)
		camera_bind(leader as Node2D)
	# Stop any lingering animations
	for p in GameManager.players:
		if is_instance_valid(p) and p is Creature:
			stop_animation(p as Creature)
			go_look(p as Creature, Constants.Facing.DOWN)
	# Go to "Done" step
	scene_step = 4
	timer = 0.0


# =====================================================================
# DEMO DISPATCHER
# =====================================================================

func _process_demo() -> void:
	_demo_timer += get_process_delta_time()
	match _category:
		CAT_CAMERA: _process_camera_demo()
		CAT_SCREEN: _process_screen_demo()
		CAT_MOVEMENT: _process_movement_demo()
		CAT_ANIMATION: _process_animation_demo()
		CAT_DIALOG: _process_dialog_demo()
		CAT_COMBINED: _process_combined_demo()


# =====================================================================
# CAMERA DEMOS
# =====================================================================

func _process_camera_demo() -> void:
	var leader: Node2D = GameManager.get_party_leader() as Node2D
	match _action:
		0:  # camera_set_coord
			if _demo_timer >= 1.0 / 60.0:
				camera_set_coord(Vector2(400, 200))
			elif _demo_timer >= 120.0 / 60.0:
				if leader: camera_set(leader); camera_bind(leader)
				_finish_demo()

		1:  # camera_move
			if _demo_timer >= 1.0 / 60.0:
				camera_move(Constants.Facing.RIGHT, 80, 2.0)
			elif _demo_timer >= 90.0 / 60.0:
				camera_move(Constants.Facing.LEFT, 80, 2.0)
			elif _demo_timer >= 180.0 / 60.0:
				if leader: camera_set(leader); camera_bind(leader)
				_finish_demo()

		2:  # camera_shake
			if _demo_timer >= 1.0 / 60.0:
				camera_shake(Constants.ShakeMode.UP_DOWN, 2.0)
			elif _demo_timer >= 90.0 / 60.0:
				camera_stop()
				camera_shake(Constants.ShakeMode.BOTH, 3.0)
			elif _demo_timer >= 180.0 / 60.0:
				camera_stop()
				_finish_demo()

		3:  # camera_move_motion (smooth pan)
			if _demo_timer >= 1.0 / 60.0:
				camera_move_motion(Vector2(400, 200), leader)
			elif _demo_timer >= 120.0 / 60.0:
				_finish_demo()

		4:  # Back — handled in _show_sub_menu
			_finish_demo()


# =====================================================================
# SCREEN EFFECT DEMOS
# =====================================================================

func _process_screen_demo() -> void:
	match _action:
		0:  # fade_out / fade_in
			if _demo_timer >= 1.0 / 60.0:
				go_fade_out(40, Color.BLACK)
			elif _demo_timer >= 80.0 / 60.0:
				go_fade_in(40, Color.BLACK)
			elif _demo_timer >= 140.0 / 60.0:
				_finish_demo()

		1:  # blend_screen_on / off
			if _demo_timer >= 1.0 / 60.0:
				go_blend_screen_on(Color.RED, 0.6, 30)
			elif _demo_timer >= 90.0 / 60.0:
				go_blend_screen_off(30)
			elif _demo_timer >= 140.0 / 60.0:
				_finish_demo()

		2:  # blend_on_off (flash tint)
			if _demo_timer >= 1.0 / 60.0:
				go_blend_screen_on_off(Color.BLUE, 0.8, 20)
			elif _demo_timer >= 80.0 / 60.0:
				_finish_demo()

		3:  # flash (white strobe)
			if _demo_timer >= 1.0 / 60.0:
				go_flash(3)
			elif _demo_timer >= 60.0 / 60.0:
				_finish_demo()

		4:  # Back
			_finish_demo()


# =====================================================================
# MOVEMENT DEMOS
# =====================================================================

func _process_movement_demo() -> void:
	match _action:
		0:  # go_move_to_position — move 3 players to triangle formation
			if GameManager.players.size() >= 3:
				var base: Vector2 = _saved_positions[0]
				if not _movement_done[0]:
					_movement_done[0] = go_move_to_position(
						GameManager.players[0] as Creature, base.x + 40, base.y - 30)
				if not _movement_done[1]:
					_movement_done[1] = go_move_to_position(
						GameManager.players[1] as Creature, base.x - 20, base.y + 20)
				if not _movement_done[2]:
					_movement_done[2] = go_move_to_position(
						GameManager.players[2] as Creature, base.x + 20, base.y + 20)
				if _movement_done[0] and _movement_done[1] and _movement_done[2] and _demo_timer > 30.0 / 60.0:
					_finish_demo()

		1:  # go_walk — leader walks 3 tiles right
			if _demo_phase == 0:
				var leader: Creature = GameManager.get_party_leader() as Creature
				if leader and go_walk(leader, Constants.Facing.RIGHT, 3):
					_demo_phase = 1
			elif _demo_phase == 1:
				# Walk back
				var leader: Creature = GameManager.get_party_leader() as Creature
				if leader and go_walk(leader, Constants.Facing.LEFT, 3):
					_finish_demo()

		2:  # go_run — leader runs 3 tiles right then back
			if _demo_phase == 0:
				var leader: Creature = GameManager.get_party_leader() as Creature
				if leader and go_run(leader, Constants.Facing.RIGHT, 3):
					_demo_phase = 1
			elif _demo_phase == 1:
				var leader: Creature = GameManager.get_party_leader() as Creature
				if leader and go_run(leader, Constants.Facing.LEFT, 3):
					_finish_demo()

		3:  # line_up
			if _demo_timer >= 1.0 / 60.0:
				line_up(Constants.Facing.DOWN)
			elif _demo_timer >= 90.0 / 60.0:
				_finish_demo()

		4:  # Back
			_finish_demo()


# =====================================================================
# ANIMATION DEMOS
# =====================================================================

func _process_animation_demo() -> void:
	match _action:
		0:  # AFFIRMATE (head nod) on player[2]
			if _demo_phase == 0 and GameManager.players.size() >= 3:
				var result := go_animation(GameManager.players[2] as Creature, 2, Constants.Facing.DOWN)
				if result.get("finished", false):
					_demo_phase = 1
			elif _demo_phase == 1:
				if GameManager.players.size() >= 3:
					stop_animation(GameManager.players[2] as Creature)
				_finish_demo()

		1:  # FALL_UP (sad pose) on player[1]
			if _demo_timer >= 1.0 / 60.0 and GameManager.players.size() >= 2:
				go_animation(GameManager.players[1] as Creature, 1, Constants.Facing.UP)
			elif _demo_timer >= 120.0 / 60.0:
				if GameManager.players.size() >= 2:
					stop_animation(GameManager.players[1] as Creature)
				_finish_demo()

		2:  # NEGATE (head shake) on player[0]
			if _demo_phase == 0 and GameManager.players.size() >= 1:
				var result := go_animation(GameManager.players[0] as Creature, 0, Constants.Facing.RIGHT)
				if result.get("finished", false):
					_demo_phase = 1
			elif _demo_phase == 1:
				if GameManager.players.size() >= 1:
					stop_animation(GameManager.players[0] as Creature)
				_finish_demo()

		3:  # go_look — all players rotate through 4 facings
			var facing_sequence: Array[int] = [
				Constants.Facing.UP, Constants.Facing.RIGHT,
				Constants.Facing.DOWN, Constants.Facing.LEFT
			]
			var facing_idx: int = int(_demo_timer / (30.0 / 60.0)) % 4
			for p in GameManager.players:
				if is_instance_valid(p) and p is Creature:
					go_look(p as Creature, facing_sequence[facing_idx])
			if _demo_timer >= 130.0 / 60.0:
				_finish_demo()

		4:  # Back
			_finish_demo()


# =====================================================================
# DIALOG DEMOS
# =====================================================================

func _process_dialog_demo() -> void:
	match _action:
		0:  # dialog TOP
			if _demo_timer >= 1.0 / 60.0:
				_dialog_done = false
				DialogManager.show_dialog("test-dialog-top", {
					"id": "", "anchor": Constants.DialogAnchor.TOP, "block_controls": true,
				})
			elif _dialog_done:
				_dialog_done = false
				_finish_demo()

		1:  # dialog BOTTOM
			if _demo_timer >= 1.0 / 60.0:
				_dialog_done = false
				DialogManager.show_dialog("test-dialog-bottom", {
					"id": "", "anchor": Constants.DialogAnchor.BOTTOM, "block_controls": true,
				})
			elif _dialog_done:
				_dialog_done = false
				_finish_demo()

		2:  # multi-page with pauses
			if _demo_timer >= 1.0 / 60.0:
				_dialog_done = false
				DialogManager.show_dialog("test-dialog-multipage", {
					"id": "", "anchor": Constants.DialogAnchor.TOP, "block_controls": true,
				})
			elif _dialog_done:
				_dialog_done = false
				_finish_demo()

		3:  # question dialog
			if _demo_phase == 0 and _demo_timer >= 1.0 / 60.0:
				_dialog_done = false
				_question_answer = -1
				DialogManager.show_dialog("test-dialog-question", {
					"id": "", "anchor": Constants.DialogAnchor.TOP, "block_controls": true,
					"questions": ["Randi", "Purim", "Popoie"],
				})
				_demo_phase = 1
			elif _demo_phase == 1 and _dialog_done and _question_answer >= 0:
				_dialog_done = false
				var names: Array[String] = ["Randi", "Purim", "Popoie"]
				var chosen: String = names[_question_answer] if _question_answer < names.size() else "???"
				DialogManager.show_dialog("test-dialog-answer", {
					"id": "", "anchor": Constants.DialogAnchor.BOTTOM, "block_controls": true,
					"replace_map": {"answer": chosen},
				})
				_demo_phase = 2
			elif _demo_phase == 2 and _dialog_done:
				_dialog_done = false
				_finish_demo()

		4:  # Back
			_finish_demo()


# =====================================================================
# COMBINED DEMO (mini-cutscene)
# =====================================================================

func _process_combined_demo() -> void:
	match _demo_phase:
		0:  # Fade out
			if _demo_timer >= 1.0 / 60.0:
				go_fade_out(30, Color.BLACK)
			elif _demo_timer >= 40.0 / 60.0:
				# Position camera away from players
				camera_set_coord(Vector2(300, 150))
				line_up(Constants.Facing.RIGHT)
				go_fade_in(30, Color.BLACK)
				_demo_phase = 1
				_demo_timer = 0.0

		1:  # Dialog 1
			if _demo_timer >= 40.0 / 60.0:
				_dialog_done = false
				DialogManager.show_dialog("test-combined-1", {
					"id": "", "anchor": Constants.DialogAnchor.TOP, "block_controls": true,
				})
			elif _demo_timer > 40.0 / 60.0 and _dialog_done:
				_dialog_done = false
				_demo_phase = 2
				_demo_timer = 0.0

		2:  # Camera pan back to players
			if _demo_timer >= 1.0 / 60.0:
				var leader: Node2D = GameManager.get_party_leader() as Node2D
				if leader:
					camera_move_motion(leader.global_position, leader)
			elif _demo_timer >= 60.0 / 60.0:
				_dialog_done = false
				DialogManager.show_dialog("test-combined-2", {
					"id": "", "anchor": Constants.DialogAnchor.TOP, "block_controls": true,
				})
			elif _demo_timer > 60.0 / 60.0 and _dialog_done:
				_dialog_done = false
				_demo_phase = 3
				_demo_timer = 0.0

		3:  # Camera shake + animation
			if _demo_timer >= 1.0 / 60.0:
				camera_shake(Constants.ShakeMode.BOTH, 2.0)
				if GameManager.players.size() >= 3:
					go_animation(GameManager.players[2] as Creature, 2, Constants.Facing.DOWN)
			elif _demo_timer >= 90.0 / 60.0:
				camera_stop()
				for p in GameManager.players:
					if is_instance_valid(p) and p is Creature:
						stop_animation(p as Creature)
				_dialog_done = false
				DialogManager.show_dialog("test-combined-3", {
					"id": "", "anchor": Constants.DialogAnchor.BOTTOM, "block_controls": true,
				})
			elif _demo_timer > 90.0 / 60.0 and _dialog_done:
				_dialog_done = false
				_demo_phase = 4
				_demo_timer = 0.0

		4:  # Fade out + finish
			if _demo_timer >= 1.0 / 60.0:
				go_fade_out(20, Color.BLACK)
			elif _demo_timer >= 30.0 / 60.0:
				go_fade_in(30, Color.BLACK)
			elif _demo_timer >= 70.0 / 60.0:
				_finish_demo()
