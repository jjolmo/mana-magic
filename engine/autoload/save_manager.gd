extends Node
## Save/Load manager for Mana Magic (new system, not from GMS2)
## Serializes game state to JSON file in user data directory.
## Supports 3 save slots + autosave.

const SAVE_DIR := "user://saves/"
const SAVE_EXTENSION := ".json"
const SAVE_VERSION := 1
const MAX_SLOTS := 3

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_error(slot: int, error: String)
signal load_error(slot: int, error: String)

func _ready() -> void:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

## Get save file path for a slot (0=autosave, 1-3=manual slots)
func _get_save_path(slot: int) -> String:
	if slot == 0:
		return SAVE_DIR + "autosave" + SAVE_EXTENSION
	return SAVE_DIR + "save_%d%s" % [slot, SAVE_EXTENSION]

## Check if a save slot exists
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))

## Get save metadata (for display in load screen) without loading entire save
func get_save_info(slot: int) -> Dictionary:
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	var data: Dictionary = json.data
	return {
		"slot": slot,
		"room": data.get("room", "???"),
		"money": data.get("money", 0),
		"play_time": data.get("play_time", 0),
		"timestamp": data.get("timestamp", ""),
		"version": data.get("version", 0),
		"party": data.get("party_summary", []),
	}

## Get all available save infos
func get_all_save_infos() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_SLOTS + 1):  # 0=autosave, 1-3=manual
		if has_save(i):
			result.append(get_save_info(i))
	return result

# ===================================================================
# SAVE
# ===================================================================

func save_game(slot: int) -> bool:
	var data: Dictionary = _serialize_game_state()
	var json_str: String = JSON.stringify(data, "\t")

	var path := _get_save_path(slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		var err_msg: String = "Failed to open save file: %s" % path
		push_error(err_msg)
		save_error.emit(slot, err_msg)
		return false

	f.store_string(json_str)
	f.close()
	save_completed.emit(slot)
	return true

func autosave() -> bool:
	return save_game(0)

func _serialize_game_state() -> Dictionary:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"room": GameManager.current_room,
		"money": GameManager.party_money,
		"play_time": GameManager.play_time,
		"inventory_items": _serialize_inventory_items(),
		"inventory_equipment": GameManager.inventory_equipment.duplicate(),
		"executed_dialogs": GameManager.executed_dialogs.duplicate(),
		"scenes_completed": GameManager.scenes_completed.duplicate(),
		"dialog_speed_index": GameManager.dialog_speed_index,
		"language": GameManager.language,
		"players": _serialize_players(),
		"party_summary": _get_party_summary(),
		"enabled_skills": _get_runtime_enabled_skills(),
	}
	return data

func _serialize_inventory_items() -> Dictionary:
	var items: Dictionary = {}
	for key in GameManager.inventory_items:
		items[key] = GameManager.inventory_items[key]
	return items

func _serialize_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in GameManager.players:
		if p is Actor:
			result.append(_serialize_actor(p as Actor))
	return result

func _serialize_actor(actor: Actor) -> Dictionary:
	return {
		"character_id": actor.character_id,
		"character_name": actor.character_name,
		"is_party_leader": actor.is_party_leader,
		"player_controlled": actor.player_controlled,
		"facing": actor.facing,
		"position_x": actor.global_position.x,
		"position_y": actor.global_position.y,
		# Equipment
		"equipped_weapon_id": actor.equipped_weapon_id,
		"equipped_head": actor.equipped_head,
		"equipped_body": actor.equipped_body,
		"equipped_accessory": actor.equipped_accessory,
		"weapon_attack_type": actor.weapon_attack_type,
		# Equipment levels
		"equipment_levels": actor.equipment_levels.duplicate(),
		"equipment_current_level": actor.equipment_current_level.duplicate(),
		# Deity/magic levels
		"deity_levels": actor.deity_levels.duplicate(),
		"enable_magic": actor.enable_magic,
		# Attributes
		"attribute": _serialize_attribute(actor.attribute),
		# Status
		"is_dead": actor.is_dead,
		"status_effects": actor.status_effects.duplicate(),
		"status_timers": actor.status_timers.duplicate(),
		# Elemental
		"elemental_weakness": actor.elemental_weakness.duplicate(),
		"elemental_protection": actor.elemental_protection.duplicate(),
		"elemental_atunement": actor.elemental_atunement.duplicate(),
		# AI strategy (GMS2: strategyPattern*)
		"strategy_attack_guard": actor.strategy_attack_guard,
		"strategy_approach_keep_away": actor.strategy_approach_keep_away,
		# Weapon gauge + overheat (GMS2: persistent actor state)
		"weapon_gauge": actor.weapon_gauge,
		"overheating": actor.overheating,
	}

