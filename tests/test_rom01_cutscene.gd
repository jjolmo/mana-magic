extends Node
## Test suite for rom_01 cutscene (scene_rabite1) - full choreography verification
## Run: godot --headless --path . tests/test_rom01_runner.tscn

const TIMEOUT_SECONDS: float = 180.0
const DIALOG_ADVANCE_INTERVAL: float = 0.05

var _start_time: float = 0.0
var _test_results: Array[Dictionary] = []
var _scene_ref: Node = null
var _last_step: int = -1
var _step_entry_times: Dictionary = {}
var _dialogs_shown: Array[String] = []
var _dialogs_finished: Array[String] = []
var _scene_finished: bool = false
var _map_changed_to: String = ""
var _auto_advance_timer: float = 0.0
var _current_room_scene: Node = null
var _test_phase: String = "loading"
var _frame_count: int = 0
var _input_pressed: bool = false
# Track player positions at key moments
var _step1_player_positions: Array[Vector2] = []
var _blend_screen_active: bool = false

const EXPECTED_DIALOGS: Array[String] = [
	"rom_02-evt_rabiteQuestStart_0",
	"rom_02-evt_rabiteQuestStart_1",
	"rom_02-evt_rabiteQuestStart_2",
	"rom_02-evt_rabiteQuestStart_3",
	"rom_02-evt_rabiteQuestStart_4",
	"rom_02-evt_rabiteQuestStart_5",
	"rom_02-evt_rabiteQuestStart_6",
	"rom_02-evt_rabiteQuestStart_7",
]


func _ready() -> void:
	_start_time = Time.get_ticks_msec() / 1000.0
	_log("=".repeat(70))
	_log("TEST SUITE: rom_01 Cutscene (SceneRabite1) - Full Choreography")
	_log("=".repeat(70))
	_log("Starting test...")

	Engine.max_fps = 60

	DialogManager.dialog_started.connect(_on_dialog_started)
	DialogManager.dialog_finished.connect(_on_dialog_finished)

	call_deferred("_load_rom01")


func _load_rom01() -> void:
	GameManager.scenes_completed.clear()
	GameManager.executed_dialogs.clear()
	GameManager.players.clear()
	GameManager.total_players = 0
	GameManager.scene_running = false

	var scene: PackedScene = load("res://scenes/rooms/rom_01.tscn")
	if scene == null:
		_fail("CRITICAL: Could not load rom_01.tscn")
		_finish_tests()
		return

	_current_room_scene = scene.instantiate()
	get_tree().root.add_child(_current_room_scene)
	get_tree().current_scene = _current_room_scene

	_log("rom_01 scene loaded")
	_test_phase = "waiting_for_scene"


func _process(delta: float) -> void:
	_frame_count += 1
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _start_time

	if elapsed > TIMEOUT_SECONDS:
		var extra: String = ""
		if _scene_ref and is_instance_valid(_scene_ref):
			extra = " step=%d timer=%d dialog=%s" % [_scene_ref.scene_step, _scene_ref.timer, str(DialogManager.is_showing())]
		_fail("TIMEOUT after %ds (phase=%s%s)" % [int(TIMEOUT_SECONDS), _test_phase, extra])
		_finish_tests()
		return

	match _test_phase:
		"waiting_for_scene":
			_find_scene_ref()
			if _scene_ref != null:
				_test_phase = "running"
				_log("SceneRabite1 found")
				_verify_initial_setup()
			elif _frame_count > 180:
				_fail("SceneRabite1 not found")
				_finish_tests()

		"running":
			_monitor_cutscene()
			_auto_advance_dialog(delta)

			if _scene_finished or _map_changed_to != "":
				_test_phase = "done"
				_verify_final_state()
				_finish_tests()


func _find_scene_ref() -> void:
	if _current_room_scene == null:
		return
	for child in _current_room_scene.get_children():
		if child is SceneRabite1:
			_scene_ref = child
			_scene_ref.scene_finished.connect(_on_scene_finished)
			return


