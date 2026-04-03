class_name Actor
extends Creature
## Player character - replaces oActor from GMS2

# Character identity
var character_id: int = Constants.CharacterId.RANDI
var character_name: String = "Randi"

# Equipment
var equipped_weapon_id: int = Constants.Weapon.SWORD
var equipped_head: int = -1
var equipped_body: int = -1
var equipped_accessory: int = -1

# Equipment levels (per weapon name)
var equipment_levels: Dictionary = {}
var equipment_current_level: Dictionary = {}

# Weapon gauge / overheat
var weapon_gauge: float = 0.0
var weapon_gauge_max_base: float = 110.0  # GMS2: weaponGaugeMaxBase = 110
var overheating: bool = false
var overheat_performed: bool = false  ## GMS2: true after overheat bar fills, waiting for cooldown
var show_weapon_level: bool = false
var charge_ready_played: bool = false  ## GMS2: chargeReadyPlayed - prevents repeat charge-ready sound
var sound_charge_step: float = 0.0  ## GMS2: soundChargeStep - counter for charging loop sound (seconds)
var stop_charging_sound: bool = false  ## GMS2: stopChargingSound - true when max level reached
var overheat_timer: float = 0.0
var overheat_cooldown_limit: float = 0.25  ## GMS2: 15 frames / 60 = 0.25 seconds

# Movement speeds
var walk_speed: float = 1.8
var run_speed: float = 2.8
var walk_charging_speed: float = 1.0  ## GMS2: walkCharging = 1

# Attack chain
var attack_chain: int = 0
var max_combo: int = 3
var charging_counter: float = 0.0
var base_charging_counter: float = 100.0  ## GMS2: baseChargingCounter = 100

# Input group
var input_group: Dictionary = {}

# Weapon attack type for current swing
var weapon_attack_type: int = Constants.WeaponAttackType.SLASH

# Weapon-specific sprite animations (per weapon type per direction)
# Format: [weaponId][attackType] = { up_ini, up_end, right_ini, right_end, ... }
var weapon_sprite_data: Dictionary = {}

# Walk/Run animation frames (with weapon variants)
var spr_walk_up_ini: int = 0; var spr_walk_up_end: int = 3
var spr_walk_right_ini: int = 4; var spr_walk_right_end: int = 7
var spr_walk_down_ini: int = 8; var spr_walk_down_end: int = 11
var spr_walk_left_ini: int = 12; var spr_walk_left_end: int = 15

var spr_run_up_ini: int = 0; var spr_run_up_end: int = 3
var spr_run_right_ini: int = 4; var spr_run_right_end: int = 7
var spr_run_down_ini: int = 8; var spr_run_down_end: int = 11
var spr_run_left_ini: int = 12; var spr_run_left_end: int = 15

var spr_walk_charge_up_ini: int = 0; var spr_walk_charge_up_end: int = 3
var spr_walk_charge_right_ini: int = 4; var spr_walk_charge_right_end: int = 7
var spr_walk_charge_down_ini: int = 8; var spr_walk_charge_down_end: int = 11
var spr_walk_charge_left_ini: int = 12; var spr_walk_charge_left_end: int = 15

# Attack animation frames
var subimg_attack_up_ini: Array = [0, 0, 0]
var subimg_attack_up_end: Array = [3, 3, 3]
var subimg_attack_right_ini: Array = [4, 4, 4]
var subimg_attack_right_end: Array = [7, 7, 7]
var subimg_attack_down_ini: Array = [8, 8, 8]
var subimg_attack_down_end: Array = [11, 11, 11]
var subimg_attack_left_ini: Array = [12, 12, 12]
var subimg_attack_left_end: Array = [15, 15, 15]

# Hit animation frames (directional hurt sprites)
var spr_hit_up_ini: int = 0; var spr_hit_up_end: int = 0
var spr_hit_right_ini: int = 0; var spr_hit_right_end: int = 0
var spr_hit_down_ini: int = 0; var spr_hit_down_end: int = 0
var spr_hit_left_ini: int = 0; var spr_hit_left_end: int = 0

# Hit2 (faint/heavy hit) animation frames
var spr_hit2_up_ini: int = 0; var spr_hit2_up_end: int = 0
var spr_hit2_right_ini: int = 0; var spr_hit2_right_end: int = 0
var spr_hit2_down_ini: int = 0; var spr_hit2_down_end: int = 0
var spr_hit2_left_ini: int = 0; var spr_hit2_left_end: int = 0

# Parry animation frames (static single-frame per direction)
var spr_parry1_up: int = 0; var spr_parry1_right: int = 0
var spr_parry1_down: int = 0; var spr_parry1_left: int = 0
var spr_parry2_up: int = 0; var spr_parry2_right: int = 0
var spr_parry2_down: int = 0; var spr_parry2_left: int = 0

# Healed animation frames (single-frame poses, GMS2: state_sprHealedUpIni = 195..198)
var spr_healed_up: int = 0; var spr_healed_right: int = 0
var spr_healed_down: int = 0; var spr_healed_left: int = 0

# Avoid/dodge animation frames
var spr_avoid_up_ini: int = 0; var spr_avoid_up_end: int = 0
var spr_avoid_right_ini: int = 0; var spr_avoid_right_end: int = 0
var spr_avoid_down_ini: int = 0; var spr_avoid_down_end: int = 0
var spr_avoid_left_ini: int = 0; var spr_avoid_left_end: int = 0

# Summon/cast animation frames
var spr_summon_up_ini: int = 0; var spr_summon_up_end: int = 0
var spr_summon_right_ini: int = 0; var spr_summon_right_end: int = 0
var spr_summon_down_ini: int = 0; var spr_summon_down_end: int = 0
var spr_summon_left_ini: int = 0; var spr_summon_left_end: int = 0

# Recover animation frames (getting up from faint)
var spr_recover_up_ini: int = 0; var spr_recover_up_end: int = 0
var spr_recover_right_ini: int = 0; var spr_recover_right_end: int = 0
var spr_recover_down_ini: int = 0; var spr_recover_down_end: int = 0
var spr_recover_left_ini: int = 0; var spr_recover_left_end: int = 0

# Push animation frames
var spr_push_up_ini: int = 0; var spr_push_up_end: int = 0
var spr_push_right_ini: int = 0; var spr_push_right_end: int = 0
var spr_push_down_ini: int = 0; var spr_push_down_end: int = 0
var spr_push_left_ini: int = 0; var spr_push_left_end: int = 0

