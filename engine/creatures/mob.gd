class_name Mob
extends Creature
## Enemy/mob - replaces oMob from GMS2

# --- Sprite configuration per mob type ---
const MOB_SPRITE_CONFIG: Dictionary = {
	"slime": {
		"texture": "res://assets/sprites/sheets/spr_mob_slime.png",
		"columns": 8, "fw": 32, "fh": 32, "origin": Vector2(16, 27),
		"walk_up": [0, 4], "walk_right": [6, 10], "walk_down": [12, 16], "walk_left": [18, 22],
		"attack_up": [24, 28], "attack_right": [30, 34], "attack_down": [36, 40], "attack_left": [42, 46],
		"hit": [48, 48, 48, 48],
	},
	"rabite": {
		"texture": "res://assets/sprites/sheets/spr_mob_rabite.png",
		"columns": 4, "fw": 32, "fh": 32, "origin": Vector2(16, 20),
		"walk_up": [0, 1], "walk_right": [0, 1], "walk_down": [0, 1], "walk_left": [0, 1],
		"walk_jump": [2, 4],  # Hop animation (shared for all directions)
		"attack_up": [5, 6], "attack_right": [5, 6], "attack_down": [5, 6], "attack_left": [5, 6],
		"attack2_up": [7, 10], "attack2_right": [7, 10], "attack2_down": [7, 10], "attack2_left": [7, 10],
		"hit": [11, 11, 11, 11],
		"sight_radius": 60.0,
		"rabite_type": true,
	},
	"drago": {
		"texture": "res://assets/sprites/sheets/spr_mob_drago.png",
		"columns": 5, "fw": 32, "fh": 32, "origin": Vector2(16, 25),
		"walk_up": [0, 4], "walk_right": [5, 9], "walk_down": [10, 14], "walk_left": [15, 19],
		"attack_up": [20, 23], "attack_right": [20, 23], "attack_down": [20, 23], "attack_left": [20, 23],
		"hit": [20, 20, 20, 20],
	},
	"flower": {
		"texture": "res://assets/sprites/sheets/spr_mob_flower.png",
		"columns": 5, "fw": 32, "fh": 32, "origin": Vector2(16, 25),
		"walk_up": [0, 4], "walk_right": [5, 9], "walk_down": [10, 14], "walk_left": [15, 19],
		"attack_up": [20, 23], "attack_right": [20, 23], "attack_down": [20, 23], "attack_left": [20, 23],
		"hit": [20, 20, 20, 20],
	},
	"succubus": {
		"texture": "res://assets/sprites/sheets/spr_mob_succubus.png",
		"columns": 5, "fw": 32, "fh": 32, "origin": Vector2(16, 26),
		"walk_up": [0, 4], "walk_right": [5, 9], "walk_down": [10, 14], "walk_left": [15, 19],
		"attack_up": [20, 23], "attack_right": [20, 23], "attack_down": [20, 23], "attack_left": [20, 23],
		"hit": [20, 20, 20, 20],
	},
	"rabbi": {
		"texture": "res://assets/sprites/sheets/spr_mob_rabbi.png",
		"columns": 5, "fw": 128, "fh": 128, "origin": Vector2(65, 84),
		"walk_up": [0, 1], "walk_right": [0, 1], "walk_down": [0, 1], "walk_left": [0, 1],
		"walk_jump": [2, 4],
		"attack_up": [5, 6], "attack_right": [5, 6], "attack_down": [5, 6], "attack_left": [5, 6],
		"attack2_up": [7, 10], "attack2_right": [7, 10], "attack2_down": [7, 10], "attack2_left": [7, 10],
		"hit": [16, 16, 16, 16],
		"sight_radius": 60.0,
		"rabite_type": true,
	},
}

# Mob identity
var mob_id: int = 0
var mob_name: String = ""
var display_name: String = ""
var mob_class_name: String = ""

# AI Configuration
var sight_radius: float = 80.0
var radius_reach_target: float = 14.0  # GMS2: radiusReachTarget — chase→attack transition distance
var radius_attack: float = 28.0  # GMS2: radiusAttack = radiusReachTarget * 2 — attack state damage range
var wander_radius: float = 60.0

# AI timers
var steps_stand_min: int = 60
var steps_stand_max: int = 300
var random_timer_limit: float = 100.0
var attack_cooldown_max: float = 50.0
var random_skill_timer: float = 5.0        # 300 frames / 60 = 5 seconds
var random_skill_oscillation: float = 1.667  # 100 frames / 60 ≈ 1.667 seconds

