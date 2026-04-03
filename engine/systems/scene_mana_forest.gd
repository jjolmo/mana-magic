class_name SceneManaForest
extends SceneEvent
## Mana Forest Outside cutscene (rom_manaFortressOutside) - replaces oSce_manaForestOutside
## Emotional scene before final boss: the party prepares to face the Mana Beast.
## GMS2: 15 steps with dialog-index-driven choreography

var dialog_done: bool = false
var _go_affirmate: bool = false
var _move_actor: bool = false
var _dialog1_shown: bool = false  # One-shot guard for first dialog

# Choreography timer — always increments, even during dialog
# (base class timer pauses while DialogManager.is_showing())
var _choreo_timer: float = 0.0

# Track one-shot actions within dialog-index steps
var _step9_locked: bool = false
var _step10_walked: bool = false
var _s0_locked: bool = false
var _s5_walked: bool = false
var _s13_looked: bool = false

func _ready() -> void:
	auto_start = true
	scene_persistence_id = "scene_mana_forest"
	super._ready()
	DialogManager.dialog_finished.connect(_on_dialog_finished)


func _on_dialog_finished(_id: String) -> void:
	dialog_done = true


func _reset_choreo_timer() -> void:
	_choreo_timer = 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running:
		return

	# Choreography timer always ticks (GMS2: timer++ runs regardless of dialog)
	_choreo_timer += delta

	# Steps 8-13 run DURING dialog (they check dialogIndex for choreography).
	# All other steps pause during dialog to match GMS2 behavior.
	if _dialog_paused and (scene_step < 8 or scene_step > 13):
		return

	# --- Step 0: Lock players, face DOWN ---
	# GMS2: startAnimationScene(); go_look(oActor, FACING_DOWN)
	if is_scene_step(0):
		if timer >= 1.0 / 60.0 and not _s0_locked:
			_s0_locked = true
			lock_all_players()
			for p in GameManager.players:
				if is_instance_valid(p):
					go_look(p, Constants.Facing.DOWN)
			add_step()

	# --- Step 1: Line up party ---
	# GMS2: timer>20, go_lineUp(DOWN, [1, 0, 2])
	elif is_scene_step(1, 20.0 / 60.0):
		go_line_up(Constants.Facing.DOWN, [1, 0, 2])
		add_step()

	# --- Step 2: Weapon stand-ready on leader ---
	# GMS2: timer>20, anim_wpnStandReady(oActor) — sets stand frames for current facing
	elif is_scene_step(2, 20.0 / 60.0):
		if GameManager.players.size() > 0:
			var leader: Creature = GameManager.players[0] as Creature
			if is_instance_valid(leader):
				go_look(leader, leader.facing)
		add_step()

	# --- Step 3: Music + camera shake + red blend ---
	# GMS2: musicPlay(bgm_oneOfThemIsHope), cameraShake(RIGHT_LEFT), go_blendScreenOn(c_red, 0.4, 30)
	elif is_scene_step(3, 20.0 / 60.0):
		MusicManager.play("bgm_oneOfThemIsHope")
		camera_shake(Constants.ShakeMode.LEFT_RIGHT, 1.0)
		go_blend_screen_on(Color.RED, 0.4, 30)
		add_step()

	# --- Step 4: First dialog (after 90-frame dramatic pause) ---
	# GMS2: timer>90, showDialog("rom_darklich-evt_manaFortressOutside1", ANCHOR_TOP, true)
	# NOTE: Use >= guard + one-shot flag instead of fragile "timer == N" check.
	# If the step accumulator processes 2+ ticks in one frame (lag spike from camera_shake etc.),
	# "timer == 90" could be skipped entirely, causing the dialog to never show → permanent freeze.
	elif is_scene_step(4, 90.0 / 60.0):
		if dialog_done:
			dialog_done = false
			_dialog1_shown = false
			add_step()
		elif not _dialog1_shown:
			_dialog1_shown = true
			dialog_done = false
			DialogManager.show_dialog(
				"POPOIE:It's a Mana Beast!\nPURIM:Isn't it a Flammie?\nRANDI:I guess Flammies were once Mana Beasts...\nPOPOIE:Hurry, or the Mana Beast will ruin the world!", {
				"id": "rom_darklich-evt_manaFortressOutside1",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})

	# --- Step 5: Dialog 1 finished → companions walk UP 2 tiles ---
	# GMS2: !instance_exists(dialog), go_walk(players[1], UP, 2), go_walk(players[2], UP, 2)
	elif is_scene_step(5):
		if timer >= 1.0 / 60.0 and not _s5_walked:
			_s5_walked = true
			if GameManager.players.size() >= 3:
				go_walk(GameManager.players[1] as Creature, Constants.Facing.UP, 2)
				go_walk(GameManager.players[2] as Creature, Constants.Facing.UP, 2)
			add_step()

	# --- Step 6: After walk (50f), companions face DOWN ---
	# GMS2: timer>50, go_look(players[1/2], DOWN)
	elif is_scene_step(6, 50.0 / 60.0):
		if GameManager.players.size() >= 3:
			go_look(GameManager.players[1] as Creature, Constants.Facing.DOWN)
			go_look(GameManager.players[2] as Creature, Constants.Facing.DOWN)
		add_step()

	# --- Step 7: Show long emotional dialog ---
	# GMS2: timer>10, showDialog("rom_darklich-evt_manaFortressOutside2", ...)
	# NOTE: Use is_scene_step min_timer instead of fragile "timer == N" check.
	# add_step() fires immediately so this only runs once.
	elif is_scene_step(7, 10.0 / 60.0):
		dialog_done = false
		_go_affirmate = false
		_move_actor = false
		_step9_locked = false
		_step10_walked = false
		DialogManager.show_dialog(
			"POPOIE:Come on! Do it!\nRANDI:...I can't...\nI won't hurt a Mana Beast! I can't!\nThey are only trying to restore Mana!\nAnd... ...POPOIE!\nIf you use up all your Mana power, you'll dissapear!\nPURIM:Oh NO!\nRANDI:Right...I can't go through with this...\nPOPOIE:...\nWhaddaya mean? I'm NOT gonna kick the bucket!\nMy world is separate from this one. It just means I won't...see you again.\nIt's ok, if we don't stop the Mana Beast, your world is finished, right?\nEverything will perish.\nTrees...animals...PEOPLE!\nThat must not happen!\nYOU have the mana Sword\nYOU must save this world...\nYou have no choice!\nYou made a vow to your mother, the Mana Tree, right? I'll be okay.\nRANDI:All right...\n...you're sure?\nPOPOIE:OF COURSE!\nLater, PURIM!", {
			"id": "rom_darklich-evt_manaFortressOutside2",
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		add_step()

	# --- Step 8: dialogIndex==1 → leader looks UP ---
	# GMS2: if (dialog.dialogIndex == 1) { go_look(players[0], UP) }
	elif is_scene_step(8):
		if DialogManager.get_dialog_index() >= 1:
			if GameManager.players.size() > 0:
				go_look(GameManager.players[0] as Creature, Constants.Facing.UP)
			_reset_choreo_timer()
			add_step()

	# --- Step 9: dialogIndex==4 → Purim RIGHT (lock, 20f delay), Popoie UP, unlock ---
	# GMS2: dialogLock(), go_look(players[1], RIGHT), timer>20: go_look(players[2], UP), dialogUnlock()
	elif is_scene_step(9):
		if DialogManager.get_dialog_index() >= 4:
			if not _step9_locked:
				_step9_locked = true
				DialogManager.dialog_lock()
				_reset_choreo_timer()
				if GameManager.players.size() >= 2:
					go_look(GameManager.players[1] as Creature, Constants.Facing.RIGHT)
			elif _choreo_timer >= 20.0 / 60.0:
				if GameManager.players.size() >= 3:
					go_look(GameManager.players[2] as Creature, Constants.Facing.UP)
				DialogManager.dialog_unlock()
				_reset_choreo_timer()
				add_step()

	# --- Step 10: dialogIndex==4 AND page finished → leader walks UP 1 tile ---
	# GMS2: dialog.dialogIndex==4 && dialog.drawTextResult[1]==true → go_walk(players[0], UP, 1)
	elif is_scene_step(10):
		if not _step10_walked and DialogManager.get_dialog_index() >= 4 and DialogManager.is_page_finished():
			_step10_walked = true
			if GameManager.players.size() > 0:
				go_walk(GameManager.players[0] as Creature, Constants.Facing.UP, 1)
			_reset_choreo_timer()
			add_step()
		# If dialog already advanced past index 4, just proceed
		elif DialogManager.get_dialog_index() > 4:
			add_step()

	# --- Step 11: dialogIndex==5 → Popoie looks DOWN ---
	# GMS2: dialog.dialogIndex==5 → go_look(players[2], DOWN)
	elif is_scene_step(11):
		if DialogManager.get_dialog_index() >= 5:
			if GameManager.players.size() >= 3:
				go_look(GameManager.players[2] as Creature, Constants.Facing.DOWN)
			_reset_choreo_timer()
			add_step()

	# --- Step 12: dialogIndex==9 → Purim looks DOWN ---
	# GMS2: dialog.dialogIndex==9 → go_look(players[1], DOWN), goAfirmate=false
	elif is_scene_step(12):
		if DialogManager.get_dialog_index() >= 9:
			if GameManager.players.size() >= 2:
				go_look(GameManager.players[1] as Creature, Constants.Facing.DOWN)
			_go_affirmate = false
			_reset_choreo_timer()
			add_step()

	# --- Step 13: dialogIndex==12 → Popoie AFFIRMATE + timed reactions ---
	# GMS2: go_animation(players[2], AFFIRMATE, DOWN)
	#        timer==20: players[1] look RIGHT
	#        timer==40: players[2] look LEFT, dialogUnlock()
	elif is_scene_step(13):
		if DialogManager.get_dialog_index() >= 12:
			if not _go_affirmate:
				_go_affirmate = true
				DialogManager.dialog_lock()
				_reset_choreo_timer()
				if GameManager.players.size() >= 3:
					go_animation(GameManager.players[2] as Creature, 2, Constants.Facing.DOWN)
			else:
				# Keep animation ticking
				if GameManager.players.size() >= 3:
					go_animation(GameManager.players[2] as Creature, 2, Constants.Facing.DOWN)
				if _choreo_timer >= 20.0 / 60.0 and not _s13_looked:
					_s13_looked = true
					if GameManager.players.size() >= 2:
						go_look(GameManager.players[1] as Creature, Constants.Facing.RIGHT)
				elif _choreo_timer >= 40.0 / 60.0:
					if GameManager.players.size() >= 3:
						go_look(GameManager.players[2] as Creature, Constants.Facing.LEFT)
						stop_animation(GameManager.players[2] as Creature)
					DialogManager.dialog_unlock()
					_reset_choreo_timer()
					add_step()

	# --- Step 14: Dialog done → cameraStop, blend off, walk all UP 10 tiles, map change ---
	# GMS2: !instance_exists(dialog), cameraStop(), go_walk all UP 10, bgm_meridianDance,
	#        go_blendScreenOff(30), after 90 frames: mapChange(rom_manaBeast)
	elif is_scene_step(14):
		if dialog_done:
			if not _move_actor:
				_move_actor = true
				camera_stop()
				go_blend_screen_off(30)
				MusicManager.play("bgm_meridianDance")
				for p in GameManager.players:
					if is_instance_valid(p) and p is Creature:
						go_look(p as Creature, Constants.Facing.UP)
						go_walk(p as Creature, Constants.Facing.UP, 10)
				_reset_choreo_timer()

			if _move_actor and _choreo_timer > 90.0 / 60.0:
				unlock_all_players()
				GameManager.change_map("rom_manaBeast")
				end_scene()