# Cutscene animation frames (GMS2 oActor lines 280-289: say no, fall up, say yes)
var spr_look_no_ini: int = 0; var spr_look_no_end: int = 0
var spr_fall_up: int = 0
var spr_look_yes_ini: int = 0; var spr_look_yes_end: int = 0

# Image speeds (GMS2 oActor: walk=0.2, run=0.15, charging=0.1, hurt=0.15, faint=0.08, push=0.1)
var img_speed_walk: float = 0.2
var img_speed_run: float = 0.15
var img_speed_walk_charging: float = 0.1
var img_speed_attack_combo3: float = 0.6
var img_speed_hurt: float = 0.15
var img_speed_faint: float = 0.08
var img_speed_push: float = 0.1

# Control state
var control_is_moving: bool = false
var control_is_running: bool = false
var control_run_held: bool = false
var control_attack_pressed: bool = false
var control_up_held: bool = false
var control_down_held: bool = false
var control_left_held: bool = false
var control_right_held: bool = false

# GMS2: lockRunningDirection — locks directional input when starting to run
# Player is committed to their facing direction while running; only unlocks when run is released
var control_up_locked: bool = false
var control_down_locked: bool = false
var control_left_locked: bool = false
var control_right_locked: bool = false

# Combat
var battle_knockback_speed: float = 2.0  ## GMS2: battle_knockbackSpeed = 2
var battle_avoid_speed: float = 1.0  ## GMS2: battle_avoidSpeed = 1
var walk_pushing_speed: float = 1.0  ## GMS2: walkPushing = 1

# AI strategy patterns (GMS2: attribute.strategyPattern*)
# strategyPatternAttackGuard: 1-4, controls AI sight distance (higher = shorter sight)
# strategyPatternApproachKeepAway: 1=aggressive, 2=balanced, 3=normal range, 4=evasive
var strategy_attack_guard: int = 2
var strategy_approach_keep_away: int = 3
# GMS2: game.weaponRadius[weaponId] - attack range per weapon type
var weapon_radius: float = 20.0
# GMS2: evadeDistanceActionEnabled - AI uses distance-based evasion (disabled for flying bosses)
var evade_distance_action_enabled: bool = true
# GMS2: ignoreCollisionSightDetection - AI skips raycast sight checks (for targeting flying bosses)
var ignore_collision_sight_detection: bool = false

# Debug
var _debug_click_held: bool = false

# Magic type (GMS2: MAGIC_NONE=0, MAGIC_BLACK=1, MAGIC_WHITE=2)
var enable_magic: int = 0

# Summon data (set before switching to Summon state)
var summon_magic: String = ""
var summon_magic_deity: int = 0
var summon_target: Node = null
var summon_target_all: bool = false  # GMS2: selectedTarget == -1 means target all

# Move assisted queue (direction, distance, speed triples)
var move_queue: Array = []

# Deity levels (magic levels per element)
var deity_levels: Array[int] = []

# Running steps (for sound)
var running_steps: int = 0

# GMS2: actorFollowingId - the previous actor in the party chain
# Each follower chases the actor before them, not all chasing the leader
var actor_following: Node = null

# Change state helper
var change_state: bool = false

# Weapon strip overlay (GMS2: weaponMovementStrip drawn on top/below character during movement)
var weapon_sprite: Sprite2D = null
var weapon_animated_strip: AnimatedSprite2D = null  # New system
var _weapon_strip_animated: bool = false
var weapon_strip_sheet: Texture2D = null
var weapon_strip_columns: int = 18
var weapon_strip_origin: Vector2 = Vector2(22, 35)
var swapping_weapon: bool = false
const WEAPON_MOVEMENT_FRAME_LIMIT: int = 260

## Character sprite configurations
const CHARACTER_SPRITES := {
	Constants.CharacterId.RANDI: {
		"texture": "res://assets/sprites/sheets/spr_actor_randi.png",
		"columns": 18, "fw": 46, "fh": 46,
		"origin": Vector2(22, 35),
	},
	Constants.CharacterId.POPOIE: {
		"texture": "res://assets/sprites/sheets/spr_actor_popoie.png",
		"columns": 18, "fw": 46, "fh": 46,
		"origin": Vector2(22, 35),
	},
	Constants.CharacterId.PURIM: {
		"texture": "res://assets/sprites/sheets/spr_actor_purim.png",
		"columns": 18, "fw": 46, "fh": 46,
		"origin": Vector2(22, 35),
	},
}

func _ready() -> void:
	super._ready()
	# GMS2 oActor defaults
	attribute.attackMultiplier = 1.0
	attribute.attackDivisor = 1.4
	_init_deity_levels()
	_init_equipment_levels()
	_init_sprite()
	_init_animation_ranges()
	_init_weapon_strip()
	# Calculate initial gear bonuses from equipped items
	recalculate_gear()
	# Deferred: switch AI followers to IAStand after StateMachine is ready
	call_deferred("_init_ai_state")

func _init_ai_state() -> void:
	if not is_party_leader and not player_controlled:
		if state_machine_node and state_machine_node.has_state("IAStand"):
			state_machine_node.switch_state("IAStand")

func _init_weapon_strip() -> void:
	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponStrip"
	weapon_sprite.region_enabled = true
	weapon_sprite.centered = false  # Match main sprite (centered=false + offset=-origin)
	weapon_sprite.visible = false
	weapon_sprite.z_as_relative = true
	add_child(weapon_sprite)
	_load_weapon_strip()

