class_name SceneRabite2
extends SceneEvent
## Rabite quest field cutscene (rom_02) - replaces oSce_rabite2 from GMS2
## GMS2 flow: black screen → camera snap to rabite → spawn NPC → fade in →
## actors face up → camera pan back to player → dialog → destroy NPC → end

var rabite_npc: Node2D = null
var _step3_dialog_shown: bool = false

func _ready() -> void:
	auto_start = true
	scene_persistence_id = "oSce_rabite2"
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running or DialogManager.is_showing():
		return

	# Step 0: Instant black screen + camera snap (GMS2: go_blendScreenOn(c_black, 1) + cameraSetCoord(429, 470))
	if is_scene_step(0):
		go_blend_screen_on(Color.BLACK, 1.0)
		camera_set_coord(Vector2(429, 470))
		add_step()

	# Step 1: After 60f, spawn rabite NPC, lock players, fade from black, face UP
	# GMS2: instance_create(431, 619, oMob_rabiteNPC2), startAnimationScene(),
	#        go_blendScreenOff(60), actors face UP
	elif is_scene_step(1, 60.0 / 60.0):
		_spawn_rabite_npc(Vector2(431, 619))
		lock_all_players()
		go_blend_screen_off(60)
		for p in GameManager.players:
			if is_instance_valid(p):
				go_look(p, Constants.Facing.UP)
		add_step()

	# Step 2: After 60f, camera motion back to party leader
	# GMS2: cameraMoveMotion(players[0].x, players[0].y)
	elif is_scene_step(2, 60.0 / 60.0):
		var leader: Node2D = GameManager.get_party_leader() as Node2D
		if leader and is_instance_valid(leader):
			camera_move_motion(leader.global_position)
		add_step()

	# Step 3: After 60f, show dialog + destroy NPC, wait for dialog finish
	# GMS2: show dialog_2, stepOnDialogFinished(), destroy oMob_rabiteNPC2
	# Note: GMS2 dialog_1 ("There it is!") is dead code (never reached due to duplicate step)
	elif is_scene_step(3, 60.0 / 60.0):
		if timer >= 60.0 / 60.0 and not _step3_dialog_shown:
			_step3_dialog_shown = true
			# GMS2: showDialog("rom_02-evt_rabiteQuestField_2") — looked up from dialogs.json
			DialogManager.show_dialog("rom_02-evt_rabiteQuestField_2", {
				"id": "rom_02-evt_rabiteQuestField_2",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
			_destroy_rabite_npc()
		elif _step3_dialog_shown:
			step_on_dialog_finished()

	# Step 4: After 15f, end animation scene + self-destruct
	# GMS2: endAnimationScene(), instance_destroy()
	elif is_scene_step(4, 15.0 / 60.0):
		end_scene()
		queue_free()

func _spawn_rabite_npc(pos: Vector2) -> void:
	## Spawn a temporary rabite NPC for the cutscene (GMS2: oMob_rabiteNPC2)
	var mob_scene: PackedScene = load("res://scenes/creatures/mob.tscn")
	if not mob_scene:
		return
	rabite_npc = mob_scene.instantiate()
	rabite_npc.name = "mob_rabite_npc"  # _npc suffix makes it passive in mob.gd
	rabite_npc.position = pos
	get_tree().current_scene.add_child(rabite_npc)

func _destroy_rabite_npc() -> void:
	if is_instance_valid(rabite_npc):
		rabite_npc.queue_free()
		rabite_npc = null
