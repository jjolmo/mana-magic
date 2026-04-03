extends Node
## Global game state - replaces the persistent `game` object from GMS2

# Player references
var players: Array = []
var total_players: int = 0
var party_name: String = ""
var party_money: int = 0

# Game state flags
var ring_menu_opened: bool = false
var show_debug: bool = false
var is_mobile: bool = false
var is_paused: bool = false
var scene_running: bool = false
var lock_global_input: bool = false

# Play time tracking (seconds elapsed)
var play_time: float = 0.0

# Music state
var music_enabled: bool = true
var current_music: String = ""

# Target modes
enum TargetMode { ALLY, ENEMY }
var target_mode: int = TargetMode.ALLY

# Weapon data (loaded from database)
var weapon_image_attack_speed: Array = []
var weapon_end_anim_timeout: Array = []
var sound_weapons: Array = []

# Unique group effect tracking
var unique_group_effect_id: Node = null

# Dialog executed tracking
var executed_dialogs: Dictionary = {}

# Inventory (GMS2: bag.items / bag.equipment)
# Format: { "itemName": quantity, ... }
var inventory_items: Dictionary = {}
# Owned equipment names
var inventory_equipment: Array[String] = []

# Scene management
var current_room: String = ""
var previous_room: String = ""

## GMS2: item conditions - rooms can allow/disallow Flammie Drum and Magic Rope
## Set by StartingPoint or room scripts based on room type (outdoor vs dungeon)
var current_room_allows_flammie: bool = false
var current_room_allows_rope: bool = false

# Language config (GMS2: manual file swap between dialogs_en.json / dialogs_es.json)
var language: String = "en"  # "en" or "es"
const LANGUAGES: Array[String] = ["en", "es"]
const LANGUAGE_NAMES: Array[String] = ["English", "Español"]

# Dialog speed config (GMS2: dialog_speedConfigIndex, dialog_speed[0..2])
var dialog_speed_index: int = 0
const DIALOG_SPEEDS: Array[float] = [0.5, 1.0, 2.0]
const DIALOG_SPEED_NAMES: Array[String] = ["Slow", "Normal", "Fast"]

# Dialog visual config (GMS2: game.configuration.dialogBackground/dialogBorder/dialogColorRGB)
const GUI_SCALE: float = 1.0  # Godot 427x240 viewport (GMS2 was 3.0 at 1281x720)
var dialog_background_index: int = 0  # spr_scriptDialog_bg subimage index
var dialog_border_index: int = 0  # spr_scriptDialog_border subimage index
var dialog_color_rgb: Color = Color(0.0, 0.0, 0.5, 1.0)  # Tint for dialog bg (GMS2: dialogColorRGB)
const DIALOG_X_WINDOW_MARGIN: float = 4.0  # GMS2: dialogXWindowMargin
const DIALOG_Y_WINDOW_MARGIN: float = 4.0  # GMS2: dialogYWindowMargin
const DIALOG_BORDER_MARGIN: float = 4.0  # GMS2: dialogBorderMargin

func get_dialog_speed_base() -> float:
	return DIALOG_SPEEDS[dialog_speed_index]

func _load_dialog_settings() -> void:
	var path := "res://data/databases/dialog_settings.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	file.close()
	var data: Dictionary = json.data if json.data is Dictionary else {}
	dialog_speed_index = clampi(int(data.get("dialog_speed_index", 0)), 0, DIALOG_SPEEDS.size() - 1)
	dialog_background_index = int(data.get("dialog_background_index", 0))
	dialog_border_index = int(data.get("dialog_border_index", 0))
	dialog_color_rgb = Color(
		float(data.get("dialog_color_r", 0.0)),
		float(data.get("dialog_color_g", 0.0)),
		float(data.get("dialog_color_b", 0.5)),
	)

# Spawn point for room transitions (GMS2: game.linkToTeleport_name/moveDirection)
var pending_spawn_point: String = ""
var pending_spawn_direction: int = -1  # Constants.Facing value, -1 = none

# Event persistence (GMS2: game.scenesLoaded prevents scenes from replaying)
var scenes_completed: Dictionary = {}