func _load_weapon_strip() -> void:
	var wname: String = get_weapon_name()
	if equipped_weapon_id in [Constants.Weapon.KNUCKLES, Constants.Weapon.NONE]:
		if weapon_sprite:
			weapon_sprite.visible = false
		if weapon_animated_strip:
			weapon_animated_strip.visible = false
		weapon_strip_sheet = null
		_weapon_strip_animated = false
		return

	var cname: String = character_name.to_lower()

	# Try AnimatedSprite2D .tres first (new system)
	var tres_path: String = "res://assets/animations/weapon_strips/%s_%s/%s_%s_strip.tres" % [cname, wname, cname, wname]
	if _use_animated_sprite and ResourceLoader.exists(tres_path):
		var sf: SpriteFrames = load(tres_path)
		if sf and sf.get_animation_names().size() > 1:  # Has real animations (not just "strip")
			_weapon_strip_animated = true
			if not weapon_animated_strip:
				weapon_animated_strip = AnimatedSprite2D.new()
				weapon_animated_strip.name = "WeaponStripAnim"
				weapon_animated_strip.centered = false
				weapon_animated_strip.z_as_relative = true
				add_child(weapon_animated_strip)
			weapon_animated_strip.sprite_frames = sf
			weapon_animated_strip.offset = -weapon_strip_origin
			weapon_animated_strip.visible = true
			if weapon_sprite:
				weapon_sprite.visible = false
			return

	# Fallback: legacy Sprite2D system
	_weapon_strip_animated = false
	if weapon_animated_strip:
		weapon_animated_strip.visible = false
	var strip_path: String = "res://assets/sprites/sheets/spr_weaponStrip_%s_%s.png" % [cname, wname]
	if ResourceLoader.exists(strip_path):
		weapon_strip_sheet = load(strip_path)
		if weapon_sprite:
			weapon_sprite.texture = weapon_strip_sheet
			var json_path: String = strip_path.replace(".png", ".json")
			if FileAccess.file_exists(json_path):
				var f := FileAccess.open(json_path, FileAccess.READ)
				var json := JSON.new()
				if json.parse(f.get_as_text()) == OK:
					var meta: Dictionary = json.data
					weapon_strip_columns = meta.get("columns", 18)
					weapon_strip_origin = Vector2(meta.get("xorigin", 22), meta.get("yorigin", 35))
			weapon_sprite.offset = -weapon_strip_origin
			weapon_sprite.visible = true
	else:
		weapon_strip_sheet = null
		if weapon_sprite:
			weapon_sprite.visible = false

func _init_sprite() -> void:
	# Try loading AnimatedSprite2D from animation library (new system)
	var hero_data: Dictionary = Database.get_hero(character_id)
	var anim_lib_path: String = hero_data.get("animationLibrary", "")
	if anim_lib_path != "" and ResourceLoader.exists(anim_lib_path):
		var sf: SpriteFrames = load(anim_lib_path)
		if sf:
			var config: Dictionary = CHARACTER_SPRITES.get(character_id, {})
			var origin: Vector2 = config.get("origin", Vector2(22, 35)) if not config.is_empty() else Vector2(22, 35)
			# Keep sheet metadata for weapon strip sync (reverse frame index mapping)
			if not config.is_empty():
				frame_width = config.fw
				frame_height = config.fh
				sprite_columns = config.columns
			setup_animated_sprite(sf, origin)
			return

	# Fallback: legacy Sprite2D system
	var config: Dictionary = CHARACTER_SPRITES.get(character_id, {})
	if config.is_empty():
		return
	var tex: Texture2D = load(config.texture)
	if tex:
		set_sprite_sheet(tex, config.columns, config.fw, config.fh, config.origin)

func _init_animation_ranges() -> void:
	# Standing frames (weapon ready)
	spr_stand_up = 0
	spr_stand_right = 1
	spr_stand_down = 2
	spr_stand_left = 3

	# Walking animation ranges
	spr_walk_up_ini = 5; spr_walk_up_end = 10
	spr_walk_right_ini = 12; spr_walk_right_end = 17
	spr_walk_down_ini = 19; spr_walk_down_end = 24
	spr_walk_left_ini = 26; spr_walk_left_end = 31

	# Running animation ranges
	spr_run_up_ini = 83; spr_run_up_end = 88
	spr_run_right_ini = 90; spr_run_right_end = 95
	spr_run_down_ini = 97; spr_run_down_end = 102
	spr_run_left_ini = 104; spr_run_left_end = 109

	# Walk charging ranges
	spr_walk_charge_up_ini = 38; spr_walk_charge_up_end = 39
	spr_walk_charge_right_ini = 41; spr_walk_charge_right_end = 42
	spr_walk_charge_down_ini = 44; spr_walk_charge_down_end = 45
	spr_walk_charge_left_ini = 47; spr_walk_charge_left_end = 48

	# Hit (hurt) animation ranges (GMS2 oActor lines 229-237)
	spr_hit_up_ini = 111; spr_hit_up_end = 116
	spr_hit_right_ini = 118; spr_hit_right_end = 123
	spr_hit_down_ini = 125; spr_hit_down_end = 130
	spr_hit_left_ini = 132; spr_hit_left_end = 137

	# Hit2 (heavy hit/faint) animation ranges (GMS2 lines 239-247)
	spr_hit2_up_ini = 139; spr_hit2_up_end = 141
	spr_hit2_right_ini = 139; spr_hit2_right_end = 141
	spr_hit2_down_ini = 147; spr_hit2_down_end = 149
	spr_hit2_left_ini = 147; spr_hit2_left_end = 149

	# Recover (getting up from faint) animation ranges (GMS2 lines 249-257)
	spr_recover_up_ini = 141; spr_recover_up_end = 145
	spr_recover_right_ini = 141; spr_recover_right_end = 145
	spr_recover_down_ini = 149; spr_recover_down_end = 153
	spr_recover_left_ini = 149; spr_recover_left_end = 153

	# Push animation ranges (GMS2 lines 219-227)
	spr_push_up_ini = 155; spr_push_up_end = 156
	spr_push_right_ini = 158; spr_push_right_end = 159
	spr_push_down_ini = 161; spr_push_down_end = 162
	spr_push_left_ini = 164; spr_push_left_end = 165

	# Summon/casting animation ranges (GMS2 lines 259-267)
	spr_summon_up_ini = 167; spr_summon_up_end = 172
	spr_summon_right_ini = 174; spr_summon_right_end = 179
	spr_summon_down_ini = 181; spr_summon_down_end = 186
	spr_summon_left_ini = 188; spr_summon_left_end = 193

	# Parry animation frames (single-frame poses, GMS2 lines 359-367)
	spr_parry1_up = 200; spr_parry1_right = 201
	spr_parry1_down = 202; spr_parry1_left = 203
	spr_parry2_up = 200; spr_parry2_right = 204
	spr_parry2_down = 202; spr_parry2_left = 205

	# Healed animation frames (single-frame poses, GMS2 lines 354-357)
	spr_healed_up = 195; spr_healed_right = 196
	spr_healed_down = 197; spr_healed_left = 198

	# Avoid/dodge animation ranges (GMS2 lines 269-277)
	spr_avoid_up_ini = 207; spr_avoid_up_end = 211
	spr_avoid_right_ini = 207; spr_avoid_right_end = 211
	spr_avoid_down_ini = 213; spr_avoid_down_end = 217
	spr_avoid_left_ini = 213; spr_avoid_left_end = 217

	# Attack animation ranges: [PIERCE, SLASH, SWING, BOW, THROW]
	subimg_attack_up_ini = [235, 219, 251, 267, 285]
	subimg_attack_up_end = [237, 221, 253, 269, 287]
	subimg_attack_right_ini = [239, 223, 255, 271, 289]
	subimg_attack_right_end = [241, 225, 257, 274, 291]
	subimg_attack_down_ini = [243, 227, 259, 276, 293]
	subimg_attack_down_end = [245, 229, 261, 278, 295]
	subimg_attack_left_ini = [247, 231, 263, 280, 297]
	subimg_attack_left_end = [249, 233, 265, 283, 299]

	# Cutscene animation frames (GMS2 oActor lines 280-289)
	# "Say no" - head shake, right direction: frames 301-304
	spr_look_no_ini = 301; spr_look_no_end = 304
	# "Depressed / fall up" - sad pose: frame 115 (single frame, same as hit_up_ini)
	spr_fall_up = 115
	# "Say yes / affirm" - nod up direction: frames 306-307
	spr_look_yes_ini = 306; spr_look_yes_end = 307

	# Set default animation (standing)
	set_default_facing_animations(
		spr_walk_up_ini, spr_walk_right_ini, spr_walk_down_ini, spr_walk_left_ini,
		spr_walk_up_end, spr_walk_right_end, spr_walk_down_end, spr_walk_left_end
	)

	# Image speeds (GMS2 oActor: walk=0.2, run=0.15, charging=0.1)
	img_speed_walk = 0.2
	img_speed_run = 0.15
	img_speed_walk_charging = 0.1

	# Set initial stand frame
	set_facing_frame(spr_stand_up, spr_stand_right, spr_stand_down, spr_stand_left)

	# Build frame-to-animation-name bridge map for AnimatedSprite2D
	if _use_animated_sprite:
		_build_frame_to_anim_map()
		# Connect frame_changed signal for weapon strip sync
		if animated_sprite and not animated_sprite.frame_changed.is_connected(_on_animated_frame_changed):
			animated_sprite.frame_changed.connect(_on_animated_frame_changed)

