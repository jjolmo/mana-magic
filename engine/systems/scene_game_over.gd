class_name SceneGameOver
extends SceneEvent
## Game over scene - replaces oSce_gameOver from GMS2

var _s2_dialog_shown: bool = false

func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running or _dialog_paused:
		return

	if is_scene_step(0):
		lock_all_players()
		# GMS2: hideHud()
		if GameManager.hud:
			GameManager.hud.hide_hud()
		# Stop all mob animations (GMS2: toggleCreatureAnimations(false))
		for mob in get_tree().get_nodes_in_group("mobs"):
			if is_instance_valid(mob):
				mob.process_mode = Node.PROCESS_MODE_DISABLED
		# GMS2: go_fadeOut(30) + musicFadeOut(4000)
		if GameManager.map_transition:
			GameManager.map_transition.fade_out(30)
		MusicManager.stop(0.25)  # GMS2: musicFadeOut(4000) = 4s fade = 0.25 vol/sec
		add_step()

	elif is_scene_step(1, 30.0 / 60.0):
		MusicManager.play("bgm_iClosedMyEyes")
		add_step()

	elif is_scene_step(2):
		# GMS2: showDialog("general_gameOver", ANCHOR_TOP) + stepOnDialogFinished()
		if timer >= 100.0 / 60.0 and not _s2_dialog_shown:
			_s2_dialog_shown = true
			DialogManager.show_dialog("general_gameOver", {
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
		elif _s2_dialog_shown:
			step_on_dialog_finished()

	elif is_scene_step(3, 60.0 / 60.0):
		MusicManager.stop(0.8)  # GMS2: musicStop(1250) = 1.25s fade = 0.8 vol/sec
		add_step()

	elif is_scene_step(4, 200.0 / 60.0):
		# GMS2: game_restart() fully resets ALL state.
		# Godot's reload_current_scene() does NOT reset autoloads.
		# Must manually reset global state before reloading.
		GameManager.reset_all_state()
		get_tree().reload_current_scene()
