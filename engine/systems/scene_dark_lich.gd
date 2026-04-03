class_name SceneDarkLich1
extends SceneEvent
## Dark Lich pre-boss cutscene - replaces oSce_darkLich1 from GMS2
## Full 32-step cutscene: Thanatos confrontation, Dyluck scene, boss spawn

var i_thanatos: Creature = null  # GMS2: iThanatos NPC reference
var i_dyluck: Creature = null    # GMS2: iDyluck NPC reference
var dark_lich: Node = null       # Spawned boss reference
var counted_steps: int = 0       # GMS2: countedSteps for Thanatos rising
var timer2: float = 0.0          # GMS2: secondary timer for step 6
var _anim_tracker: Dictionary = {}  # go_animation return tracker
# One-shot flags for timer-based triggers
var _s0_lock_done: bool = false
var _s7_dialog_shown: bool = false
var _s8_run_done: bool = false
var _s9_walk_done: bool = false
var _s11_flash_done: bool = false
var _s11_look_done: bool = false

func _ready() -> void:
	auto_start = true
	scene_persistence_id = "scene_dark_lich1"
	super._ready()

func _find_npcs() -> void:
	if i_thanatos and i_dyluck:
		return
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return
	for child in scene_root.get_children():
		if child is NPC:
			if (child as NPC).npc_name == "Thanatos":
				i_thanatos = child
				# Disable collision so Thanatos doesn't block player movement during cutscene
				i_thanatos.collision_layer = 0
				i_thanatos.collision_mask = 0
			elif (child as NPC).npc_name == "Dyluck":
				i_dyluck = child
				# Disable collision so Dyluck doesn't block player movement during cutscene
				i_dyluck.collision_layer = 0
				i_dyluck.collision_mask = 0

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

func _unhandled_input(event: InputEvent) -> void:
	if not scene_running:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_skip_cutscene()
		get_viewport().set_input_as_handled()

func _skip_cutscene() -> void:
	## Skip the entire cutscene — clean up and jump straight to boss fight.
	# 1. Force-close any active dialog and clear the queue
	DialogManager._dialog_queue.clear()
	if DialogManager.is_showing():
		DialogManager.hide_dialog()
	# Clear any remaining queued dialogs that hide_dialog might have triggered
	DialogManager._dialog_queue.clear()

	# 2. Ensure screen is not faded out
	if GameManager.map_transition and GameManager.map_transition.is_fading():
		GameManager.map_transition.animating = false
	if GameManager.map_transition:
		GameManager.map_transition.fade_in(1)  # Instant fade in

	# 3. Destroy NPCs
	if is_instance_valid(i_thanatos):
		i_thanatos.queue_free()
		i_thanatos = null
	if is_instance_valid(i_dyluck):
		i_dyluck.queue_free()
		i_dyluck = null

	# 4. Reposition players to battle positions
	for player in GameManager.players:
		if is_instance_valid(player):
			player.global_position = Vector2(327, 407)
			player.modulate.a = 1.0
	go_look(GameManager.players[0], Constants.Facing.UP)
	if GameManager.players.size() > 1:
		go_look(GameManager.players[1], Constants.Facing.UP)
	if GameManager.players.size() > 2:
		go_look(GameManager.players[2], Constants.Facing.UP)

	# 5. Spawn Dark Lich if not already spawned
	if not is_instance_valid(dark_lich):
		var boss_scene: PackedScene = preload("res://scenes/creatures/dark_lich.tscn")
		dark_lich = boss_scene.instantiate()
		dark_lich.global_position = Vector2(334, 287)
		get_parent().add_child(dark_lich)

	# 6. Unpause boss
	if is_instance_valid(dark_lich) and "paused" in dark_lich:
		dark_lich.paused = false

	# 7. Music + teleport
	MusicManager.play_splitted("bgm_darkLichIntro", "bgm_darkLichLoop")
	_enable_teleport()

	# 8. End scene (handles unlock, camera_set, camera_bind, show_hud)
	end_scene()
	# GMS2: rom_lich is 650x650 — override end_scene's _auto_set_limits
	camera_set_limits(0, 0, 650, 650)