func _build_frame_to_anim_map() -> void:
	## Maps UP-direction frame indices to animation name prefixes.
	## This enables the bridge: old API calls → AnimatedSprite2D named animations.
	_frame_to_anim_map.clear()

	# Single-frame poses (set_facing_frame uses the UP frame as key)
	_frame_to_anim_map[spr_stand_up] = "stand"
	_frame_to_anim_map[spr_parry1_up] = "parry"
	_frame_to_anim_map[spr_parry2_up] = "parry2"
	_frame_to_anim_map[spr_healed_up] = "healed"
	_frame_to_anim_map[spr_fall_up] = "fall_up"

	# Range animations (set_default_facing_animations uses up_ini as key)
	_frame_to_anim_map[spr_walk_up_ini] = "walk"
	_frame_to_anim_map[spr_run_up_ini] = "run"
	_frame_to_anim_map[spr_walk_charge_up_ini] = "walk_charging"
	_frame_to_anim_map[spr_hit_up_ini] = "hit"
	_frame_to_anim_map[spr_hit2_up_ini] = "hit2"
	_frame_to_anim_map[spr_recover_up_ini] = "recover"
	_frame_to_anim_map[spr_push_up_ini] = "push"
	_frame_to_anim_map[spr_summon_up_ini] = "summon"
	_frame_to_anim_map[spr_avoid_up_ini] = "avoid"

	# Attack animations per weapon type (5 types: pierce, slash, swing, bow, throw)
	var attack_type_names := ["pierce", "slash", "swing", "bow", "throw"]
	for i in range(mini(subimg_attack_up_ini.size(), attack_type_names.size())):
		_frame_to_anim_map[subimg_attack_up_ini[i]] = "attack_%s" % attack_type_names[i]

	# Cutscene animations
	_frame_to_anim_map[spr_look_no_ini] = "cutscene_no"
	_frame_to_anim_map[spr_look_yes_ini] = "cutscene_yes"

func _init_deity_levels() -> void:
	deity_levels.resize(Constants.ELEMENT_COUNT)
	# GMS2: deityLevel initialized to 7 for all elements (not 0)
	deity_levels.fill(7)

func _init_equipment_levels() -> void:
	for w in Constants.Weapon.values():
		var wname: String = Constants.Weapon.keys()[w].to_lower()
		equipment_levels[wname] = 0
		equipment_current_level[wname] = 1

func _physics_process(_delta: float) -> void:
	if not input_locked and player_controlled and not GameManager.lock_global_input:
		_read_input()
		# Swap actor check (GMS2: playerInputController - runs outside FSM)
		# GMS2: control_swapActorPressed = keyboard_check_pressed(vk_shift)
		if Input.is_action_just_pressed("swap_actor") and not GameManager.ring_menu_opened:
			GameManager.swap_actor()
	elif GameManager.lock_global_input:
		# Clear all controls when globally locked (dialog showing)
		control_is_moving = false
		control_attack_pressed = false
		control_run_held = false
	# Debug: Ctrl+Click spawns a rabite at mouse position
	if player_controlled and is_party_leader:
		if Input.is_key_pressed(KEY_CTRL) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _debug_click_held:
				_debug_click_held = true
				_debug_spawn_rabite()
		else:
			_debug_click_held = false