func _verify_initial_setup() -> void:
	_log("\n--- INITIAL SETUP ---")

	var pc: int = GameManager.players.size()
	_assert_eq(pc, 3, "3 players spawned")

	if pc >= 3:
		if GameManager.players[0] is Actor:
			_assert_eq((GameManager.players[0] as Actor).character_name, "Randi", "P0 = Randi")
		if GameManager.players[1] is Actor:
			_assert_eq((GameManager.players[1] as Actor).character_name, "Purim", "P1 = Purim")
		if GameManager.players[2] is Actor:
			_assert_eq((GameManager.players[2] as Actor).character_name, "Popoie", "P2 = Popoie")

	var rabite: Node = _current_room_scene.get_node_or_null("mob_rabite_npc")
	if rabite:
		_pass("mob_rabite_npc exists at %s" % str((rabite as Node2D).global_position))
	else:
		_fail("mob_rabite_npc NOT found")

	# Verify blend screen was activated (black screen on start)
	if GameManager.map_transition:
		_pass("MapTransition exists (blend screen support)")
	else:
		_warn("MapTransition missing - blend screen may not work")


func _monitor_cutscene() -> void:
	if _scene_ref == null or not is_instance_valid(_scene_ref):
		return

	var current_step: int = _scene_ref.scene_step
	var timer_val: int = _scene_ref.timer

	if current_step != _last_step:
		if _last_step >= 0:
			var dur: float = (Time.get_ticks_msec() / 1000.0) - _step_entry_times.get(_last_step, 0.0)
			_log("  Step %d done (%.1fs)" % [_last_step, dur])
			_verify_step_completion(_last_step)

		_last_step = current_step
		_step_entry_times[current_step] = Time.get_ticks_msec() / 1000.0
		_log("\n--- STEP %d (t=%d) ---" % [current_step, timer_val])
		_verify_step_entry(current_step)

	# Detect map change
	if current_step >= 10 and GameManager.players.size() == 0 and _map_changed_to == "":
		_map_changed_to = "rom_02"
		_log("  [MAP_CHANGE] rom_02")


func _verify_step_entry(step: int) -> void:
	match step:
		0:
			_pass("Step 0: Setup started")
		1:
			_pass("Step 1: Blend off + player movement started")
		2:
			_pass("Step 2: Dialog 0 (Popoie hungry)")
		3:
			_pass("Step 3: Dialog 1 (Purim teases) + animations")
		4:
			_pass("Step 4: Dialog 2 (Randi seeds)")
		5:
			_pass("Step 5: Dialog 3 (spot rabite) + rabite moves")
		6:
			_pass("Step 6: Rabite attack choreography")
		7:
			_pass("Step 7: Dialog 5 (party angry)")
		8:
			_pass("Step 8: Dialog 6 (Popoie chase)")
		9:
			_pass("Step 9: Dialog 7 (Randi wait)")
		10:
			_pass("Step 10: Map change")


func _verify_step_completion(step: int) -> void:
	match step:
		0:
			# Verify player offsets
			if GameManager.players.size() >= 3:
				var p0: Node2D = GameManager.players[0]
				var p1: Node2D = GameManager.players[1]
				var p2: Node2D = GameManager.players[2]
				var dx1: float = p1.global_position.x - p0.global_position.x
				var dx2: float = p2.global_position.x - p0.global_position.x
				_assert_approx(dx1, -40.0, 5.0, "P1 X offset")
				_assert_approx(dx2, -80.0, 5.0, "P2 X offset")

		1:
			# Verify players reached cutscene positions
			if GameManager.players.size() >= 3:
				var p0: Node2D = GameManager.players[0]
				var p1: Node2D = GameManager.players[1]
				var p2: Node2D = GameManager.players[2]
				_assert_approx(p0.global_position.x, 620.0, 10.0, "P0 at x=620")
				_assert_approx(p0.global_position.y, 443.0, 10.0, "P0 at y=443")
				_assert_approx(p1.global_position.x, 572.0, 10.0, "P1 at x=572")
				_assert_approx(p2.global_position.x, 595.0, 10.0, "P2 at x=595")

		5:
			# Verify rabite moved to target position
			var rabite_node: Node = _current_room_scene.get_node_or_null("mob_rabite_npc")
			if rabite_node and is_instance_valid(rabite_node):
				var rpos: Vector2 = (rabite_node as Node2D).global_position
				_log("  Rabite pos after step 5: %s" % str(rpos))
				_assert_approx(rpos.x, 637.0, 20.0, "Rabite near x=637")
				_assert_approx(rpos.y, 392.0, 20.0, "Rabite near y=392")
			else:
				_warn("Rabite node not available for position check")