# Movement
var wander_speed: float = 0.8
var chase_speed: float = 0.5  # GMS2: attribute.runMax = 0.5 for mobs
var avoid_speed: float = 2.0
var knockback_speed: float = 3.0

# Animation speeds (GMS2 oMob defaults: stand=0.1, walk=0.1, attack=0.1)
var img_speed_stand: float = 0.1
var img_speed_walk: float = 0.1
var img_speed_attack: float = 0.1

# Walk animation frames
var spr_walk_up_ini: int = 0; var spr_walk_up_end: int = 3
var spr_walk_right_ini: int = 4; var spr_walk_right_end: int = 7
var spr_walk_down_ini: int = 8; var spr_walk_down_end: int = 11
var spr_walk_left_ini: int = 12; var spr_walk_left_end: int = 15

# Attack animation frames
var spr_attack_up_ini: int = 0; var spr_attack_up_end: int = 3
var spr_attack_right_ini: int = 4; var spr_attack_right_end: int = 7
var spr_attack_down_ini: int = 8; var spr_attack_down_end: int = 11
var spr_attack_left_ini: int = 12; var spr_attack_left_end: int = 15

# Hit animation frames
var spr_hit_up: int = 0
var spr_hit_right: int = 0
var spr_hit_down: int = 0
var spr_hit_left: int = 0

# Current target
var current_target: Node = null
var idle_skills: Array = []
var passive: bool = false
## GMS2: pushable — player can push this mob by walking into it.
## Default true for normal mobs; bosses set this to false.
var pushable: bool = true

# Summon animation frames
var spr_summon_up_ini: int = 0; var spr_summon_up_end: int = 0
var spr_summon_right_ini: int = 0; var spr_summon_right_end: int = 0
var spr_summon_down_ini: int = 0; var spr_summon_down_end: int = 0
var spr_summon_left_ini: int = 0; var spr_summon_left_end: int = 0

# Death animation (GMS2: state_sprDeathAnim)
# 0 = spr_death0 (red burst, 7 frames, default), 1 = spr_death1 (white puff, 17 frames, rabites)
var death_anim_id: int = 0

# Sounds
var snd_hurt: String = ""
var snd_attack: String = ""
var snd_dead: String = ""
var snd_parry: String = ""

# Idle skill tracking
var skill_idle_count: int = 0
var skill_timer: float = 0.0

# Change state flag (matches GMS2 pattern)
var change_state: bool = false

# Rabite-specific properties
var is_rabite: bool = false
var jump_attack_speed: float = 1.5
var attack_distance_bite: float = 30.0
var attack_distance_jump: float = 120.0
var initial_position: Vector2 = Vector2.ZERO  # Spawn point for return-to-spawn

# Extra animation frames (rabite walk-jump, attack2)
var spr_walk_jump_ini: int = 2; var spr_walk_jump_end: int = 4
var spr_attack2_up_ini: int = 7; var spr_attack2_up_end: int = 10
var spr_attack2_right_ini: int = 7; var spr_attack2_right_end: int = 10
var spr_attack2_down_ini: int = 7; var spr_attack2_down_end: int = 10
var spr_attack2_left_ini: int = 7; var spr_attack2_left_end: int = 10

# Boss mob properties (GMS2: oMob_rabbigte Create_0)
var pierce_magic: bool = false  # GMS2: pierceMagic — bypasses WALL protection
var hit_animation_enabled: bool = true  # GMS2: hitAnimationEnabled — show hit flash
var skill_list: Array = []  # GMS2: skillList — skills available for castRandomSkill
var skill_level: int = 1  # GMS2: skillLevel — level used when casting skills
var _skill_index: int = 0
var _random_cast_timer: float = 0.0
var random_cast_timer_limit: float = 5.0  # GMS2: 300 frames / 60 = 5.0 seconds
var boss_bounce_timer: float = 0.0  # GMS2: bounceTimer — for boss bounce (every 0.25 seconds)
var boss_bounce_value: float = 4.0  # GMS2: bounceValue for boss bounce

# Rewards on death (GMS2: experience/money from enemy class)
var exp_reward: int = 0
var money_reward: int = 0

## Name-to-sprite-config alias mapping (GMS2 object names → MOB_SPRITE_CONFIG keys)
const MOB_NAME_ALIASES: Dictionary = {
	"rabbigte": "rabbi",
}