func _read_input() -> void:
	control_attack_pressed = Input.is_action_just_pressed("attack")
	control_run_held = Input.is_action_pressed("run")

	# GMS2: lockRunningDirection — when ANY directional lock is active,
	# directional inputs are SKIPPED entirely. The locked direction keeps
	# the player moving. Locks clear only when run button is released.
	var move_locked: bool = control_up_locked or control_down_locked or control_left_locked or control_right_locked
	if not control_run_held:
		# Unlock running directions when run button is released
		control_up_locked = false
		control_down_locked = false
		control_left_locked = false
		control_right_locked = false
		move_locked = false

	if not move_locked:
		control_up_held = Input.is_action_pressed("move_up")
		control_down_held = Input.is_action_pressed("move_down")
		control_left_held = Input.is_action_pressed("move_left")
		control_right_held = Input.is_action_pressed("move_right")
	else:
		# GMS2: playerCollisionController checks (control_leftHeld || control_leftLocked)
		# Locked direction forces movement even if player releases that key
		control_up_held = control_up_locked
		control_down_held = control_down_locked
		control_left_held = control_left_locked
		control_right_held = control_right_locked

	control_is_moving = control_up_held or control_down_held or control_left_held or control_right_held

	# Update facing from input
	if control_is_moving and not movement_input_locked:
		if control_left_held:
			new_facing = Constants.Facing.LEFT
		if control_right_held:
			new_facing = Constants.Facing.RIGHT
		if control_up_held:
			new_facing = Constants.Facing.UP
		if control_down_held:
			new_facing = Constants.Facing.DOWN

## GMS2: lockRunningDirection(direction) - locks one directional input when running starts
func lock_running_direction(dir: int) -> void:
	control_up_locked = false
	control_down_locked = false
	control_left_locked = false
	control_right_locked = false
	match dir:
		Constants.Facing.UP: control_up_locked = true
		Constants.Facing.RIGHT: control_right_locked = true
		Constants.Facing.DOWN: control_down_locked = true
		Constants.Facing.LEFT: control_left_locked = true

# --- Weapon gauge / overheat ---

func start_overheating() -> void:
	overheating = true
	overheat_performed = false
	overheat_timer = 0.0
	attribute.overheat = 0.0  # GMS2: starts at 0 and fills up to overheatTotal
	# GMS2: enableShader(shc_rechargeEnergy) — pulsing glow while recharging
	if is_party_leader:
		var _recharge_shader := load("res://assets/shaders/sha_composite.gdshader") as Shader
		if _recharge_shader:
			var mat := ShaderMaterial.new()
			mat.shader = _recharge_shader
			mat.set_shader_parameter("u_color", Color(0.0, 0.0, 0.0, 0.0))
			enable_shader(mat)

func overheat_controller(change_state: bool = false, delta: float = -1.0) -> void:
	## GMS2: overheatController - 3-phase system:
	## 1. Overheat bar fills up (attribute.overheat increments)
	## 2. Bar full -> play sound + shader, set overheat_performed
	## 3. Cooldown timer -> reset overheating, weapon gauge = 0
	if delta < 0.0:
		delta = get_physics_process_delta_time()
	if not overheating or is_dead:
		return

	if not overheat_performed:
		# Phase 1 & 2: Overheat bar filling up (GMS2: overheat += overheatSpeed)
		attribute.overheat += 60.0 * delta
		# GMS2: shc_rechargeEnergy — animate pulsing glow during recharge
		# ease_in_sine(state_timer_local, minRGB=-0.25, maxRGB=0.10, duration=5)
		if is_party_leader and current_shader:
			var min_rgb: float = -0.25
			var max_rgb: float = 0.10
			var t: float = attribute.overheat
			var val: float = max_rgb * (1.0 - cos(t / 5.0 * PI / 2.0)) + min_rgb
			current_shader.set_shader_parameter("u_color", Color(val, val, val, 0.0))
		var oh_total: float = attribute.get("overheatTotal", 100.0)
		if attribute.overheat >= oh_total:
			attribute.overheat = oh_total
			overheat_performed = true
			overheat_timer = 0.0
			# GMS2: play sound and shader for player-controlled actors
			if is_party_leader:
				# GMS2: shc_rechargeEnergyComplete uses sha_composite with pink tint
				var _recharge_shader := load("res://assets/shaders/sha_composite.gdshader") as Shader
				if _recharge_shader:
					var mat := ShaderMaterial.new()
					mat.shader = _recharge_shader
					mat.set_shader_parameter("u_color", Color(0.92, 0.17, 0.56, 0.0))
					enable_shader(mat)
				MusicManager.play_sfx("snd_attackRecover")
	else:
		# Phase 3: Cooldown timer after overheat completed
		overheat_timer += delta
		if overheat_timer > overheat_cooldown_limit:
			overheating = false
			overheat_performed = false
			weapon_gauge = 0.0  # GMS2: attribute.weaponGauge = 0 on overheat end
			charge_ready_played = false
			overheat_timer = 0.0
			disable_shader()
			# GMS2: optionally change state after overheat finishes
			if change_state:
				if control_attack_pressed:
					state_machine_node.switch_state("ChargingWeapon")
				elif control_is_moving:
					state_machine_node.switch_state("Walk")
				else:
					state_machine_node.switch_state("Stand")

func weapon_level_controller(delta: float = -1.0) -> void:
	## Charges weapon gauge (GMS2: weaponLevelController)
	## Only call from ChargingWeapon and Pushing states.
	## GMS2: no guard on weaponGauge > 0 — always increments
	if delta < 0.0:
		delta = get_physics_process_delta_time()
	if not overheating:
		weapon_gauge += 60.0 * delta  # GMS2: attribute.weaponGauge += 1 per frame
		if weapon_gauge >= weapon_gauge_max_base:
			weapon_gauge = weapon_gauge_max_base
			var weapon_name: String = get_weapon_name()
			var current_lvl: int = equipment_current_level.get(weapon_name, 0)
			var max_lvl: int = equipment_levels.get(weapon_name, 1)
			if current_lvl < max_lvl - 1:
				# Level up weapon charge — advance to next level and reset gauge
				equipment_current_level[weapon_name] = current_lvl + 1
				weapon_gauge = 0.0
			else:
				# GMS2: increments level even at max (needed for release_charged_attack)
				# Then shows ready indicator and plays charge ready sound
				equipment_current_level[weapon_name] = current_lvl + 1
				show_weapon_level = true
				stop_charging_sound = true
				if not charge_ready_played:
					MusicManager.play_sfx("snd_weaponChargeReady")
					charge_ready_played = true
		# GMS2: soundChargeStep — play snd_weaponCharging every 25 frames while charging
		if not stop_charging_sound:
			sound_charge_step += delta
			if sound_charge_step >= 25 / 60.0:
				MusicManager.play_sfx("snd_weaponCharging")
				sound_charge_step = 0.0