# Map transition reference (for convenience access)
var map_transition: MapTransition = null
# HUD reference (for hide/show during scenes/menus)
var hud: HUD = null
# Battle dialog reference (GMS2: addBattleDialog global function)
var battle_dialog: BattleDialog = null
# GMS2: Actors are persistent objects that survive room changes.
# Godot: change_scene destroys all nodes, so we save/restore actor state.
var _pending_actor_states: Array = []

func _ready() -> void:
	_init_weapon_data()
	_init_ui()
	_init_starting_inventory()
	_load_dialog_settings()

func _process(delta: float) -> void:
	# Track play time (only when not paused)
	if not is_paused:
		play_time += delta

func _init_starting_inventory() -> void:
	# Starting items (matches GMS2 defineDefaultCharacters - all items available)
	add_item("candy", 4)
	add_item("medicalHerb", 4)
	add_item("cupOfWishes", 4)
	add_item("faerieWalnut", 4)
	add_item("royalJam", 4)
	add_item("chocolate", 4)
	add_item("barrel", 2)
	# Starting equipment (matches GMS2 defineDefaultCharacters)
	# Weapons
	inventory_equipment.append("dragonBuster")
	inventory_equipment.append("doomAxe")
	inventory_equipment.append("daedlusLance")
	inventory_equipment.append("gigasFlail")
	inventory_equipment.append("garudaBuster")
	inventory_equipment.append("ninjaTrump")
	inventory_equipment.append("valkyrian")
	# Armor
	inventory_equipment.append("needleHelm")
	inventory_equipment.append("faerieCrown")
	inventory_equipment.append("amuletRing")
	inventory_equipment.append("faerieRing")
	inventory_equipment.append("vestguard")
	inventory_equipment.append("faerieCloak")
	inventory_equipment.append("vampireCape")
	inventory_equipment.append("sageRobe")

func _init_ui() -> void:
	# Create persistent UI layers
	var hud_scene: PackedScene = preload("res://scenes/ui/hud.tscn")
	var hud_layer: Node = hud_scene.instantiate()
	add_child(hud_layer)
	# Store HUD reference for hide/show access (GMS2: hideHud/showHud)
	# hud.tscn: CanvasLayer > HUD (Control with hud.gd script)
	var hud_node: Node = hud_layer.get_node_or_null("HUD")
	if hud_node is HUD:
		hud = hud_node as HUD

	var bd_scene: PackedScene = preload("res://scenes/ui/battle_dialog.tscn")
	var bd_layer: Node = bd_scene.instantiate()
	add_child(bd_layer)
	# Store BattleDialog reference (GMS2: addBattleDialog is a global function)
	var bd_node: Node = bd_layer.get_node_or_null("BattleDialog")
	if bd_node is BattleDialog:
		battle_dialog = bd_node as BattleDialog

	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	var rm_scene: PackedScene = preload("res://scenes/ui/ring_menu.tscn")
	var rm_layer: Node = rm_scene.instantiate()
	add_child(rm_layer)

	# Create map transition system (fade/room change)
	var transition := MapTransition.new()
	transition.name = "MapTransition"
	add_child(transition)
	map_transition = transition

	# Boss HP bar (shows when a boss is active)
	var boss_bar := BossHPBar.new()
	boss_bar.name = "BossHPBar"
	add_child(boss_bar)

	# Touch controls (auto-detect mobile)
	is_mobile = _detect_mobile()
	var tc := TouchControls.new()
	tc.name = "TouchControls"
	add_child(tc)

func _detect_mobile() -> bool:
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"

func _init_weapon_data() -> void:
	# Default weapon animation speeds (index = weapon enum value)
	# Order: SWORD, AXE, SPEAR, JAVELIN, BOW, BOOMERANG, WHIP, KNUCKLES, NONE
	weapon_image_attack_speed = [0.24, 0.17, 0.14, 0.24, 0.20, 0.08, 0.08, 0.24, 0.0]
	weapon_end_anim_timeout = [16, 16, 16, 30, 50, 40, 16, 16, 16]

func add_player(player: Node) -> void:
	# GMS2: actorFollowingId = partyList[priorPlayerId] - chain following
	if players.size() > 0 and player is Actor:
		(player as Actor).actor_following = players[players.size() - 1]
	players.append(player)
	total_players = players.size()