func _serialize_attribute(attr: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	# Only serialize persistent attributes (not runtime state like walkSpeed)
	var persistent_keys: Array[String] = [
		"hp", "mp", "maxHP", "maxMP", "level", "experience",
		"strength", "constitution", "agility", "luck", "intelligence", "wisdom",
		"criticalRate", "criticalMultiplier",
		"weaponGaugeMaxBase",
		"classId", "maxLevel",
		"HPMultiplier", "HPMultiplier2", "HPExponential",
		"MPMultiplier", "MPMultiplier2", "MPDivisor",
		"gear",
	]
	for key in persistent_keys:
		if attr.has(key):
			result[key] = attr[key]
	return result

## Get skills that are enabled at runtime but disabled in the default JSON database.
## Only manaMagicOffensive and manaMagicSupport can be runtime-enabled (after Dark Lich).
func _get_runtime_enabled_skills() -> Array[String]:
	var result: Array[String] = []
	for skill in Database.skills:
		if skill is Dictionary and skill.get("enabled", false):
			var sname: String = skill.get("name", "")
			if sname == "manaMagicOffensive" or sname == "manaMagicSupport":
				result.append(sname)
	return result

func _get_party_summary() -> Array[Dictionary]:
	## Brief summary for save slot display
	var result: Array[Dictionary] = []
	for p in GameManager.players:
		if p is Actor:
			var a: Actor = p as Actor
			result.append({
				"name": a.character_name,
				"level": a.attribute.get("level", 1),
				"hp": a.attribute.get("hp", 0),
				"maxHP": a.attribute.get("maxHP", 100),
			})
	return result

# ===================================================================
# LOAD
# ===================================================================

func load_game(slot: int) -> bool:
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		var err_msg: String = "Save file not found: %s" % path
		push_error(err_msg)
		load_error.emit(slot, err_msg)
		return false

	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		var err_msg: String = "Failed to open save file: %s" % path
		push_error(err_msg)
		load_error.emit(slot, err_msg)
		return false

	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		var err_msg: String = "Failed to parse save file: %s" % json.get_error_message()
		push_error(err_msg)
		load_error.emit(slot, err_msg)
		return false

	var data: Dictionary = json.data
	if data.get("version", 0) != SAVE_VERSION:
		push_warning("Save version mismatch: expected %d, got %d" % [SAVE_VERSION, data.get("version", 0)])

	_deserialize_game_state(data)
	load_completed.emit(slot)
	return true

func _deserialize_game_state(data: Dictionary) -> void:
	# Restore global state
	GameManager.party_money = int(data.get("money", 0))
	GameManager.play_time = float(data.get("play_time", 0.0))
	GameManager.dialog_speed_index = clampi(int(data.get("dialog_speed_index", 0)), 0, 2)
	var saved_lang: String = str(data.get("language", "en"))
	if saved_lang in GameManager.LANGUAGES:
		GameManager.language = saved_lang
		Database.reload_dialogs(saved_lang)
	GameManager.executed_dialogs = data.get("executed_dialogs", {})
	GameManager.scenes_completed = data.get("scenes_completed", {})

	# Restore inventory
	GameManager.inventory_items.clear()
	var items_data: Dictionary = data.get("inventory_items", {})
	for key in items_data:
		GameManager.inventory_items[key] = int(items_data[key])

	GameManager.inventory_equipment.clear()
	for eq_name in data.get("inventory_equipment", []):
		GameManager.inventory_equipment.append(str(eq_name))

	# Restore runtime-enabled skills (e.g. manaMagic unlocked after Dark Lich)
	var enabled_skills: Array = data.get("enabled_skills", [])
	for skill_name in enabled_skills:
		Database.enable_skill(str(skill_name))

	# Store player data for room load (actors are created per-room)
	_pending_player_data = data.get("players", [])

	# Change to saved room (this will trigger room load + player spawn)
	var target_room: String = data.get("room", "")
	if target_room != "":
		GameManager.change_map(target_room)

## Pending player data to apply after room loads
var _pending_player_data: Array = []

## Called after room change to apply saved player state to spawned actors
func apply_pending_player_data() -> void:
	if _pending_player_data.is_empty():
		return

	# Wait a frame for actors to be fully initialized
	await get_tree().process_frame

	for i in range(mini(_pending_player_data.size(), GameManager.players.size())):
		var pdata: Dictionary = _pending_player_data[i]
		var actor: Actor = GameManager.players[i] as Actor
		if actor:
			_deserialize_actor(actor, pdata)

	_pending_player_data.clear()

func _deserialize_actor(actor: Actor, data: Dictionary) -> void:
	# Identity
	actor.character_id = int(data.get("character_id", actor.character_id))
	actor.character_name = str(data.get("character_name", actor.character_name))
	actor.is_party_leader = data.get("is_party_leader", false)
	actor.player_controlled = data.get("player_controlled", false)

	# Position
	actor.global_position = Vector2(
		float(data.get("position_x", actor.global_position.x)),
		float(data.get("position_y", actor.global_position.y))
	)
	actor.facing = int(data.get("facing", actor.facing))

	# Equipment
	var weapon_id: int = int(data.get("equipped_weapon_id", actor.equipped_weapon_id))
	actor.set_weapon(weapon_id)
	actor.equipped_head = int(data.get("equipped_head", -1))
	actor.equipped_body = int(data.get("equipped_body", -1))
	actor.equipped_accessory = int(data.get("equipped_accessory", -1))
	actor.weapon_attack_type = int(data.get("weapon_attack_type", 0))

	# Equipment levels
	var eq_levels: Dictionary = data.get("equipment_levels", {})
	for key in eq_levels:
		actor.equipment_levels[key] = int(eq_levels[key])
	var eq_current: Dictionary = data.get("equipment_current_level", {})
	for key in eq_current:
		actor.equipment_current_level[key] = int(eq_current[key])

	# Deity levels
	var dl: Array = data.get("deity_levels", [])
	for j in range(mini(dl.size(), actor.deity_levels.size())):
		actor.deity_levels[j] = int(dl[j])
	actor.enable_magic = int(data.get("enable_magic", 0))

	# Attributes
	var attr_data: Dictionary = data.get("attribute", {})
	for key in attr_data:
		actor.attribute[key] = attr_data[key]

	# Rebuild gear stats from equipped items (populates attribute.gear and elementals)
	actor.recalculate_gear()

	# Recalculate HP/MP percentages
	var max_hp: float = float(actor.attribute.get("maxHP", 100))
	var max_mp: float = float(actor.attribute.get("maxMP", 0))
	if max_hp > 0:
		actor.attribute["hpPercent"] = float(actor.attribute.get("hp", 0)) / max_hp * 100.0
	if max_mp > 0:
		actor.attribute["mpPercent"] = float(actor.attribute.get("mp", 0)) / max_mp * 100.0

	# Status
	actor.is_dead = data.get("is_dead", false)
	var se: Array = data.get("status_effects", [])
	for j in range(mini(se.size(), actor.status_effects.size())):
		actor.status_effects[j] = bool(se[j])
	var st: Array = data.get("status_timers", [])
	for j in range(mini(st.size(), actor.status_timers.size())):
		actor.status_timers[j] = int(st[j])

	# Elemental
	var ew: Array = data.get("elemental_weakness", [])
	for j in range(mini(ew.size(), actor.elemental_weakness.size())):
		actor.elemental_weakness[j] = float(ew[j])
	var ep: Array = data.get("elemental_protection", [])
	for j in range(mini(ep.size(), actor.elemental_protection.size())):
		actor.elemental_protection[j] = float(ep[j])
	var ea: Array = data.get("elemental_atunement", [])
	for j in range(mini(ea.size(), actor.elemental_atunement.size())):
		actor.elemental_atunement[j] = float(ea[j])

	# AI strategy
	actor.strategy_attack_guard = int(data.get("strategy_attack_guard", 2))
	actor.strategy_approach_keep_away = int(data.get("strategy_approach_keep_away", 2))

	# Weapon gauge + overheat
	actor.weapon_gauge = float(data.get("weapon_gauge", 0.0))
	actor.overheating = bool(data.get("overheating", false))

	# Set correct state
	if actor.is_party_leader:
		if actor.state_machine_node and actor.state_machine_node.has_state("Stand"):
			actor.state_machine_node.switch_state("Stand")
	else:
		if actor.state_machine_node and actor.state_machine_node.has_state("IAStand"):
			actor.state_machine_node.switch_state("IAStand")

# ===================================================================
# DELETE
# ===================================================================

func delete_save(slot: int) -> bool:
	var path := _get_save_path(slot)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		return err == OK
	return false