# --- Equipment ---

## GMS2: game.weaponRadius per weapon type (AI guard distance)
const WEAPON_RADIUS := {
	Constants.Weapon.SWORD: 25.0,
	Constants.Weapon.AXE: 25.0,
	Constants.Weapon.SPEAR: 25.0,
	Constants.Weapon.WHIP: 50.0,
	Constants.Weapon.BOW: 60.0,
	Constants.Weapon.BOOMERANG: 50.0,
	Constants.Weapon.JAVELIN: 60.0,
}

func set_weapon(weapon_id: int) -> void:
	equipped_weapon_id = weapon_id
	attribute.equipedGearWeaponId = weapon_id
	var wname: String = Constants.Weapon.keys()[weapon_id].to_lower()
	attribute.equipedGearWeaponName = wname
	weapon_radius = WEAPON_RADIUS.get(weapon_id, 25.0)
	_load_weapon_strip()

func get_creature_name() -> String:
	return character_name

func get_weapon_name() -> String:
	return Constants.Weapon.keys()[equipped_weapon_id].to_lower()

func recalculate_gear() -> void:
	## Rebuild attribute.gear from all equipped items (weapon + head + body + accessory).
	## GMS2: setPlayerEquipment sets per-slot gear arrays; getStrength/etc sum them.
	## Godot: we sum everything into attribute.gear which damage_calculator reads directly.
	var total_gear: Dictionary = {}
	var attr_map: Dictionary = {
		Constants.Attribute.STRENGTH: "strength",
		Constants.Attribute.CONSTITUTION: "constitution",
		Constants.Attribute.AGILITY: "agility",
		Constants.Attribute.LUCK: "luck",
		Constants.Attribute.INTELLIGENCE: "intelligence",
		Constants.Attribute.WISDOM: "wisdom",
		Constants.Attribute.MAX_HP: "maxHP",
		Constants.Attribute.MAX_MP: "maxMP",
		Constants.Attribute.CRITICAL_RATE: "criticalRate",
	}

	# Reset elemental arrays before re-summing from equipment
	elemental_protection.fill(0.0)
	elemental_atunement.fill(0.0)
	elemental_weakness.fill(0.0)

	# Sum armor slot bonuses (head, body, accessory)
	var armor_ids: Array[int] = [equipped_head, equipped_body, equipped_accessory]
	for eid in armor_ids:
		if eid < 0:
			continue
		var eq: Dictionary = Database.get_equipment(eid)
		if eq.is_empty():
			continue
		_sum_equipment_attrs(eq, attr_map, total_gear)
		_apply_equipment_elementals(eq)

	# Sum weapon bonuses: find matching weapon equipment by type name
	var wname: String = get_weapon_name()
	for eq in Database.equipments:
		if eq is Dictionary and eq.get("kind", -1) == 0:
			var aux: Dictionary = eq.get("auxData", {})
			if str(aux.get("weaponKindName", "")).to_lower() == wname:
				_sum_equipment_attrs(eq, attr_map, total_gear)
				_apply_equipment_elementals(eq)
				break

	attribute.gear = total_gear
	recalculate_stats()

func _sum_equipment_attrs(eq: Dictionary, attr_map: Dictionary, total: Dictionary) -> void:
	for attr in eq.get("attributes", []):
		if attr is Dictionary:
			var attr_id: int = int(attr.get("id", -1))
			var attr_val: int = int(attr.get("value", 0))
			if attr_map.has(attr_id):
				var key: String = attr_map[attr_id]
				total[key] = total.get(key, 0) + attr_val

func _apply_equipment_elementals(eq: Dictionary) -> void:
	## Add elemental protection/atunement/weakness from equipment
	## GMS2: elementalProtection/Atunement/Weakness arrays contain element IDs.
	## GMS2 uses binary check (count > 0 → apply multiplier), so we increment by 1.
	for elem_id in eq.get("elementalProtection", []):
		if elem_id >= 0 and elem_id < Constants.ELEMENT_COUNT:
			elemental_protection[elem_id] += 1.0
	for elem_id in eq.get("elementalAtunement", []):
		if elem_id >= 0 and elem_id < Constants.ELEMENT_COUNT:
			elemental_atunement[elem_id] += 1.0
	for elem_id in eq.get("elementalWeakness", []):
		if elem_id >= 0 and elem_id < Constants.ELEMENT_COUNT:
			elemental_weakness[elem_id] += 1.0

# --- Leveling System (GMS2: getCalculatedAllyStats / setCreatureLevel) ---

const EXP_BASE_MULTIPLIER: int = 50  # GMS2: game.EXP_baseMultiplier

func add_experience(amount: int) -> void:
	attribute.experience += amount
	_check_level_up()

func _check_level_up() -> void:
	while attribute.level < attribute.maxLevel:
		var exp_needed: int = attribute.level * Constants.EXP_MULTIPLIER
		if attribute.experience >= exp_needed:
			attribute.experience -= exp_needed
			_level_up()
		else:
			break

func _level_up() -> void:
	attribute.level += 1
	recalculate_stats()
	MusicManager.play_sfx("snd_menuSelect")
	# Visual feedback: floating "Level Up!" text
	var scene_root: Node = get_tree().current_scene if get_tree() else null
	if scene_root:
		FloatingNumber.spawn_text(scene_root, global_position, "Level %d!" % attribute.level, Color(1.0, 1.0, 0.3))