func remove_player(player: Node) -> void:
	players.erase(player)
	total_players = players.size()

func get_player(index: int) -> Node:
	if index >= 0 and index < players.size():
		return players[index]
	return null

func get_alive_players() -> Array:
	var alive: Array = []
	for p in players:
		if is_instance_valid(p) and not p.is_dead:
			alive.append(p)
	return alive

func get_dead_players() -> Array:
	var dead: Array = []
	for p in players:
		if is_instance_valid(p) and p.is_dead:
			dead.append(p)
	return dead

func get_party_leader() -> Node:
	for p in players:
		if is_instance_valid(p) and p.is_party_leader:
			return p
	if players.size() > 0:
		return players[0]
	return null

func get_random_player() -> Node:
	if players.size() == 0:
		return null
	return players[randi() % players.size()]

func get_random_alive_player() -> Node:
	var alive := get_alive_players()
	if alive.size() == 0:
		return null
	return alive[randi() % alive.size()]

func is_party_alive() -> bool:
	return get_alive_players().size() > 0

func add_money(amount: int) -> void:
	party_money += amount

## GMS2: addBattleDialog(text) - global function to queue combat messages
func add_battle_dialog(text: String, p_align: int = BattleDialog.Align.BOTTOM, override: bool = false, time_seconds: float = 4.0) -> void:
	if battle_dialog:
		battle_dialog.add_message(text, p_align, override, time_seconds)

func remove_money(amount: int) -> bool:
	if party_money >= amount:
		party_money -= amount
		return true
	return false

func get_map_transition() -> MapTransition:
	for child in get_children():
		if child is MapTransition:
			return child
	return null

func change_map(target_room: String, color: Color = Color.BLACK) -> void:
	# GMS2: actors are persistent, but Godot destroys scene nodes on change_scene.
	# Save actor state so we can restore it after spawning new actors.
	_save_actor_states()
	# Clear player references before scene change to avoid freed-object errors
	players.clear()
	total_players = 0
	var transition := get_map_transition()
	if transition:
		transition.map_change(target_room, color)

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false

## Swap to the next alive actor in the party (GMS2: BUTTON_SWAP_ACTOR)
var _last_swap_frame: int = -1
func swap_actor() -> void:
	# Prevent multiple swaps in the same physics frame (all actors' _physics_process
	# runs in the same tick, so the new leader would also see just_pressed = true)
	var frame: int = Engine.get_physics_frames()
	if frame == _last_swap_frame:
		return
	_last_swap_frame = frame
	if players.size() <= 1:
		return
	var current_leader: Node = get_party_leader()
	if not current_leader:
		return

	var leader_index: int = players.find(current_leader)
	if leader_index < 0:
		return

	# Cycle to next alive actor
	var next_index: int = (leader_index + 1) % players.size()
	var attempts: int = 0
	while attempts < players.size():
		var candidate: Node = players[next_index]
		if is_instance_valid(candidate) and not candidate.is_dead and candidate != current_leader:
			_set_party_leader(candidate, current_leader)
			return
		next_index = (next_index + 1) % players.size()
		attempts += 1

func _set_party_leader(new_leader: Node, old_leader: Node) -> void:
	# Old leader -> AI mode
	old_leader.is_party_leader = false
	old_leader.player_controlled = false
	old_leader.control_is_moving = false
	old_leader.control_attack_pressed = false
	old_leader.control_run_held = false
	old_leader.control_is_running = false
	# Don't switch dead actors to IAStand - they stay in Dead state
	if not old_leader.is_dead and old_leader.state_machine_node and old_leader.state_machine_node.has_state("IAStand"):
		old_leader.state_machine_node.switch_state("IAStand")

	# New leader -> player mode
	new_leader.is_party_leader = true
	new_leader.player_controlled = true
	if new_leader.state_machine_node:
		new_leader.state_machine_node.switch_state("Stand")

	# GMS2: switchPlayerInput rebuilds actorFollowingId chain after swap
	_rebuild_follow_chain()

	# Rebind camera
	var cameras := get_tree().root.find_children("*", "CameraController", true, false)
	if cameras.size() > 0 and cameras[0].has_method("camera_set"):
		cameras[0].camera_set(new_leader)

