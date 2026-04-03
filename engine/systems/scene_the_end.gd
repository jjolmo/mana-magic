class_name SceneTheEnd
extends SceneEvent
## Ending scene - replaces oSce_theEnd from GMS2

var _s1_dialog_shown: bool = false

func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running or _dialog_paused:
		return

	if is_scene_step(0):
		for player in GameManager.players:
			if is_instance_valid(player):
				player.visible = false
		MusicManager.play("bgm_end")
		add_step()

	elif is_scene_step(1, 60.0 / 60.0):
		# GMS2: showDialog("rom_end-evt_end", ANCHOR_TOP, true, false, true)
		if timer >= 60.0 / 60.0 and not _s1_dialog_shown:
			_s1_dialog_shown = true
			DialogManager.show_dialog("rom_end-evt_end", {
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
				"auto_dialog": true,
			})
		elif _s1_dialog_shown:
			step_on_dialog_finished()

	elif is_scene_step(2, 60.0 / 60.0):
		# Fade in the end screen
		modulate.a = move_toward(modulate.a, 1.0, 0.02)
		if modulate.a >= 1.0:
			add_step()

	elif is_scene_step(3, 60.0 / 60.0):
		# GMS2: playerPressedStartOrAttack() + musicStop(1250) + go_blendScreenOn(c_black, 1, 40)
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("menu"):
			MusicManager.stop(0.8)  # GMS2: musicStop(1250) = 1.25s fade = 0.8 vol/sec
			if GameManager.map_transition:
				GameManager.map_transition.blend_screen_on(Color.BLACK, 1.0, 40)
			add_step()

	elif is_scene_step(4, 200.0 / 60.0):
		get_tree().reload_current_scene()