func _ready() -> void:
	super._ready()
	is_npc = false
	# GMS2 oMob defaults - mobs hit harder but don't reduce defense as much
	attribute.attackMultiplier = 11.0
	attribute.attackDivisor = 1.0

	# All mobs must be in "mobs" group for companion AI target detection
	# (mob_spawner adds spawned mobs, but room-placed mobs need it too)
	if not is_in_group("mobs"):
		add_to_group("mobs")

	# Self-initialization for bare nodes placed directly in rooms
	# (room converter placed CharacterBody2D + mob.gd script without sub-nodes)
	_ensure_mob_initialized()


func _ensure_mob_initialized() -> void:
	## Create missing CollisionShape2D, state machine states, and load monster data
	## when this mob was placed as a bare node in a room scene.

	# 1. Ensure CollisionShape2D exists
	if not get_node_or_null("CollisionShape2D"):
		var col_shape := CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(14, 10)
		col_shape.shape = rect
		add_child(col_shape)
		# Set collision layers for enemies (GMS2: oMob collision group)
		collision_layer = 4  # Layer 3 = enemies
		collision_mask = 3   # Layers 1+2 = environment + players

	# 2. Ensure state machine has states
	if state_machine_node and state_machine_node.get_child_count() == 0:
		_create_default_mob_states()

	# 3. Infer monster data from node name if not already loaded
	if mob_name == "" and name.begins_with("mob_"):
		_load_from_node_name()

	# 4. Re-initialize state machine now that states exist
	if state_machine_node and state_machine_node.current_state == null:
		state_machine_node.initialize()


func _create_default_mob_states() -> void:
	## Programmatically create all mob FSM states (normally defined in mob.tscn)
	var state_defs: Array = [
		["Stand", MobStand],
		["Wander", MobWander],
		["Attack", MobAttack],
		["Hit", MobHit],
		["Dead", MobDead],
		["Chase", MobChase],
		["Parry", MobParry],
		["Summon", MobSummon],
		["Animation", MobAnimation],
		["RabiteWander", RabiteWander],
		["RabiteChase", RabiteChase],
		["RabiteAttack", RabiteAttack],
		["RabiteAvoid", RabiteAvoid],
		["RabbigteStand", RabbigteStand],
		["RabbigteChase", RabbigteChase],
		["RabbigteWander", RabbigteWander],
	]
	for state_def in state_defs:
		var state_script: GDScript = state_def[1] as GDScript
		var state: Node = state_script.new()
		state.name = state_def[0]
		state_machine_node.add_child(state)


func _load_from_node_name() -> void:
	## Infer monster type from node name pattern: mob_<type>[_<suffix>]
	## e.g. mob_rabite_1 → "rabite", mob_rabbigte → "rabbigte", mob_rabite_npc → "rabite"
	var stripped: String = name.trim_prefix("mob_")

	# Try exact match first
	var data: Dictionary = Database.get_monster_by_name(stripped)
	if data.is_empty():
		# Strip trailing _N (number) or _npc suffix
		var parts: PackedStringArray = stripped.split("_")
		if parts.size() > 1:
			var last_part: String = parts[parts.size() - 1]
			if last_part.is_valid_int() or last_part == "npc":
				parts.resize(parts.size() - 1)
				stripped = "_".join(parts)
		data = Database.get_monster_by_name(stripped)

	if not data.is_empty():
		load_from_database(data.get("id", 0))
		# Handle sprite config alias (e.g. "rabbigte" → "rabbi" in MOB_SPRITE_CONFIG)
		var original_name: String = str(data.get("name", ""))
		if MOB_SPRITE_CONFIG.get(mob_name, {}).is_empty() and MOB_NAME_ALIASES.has(mob_name):
			mob_name = MOB_NAME_ALIASES[mob_name]
			_init_mob_sprite()
		# Initialize rabbigte boss properties (GMS2: oMob_rabbigte Create_0)
		if original_name == "rabbigte":
			_init_rabbigte_properties()
		# Handle NPC suffix — make passive
		if name.ends_with("_npc"):
			passive = true
	else:
		push_warning("Mob: Could not find monster data for node '%s' (tried '%s')" % [name, stripped])


func get_creature_name() -> String:
	return display_name

