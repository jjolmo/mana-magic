class_name StartingPoint
extends Node2D
## Starting point for player spawn - replaces oStartingPoint from GMS2

@export var spawn_party: bool = true
@export var party_config: String = "default" # default, debug, boss
@export var hero_ids_override: Array[int] = [] ## If non-empty, only spawn these hero IDs (ignores enabledByDefault)

func _ready() -> void:
	if spawn_party:
		call_deferred("_spawn_party")

func _spawn_party() -> void:
	var actor_scene: PackedScene = preload("res://scenes/creatures/actor.tscn")

	# GMS2: set room flags for item conditions (callFlammie, useRope)
	var room_name: String = get_tree().current_scene.name if get_tree().current_scene else ""
	GameManager.current_room = room_name
	# Outdoor field rooms allow Flammie; dungeon/boss rooms allow Rope
	GameManager.current_room_allows_flammie = room_name.begins_with("rom_0")
	GameManager.current_room_allows_rope = not room_name.begins_with("rom_0")

	# GMS2 RoomCreationCode: musicSet(bgm_distantThunder) for field rooms
	# Boss/special rooms set music through their own SceneEvent scripts
	if room_name.begins_with("rom_0"):
		MusicManager.play("bgm_distantThunder")

	# Create party based on config
	var characters := _get_character_configs()
	for i in range(characters.size()):
		var actor := actor_scene.instantiate() as Actor
		if actor:
			var config: Dictionary = characters[i]
			actor.character_id = config.get("id", 0)
			actor.character_name = config.get("name", "Unknown")
			actor.equipped_weapon_id = config.get("weapon", Constants.Weapon.SWORD)
			actor.global_position = global_position
			actor.facing = Constants.Facing.DOWN
			actor.add_to_group("players")

			# Set class and HP/MP multipliers before adding to tree
			actor.attribute.classId = config.get("classId", 0)
			actor.attribute.HPMultiplier = config.get("HPMultiplier", 3.8)
			actor.attribute.MPMultiplier = config.get("MPMultiplier", 1.0)
			actor.attribute.MPMultiplier2 = config.get("MPMultiplier2", 1.0)
			actor.attribute.MPDivisor = config.get("MPDivisor", 2.0)
			actor.attribute.level = config.get("level", 1)

			get_parent().add_child(actor)
			GameManager.add_player(actor)

			# Magic type and deity levels (GMS2: defineDefaultCharacters)
			actor.enable_magic = config.get("enableMagic", Constants.MAGIC_NONE)
			var deity_levels_arr = config.get("deityLevels", [])
			if deity_levels_arr is Array and deity_levels_arr.size() > 0:
				for di in range(mini(deity_levels_arr.size(), actor.deity_levels.size())):
					actor.deity_levels[di] = int(deity_levels_arr[di])
			else:
				# Fallback: old single deityLevel format
				var deity_lvl: int = int(config.get("deityLevel", 0))
				if deity_lvl > 0:
					for di in range(actor.deity_levels.size()):
						actor.deity_levels[di] = deity_lvl

			# Equip default armor (GMS2: defineDefaultCharacters / setPlayerEquipment)
			actor.equipped_head = config.get("head", -1)
			actor.equipped_body = config.get("body", -1)
			actor.equipped_accessory = config.get("accessory", -1)
			actor.recalculate_gear()

			# Calculate initial stats from class data
			actor.recalculate_stats()
			actor.attribute.hp = actor.attribute.maxHP
			actor.attribute.mp = actor.attribute.maxMP
			actor.refresh_hp_percent()
			actor.refresh_mp_percent()

			# First actor is party leader (player-controlled), rest are AI followers
			if i == 0:
				actor.is_party_leader = true
				actor.player_controlled = true
			else:
				actor.is_party_leader = false
				actor.player_controlled = false

	# GMS2: Actors are persistent across rooms. Restore saved state if transitioning.
	GameManager.restore_actor_states()

	# Ensure non-leader actors start in AI state (IAStand).
	# restore_actor_states() handles this when transitioning between rooms,
	# but on the first room load (no saved states) actors stay in their initial
	# state from the .tscn (e.g. "Stand"), which causes AI actors to not follow
	# or line up correctly during cutscenes.
	for p in GameManager.players:
		if is_instance_valid(p) and p is Actor:
			var a := p as Actor
			if not a.player_controlled and not a.is_dead:
				if a.state_machine_node and a.state_machine_node.has_state("IAStand"):
					a.state_machine_node.switch_state("IAStand")

	# Build pathfinding grid from collision tiles (GMS2: mp_grid_create + mp_grid_add_instances)
	Pathfinding.setup_from_scene(get_tree().current_scene)

	# Setup animated tiles for TileMapLayers that use animated tilesets
	TileAnimator.setup_scene(get_tree().current_scene)

	# Create camera following the party leader
	if GameManager.players.size() > 0:
		var camera := CameraController.new()
		camera.name = "CameraController"
		get_parent().add_child(camera)
		# Follow the actual party leader (may differ after restore)
		var leader: Node = GameManager.get_party_leader()
		camera.camera_set(leader if leader else GameManager.players[0])

