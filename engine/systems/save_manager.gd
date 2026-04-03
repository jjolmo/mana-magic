extends Node
## Save/Load system - serializes game state to JSON files

const SAVE_DIR: String = "user://saves/"
const MAX_SLOTS: int = 3


static func save_game(slot: int = 0) -> bool:
	var data: Dictionary = _serialize_game_state()
	if data.is_empty():
		return false

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path: String = SAVE_DIR + "save_slot_%d.json" % slot
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_warning("SaveManager: Could not open %s for writing" % path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


static func load_game(slot: int = 0) -> bool:
	var path: String = SAVE_DIR + "save_slot_%d.json" % slot
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("SaveManager: Save file not found: %s" % path)
		return false

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("SaveManager: Failed to parse save file")
		file.close()
		return false
	file.close()

	var data: Dictionary = json.data
	if data.is_empty():
		return false

	_deserialize_game_state(data)
	return true


static func has_save(slot: int = 0) -> bool:
	var path: String = SAVE_DIR + "save_slot_%d.json" % slot
	return FileAccess.file_exists(path)


static func get_save_info(slot: int = 0) -> Dictionary:
	## Returns basic info for a save slot without loading it
	var path: String = SAVE_DIR + "save_slot_%d.json" % slot
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()

	var data: Dictionary = json.data
	return {
		"room": data.get("current_room", "???"),
		"money": data.get("party_money", 0),
		"players": data.get("total_players", 0),
		"leader_name": _get_leader_name_from_data(data),
		"leader_level": _get_leader_level_from_data(data),
		"play_time": data.get("play_time", 0.0),
	}


static func _serialize_game_state() -> Dictionary:
	var data: Dictionary = {}

	# Party info
	data["party_money"] = GameManager.party_money
	data["party_name"] = GameManager.party_name
	data["total_players"] = GameManager.total_players
	data["current_room"] = GameManager.current_room
	data["previous_room"] = GameManager.previous_room
	data["play_time"] = GameManager.play_time

	# Inventory
	data["inventory_items"] = GameManager.inventory_items.duplicate()
	data["inventory_equipment"] = GameManager.inventory_equipment.duplicate()

	# Event persistence (GMS2: game.scenesLoaded)
	data["scenes_completed"] = GameManager.scenes_completed.duplicate()
	data["executed_dialogs"] = GameManager.executed_dialogs.duplicate()

	# Players
	var players_data: Array = []
	for i in range(GameManager.total_players):
		var player: Node = GameManager.get_player(i)
		if is_instance_valid(player) and player is Actor:
			players_data.append(_serialize_actor(player as Actor))
	data["players"] = players_data

	return data


static func _serialize_actor(actor: Actor) -> Dictionary:
	var d: Dictionary = {}

	# Identity
	d["character_id"] = actor.character_id
	d["character_name"] = actor.character_name

	# Position
	d["position_x"] = actor.global_position.x
	d["position_y"] = actor.global_position.y

	# Attributes
	d["level"] = actor.attribute.level
	d["hp"] = actor.attribute.hp
	d["mp"] = actor.attribute.mp
	d["maxHP"] = actor.attribute.maxHP
	d["maxMP"] = actor.attribute.maxMP
	d["strength"] = actor.attribute.strength
	d["constitution"] = actor.attribute.constitution
	d["agility"] = actor.attribute.agility
	d["intelligence"] = actor.attribute.intelligence
	d["wisdom"] = actor.attribute.wisdom
	d["luck"] = actor.attribute.luck
	d["experience"] = actor.attribute.get("experience", 0)

	# Equipment
	d["equipped_weapon_id"] = actor.equipped_weapon_id
	d["equipped_head"] = actor.equipped_head
	d["equipped_body"] = actor.equipped_body
	d["equipped_accessory"] = actor.equipped_accessory

	# Weapon levels
	d["equipment_levels"] = actor.equipment_levels.duplicate()
	d["equipment_current_level"] = actor.equipment_current_level.duplicate()

	# Magic levels
	d["deity_levels"] = actor.deity_levels.duplicate()

	# AI strategy
	d["strategy_attack_guard"] = actor.strategy_attack_guard
	d["strategy_approach_keep_away"] = actor.strategy_approach_keep_away

	# State
	d["is_dead"] = actor.is_dead

	return d


static func _deserialize_game_state(data: Dictionary) -> void:
	# Party info
	GameManager.party_money = data.get("party_money", 0)
	GameManager.party_name = data.get("party_name", "")
	GameManager.current_room = data.get("current_room", "")
	GameManager.previous_room = data.get("previous_room", "")
	GameManager.play_time = data.get("play_time", 0.0)

	# Event persistence (GMS2: game.scenesLoaded)
	GameManager.scenes_completed = data.get("scenes_completed", {})
	GameManager.executed_dialogs = data.get("executed_dialogs", {})

	# Inventory
	GameManager.inventory_items = data.get("inventory_items", {})
	var equip_data = data.get("inventory_equipment", [])
	GameManager.inventory_equipment.clear()
	for e in equip_data:
		GameManager.inventory_equipment.append(str(e))

	# Load room
	var room_name: String = data.get("current_room", "")
	if room_name.is_empty():
		return

	# Players will be restored after room loads
	var players_data: Array = data.get("players", [])

	# Change room and restore players after
	GameManager.change_map(room_name)

	# Defer player restoration to after room loads
	if players_data.size() > 0:
		GameManager.call_deferred("_restore_players_from_save", players_data)


static func _get_leader_name_from_data(data: Dictionary) -> String:
	var players: Array = data.get("players", [])
	if players.size() > 0:
		return str(players[0].get("character_name", "???"))
	return "???"


static func _get_leader_level_from_data(data: Dictionary) -> int:
	var players: Array = data.get("players", [])
	if players.size() > 0:
		return int(players[0].get("level", 1))
	return 1