func recalculate_stats() -> void:
	## Recalculate all stats based on current level and class
	## GMS2 formula: stat = round(base + ((growth * 50) - base) / 98 * (level - 1))
	var class_data: Dictionary = Database.get_ally_class(attribute.classId)
	if class_data.is_empty():
		return

	var level: int = attribute.level
	var max_level: int = attribute.maxLevel
	var divisor: float = max(1.0, max_level - 1.0)

	var base_str: float = class_data.get("base_strength", 5)
	var base_con: float = class_data.get("base_constitution", 5)
	var base_agi: float = class_data.get("base_agility", 5)
	var base_lck: float = class_data.get("base_luck", 5)
	var base_int: float = class_data.get("base_intelligence", 5)
	var base_wis: float = class_data.get("base_wisdom", 5)

	var growth_str: float = class_data.get("growth_strength", 1.5)
	var growth_con: float = class_data.get("growth_constitution", 1.5)
	var growth_agi: float = class_data.get("growth_agility", 1.5)
	var growth_lck: float = class_data.get("growth_luck", 1.5)
	var growth_int: float = class_data.get("growth_intelligence", 1.5)
	var growth_wis: float = class_data.get("growth_wisdom", 1.5)

	# Linear interpolation between base and max stats
	attribute.strength = roundi(base_str + ((growth_str * EXP_BASE_MULTIPLIER) - base_str) / divisor * (level - 1))
	attribute.constitution = roundi(base_con + ((growth_con * EXP_BASE_MULTIPLIER) - base_con) / divisor * (level - 1))
	attribute.agility = roundi(base_agi + ((growth_agi * EXP_BASE_MULTIPLIER) - base_agi) / divisor * (level - 1))
	attribute.luck = roundi(base_lck + ((growth_lck * EXP_BASE_MULTIPLIER) - base_lck) / divisor * (level - 1))
	attribute.intelligence = roundi(base_int + ((growth_int * EXP_BASE_MULTIPLIER) - base_int) / divisor * (level - 1))
	attribute.wisdom = roundi(base_wis + ((growth_wis * EXP_BASE_MULTIPLIER) - base_wis) / divisor * (level - 1))

	# Calculate HP/MP from stats + gear (GMS2: calculateAllyHP / calculateAllyMP)
	# Gear bonuses affect HP/MP but are NOT baked into base stats
	# (base stats stay clean; damage_calculator reads attribute.gear separately)
	var gear: Dictionary = attribute.get("gear", {})
	var total_con: int = attribute.constitution + gear.get("constitution", 0)
	var total_str: int = attribute.strength + gear.get("strength", 0)
	var total_int: int = attribute.intelligence + gear.get("intelligence", 0)
	var total_wis: int = attribute.wisdom + gear.get("wisdom", 0)

	var old_hp_pct: float = attribute.hpPercent / 100.0
	var old_mp_pct: float = attribute.mpPercent / 100.0

	attribute.maxHP = maxi(1, roundi(
		total_con * attribute.HPMultiplier +
		total_str * attribute.HPMultiplier + attribute.HPExponential
	))
	attribute.maxMP = maxi(0, roundi(
		(total_int * attribute.MPMultiplier +
		 total_wis * attribute.MPMultiplier2) / maxf(0.01, attribute.MPDivisor)
	))

	# Restore HP/MP proportionally
	attribute.hp = clampi(roundi(attribute.maxHP * old_hp_pct), 1, attribute.maxHP)
	attribute.mp = clampi(roundi(attribute.maxMP * old_mp_pct), 0, attribute.maxMP)
	refresh_hp_percent()
	refresh_mp_percent()

# --- Weapon EXP (GMS2: addEquipmentLevelExperience) ---

const WEAPON_EXP_TO_LEVEL: int = 100

func add_weapon_experience(weapon_name: String, amount: int) -> void:
	if not equipment_levels.has(weapon_name):
		return
	var current_exp: int = equipment_levels.get(weapon_name, 0)
	current_exp += amount
	while current_exp >= WEAPON_EXP_TO_LEVEL:
		current_exp -= WEAPON_EXP_TO_LEVEL
		var current_lvl: int = equipment_current_level.get(weapon_name, 1)
		if current_lvl < Constants.MAX_EQUIPMENT_LEVEL:
			equipment_current_level[weapon_name] = current_lvl + 1
	equipment_levels[weapon_name] = current_exp

# --- Actor state checks ---

func is_actor_dead() -> bool:
	return is_dead

func is_actor_busy() -> bool:
	if state_machine_node and state_machine_node.current_state_name in [
		"Attack", "Hit", "Hit2", "Charging", "ChargingWeapon",
		"Summon", "Animation", "StaticAnimation", "Parry", "Recover"
	]:
		return true
	return false

func release_charged_attack() -> void:
	## GMS2: releaseChargedAttack - reset gauge + overheat, then switch to WeaponPower
	weapon_gauge = 0.0
	overheating = false
	attribute.overheat = 0.0
	charge_ready_played = false
	var weapon_name := get_weapon_name()
	var current_lvl: int = equipment_current_level.get(weapon_name, 1)
	if current_lvl > 0 and state_machine_node:
		state_machine_node.switch_state("WeaponPower")
	else:
		show_weapon_level = false
		change_state_stand_dead()

func go_idle() -> void:
	change_state_stand_dead()

func change_state_stand_dead(ignore_status: bool = false) -> void:
	## GMS2: changeStateStandDead - checks isTargetAvailable then routes to Stand/IAGuard.
	## FAINT/PETRIFIED/etc. actors stay in current state until timer expires (no Recover routing).
	## GMS2: checkPygmizedStatus - reaffirm pygmized scale on state transition
	if has_status(Constants.Status.PYGMIZED) and sprite:
		sprite.scale = Vector2(0.5, 0.5)

	# GMS2: isTargetAvailable returns false if FAINT/PETRIFIED/BALLOON/ENGULFED/FROZEN/SNARED
	if not ignore_status and is_movement_blocked():
		# Actor is under hard CC - stay in current state, don't transition
		if is_dead and state_machine_node.has_state("Dead"):
			state_machine_node.switch_state("Dead")
		return

	if is_dead:
		state_machine_node.switch_state("Dead")
	elif player_controlled:
		if control_is_moving and state_machine_node.has_state("Walk"):
			state_machine_node.switch_state("Walk")
		elif state_machine_node.has_state("Stand"):
			state_machine_node.switch_state("Stand")
	else:
		if state_machine_node.has_state("IAGuard"):
			state_machine_node.switch_state("IAGuard")
		elif state_machine_node.has_state("IAStand"):
			state_machine_node.switch_state("IAStand")

# --- Weapon strip overlay (GMS2: oActor Draw_0) ---

