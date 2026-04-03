class_name SceneManaBeast
extends SceneEvent
## Mana Beast pre-boss scene - replaces oSce_manaBeast from GMS2
## GMS2: 3 steps: line up, show 3 battle dialogs, wait, then spawn boss.

var _battle_dialogs_sent: bool = false
var _s0_camera_set: bool = false

# GMS2: timer2 always ticks (not paused by dialog, used for step 2 delay)
var _choreo_timer: float = 0.0

func _ready() -> void:
	auto_start = true
	super._ready()

func _resolve_dialog(key: String) -> String:
	## Resolve a dialog key from the database (GMS2: game.dialogs[?"key"])
	if Database.dialogs is Dictionary and Database.dialogs.has(key):
		var data: Variant = Database.dialogs[key]
		if data is String:
			return data
		elif data is Array and data.size() > 0:
			return str(data[0])
	return key

func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running or _dialog_paused:
		return

	# Choreo timer always ticks (GMS2: timer2++ runs every frame in runWorld)
	_choreo_timer += delta

	# Step 0: Line up party (GMS2: step 0, timer>60, go_lineUp(UP, [1, 0, 2]))
	if is_scene_step(0):
		if timer >= 1.0 / 60.0 and not _s0_camera_set:
			_s0_camera_set = true
			# GMS2: rom_manaBeast is exactly 427x240 (viewport-sized), objectId=null.
			# Camera is FIXED at room center — no scrolling, no following.
			camera_set_limits(0, 0, 427, 240)
			camera_set_coord(Vector2(214, 120))
		if timer >= 60.0 / 60.0:
			go_line_up(Constants.Facing.UP, [1, 0, 2])
			_battle_dialogs_sent = false
			add_step()

	# Step 1: Add 3 battle dialogs, wait for all to finish (GMS2: step 1)
	# GMS2: addBattleDialog(rom_manaBeast_start0/1/2, align=TOP), wait !isBattleDialogActive()
	elif is_scene_step(1, 20.0 / 60.0):
		if not _battle_dialogs_sent:
			GameManager.add_battle_dialog(
				_resolve_dialog("rom_manaBeast_start0"), BattleDialog.Align.TOP)
			GameManager.add_battle_dialog(
				_resolve_dialog("rom_manaBeast_start1"), BattleDialog.Align.TOP)
			GameManager.add_battle_dialog(
				_resolve_dialog("rom_manaBeast_start2"), BattleDialog.Align.TOP)
			_battle_dialogs_sent = true
			_choreo_timer = 0.0
		elif GameManager.battle_dialog == null or not GameManager.battle_dialog.active:
			# All battle dialogs finished — advance
			_choreo_timer = 0.0
			add_step()

	# Step 2: After 120 frames, enable skills, spawn boss, end scene (GMS2: step 2)
	# GMS2: timer2>120 → evadeDistanceActionEnabled=false, skillEnable, endAnimationScene, spawn
	elif is_scene_step(2):
		if _choreo_timer > 120.0 / 60.0:
			# GMS2: with(oActor) { evadeDistanceActionEnabled = false }
			# Prevents companion AI from evading the Mana Beast (it flies)
			for player in GameManager.players:
				if is_instance_valid(player) and player is Actor:
					(player as Actor).evade_distance_action_enabled = false

			# GMS2: skillEnable("manaMagicSupport") + skillEnable("manaMagicOffensive")
			Database.enable_skill("manaMagicSupport")
			Database.enable_skill("manaMagicOffensive")

			# Create Mana Beast (GMS2: instance_create_pre(0, 0, "lyr_objects2", oMob_manaBeast, 70))
			var boss_scene: PackedScene = preload("res://scenes/creatures/mana_beast.tscn")
			var boss: Node = boss_scene.instantiate()
			boss.global_position = Vector2(0, 0)
			get_parent().add_child(boss)

			# Play final battle music
			MusicManager.play("bgm_lastDecision")
			unlock_all_players()
			end_scene()
			# GMS2: rom_manaBeast is viewport-sized, objectId=null — camera is FIXED.
			# Override end_scene's camera_bind (which calls _auto_set_limits).
			camera_set_limits(0, 0, 427, 240)
			camera_set_coord(Vector2(214, 120))