func load_from_database(monster_id: int) -> void:
	var data: Dictionary = Database.get_monster(monster_id)
	if data.is_empty():
		push_warning("Monster not found: %d" % monster_id)
		return

	mob_id = data.get("id", 0)
	mob_name = str(data.get("name", ""))
	display_name = data.get("nameText", mob_name)
	mob_class_name = str(data.get("class", "normal"))
	passive = data.get("passive", false)

	# Load enemy class for fallback stats
	var enemy_class: Dictionary = Database.get_enemy_class_by_name(mob_class_name)

	# Level (default 1, can be overridden by spawner)
	attribute.level = data.get("level", 1)

	# HP/MP - use monster-specific values, -1 means calculate from class
	var max_hp: int = int(data.get("max_hp", -1))
	var max_mp: int = int(data.get("max_mp", -1))
	if max_hp > 0:
		attribute.maxHP = max_hp
		attribute.hp = max_hp
	else:
		attribute.maxHP = 100
		attribute.hp = 100

	if max_mp > 0:
		attribute.maxMP = max_mp
		attribute.mp = max_mp
	else:
		attribute.maxMP = 0
		attribute.mp = 0

	# Stats - values of -1 mean "use class default", then scale by level
	attribute.strength = _calc_stat(data, enemy_class, "strength")
	attribute.constitution = _calc_stat(data, enemy_class, "constitution")
	attribute.agility = _calc_stat(data, enemy_class, "agility")
	attribute.luck = _calc_stat(data, enemy_class, "luck")
	attribute.intelligence = _calc_stat(data, enemy_class, "intelligence")
	attribute.wisdom = _calc_stat(data, enemy_class, "wisdom")

	# Calculate EXP/money rewards from enemy class
	_calculate_rewards(data, enemy_class)

	refresh_hp_percent()
	refresh_mp_percent()

	# Elemental weaknesses/protections
	var weaknesses: Array = data.get("magic_weakness", [])
	for i in range(min(weaknesses.size(), Constants.ELEMENT_COUNT)):
		elemental_weakness[i] = weaknesses[i]

	var protections: Array = data.get("magic_protection", [])
	for i in range(min(protections.size(), Constants.ELEMENT_COUNT)):
		elemental_protection[i] = protections[i]

	var atunements: Array = data.get("magic_atunement", [])
	for i in range(min(atunements.size(), Constants.ELEMENT_COUNT)):
		elemental_atunement[i] = atunements[i]

	# Load sprite and animation config
	_init_mob_sprite()


func _calc_stat(monster_data: Dictionary, class_data: Dictionary, stat_name: String) -> int:
	## Calculate a stat using base + growth scaling by level. -1 = use class default.
	var base_val: float = float(monster_data.get("base_" + stat_name, -1))
	var growth_val: float = float(monster_data.get("growth_" + stat_name, -1))

	if base_val < 0:
		base_val = float(class_data.get("base_" + stat_name, 5))
	if growth_val < 0:
		growth_val = float(class_data.get("growth_" + stat_name, 1.5))

	var level: int = attribute.level
	var divisor: float = maxf(1.0, float(Constants.MAX_LEVEL - 1))
	return maxi(1, roundi(base_val + ((growth_val * 50.0) - base_val) / divisor * float(level - 1)))


func _init_mob_sprite() -> void:
	## Load sprite sheet and set animation ranges based on mob_name
	var config: Dictionary = MOB_SPRITE_CONFIG.get(mob_name, {})
	if config.is_empty():
		return

	# Try loading AnimatedSprite2D from animation library (new system)
	var monster_data: Dictionary = Database.get_monster(mob_id)
	var anim_lib_path: String = monster_data.get("animationLibrary", "")
	if anim_lib_path != "" and ResourceLoader.exists(anim_lib_path):
		var sf: SpriteFrames = load(anim_lib_path)
		if sf:
			var origin: Vector2 = config.get("origin", Vector2(16, 16))
			setup_animated_sprite(sf, origin)
			# Still need to set frame ranges for the bridge map
			_init_mob_frame_ranges(config)
			_build_mob_frame_to_anim_map(config)
			return

	# Fallback: legacy Sprite2D system
	var tex: Texture2D = load(config.get("texture", ""))
	if not tex:
		return

	set_sprite_sheet(
		tex,
		config.get("columns", 4),
		config.get("fw", 32),
		config.get("fh", 32),
		config.get("origin", Vector2(16, 16))
	)

	_init_mob_frame_ranges(config)

	# Set default facing animation
	set_default_facing_animations(
		spr_walk_up_ini, spr_walk_right_ini,
		spr_walk_down_ini, spr_walk_left_ini,
		spr_walk_up_end, spr_walk_right_end,
		spr_walk_down_end, spr_walk_left_end
	)
	set_default_facing_index()