func _process(delta: float) -> void:
	super._process(delta)
	_update_weapon_depth()
	# Sync weapon strip position and shader
	var active_weapon_node: Node2D = weapon_animated_strip if _weapon_strip_animated else weapon_sprite
	if active_weapon_node:
		active_weapon_node.position.y = -z_height
		# GMS2: performWeaponShader applies saber shader ONLY to weapon, not character
		if _saber_active and _saber_shader:
			active_weapon_node.material = _saber_shader
			# Remove saber shader from character sprite
			var main_sprite: Node2D = animated_sprite if _use_animated_sprite else sprite
			if main_sprite and main_sprite.material == _saber_shader:
				main_sprite.material = current_shader if current_shader else null
		elif sprite:
			# Non-saber shaders (ghost, flash, etc.) sync to both
			weapon_sprite.material = sprite.material

func set_frame(frame_index: int) -> void:
	super.set_frame(frame_index)
	if not _use_animated_sprite:
		_sync_weapon_strip_frame(frame_index)

## Called when any animation starts — sync weapon strip to the same animation.
func _on_animated_sprite_started() -> void:
	if _weapon_strip_animated and weapon_animated_strip and animated_sprite:
		var anim_name: String = animated_sprite.animation
		if weapon_animated_strip.sprite_frames.has_animation(anim_name):
			# Set animation but DON'T play — we control frames manually
			weapon_animated_strip.animation = anim_name
			weapon_animated_strip.stop()
			weapon_animated_strip.frame = 0
	_sync_weapon_strip_visibility()

## Called by AnimatedSprite2D.frame_changed signal — sync weapon strip frame.
func _on_animated_frame_changed() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if _weapon_strip_animated and weapon_animated_strip:
		# Sync animation and frame — strip is slave, never plays independently
		var anim_name: String = animated_sprite.animation
		if weapon_animated_strip.sprite_frames.has_animation(anim_name):
			if weapon_animated_strip.animation != anim_name:
				weapon_animated_strip.animation = anim_name
				weapon_animated_strip.stop()
			weapon_animated_strip.frame = animated_sprite.frame
		_sync_weapon_strip_visibility()
	else:
		# Legacy: reverse-map to sheet frame index
		var anim_name: String = animated_sprite.animation
		var frame_idx: int = animated_sprite.frame
		var tex: Texture2D = animated_sprite.sprite_frames.get_frame_texture(anim_name, frame_idx)
		if tex is AtlasTexture:
			var atlas_tex: AtlasTexture = tex
			var region: Rect2 = atlas_tex.region
			@warning_ignore("INTEGER_DIVISION")
			var col: int = int(region.position.x) / frame_width
			@warning_ignore("INTEGER_DIVISION")
			var row: int = int(region.position.y) / frame_height
			var sheet_frame: int = row * sprite_columns + col
			_sync_weapon_strip_frame(sheet_frame)

func _sync_weapon_strip_visibility() -> void:
	## Show/hide weapon strip based on game state (both animated and legacy)
	var current_state: String = state_machine_node.current_state_name if state_machine_node else ""
	var in_attack: bool = current_state in ["Attack", "IAAttack"]
	var should_show: bool = not in_attack \
		and not swapping_weapon \
		and not is_dead \
		and not has_status(Constants.Status.FROZEN) \
		and not has_status(Constants.Status.PETRIFIED)
	if _weapon_strip_animated and weapon_animated_strip:
		weapon_animated_strip.visible = should_show
	elif weapon_sprite:
		weapon_sprite.visible = should_show

func _sync_weapon_strip_frame(frame_idx: int) -> void:
	if not weapon_sprite or not weapon_strip_sheet:
		return
	var current_state: String = state_machine_node.current_state_name if state_machine_node else ""
	var in_attack: bool = current_state in ["Attack", "IAAttack"]
	var should_show: bool = not in_attack \
		and not swapping_weapon \
		and frame_idx < WEAPON_MOVEMENT_FRAME_LIMIT \
		and not is_dead \
		and not has_status(Constants.Status.FROZEN) \
		and not has_status(Constants.Status.PETRIFIED)
	weapon_sprite.visible = should_show
	if should_show:
		var col := frame_idx % weapon_strip_columns
		@warning_ignore("INTEGER_DIVISION")
		var row: int = frame_idx / weapon_strip_columns
		weapon_sprite.region_rect = Rect2(
			col * frame_width, row * frame_height,
			frame_width, frame_height
		)

func _update_weapon_depth() -> void:
	## GMS2 oActor Draw_0 depth logic: determines if weapon draws in front or behind actor
	## GMS2: weaponDepth=1 (default) = drawn AFTER body = IN FRONT
	## GMS2: weaponDepth=0 = drawn BEFORE body = BEHIND
	if not weapon_sprite:
		return
	var depth: int = 1  # Default: in front of character (GMS2 default)

	if equipped_weapon_id in [Constants.Weapon.AXE, Constants.Weapon.BOW]:
		if facing == Constants.Facing.UP:
			depth = 0  # Behind when facing up
	elif equipped_weapon_id == Constants.Weapon.JAVELIN:
		if facing == Constants.Facing.DOWN:
			depth = 0  # Behind when facing down
	elif facing == Constants.Facing.DOWN:
		var sn: String = state_machine_node.current_state_name if state_machine_node else ""
		if sn in ["IAGuard", "IAGuardTarget", "ChargingWeapon", "Stand", "Animation", "WeaponPower"]:
			depth = 0  # Behind when facing down in idle/guard states

	# Snare special case
	if has_status(Constants.Status.SNARED) and facing == Constants.Facing.DOWN:
		if equipped_weapon_id in [Constants.Weapon.SWORD, Constants.Weapon.SPEAR,
				Constants.Weapon.BOOMERANG, Constants.Weapon.WHIP]:
			depth = 0

	# depth 1 = in front (z_index +1), depth 0 = behind (z_index -1)
	weapon_sprite.z_index = 1 if depth == 1 else -1


# --- Debug tools ---

func _debug_spawn_rabite() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var mob_scene: PackedScene = preload("res://scenes/creatures/mob.tscn")
	var mob := mob_scene.instantiate() as Mob
	if not mob:
		return
	mob.global_position = mouse_pos
	# add_child first so _ready() creates sprite/state_machine nodes
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(mob)
	# Load data after add_child (sprite node must exist for texture assignment)
	mob.load_from_database(2)  # rabite = id 2
	# Re-initialize state machine now that is_rabite is set —
	# first initialize() ran during _ready() when is_rabite was false,
	# so the mob entered generic Wander instead of RabiteWander.
	if mob.state_machine_node:
		mob.state_machine_node.initialize()
