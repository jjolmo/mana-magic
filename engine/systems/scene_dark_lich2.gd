class_name SceneDarkLich2
extends SceneEvent
## Post-Dark Lich victory cutscene - replaces oSce_darkLich2 from GMS2
## Full 15-step cutscene: victory dialog, mana magic unlock, emotional sequence, exit teleport

var _fading: bool = false
var _camera_bound: bool = false
var _looked: bool = false
var _anim_tracker: Dictionary = {}

# Choreography timer — always ticks, even during dialog
# (base class timer pauses while DialogManager.is_showing())
var _choreo_timer: float = 0.0

func _ready() -> void:
	auto_start = true
	scene_persistence_id = "scene_dark_lich2"
	super._ready()

func _disable_teleport() -> void:
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return
	for child in scene_root.get_children():
		if child is MapChangeArea:
			child.enabled = false

func _enable_teleport() -> void:
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return
	for child in scene_root.get_children():
		if child is MapChangeArea:
			child.enabled = true

func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running:
		return

	# Choreography timer always ticks (GMS2: timer++ runs regardless of dialog)
	_choreo_timer += delta

	# Steps 12-13 run DURING dialog (they check dialogIndex for choreography).
	# All other steps pause during dialog to match GMS2 behavior.
	if _dialog_paused and (scene_step < 12 or scene_step > 13):
		return

	# Step 0: Initial setup - lock, disable teleport, hide HUD (GMS2: step 0)
	if is_scene_step(0, 60.0 / 60.0):
		_disable_teleport()
		lock_all_players()
		if GameManager.hud:
			GameManager.hud.hide_hud()
		add_step()

	# Step 1: Enable mana magic skills, show dialog 1 (GMS2: step 1)
	elif is_scene_step(1, 60.0 / 60.0):
		# GMS2: setPlayerInput(0) + skillEnable("manaMagicSupport") + skillEnable("manaMagicOffensive")
		Database.enable_skill("manaMagicSupport")
		Database.enable_skill("manaMagicOffensive")
		DialogManager.show_dialog("rom_darklich-evt_killedDarkLich1", {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		add_step()

	# Step 2: Wait for dialog 1, move companions to leader (GMS2: step 2)
	elif is_scene_step(2):
		if not DialogManager.is_showing():
			# Move players 1 and 2 to player 0's position
			if GameManager.players.size() > 1:
				go_move_to_position(GameManager.players[1],
					GameManager.players[0].global_position.x,
					GameManager.players[0].global_position.y)
			if GameManager.players.size() > 2:
				go_move_to_position(GameManager.players[2],
					GameManager.players[0].global_position.x,
					GameManager.players[0].global_position.y)
			add_step()

	# Step 3: Check all actors arrived, line up (GMS2: step 3 - checkActorsInPosition)
	elif is_scene_step(3, 30.0 / 60.0):
		# Line up formation: [0, 1, 2] (GMS2: placement = [0, 1, 2])
		go_line_up(Constants.Facing.UP, [0, 1, 2])
		add_step()

	# Step 4: Play bgm_aConclusion, show dialog 2 (GMS2: step 4)
	elif is_scene_step(4, 40.0 / 60.0):
		MusicManager.play("bgm_aConclusion")
		DialogManager.show_dialog("rom_darklich-evt_killedDarkLich2", {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		add_step()

	# Step 5: After dialog, Purim runs up (GMS2: step 5)
	elif is_scene_step(5, 60.0 / 60.0):
		go_run(GameManager.players[1], Constants.Facing.UP, 3)
		add_step()

	# Step 6: Wait for dialog to end, Purim fall animation (GMS2: step 6)
	elif is_scene_step(6):
		if not DialogManager.is_showing():
			_anim_tracker = go_animation(GameManager.players[1], 1, Constants.Facing.UP)  # ANIMATION_FALL_UP
			_camera_bound = false
			add_step()

	# Step 7: Wait 180 frames, bind camera, show dialog 3 (GMS2: step 7)
	elif is_scene_step(7):
		if not _camera_bound:
			var leader: Node = GameManager.get_party_leader()
			if leader:
				camera_bind(leader)
			# GMS2: rom_lich is 650x650 — override _auto_set_limits from camera_bind
			camera_set_limits(0, 0, 650, 650)
			_camera_bound = true
		if timer > 180.0 / 60.0:
			DialogManager.show_dialog("rom_darklich-evt_killedDarkLich3", {
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
			_fading = false
			add_step()

	# Step 8: After dialog, fade out, reposition, fade in (GMS2: step 8)
	elif is_scene_step(8):
		if not DialogManager.is_showing() and timer > 20.0 / 60.0 and not _fading:
			MusicManager.play("bgm_leaveTimeForLove", 500.0)
			go_fade_out(30)
			_fading = true
			timer = 0.0
		elif _fading and timer > 180.0 / 60.0:
			# Reposition all actors and set stand/dead state
			for player in GameManager.players:
				if is_instance_valid(player) and player is Actor:
					player.global_position = Vector2(342, 406)
					if player.has_method("change_state_stand_dead"):
						player.change_state_stand_dead()
			# Stop the fall animation on Purim
			stop_animation(GameManager.players[1])
			go_fade_in(30)
			add_step()

	# Step 9: Re-line up with different formation (GMS2: step 9 - positions [0, 2, 1])
	elif is_scene_step(9, 30.0 / 60.0):
		go_line_up(Constants.Facing.UP, [0, 2, 1])
		add_step()

	# Step 10: Earthquake effect (GMS2: step 10 - thunder + shake after 160 frames)
	elif is_scene_step(10, 160.0 / 60.0):
		# GMS2: soundPlay(snd_thunderbolt) + cameraShake()
		MusicManager.play_sfx("snd_thunderbolt")
		# Continuous 1px shake for rest of scene (duration=0 = infinite, stopped in step 15)
		# GMS2: cameraShake() with no args → mode=UPDOWN, but due to a copy-paste bug in
		# oCamera/Step_0.gml both modes actually shake horizontally (add tilt to X).
		# So the real behavior was always LEFT_RIGHT. Intensity 1px (GMS2 default is 2).
		camera_shake(Constants.ShakeMode.LEFT_RIGHT, 1.0)
		add_step()

	# Step 11: Play bgm_morningIsHere, show dialog 4 (GMS2: step 11)
	elif is_scene_step(11, 40.0 / 60.0):
		MusicManager.play("bgm_morningIsHere", 500.0)
		DialogManager.show_dialog("rom_darklich-evt_killedDarkLich4", {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		add_step()

	# Step 12: Popoie hit2 animation DURING dialog (GMS2: step 12)
	# GMS2: triggers at dialog.dialogIndex==1 (Popoie says "Uwaaa!") while dialog is showing.
	# This step runs during dialog (_dialog_paused bypass for steps 12-13).
	elif is_scene_step(12):
		if DialogManager.get_dialog_index() >= 1 and DialogManager.is_page_finished():
			# GMS2: Popoie enters state_HIT2 with isAnim=true (animation-only, no damage)
			# state_payload_partial(0, getDegreeFromMoving(FACING_RIGHT)) => push at 0 degrees
			# state_payload_partial(1, true) => isAnim mode
			if GameManager.players.size() > 2:
				var popoie := GameManager.players[2] as Actor
				if popoie and popoie.state_machine_node:
					# MUST unlock movement so state_machine._physics_process executes
					# Hit2 state (non-player-controlled actors are skipped when locked)
					popoie.unlock_movement_input()
					popoie.set_meta("hit2_push_dir", 0.0)
					popoie.set_meta("hit2_is_anim", true)
					popoie.state_machine_node.switch_state("Hit2")
			# Lock dialog so player can't advance while Hit2 plays
			DialogManager.dialog_lock()
			_looked = false
			_choreo_timer = 0.0
			add_step()

	# Step 13: Randi/Purim react, wait for Popoie recovery, unlock dialog (GMS2: step 13)
	# This step also runs during dialog (_dialog_paused bypass for steps 12-13).
	# Uses _choreo_timer (always ticks) instead of base timer (paused during dialog).
	elif is_scene_step(13):
		if _choreo_timer > 60.0 / 60.0 and not _looked:
			# GMS2: dialogLock() + go_look reactions
			go_look(GameManager.players[0], Constants.Facing.RIGHT)
			if GameManager.players.size() > 1:
				go_look(GameManager.players[1], Constants.Facing.LEFT)
			_looked = true
		elif _looked:
			# Wait for Popoie to finish hit2 animation (GMS2: state_name != "hit2")
			var popoie_done: bool = true
			if GameManager.players.size() > 2:
				var popoie := GameManager.players[2] as Actor
				if popoie and popoie.state_machine_node:
					popoie_done = popoie.state_machine_node.current_state_name != "Hit2"
			if popoie_done:
				# Re-lock Popoie for cutscene after Hit2 finishes
				if GameManager.players.size() > 2:
					GameManager.players[2].lock_movement_input()
					go_look(GameManager.players[2], Constants.Facing.DOWN)
				# GMS2: dialogUnlock() — resume dialog so player can continue reading
				DialogManager.dialog_unlock()
				add_step()

	# Step 14: All look forward again (GMS2: step 13 end)
	elif is_scene_step(14, 60.0 / 60.0):
		go_look(GameManager.players[0], Constants.Facing.UP)
		if GameManager.players.size() > 1:
			go_look(GameManager.players[1], Constants.Facing.UP)
		if GameManager.players.size() > 2:
			go_look(GameManager.players[2], Constants.Facing.UP)
		add_step()

	# Step 15: End scene, enable teleport (GMS2: step 14)
	elif is_scene_step(15, 30.0 / 60.0):
		# GMS2: camera shake continues until leaving the room (map change stops it)
		unlock_all_players()
		_enable_teleport()
		GameManager.set_scene_completed("scene_dark_lich2")
		end_scene()
		# GMS2: rom_lich is 650x650 — override end_scene's _auto_set_limits
		camera_set_limits(0, 0, 650, 650)