func _init_mob_frame_ranges(config: Dictionary) -> void:
	# Walk animation ranges
	var walk_up: Array = config.get("walk_up", [0, 3])
	var walk_right: Array = config.get("walk_right", [4, 7])
	var walk_down: Array = config.get("walk_down", [8, 11])
	var walk_left: Array = config.get("walk_left", [12, 15])
	spr_walk_up_ini = walk_up[0]; spr_walk_up_end = walk_up[1]
	spr_walk_right_ini = walk_right[0]; spr_walk_right_end = walk_right[1]
	spr_walk_down_ini = walk_down[0]; spr_walk_down_end = walk_down[1]
	spr_walk_left_ini = walk_left[0]; spr_walk_left_end = walk_left[1]

	# Attack animation ranges
	var atk_up: Array = config.get("attack_up", walk_up)
	var atk_right: Array = config.get("attack_right", walk_right)
	var atk_down: Array = config.get("attack_down", walk_down)
	var atk_left: Array = config.get("attack_left", walk_left)
	spr_attack_up_ini = atk_up[0]; spr_attack_up_end = atk_up[1]
	spr_attack_right_ini = atk_right[0]; spr_attack_right_end = atk_right[1]
	spr_attack_down_ini = atk_down[0]; spr_attack_down_end = atk_down[1]
	spr_attack_left_ini = atk_left[0]; spr_attack_left_end = atk_left[1]

	# Hit frames (array of 4: up, right, down, left)
	var hit: Array = config.get("hit", [0, 0, 0, 0])
	spr_hit_up = hit[0]
	spr_hit_right = hit[1]
	spr_hit_down = hit[2]
	spr_hit_left = hit[3]

	# Apply per-type AI overrides
	if config.has("sight_radius"):
		sight_radius = config.get("sight_radius")

	# Rabite-specific frame loading
	if config.has("rabite_type"):
		is_rabite = true
		death_anim_id = 1
		mirror_image_directions = true
		initial_position = global_position
		var walk_jump: Array = config.get("walk_jump", [2, 4])
		spr_walk_jump_ini = walk_jump[0]; spr_walk_jump_end = walk_jump[1]
		var atk2_up: Array = config.get("attack2_up", [7, 10])
		var atk2_right: Array = config.get("attack2_right", [7, 10])
		var atk2_down: Array = config.get("attack2_down", [7, 10])
		var atk2_left: Array = config.get("attack2_left", [7, 10])
		spr_attack2_up_ini = atk2_up[0]; spr_attack2_up_end = atk2_up[1]
		spr_attack2_right_ini = atk2_right[0]; spr_attack2_right_end = atk2_right[1]
		spr_attack2_down_ini = atk2_down[0]; spr_attack2_down_end = atk2_down[1]
		spr_attack2_left_ini = atk2_left[0]; spr_attack2_left_end = atk2_left[1]

func _build_mob_frame_to_anim_map(config: Dictionary) -> void:
	_frame_to_anim_map.clear()
	_frame_to_anim_map[spr_walk_up_ini] = "walk"
	_frame_to_anim_map[spr_attack_up_ini] = "attack"
	_frame_to_anim_map[spr_hit_up] = "hit"

	if config.has("rabite_type"):
		_frame_to_anim_map[spr_walk_jump_ini] = "walk_jump"
		_frame_to_anim_map[spr_attack2_up_ini] = "attack2"


func find_nearest_player() -> Node:
	var nearest: Node = null
	var nearest_dist := INF
	for player in GameManager.players:
		if is_instance_valid(player) and not player.is_dead:
			var dist := global_position.distance_to(player.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = player
	return nearest


func is_player_in_sight() -> bool:
	var nearest := find_nearest_player()
	if nearest:
		if global_position.distance_to(nearest.global_position) <= sight_radius:
			return has_line_of_sight(nearest)
	return false


func has_line_of_sight(target: Node) -> bool:
	## Raycast check for walls between mob and target (GMS2: collision_line with oWall)
	if not is_instance_valid(target) or not target is Node2D:
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		(target as Node2D).global_position,
		1  # Collision layer 1 (walls/environment)
	)
	query.exclude = [get_rid()]
	if target is CharacterBody2D:
		query.exclude.append((target as CharacterBody2D).get_rid())
	var result := space.intersect_ray(query)
	# If ray hits nothing, we have clear line of sight
	return result.is_empty()


func is_in_reach_range(target: Node) -> bool:
	## GMS2: distance_to_object(target) < radiusReachTarget — used in chase state
	if target:
		return global_position.distance_to(target.global_position) <= radius_reach_target
	return false