## GMS2: switchPlayerInput rebuilds actorFollowingId = partyList[previousPlayer]
## Each actor follows the previous one in the array (chain, not all→leader)
func _rebuild_follow_chain() -> void:
	for i in range(players.size()):
		if not (players[i] is Actor):
			continue
		var prev_index: int = i - 1
		if prev_index < 0:
			prev_index = players.size() - 1
		(players[i] as Actor).actor_following = players[prev_index]

# --- Inventory Management (GMS2: addItem/removeItem/consumeItem) ---

## GMS2: maxQuantity per item (99 for consumables, 1 for key items).
## Uses a general cap of 99 here; key items are handled by DB lookup if available.
const ITEM_MAX_QUANTITY: int = 99

func add_item(item_name: String, quantity: int = 1) -> void:
	if inventory_items.has(item_name):
		inventory_items[item_name] = mini(inventory_items[item_name] + quantity, ITEM_MAX_QUANTITY)
	else:
		inventory_items[item_name] = mini(quantity, ITEM_MAX_QUANTITY)

func remove_item(item_name: String, quantity: int = 1) -> bool:
	if inventory_items.has(item_name) and inventory_items[item_name] >= quantity:
		inventory_items[item_name] -= quantity
		if inventory_items[item_name] <= 0:
			inventory_items.erase(item_name)
		return true
	return false

func has_item(item_name: String, quantity: int = 1) -> bool:
	return inventory_items.has(item_name) and inventory_items[item_name] >= quantity

func get_item_count(item_name: String) -> int:
	return inventory_items.get(item_name, 0)

func add_equipment(equip_name: String) -> void:
	inventory_equipment.append(equip_name)

func remove_equipment(equip_name: String) -> bool:
	var idx: int = inventory_equipment.find(equip_name)
	if idx >= 0:
		inventory_equipment.remove_at(idx)
		return true
	return false

func has_equipment(equip_name: String) -> bool:
	return equip_name in inventory_equipment

func get_owned_items() -> Dictionary:
	return inventory_items.duplicate()

func get_owned_equipment() -> Array[String]:
	return inventory_equipment.duplicate()

# --- Save/Load support ---

func _restore_players_from_save(players_data: Array) -> void:
	## Restore player actors from save data after a room has loaded.
	## Called deferred so the room's actors are already instantiated.
	# Wait one extra frame for actors to be fully ready
	await get_tree().process_frame
	await get_tree().process_frame

	for i in range(mini(players_data.size(), players.size())):
		var pdata: Dictionary = players_data[i]
		var player: Node = players[i]
		if not is_instance_valid(player) or not player is Actor:
			continue
		var actor := player as Actor

		# Identity
		actor.character_id = int(pdata.get("character_id", 0))
		actor.character_name = str(pdata.get("character_name", ""))

		# Position
		actor.global_position.x = float(pdata.get("position_x", actor.global_position.x))
		actor.global_position.y = float(pdata.get("position_y", actor.global_position.y))

		# Attributes
		actor.attribute.level = int(pdata.get("level", 1))
		actor.attribute.hp = int(pdata.get("hp", 100))
		actor.attribute.mp = int(pdata.get("mp", 0))
		actor.attribute.maxHP = int(pdata.get("maxHP", 100))
		actor.attribute.maxMP = int(pdata.get("maxMP", 0))
		actor.attribute.strength = int(pdata.get("strength", 5))
		actor.attribute.constitution = int(pdata.get("constitution", 5))
		actor.attribute.agility = int(pdata.get("agility", 5))
		actor.attribute.intelligence = int(pdata.get("intelligence", 5))
		actor.attribute.wisdom = int(pdata.get("wisdom", 5))
		actor.attribute.luck = int(pdata.get("luck", 5))
		actor.attribute.experience = int(pdata.get("experience", 0))

		# Equipment
		actor.equipped_weapon_id = int(pdata.get("equipped_weapon_id", 0))
		actor.equipped_head = int(pdata.get("equipped_head", -1))
		actor.equipped_body = int(pdata.get("equipped_body", -1))
		actor.equipped_accessory = int(pdata.get("equipped_accessory", -1))

		# Weapon levels
		var equip_lvls = pdata.get("equipment_levels", {})
		if equip_lvls is Dictionary:
			for key in equip_lvls:
				actor.equipment_levels[str(key)] = int(equip_lvls[key])
		var equip_cur = pdata.get("equipment_current_level", {})
		if equip_cur is Dictionary:
			for key in equip_cur:
				actor.equipment_current_level[str(key)] = int(equip_cur[key])

		# Deity/magic levels
		var d_levels = pdata.get("deity_levels", [])
		if d_levels is Array:
			for j in range(mini(d_levels.size(), actor.deity_levels.size())):
				actor.deity_levels[j] = int(d_levels[j])

		# AI strategy
		actor.strategy_attack_guard = int(pdata.get("strategy_attack_guard", 2))
		actor.strategy_approach_keep_away = int(pdata.get("strategy_approach_keep_away", 3))

		# State
		actor.is_dead = pdata.get("is_dead", false)

		# Refresh percentages
		actor.refresh_hp_percent()
		actor.refresh_mp_percent()