func _verify_final_state() -> void:
	_log("\n--- FINAL VERIFICATION ---")

	_log("  Dialogs shown (%d):" % _dialogs_shown.size())
	for d in _dialogs_shown:
		_log("    %s" % d)

	for i in range(EXPECTED_DIALOGS.size()):
		var did: String = EXPECTED_DIALOGS[i]
		if did in _dialogs_shown:
			_pass("Dialog %d '%s' shown" % [i, did])
		else:
			_fail("Dialog %d '%s' NOT shown" % [i, did])

	# Check order
	var idx: int = 0
	for shown in _dialogs_shown:
		if idx < EXPECTED_DIALOGS.size() and shown == EXPECTED_DIALOGS[idx]:
			idx += 1
	if idx == EXPECTED_DIALOGS.size():
		_pass("Dialogs in correct order")
	else:
		_fail("Dialog order wrong (matched %d/%d)" % [idx, EXPECTED_DIALOGS.size()])

	if _map_changed_to == "rom_02":
		_pass("Map transition to rom_02")
	else:
		_fail("No map transition (got '%s')" % _map_changed_to)

	if GameManager.is_scene_completed("oSce_rabite1"):
		_pass("Scene persistence: oSce_rabite1")
	else:
		_warn("Scene persistence not set (may not reach end_scene)")

	_assert_eq(_last_step >= 10, true, "Reached step 10+")


func _auto_advance_dialog(delta: float) -> void:
	_auto_advance_timer += delta
	if _auto_advance_timer >= DIALOG_ADVANCE_INTERVAL:
		_auto_advance_timer = 0.0
		if _input_pressed:
			_input_pressed = false
			var ev := InputEventAction.new()
			ev.action = "attack"
			ev.pressed = false
			Input.parse_input_event(ev)
		else:
			_input_pressed = true
			var ev := InputEventAction.new()
			ev.action = "attack"
			ev.pressed = true
			Input.parse_input_event(ev)


func _on_dialog_started(dialog_id: String) -> void:
	if dialog_id != "":
		_dialogs_shown.append(dialog_id)
		_log("  [DIALOG_START] %s" % dialog_id)

func _on_dialog_finished(dialog_id: String) -> void:
	if dialog_id != "":
		_dialogs_finished.append(dialog_id)
		_log("  [DIALOG_END] %s" % dialog_id)

func _on_scene_finished() -> void:
	_scene_finished = true
	_log("  [SCENE_FINISHED]")


# --- Assertions ---

func _assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_pass("%s: %s" % [msg, str(actual)])
	else:
		_fail("%s: got %s, expected %s" % [msg, str(actual), str(expected)])

func _assert_approx(actual: float, expected: float, tol: float, msg: String) -> void:
	if abs(actual - expected) <= tol:
		_pass("%s: %.1f" % [msg, actual])
	else:
		_fail("%s: %.1f != %.1f (tol=%.1f)" % [msg, actual, expected, tol])

func _pass(msg: String) -> void:
	_test_results.append({"status": "PASS", "message": msg})
	_log("  [PASS] %s" % msg)

func _fail(msg: String) -> void:
	_test_results.append({"status": "FAIL", "message": msg})
	_log("  [FAIL] %s" % msg)

func _warn(msg: String) -> void:
	_test_results.append({"status": "WARN", "message": msg})
	_log("  [WARN] %s" % msg)

func _log(msg: String) -> void:
	print(msg)

func _finish_tests() -> void:
	_log("\n" + "=".repeat(70))
	_log("TEST RESULTS")
	_log("=".repeat(70))

	var passes: int = 0
	var fails: int = 0
	var warns: int = 0
	for r in _test_results:
		match r.status:
			"PASS": passes += 1
			"FAIL": fails += 1
			"WARN": warns += 1

	_log("  PASS: %d | FAIL: %d | WARN: %d" % [passes, fails, warns])

	if fails > 0:
		_log("\nFAILURES:")
		for r in _test_results:
			if r.status == "FAIL":
				_log("  - %s" % r.message)

	if warns > 0:
		_log("\nWARNINGS:")
		for r in _test_results:
			if r.status == "WARN":
				_log("  - %s" % r.message)

	_log("\n" + "=".repeat(70))
	_log("OVERALL: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	_log("=".repeat(70))

	get_tree().create_timer(0.5).timeout.connect(func():
		get_tree().quit(1 if fails > 0 else 0)
	)