func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running or _dialog_paused:
		return

	_find_npcs()

	# Step 0: Initial setup (GMS2: lock input, wait 60 frames, start scene, play music)
	if is_scene_step(0):
		if timer >= 1.0 / 60.0 and not _s0_lock_done:
			_s0_lock_done = true
			lock_all_players()
		if timer > 60.0 / 60.0:
			MusicManager._play_song("bgm_ceremony")
			_disable_teleport()
			add_step()

	# Step 1: All players look up, player 1 runs up (GMS2: timer > 90)
	elif is_scene_step(1, 30.0 / 60.0):
		go_look(GameManager.players[0], Constants.Facing.UP)
		go_look(GameManager.players[1], Constants.Facing.UP)
		if GameManager.players.size() > 2:
			go_look(GameManager.players[2], Constants.Facing.UP)
		go_run(GameManager.players[1], Constants.Facing.UP, 2)
		add_step()

	# Step 2: Camera unbind, players 0 and 2 run up, camera pans up
	elif is_scene_step(2, 30.0 / 60.0):
		camera_unbind()
		go_run(GameManager.players[0], Constants.Facing.UP, 2)
		if GameManager.players.size() > 2:
			go_run(GameManager.players[2], Constants.Facing.UP, 2)
		camera_move(Constants.Facing.UP, 70)
		add_step()

	# Step 3: Line up formation (GMS2: lines = [0, 2, 1])
	elif is_scene_step(3, 50.0 / 60.0):
		go_line_up(Constants.Facing.UP, [0, 2, 1])
		add_step()

	# Step 4: Show first dialog (GMS2: timer > 200 from scene start)
	elif is_scene_step(4, 60.0 / 60.0):
		DialogManager.show_dialog("rom_darklich-evt_darklich1", {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		add_step()

	# Step 5: Wait for dialog 1 to finish
	elif is_scene_step(5):
		if not DialogManager.is_showing():
			counted_steps = 0
			timer2 = 0.0
			add_step()

	# Step 6: Thanatos rising animation (GMS2: rises 5px every 30 frames, 3 times, then looks right)
	elif is_scene_step(6):
		if is_instance_valid(i_thanatos):
			go_look(i_thanatos, Constants.Facing.UP)
			timer2 += delta
			if timer2 > 30.0 / 60.0 and counted_steps < 3:
				timer2 = 0.0
				counted_steps += 1
				i_thanatos.global_position.y -= 5
			elif timer2 > 30.0 / 60.0 and counted_steps >= 3:
				go_look(i_thanatos, Constants.Facing.RIGHT)
			if timer2 > 200.0 / 60.0:
				add_step()
		else:
			add_step()

	# Step 7: Show dialog 2
	elif is_scene_step(7):
		if timer >= 1.0 / 60.0 and not _s7_dialog_shown:
			_s7_dialog_shown = true
			DialogManager.show_dialog("rom_darklich-evt_darklich2", {
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
		elif not DialogManager.is_showing():
			add_step()

	# Step 8: Player 1 (Purim) runs up 2.5 tiles
	elif is_scene_step(8):
		if timer >= 1.0 / 60.0 and not _s8_run_done:
			_s8_run_done = true
			go_run(GameManager.players[1], Constants.Facing.UP, 2.5)
		# Wait for movement to finish
		if timer > 10.0 / 60.0 and MoveToPosition.go(GameManager.players[1],
				GameManager.players[1].global_position.x, GameManager.players[1].global_position.y,
				true, true, false):
			add_step()

	# Step 9: Dyluck walks right, Purim runs right to Dyluck (GMS2: steps 10-11)
	elif is_scene_step(9):
		if timer >= 1.0 / 60.0 and not _s9_walk_done:
			_s9_walk_done = true
			if is_instance_valid(i_dyluck):
				go_walk(i_dyluck, Constants.Facing.RIGHT, 2)
			go_run(GameManager.players[1], Constants.Facing.RIGHT, 1.2)
		elif timer > 20.0 / 60.0:
			if is_instance_valid(i_dyluck):
				go_look(i_dyluck, Constants.Facing.DOWN)
			go_look(GameManager.players[1], Constants.Facing.LEFT)
			add_step()

	# Step 10: Purim attacks left (slaps Dyluck) (GMS2: step 12)
	elif is_scene_step(10, 20.0 / 60.0):
		go_attack(GameManager.players[1], Constants.Facing.LEFT)
		add_step()

	# Step 11: Screen flash (GMS2: step 13)
	elif is_scene_step(11):
		if timer >= 1.0 / 60.0 and not _s11_flash_done:
			_s11_flash_done = true
			go_flash(3)
		# Reset Purim to idle after attack animation has played
		if timer >= 15.0 / 60.0 and not _s11_look_done:
			_s11_look_done = true
			go_look(GameManager.players[1], Constants.Facing.LEFT)
		elif timer > 30.0 / 60.0:
			DialogManager.show_dialog("rom_darklich-evt_darklich3", {
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
			add_step()

	# Step 12: Wait for dialog 3
	elif is_scene_step(12):
		if not DialogManager.is_showing():
			add_step()

	# Step 13: Thanatos disappears (GMS2: step 16)
	elif is_scene_step(13, 30.0 / 60.0):
		if is_instance_valid(i_thanatos):
			i_thanatos.visible = false
		add_step()

	# Step 14: Music change to bgm_fondMemories, Purim looks right, dialog 4a (GMS2: step 17)
	elif is_scene_step(14, 60.0 / 60.0):
		MusicManager.play("bgm_fondMemories")
		go_look(GameManager.players[1], Constants.Facing.RIGHT)
		DialogManager.show_dialog("rom_darklich-evt_darklich4a", {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		add_step()

	# Step 15: Dyluck looks left, wait for 4a, then show 4c + bgm_danger (GMS2: step 18 dialogIndex==2-3)
	# Skips 4b ("Guwa ha ha!" alone) — 4c already starts with "Guwa ha ha!" from Thanatos.
	# GMS2: timer==30 fires DURING dialog (timer runs while dialog is open).
	# In Godot the scene timer is frozen during dialogs, so we trigger
	# Dyluck's look-left as soon as dialog 4a closes.
	elif is_scene_step(15):
		if not DialogManager.is_showing():
			if is_instance_valid(i_dyluck):
				go_look(i_dyluck, Constants.Facing.LEFT)
			MusicManager.play("bgm_danger")
			DialogManager.show_dialog("rom_darklich-evt_darklich4c", {
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
			add_step()

	# Step 16: Wait for 4c, then Purim walks backward (GMS2: step 18 dialogIndex==3 drawTextResult)
	elif is_scene_step(16):
		if not DialogManager.is_showing():
			# Restore walk animations (spr_*_ini/end may still be attack frames from step 10)
			var p1: Creature = GameManager.players[1]
			if p1 is Actor:
				var a1 := p1 as Actor
				p1.set_default_facing_animations(
					a1.spr_walk_up_ini, a1.spr_walk_right_ini,
					a1.spr_walk_down_ini, a1.spr_walk_left_ini,
					a1.spr_walk_up_end, a1.spr_walk_right_end,
					a1.spr_walk_down_end, a1.spr_walk_left_end
				)
			# Purim steps backward (away from Dyluck): moves LEFT, faces RIGHT
			go_walk(GameManager.players[1], Constants.Facing.LEFT, 1.5, true)
			if is_instance_valid(i_dyluck):
				go_look(i_dyluck, Constants.Facing.LEFT)
			add_step()

	# Step 17: Wait for backward walk to finish, then play negate (GMS2: step 19-20)
	# GMS2 step 19: if (!instance_exists(animator)) { go_animation(NEGATE); step++ }
	# GMS2 step 20: if (!instance_exists(animator)) { step+=2 }
	elif is_scene_step(17):
		# Phase 1: wait for backward walk to complete
		if MoveToPosition.is_active(GameManager.players[1]):
			return
		# Phase 2: play negate, wait for it to finish
		_anim_tracker = go_animation(GameManager.players[1], 0, Constants.Facing.RIGHT)
		if _anim_tracker.get("finished", false):
			add_step()

	# Step 18: Wait, then Purim resets to stand, Randi/Popoie walk up (GMS2: step 22)
	elif is_scene_step(18, 100.0 / 60.0):
		# Reset Purim to stand animations
		stop_animation(GameManager.players[1])
		var p1: Creature = GameManager.players[1]
		if p1 is Actor:
			var a1 := p1 as Actor
			p1.set_default_facing_animations(
				a1.spr_walk_up_ini, a1.spr_walk_right_ini,
				a1.spr_walk_down_ini, a1.spr_walk_left_ini,
				a1.spr_walk_up_end, a1.spr_walk_right_end,
				a1.spr_walk_down_end, a1.spr_walk_left_end
			)
			p1.set_facing_frame(a1.spr_stand_up, a1.spr_stand_right,
				a1.spr_stand_down, a1.spr_stand_left)
		go_walk(GameManager.players[0], Constants.Facing.UP, 3.8)
		if GameManager.players.size() > 2:
			go_walk(GameManager.players[2], Constants.Facing.UP, 0.5)
		add_step()

	# Step 19: Wait for Randi's UP walk to finish, then Randi walks right (GMS2: step 23)
	# GMS2: if (!instance_exists(animationRandi)) { go_walk(RIGHT, 2.3); step++ }
	elif is_scene_step(19):
		if GameManager.players.size() > 2:
			go_look(GameManager.players[2], Constants.Facing.RIGHT)
		if not MoveToPosition.is_active(GameManager.players[0]):
			go_walk(GameManager.players[0], Constants.Facing.RIGHT, 2.3)
			add_step()

	# Step 20: Show "Liar!" dialog (GMS2: dialog.pause=false at step 23 → dialog advances)
	elif is_scene_step(20, 30.0 / 60.0):
		DialogManager.show_dialog("rom_darklich-evt_darklich4d", {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		add_step()

	# Step 21: Wait for "Liar!" dialog to finish
	elif is_scene_step(21):
		if not DialogManager.is_showing():
			add_step()

	# Step 22: Dialog 6 (GMS2: step 24)
	elif is_scene_step(22, 60.0 / 60.0):
		MusicManager.play("bgm_fondMemories")
		DialogManager.show_dialog("rom_darklich-evt_darklich6", {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		add_step()

	# Step 23: Wait for dialog 6, then dialog 7
	elif is_scene_step(23):
		if not DialogManager.is_showing():
			DialogManager.show_dialog("rom_darklich-evt_darklich7", {
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
			add_step()

	# Step 24: Wait for dialog 7, then dialog 8
	elif is_scene_step(24):
		if not DialogManager.is_showing():
			DialogManager.show_dialog("rom_darklich-evt_darklich8", {
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
			add_step()

	# Step 25: Wait for dialog 8, then dialog 9
	elif is_scene_step(25):
		if not DialogManager.is_showing():
			DialogManager.show_dialog("rom_darklich-evt_darklich9", {
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
			add_step()

	# Step 26: Wait for dialog 9, then fade out (GMS2: step 28)
	elif is_scene_step(26):
		if not DialogManager.is_showing():
			if timer > 30.0 / 60.0:
				MusicManager.play("bgm_theCurse")
				go_fade_out(60)
				add_step()

	# Step 27: Wait for fade-out to COMPLETE, then reposition while screen is black
	# GMS2: step 29 — reposition/cleanup happens after full fadeOut
	elif is_scene_step(27):
		if GameManager.map_transition and not GameManager.map_transition.is_fading():
			# Screen is now fully black — safe to reposition off-screen
			for player in GameManager.players:
				if is_instance_valid(player):
					player.global_position = Vector2(327, 407)
			go_look(GameManager.players[0], Constants.Facing.UP)
			if GameManager.players.size() > 1:
				go_look(GameManager.players[1], Constants.Facing.UP)
			if GameManager.players.size() > 2:
				go_look(GameManager.players[2], Constants.Facing.UP)
			# Destroy NPCs
			if is_instance_valid(i_dyluck):
				i_dyluck.queue_free()
				i_dyluck = null
			if is_instance_valid(i_thanatos):
				i_thanatos.queue_free()
				i_thanatos = null
			# Spawn Dark Lich boss (paused)
			var boss_scene: PackedScene = preload("res://scenes/creatures/dark_lich.tscn")
			dark_lich = boss_scene.instantiate()
			dark_lich.global_position = Vector2(334, 287)
			if dark_lich.has_method("set") and "paused" in dark_lich:
				dark_lich.paused = true
			get_parent().add_child(dark_lich)
			add_step()

	# Step 28: Brief pause at full black, then start fade in (GMS2: ~30-frame black hold)
	elif is_scene_step(28, 30.0 / 60.0):
		go_fade_in(30)
		add_step()

	# Step 29: Show dialog 10 (GMS2: step 30)
	elif is_scene_step(29, 60.0 / 60.0):
		DialogManager.show_dialog("rom_darklich-evt_darklich10", {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		add_step()

	# Step 30: Wait for dialog 10, then start battle (GMS2: step 31)
	elif is_scene_step(30):
		if not DialogManager.is_showing():
			# Unpause Dark Lich
			if is_instance_valid(dark_lich) and "paused" in dark_lich:
				dark_lich.paused = false
			MusicManager.play_splitted("bgm_darkLichIntro", "bgm_darkLichLoop")
			# end_scene() handles unlock, camera_set, camera_bind, show_hud
			end_scene()
			# GMS2: rom_lich is 650x650 — override end_scene's _auto_set_limits
			camera_set_limits(0, 0, 650, 650)