# --- Event Persistence (GMS2: game.scenesLoaded) ---

func set_scene_completed(scene_id: String) -> void:
	## Mark a scene/event as completed so it won't replay on room re-entry
	scenes_completed[scene_id] = true

func is_scene_completed(scene_id: String) -> bool:
	## Check if a scene/event has already been completed
	return scenes_completed.has(scene_id)

func clear_scene_completed(scene_id: String) -> void:
	## Clear a scene completion flag (for debug/testing)
	scenes_completed.erase(scene_id)

# --- Actor State Persistence (GMS2: actors are persistent, survive room changes) ---

func _save_actor_states() -> void:
	## Serialize all current actor states before room transition.
	## Called from change_map() before players.clear().
	_pending_actor_states.clear()
	for p in players:
		if is_instance_valid(p) and p is Actor:
			_pending_actor_states.append(_serialize_actor(p as Actor))

func restore_actor_states() -> void:
	## Restore actor states after spawning in new room.
	## Called from StartingPoint._spawn_party() after actors are created.
	if _pending_actor_states.is_empty():
		return
	for i in range(mini(_pending_actor_states.size(), players.size())):
		var data: Dictionary = _pending_actor_states[i]
		var player: Node = players[i]
		if is_instance_valid(player) and player is Actor:
			_restore_actor(player as Actor, data)
	_pending_actor_states.clear()

func _serialize_actor(actor: Actor) -> Dictionary:
	return {
		"character_id": actor.character_id,
		"character_name": actor.character_name,
		"is_party_leader": actor.is_party_leader,
		"player_controlled": actor.player_controlled,
		# Equipment
		"equipped_weapon_id": actor.equipped_weapon_id,
		"equipped_head": actor.equipped_head,
		"equipped_body": actor.equipped_body,
		"equipped_accessory": actor.equipped_accessory,
		"weapon_attack_type": actor.weapon_attack_type,
		"equipment_levels": actor.equipment_levels.duplicate(),
		"equipment_current_level": actor.equipment_current_level.duplicate(),
		# Deity/magic levels
		"deity_levels": actor.deity_levels.duplicate(),
		"enable_magic": actor.enable_magic,
		# Attributes (full dict)
		"attribute": actor.attribute.duplicate(),
		# Combat state
		"is_dead": actor.is_dead,
		"weapon_gauge": actor.weapon_gauge,
		"overheating": actor.overheating,
		# Status effects
		"status_effects": actor.status_effects.duplicate(),
		"status_timers": actor.status_timers.duplicate(),
		# Elemental
		"elemental_weakness": actor.elemental_weakness.duplicate(),
		"elemental_protection": actor.elemental_protection.duplicate(),
		"elemental_atunement": actor.elemental_atunement.duplicate(),
		# AI strategy
		"strategy_attack_guard": actor.strategy_attack_guard,
		"strategy_approach_keep_away": actor.strategy_approach_keep_away,
	}