func _get_character_configs() -> Array:
	# Load hero definitions from heroes.json (editable via Mana Magic Editor)
	# Falls back to hardcoded defaults if JSON fails to load
	match party_config:
		"default", "boss":
			var heroes := _load_heroes_from_json()
			return _filter_heroes(heroes)
		"debug":
			var heroes := _load_heroes_from_json()
			heroes = _filter_heroes(heroes)
			if heroes.size() > 0:
				return [heroes[0]]  # Debug: only first hero
			return [_fallback_hero()]
		_:
			var heroes := _load_heroes_from_json()
			heroes = _filter_heroes(heroes)
			if heroes.size() > 0:
				return [heroes[0]]
			return [_fallback_hero()]

func _filter_heroes(heroes: Array) -> Array:
	if heroes.size() == 0:
		return heroes
	# If hero_ids_override is set, use only those specific hero IDs
	if hero_ids_override.size() > 0:
		var filtered := []
		for hero in heroes:
			if int(hero.get("id", -1)) in hero_ids_override:
				filtered.append(hero)
		return filtered if filtered.size() > 0 else [heroes[0]]
	# Otherwise, use enabledByDefault flag
	var filtered := []
	for hero in heroes:
		if hero.get("enabledByDefault", true):
			filtered.append(hero)
	return filtered if filtered.size() > 0 else [heroes[0]]

func _load_heroes_from_json() -> Array:
	var path := "res://data/databases/heroes.json"
	if not FileAccess.file_exists(path):
		push_warning("StartingPoint: heroes.json not found, using fallback")
		return [_fallback_hero()]

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("StartingPoint: Failed to open heroes.json")
		return [_fallback_hero()]

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("StartingPoint: Failed to parse heroes.json: %s" % json.get_error_message())
		return [_fallback_hero()]

	var data: Array = json.data if json.data is Array else []
	if data.size() == 0:
		push_warning("StartingPoint: heroes.json is empty")
		return [_fallback_hero()]

	# Convert JSON entries to the config format expected by _spawn_party
	var result := []
	for entry in data:
		result.append({
			"id": int(entry.get("id", 0)),
			"name": str(entry.get("name", "Hero")),
			"weapon": int(entry.get("weapon", 0)),
			"head": int(entry.get("head", -1)),
			"body": int(entry.get("body", -1)),
			"accessory": int(entry.get("accessory", -1)),
			"classId": int(entry.get("classId", 0)),
			"level": int(entry.get("level", 1)),
			"HPMultiplier": float(entry.get("HPMultiplier", 3.8)),
			"MPMultiplier": float(entry.get("MPMultiplier", 1.0)),
			"MPMultiplier2": float(entry.get("MPMultiplier2", 1.0)),
			"MPDivisor": float(entry.get("MPDivisor", 2.0)),
			"enableMagic": int(entry.get("enableMagic", 0)),
			"enabledByDefault": entry.get("enabledByDefault", true),
			"deityLevels": entry.get("deityLevels", []),
			"deityLevel": int(entry.get("deityLevel", 0)),
		})
	return result

static func _fallback_hero() -> Dictionary:
	return {
		"id": 0, "name": "Randi", "weapon": Constants.Weapon.SPEAR,
		"classId": 1, "level": 60,
		"HPMultiplier": 3.8, "MPMultiplier": 4.0, "MPMultiplier2": 2.0, "MPDivisor": 4.0,
		"enableMagic": Constants.MAGIC_NONE, "deityLevel": 0,
		"head": -1, "body": -1, "accessory": -1,
	}