func is_in_attack_range(target: Node) -> bool:
	## GMS2: distance_to_object(target) < radiusAttack — used in attack state
	if target:
		return global_position.distance_to(target.global_position) <= radius_attack
	return false


func look_at_target(target: Node) -> void:
	if not target:
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	facing = get_facing_from_direction(dir)
	new_facing = facing


func cast_random_skill() -> void:
	## GMS2: castRandomSkill — cycle through skill_list and cast on a target
	if skill_list.is_empty():
		return
	var dt: float = get_physics_process_delta_time()
	_random_cast_timer += dt
	var limit_oscillation: float = random_cast_timer_limit + randf_range(-20 / 60.0, 20 / 60.0)
	if _random_cast_timer < limit_oscillation:
		return
	if not is_instance_valid(current_target) or current_target.is_dead:
		return
	_random_cast_timer = 0.0

	# Cycle through skill list (GMS2: skillIndex++)
	if _skill_index >= skill_list.size():
		skill_list.shuffle()
		_skill_index = 0
	var skill_name: String = skill_list[_skill_index]
	_skill_index += 1

	# Target selection (GMS2: castRandomSkill target logic)
	var skill_data: Dictionary = Database.get_skill(skill_name)
	var target_kind: String = skill_data.get("target", "ENEMY")
	var selected_target: Creature = null
	if target_kind == "ALLY":
		selected_target = self
	else:
		# 25% chance to target main player if >1 alive, else random
		var alive_count: int = GameManager.get_alive_players().size()
		if alive_count > 1 and randf() < 0.25:
			selected_target = GameManager.get_party_leader() as Creature
		else:
			selected_target = GameManager.get_random_alive_player() as Creature

	if is_instance_valid(selected_target):
		SkillSystem.cast_skill(skill_name, self, selected_target, skill_level)


func _init_rabbigte_properties() -> void:
	## Set up rabbigte-specific boss properties (GMS2: oMob_rabbigte Create_0)
	creature_is_boss = true
	pushable = false
	hit_animation_enabled = false
	jump_attack_speed = 2.5
	radius_reach_target = 40
	radius_attack = 100
	attack_distance_jump = 100  # GMS2: distanceToAttack = 100 (vs rabite 120)
	pierce_magic = true
	boss_bounce_value = 4.0
	random_cast_timer_limit = 5.0  # 300 / 60.0
	skill_list = ["evilGate"]
	skill_level = 8
	# GMS2: shadowSprite = spr_creature_shadow2 (larger shadow for boss rabite)
	if shadow:
		shadow.scale = Vector2(2.0, 2.0)
	# Start in chase immediately (GMS2: state_init(state_CHASE))
	current_target = GameManager.get_party_leader() if GameManager.players.size() > 0 else null
	# Deferred switch to RabbigteChase after state machine initializes
	call_deferred("_rabbigte_initial_state")


func _rabbigte_initial_state() -> void:
	## Switch to RabbigteChase after state machine is initialized
	if state_machine_node:
		state_machine_node.switch_state("RabbigteChase")


func _calculate_rewards(data: Dictionary, enemy_class: Dictionary) -> void:
	## Calculate EXP and money rewards using enemy class data (GMS2: getCalculatedEnemyStats)
	## Values of -1 in monster data mean "use enemy class defaults"
	var base_exp: float = float(data.get("base_experience", -1))
	var growth_exp: float = float(data.get("growth_experience", -1))
	var base_money: float = float(data.get("base_money", -1))
	var growth_money: float = float(data.get("growth_money", -1))

	# Fallback to enemy class defaults for -1 values
	if base_exp < 0:
		base_exp = float(enemy_class.get("base_experience", 1))
	if growth_exp < 0:
		growth_exp = float(enemy_class.get("growth_experience", 1.5))
	if base_money < 0:
		base_money = float(enemy_class.get("base_money", 1))
	if growth_money < 0:
		growth_money = float(enemy_class.get("growth_money", 1.5))

	# GMS2 formula: reward = round(base + ((growth * 50) - base) / 98 * (level - 1))
	var level: int = attribute.level
	var divisor: float = maxf(1.0, float(Constants.MAX_LEVEL - 1))
	exp_reward = maxi(1, roundi(base_exp + ((growth_exp * 50.0) - base_exp) / divisor * float(level - 1)))
	money_reward = maxi(0, roundi(base_money + ((growth_money * 50.0) - base_money) / divisor * float(level - 1)))