func _restore_actor(actor: Actor, data: Dictionary) -> void:
	## Restore a single actor's persistent state from a room transition.
	# Identity
	actor.character_id = int(data.get("character_id", actor.character_id))
	actor.character_name = str(data.get("character_name", actor.character_name))
	actor.is_party_leader = data.get("is_party_leader", actor.is_party_leader)
	actor.player_controlled = data.get("player_controlled", actor.player_controlled)

	# Equipment
	actor.equipped_weapon_id = int(data.get("equipped_weapon_id", actor.equipped_weapon_id))
	actor.equipped_head = int(data.get("equipped_head", -1))
	actor.equipped_body = int(data.get("equipped_body", -1))
	actor.equipped_accessory = int(data.get("equipped_accessory", -1))
	actor.weapon_attack_type = int(data.get("weapon_attack_type", actor.weapon_attack_type))

	# Equipment levels
	var equip_lvls = data.get("equipment_levels", {})
	if equip_lvls is Dictionary:
		for key in equip_lvls:
			actor.equipment_levels[str(key)] = int(equip_lvls[key])
	var equip_cur = data.get("equipment_current_level", {})
	if equip_cur is Dictionary:
		for key in equip_cur:
			actor.equipment_current_level[str(key)] = int(equip_cur[key])

	# Deity/magic levels
	var d_levels = data.get("deity_levels", [])
	if d_levels is Array:
		for j in range(mini(d_levels.size(), actor.deity_levels.size())):
			actor.deity_levels[j] = int(d_levels[j])
	actor.enable_magic = int(data.get("enable_magic", actor.enable_magic))

	# Full attribute dictionary
	var attr: Dictionary = data.get("attribute", {})
	for key in attr:
		actor.attribute[key] = attr[key]

	# Rebuild gear stats from equipment (recalculates elementals from gear)
	actor.recalculate_gear()

	# Combat state
	actor.is_dead = data.get("is_dead", false)
	actor.weapon_gauge = float(data.get("weapon_gauge", 0.0))
	actor.overheating = data.get("overheating", false)

	# Status effects (restore after gear recalc so they overlay properly)
	var se: Array = data.get("status_effects", [])
	for j in range(mini(se.size(), actor.status_effects.size())):
		actor.status_effects[j] = bool(se[j])
	var st: Array = data.get("status_timers", [])
	for j in range(mini(st.size(), actor.status_timers.size())):
		actor.status_timers[j] = int(st[j])

	# Elemental (saber atunement overlays equipment atunement)
	var ea: Array = data.get("elemental_atunement", [])
	for j in range(mini(ea.size(), actor.elemental_atunement.size())):
		actor.elemental_atunement[j] = float(ea[j])

	# AI strategy
	actor.strategy_attack_guard = int(data.get("strategy_attack_guard", 2))
	actor.strategy_approach_keep_away = int(data.get("strategy_approach_keep_away", 3))

	# Refresh percentages
	actor.refresh_hp_percent()
	actor.refresh_mp_percent()

	# Set correct FSM state based on role
	if actor.is_dead:
		if actor.state_machine_node and actor.state_machine_node.has_state("Dead"):
			actor.state_machine_node.switch_state("Dead")
	elif actor.is_party_leader:
		if actor.state_machine_node and actor.state_machine_node.has_state("Stand"):
			actor.state_machine_node.switch_state("Stand")
	else:
		if actor.state_machine_node and actor.state_machine_node.has_state("IAStand"):
			actor.state_machine_node.switch_state("IAStand")


## GMS2: game_restart() fully resets ALL state. Godot autoloads persist across
## reload_current_scene(), so we must manually reset all global state.
func reset_all_state() -> void:
	players.clear()
	total_players = 0
	party_money = 0
	ring_menu_opened = false
	is_paused = false
	scene_running = false
	lock_global_input = false
	play_time = 0.0
	current_music = ""
	unique_group_effect_id = null
	executed_dialogs.clear()
	inventory_items.clear()
	inventory_equipment.clear()
	current_room = ""
	previous_room = ""
	current_room_allows_flammie = false
	current_room_allows_rope = false
	dialog_speed_index = 0
	pending_spawn_point = ""
	pending_spawn_direction = -1
	scenes_completed.clear()
	_pending_actor_states.clear()
	map_transition = null
	hud = null
	battle_dialog = null
	# Re-initialize starting inventory
	_init_starting_inventory()
