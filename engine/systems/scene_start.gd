class_name SceneStart
extends SceneEvent
## Starting scene event - replaces oSce_start from GMS2
## Full dialog flow: welcome → input choice → engine info → scene choice → farewell

var input_question: int = -1   # 0=Keyboard, 1=Gamepad
var scene_question: int = -1   # 0=Last bosses, 1=Free room
var input_option_text: String = ""
var scene_option_text: String = ""

func _ready() -> void:
	auto_start = true
	super._ready()
	DialogManager.dialog_question_answered.connect(_on_question_answered)

func _on_question_answered(dialog_id: String, answer: int) -> void:
	if dialog_id == "rom_start-evt_start1":
		input_question = answer
		input_option_text = "Keyboard" if answer == 0 else "Gamepad"
	elif dialog_id == "rom_start-evt_start4":
		scene_question = answer
		scene_option_text = "Last bosses" if answer == 0 else "Free room"

## Set to true to skip intro dialogs and go straight to free roam (rom_01)
var force_free_roam: bool = false
# One-shot flags for timer-based triggers
var _s0_music_done: bool = false
var _s1_dialog_shown: bool = false
var _s2_dialog_shown: bool = false
var _s3_dialog_shown: bool = false
var _s4_dialog_shown: bool = false
var _s5_dialog_shown: bool = false
var _s6_done: bool = false

func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running or _dialog_paused:
		return

	# Skip intro and go directly to free roam room
	if force_free_roam:
		if is_scene_step(0) and timer > 2.0 / 60.0:
			unlock_all_players()
			GameManager.change_map("rom_01")
			end_scene()
		return

	# Step 0: Setup - lock players, play music, wait, line up
	if is_scene_step(0):
		if timer >= 1.0 / 60.0 and not _s0_music_done:
			_s0_music_done = true
			MusicManager.play("bgm_distantThunder")
			lock_all_players()
		elif timer > 60.0 / 60.0:
			if GameManager.players.size() >= 3:
				look_at_direction(GameManager.players[0], Constants.Facing.DOWN)
				look_at_direction(GameManager.players[1], Constants.Facing.DOWN)
				look_at_direction(GameManager.players[2], Constants.Facing.DOWN)
			line_up(Constants.Facing.DOWN)
			add_step()

	# Step 1: Welcome + input choice
	# GMS2: evt_start1 = "Welcome to Mana Magic..." + "What kind of input?"
	elif is_scene_step(1):
		if timer >= 1.0 / 60.0 and not _s1_dialog_shown:
			_s1_dialog_shown = true
			DialogManager.show_dialog("rom_start-evt_start1", {
				"id": "rom_start-evt_start1",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
				"questions": ["Keyboard", "Gamepad"],
			})
		elif _s1_dialog_shown and not DialogManager.is_showing():
			add_step()

	# Step 2: Confirm input choice
	# GMS2: evt_start2 = "Perfect. I'll configure {option} as the controller"
	elif is_scene_step(2):
		if timer >= 1.0 / 60.0 and not _s2_dialog_shown:
			_s2_dialog_shown = true
			DialogManager.show_dialog("rom_start-evt_start2", {
				"id": "rom_start-evt_start2",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
				"replace_map": {"option": input_option_text},
			})
		elif _s2_dialog_shown and not DialogManager.is_showing():
			add_step()

	# Step 3: Engine info (3 dialog pages)
	# GMS2: evt_start3 = "This is a recreation of Secret of Mana..." etc.
	elif is_scene_step(3):
		if timer >= 1.0 / 60.0 and not _s3_dialog_shown:
			_s3_dialog_shown = true
			DialogManager.show_dialog("rom_start-evt_start3", {
				"id": "rom_start-evt_start3",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
		elif _s3_dialog_shown and not DialogManager.is_showing():
			add_step()

	# Step 4: Scene selection (4 dialog pages + question)
	# GMS2: evt_start4 = "This engine have two test scenes" ... "Please select:"
	elif is_scene_step(4):
		if timer >= 1.0 / 60.0 and not _s4_dialog_shown:
			_s4_dialog_shown = true
			DialogManager.show_dialog("rom_start-evt_start4", {
				"id": "rom_start-evt_start4",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
				"questions": ["Last bosses", "Free room"],
			})
		elif _s4_dialog_shown and not DialogManager.is_showing():
			add_step()

	# Step 5: Farewell (4 dialog pages)
	# GMS2: evt_start5 = "Perfect! I'll teleport you..." etc.
	elif is_scene_step(5):
		if timer >= 1.0 / 60.0 and not _s5_dialog_shown:
			_s5_dialog_shown = true
			DialogManager.show_dialog("rom_start-evt_start5", {
				"id": "rom_start-evt_start5",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
				"replace_map": {"option": scene_option_text},
			})
		elif _s5_dialog_shown and not DialogManager.is_showing():
			add_step()

	# Step 6: Transition to selected scene
	elif is_scene_step(6):
		if timer >= 1.0 / 60.0 and not _s6_done:
			_s6_done = true
			unlock_all_players()
			var map: String = "rom_lich" if scene_question == 0 else "rom_01"
			GameManager.change_map(map)
			end_scene()
