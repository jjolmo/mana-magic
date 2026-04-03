class_name Creature
extends CharacterBody2D
## Base creature class - replaces oCreature from GMS2
## All actors, mobs, and NPCs extend this

# Sprite and animation
var sprite: Sprite2D
var animated_sprite: AnimatedSprite2D
var _use_animated_sprite: bool = false
var _anim_paused_by_ring_menu: bool = false
var shadow: Sprite2D
var state_machine_node: StateMachine

# Z-axis (pseudo-3D height)
var z_height: float = 0.0
var z_gravity: float = 0.125  # GMS2: gravSpeed=1, applied as gravSpeed/8 = 0.125
var z_velocity: float = 0.0

# Facing direction
var facing: int = Constants.Facing.DOWN
var new_facing: int = Constants.Facing.DOWN

# Animation subimage ranges per direction
var sprite_sheet: Texture2D
var frame_width: int = 46
var frame_height: int = 46
var sprite_origin: Vector2 = Vector2(23, 38)
var current_frame: int = 0
var image_speed: float = 0.1  # GMS2 default: state_imgSpeedWalk = 0.1
var _frame_accumulator: float = 0.0
var sprite_columns: int = 1  # columns in the spritesheet

# GMS2: mirrorImageAnimationDirections - flip sprite horizontally for DOWN/LEFT
# Used by rabite-type mobs that only have UP/RIGHT sprites
var mirror_image_directions: bool = false

# Directional animation ranges (subimage indices)
var spr_stand_up: int = 0
var spr_stand_right: int = 0
var spr_stand_down: int = 0
var spr_stand_left: int = 0

var spr_up_ini: int = 0
var spr_up_end: int = 0
var spr_right_ini: int = 0
var spr_right_end: int = 0
var spr_down_ini: int = 0
var spr_down_end: int = 0
var spr_left_ini: int = 0
var spr_left_end: int = 0

# Attributes
var attribute: Dictionary = {
	"hp": 100,
	"mp": 0,
	"maxHP": 100,
	"maxMP": 0,
	"hpPercent": 100.0,
	"mpPercent": 0.0,
	"level": 1,
	"strength": 5,
	"constitution": 5,
	"agility": 5,
	"luck": 5,
	"intelligence": 5,
	"wisdom": 5,
	"walkSpeed": 1.8,
	"walkMax": 1.8,
	"runMax": 2.8,
	"walkCharging": 0.8,
	"walkSpeedAttacking1": 0.5,
	"walkSpeedAttacking2": 1.2,
	"criticalRate": 5,
	"criticalMultiplier": 2.0,  # GMS2: oActor=2, oMob=2
	"weaponGauge": 0.0,
	"weaponGaugeMaxBase": 100.0,
	"overheat": 0.0,
	"statusList": [],
	"equipedGearWeaponId": 0,
	"equipedGearWeaponName": "sword",
	"experience": 0,
	"maxLevel": 99,
	"classId": 0,
	"HPMultiplier": 3.8,
	"HPMultiplier2": 0.0,
	"HPExponential": 0.0,
	"MPMultiplier": 1.0,
	"MPMultiplier2": 1.0,
	"MPDivisor": 2.0,
	"gear": {},
	"attackMultiplier": 1.0,  # GMS2: oCreature default 1, oMob default 11
	"attackDivisor": 1.0,     # GMS2: oActor 1.4, oMob 1
	"weaponLevelDamageMultiplier": 0.6,  # GMS2: oActor default 0.6
	"overheatTotal": 100.0,   # GMS2: overheatTotal for proportional damage calc
	"randomDamagePercent": 15.0,  # GMS2: ±15% damage oscillation (oActor=15, oMob=15)
}

# Status effects
var status_effects: Array[bool] = []
var status_timers: Array[float] = []

# Elemental attributes
var elemental_weakness: Array[float] = []
var elemental_protection: Array[float] = []
var elemental_atunement: Array[float] = []

# State flags
var is_dead: bool = false
var reviving: bool = false  # GMS2: prevents double-revive (two casters targeting same dead actor)
var is_invulnerable: bool = false
var is_untargetable: bool = false
var is_boss: bool = false
var creature_is_boss: bool = false
var is_npc: bool = false
var is_asset: bool = false
var player_controlled: bool = false
var is_party_leader: bool = false

# GMS2: pauseCreature() system - freezes creature during spell/skill animations
var paused: bool = false
var _resume_pause_next_switch: bool = false

# Combat
var damage_stack: Array = []
var attacked: bool = false
var attacking: Node = null  # GMS2: target this creature is currently attacking (for AI conflict detection)
var last_creature_attacked: Node = null  # GMS2: lastCreatureAttacked - last target this creature successfully hit (for leader protection AI)
var state_protect: bool = false  # When true, creature can't be interrupted by hits
var _invuln_timer: float = 0.0  # Post-hit invulnerability (seconds)


# Movement
var move_speed: float = 1.8
var movement_input_locked: bool = false
var input_locked: bool = false

# Shader
var current_shader: ShaderMaterial = null

func _ready() -> void:
	_ensure_child_nodes()
	_init_status_effects()
	_init_elemental_arrays()
	z_index = 0
	y_sort_enabled = false  # Parent should have y_sort

func _ensure_child_nodes() -> void:
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	shadow = get_node_or_null("Shadow") as Sprite2D
	if not shadow:
		shadow = Sprite2D.new()
		shadow.name = "Shadow"
		shadow.position = Vector2(0, -1)
		add_child(shadow)
	shadow.z_index = -1
	# GMS2: shadowSprite = spr_creature_shadow (12x6 dark ellipse)
	# Load texture once; shadow stays at creature's feet (GMS2: drawCreatureShadow mode 0)
	# GMS2 draws shadow ALWAYS (drawShadow=true), not just when airborne
	if shadow and not shadow.texture:
		var shadow_tex: Texture2D = load("res://assets/sprites/spr_creature_shadow/shadow.png")
		if shadow_tex:
			shadow.texture = shadow_tex
			shadow.centered = true
			shadow.modulate = Color(1, 1, 1, 1)  # GMS2: c_white, alpha 1.0 (no tint)
			shadow.visible = true
	state_machine_node = get_node_or_null("StateMachine") as StateMachine
	if not state_machine_node:
		state_machine_node = StateMachine.new()
		state_machine_node.name = "StateMachine"
		add_child(state_machine_node)

func _init_status_effects() -> void:
	status_effects.resize(Constants.STATUS_COUNT)
	status_effects.fill(false)
	status_timers.resize(Constants.STATUS_COUNT)
	status_timers.fill(0.0)
	attribute.statusList = status_effects

func _init_elemental_arrays() -> void:
	elemental_weakness.resize(Constants.ELEMENT_COUNT)
	elemental_weakness.fill(0.0)
	elemental_protection.resize(Constants.ELEMENT_COUNT)
	elemental_protection.fill(0.0)
	elemental_atunement.resize(Constants.ELEMENT_COUNT)
	elemental_atunement.fill(0.0)

func get_elemental_damage_multiplier(element: int, _attack_type: int) -> float:
	## Returns elemental damage multiplier for a given element and attack type.
	## GMS2: calculateElementalDamage() - binary check with 1.5x multipliers.
	## If creature has ANY weakness to element → damage *= 1.5
	## If creature has ANY protection against element → damage /= 1.5
	## Bosses can override for different weapon vs magic multipliers.
	if element < 0 or element >= Constants.ELEMENT_COUNT:
		return 1.0
	var mult := 1.0
	if elemental_weakness[element] > 0:
		mult *= 1.5
	if elemental_protection[element] > 0:
		mult /= 1.5
	return mult

func _process(delta: float) -> void:
	_update_draw_order()
	_update_invuln_flash(delta)
	# GMS2: game.ringMenuOpened pauses all creature game logic
	if GameManager.ring_menu_opened:
		if _use_animated_sprite and animated_sprite and animated_sprite.is_playing():
			animated_sprite.pause()
			_anim_paused_by_ring_menu = true
		_update_sprite_position()
		return
	# Resume AnimatedSprite2D if it was paused by ring menu
	if _anim_paused_by_ring_menu and _use_animated_sprite and animated_sprite:
		animated_sprite.play()
		_anim_paused_by_ring_menu = false
	# Game logic: delta-time based (was 60fps accumulator)
	# NOTE: z-axis physics is handled in state_machine._physics_process (after state execution)
	# to match GMS2's End Step zAxisController order and ensure bounce z_velocity is processed
	# in the same physics frame it's set, avoiding cross-callback timing issues.
	_update_status_timers(delta)
	_update_contact_damage(delta)
	if _invuln_timer > 0:
		_invuln_timer -= delta
		if _invuln_timer <= 0:
			_invuln_timer = 0.0
			is_invulnerable = false
	# Rendering: sprite position reflects z_height updated in _physics_process.
	# (GMS2: Draw event runs after End Step which has zAxisController)
	_update_sprite_position()

func _update_z_axis(delta: float = 0.0167) -> void:
	## GMS2 zAxisController (End Step): velocity applied first, then gravity.
	## Called from state_machine._physics_process AFTER state execution,
	## matching GMS2's End Step order (zAxisController runs after Step event).
	## Multiplied by delta * 60.0 to preserve same physics feel as the original 60fps code.
	if z_height > 0 or z_velocity != 0:
		z_height += z_velocity * delta * 60.0
		z_velocity -= z_gravity * delta * 60.0
		if z_height <= 0:
			z_height = 0
			z_velocity = 0

func _update_sprite_position() -> void:
	if _use_animated_sprite and animated_sprite:
		animated_sprite.position.y = -z_height
	elif sprite:
		sprite.position.y = -z_height
	# GMS2: drawCreatureShadow — shadow stays at creature's feet on ground.
	# Shadow is ALWAYS visible (GMS2: drawShadow=true for mobs/actors).
	# Position stays fixed; only sprite moves up/down with z_height.

func _update_draw_order() -> void:
	# Y-sorting: higher Y = drawn later (on top)
	z_index = int(global_position.y)

var _invuln_flash_acc: float = 0.0
const _INVULN_FLASH_INTERVAL: float = 1.0 / 30.0  # Toggle visibility every ~2 frames at 60fps

func _update_invuln_flash(delta: float) -> void:
	## GMS2: flickSprite() toggles image_alpha 0/1 each frame during invulnerability.
	## Both sprite AND shadow flicker in sync (GMS2 uses draw_sprite_ext with image_alpha).
	var active_sprite: Node2D = animated_sprite if _use_animated_sprite else sprite
	if active_sprite and _invuln_timer > 0:
		_invuln_flash_acc += delta
		if _invuln_flash_acc >= _INVULN_FLASH_INTERVAL:
			_invuln_flash_acc -= _INVULN_FLASH_INTERVAL
			active_sprite.visible = not active_sprite.visible
			if shadow:
				shadow.visible = active_sprite.visible
	elif active_sprite and _invuln_flash_acc > 0.0:
		# Invulnerability ended - ensure sprite + shadow are visible
		active_sprite.visible = true
		if shadow:
			shadow.visible = true
		_invuln_flash_acc = 0.0

var _poison_tick_timer: float = 0.0
var _poison_sfx_timer: float = 0.0  # Separate timer for poison sfx (every 0.4s)
var _engulf_flip_timer: float = 0.0  # Timer for engulf face-flipping (every 0.5s)

func _update_status_timers(delta: float) -> void:
	for i in range(Constants.STATUS_COUNT):
		if status_effects[i] and status_timers[i] > 0:
			status_timers[i] -= delta
			if status_timers[i] <= 0:
				# GMS2: refreshStatusAnimationEffects - show "magic faded" for buff expiry on actors
				if i >= Constants.STATUS_BUFF_START and not (self is Mob):
					GameManager.add_battle_dialog(get_creature_name() + "'s magic faded")
				remove_status(i)

	# Poison/Engulfed DoT: 1% max HP every 0.5s (GMS2: AILMENT_UPDATE_SECONDS = 30 frames = 0.5s)
	# GMS2: poison can't kill (hp - damage > 0 check)
	var is_dot_active: bool = (has_status(Constants.Status.POISONED) or has_status(Constants.Status.ENGULFED)) and not is_dead
	if is_dot_active:
		_poison_tick_timer += delta
		_poison_sfx_timer += delta
		# GMS2: poisonTickTimer = 24 frames = 0.4s (defineGeneralParameters.gml line 36)
		if _poison_sfx_timer >= 0.4:
			_poison_sfx_timer -= 0.4
			MusicManager.play_sfx("snd_poisonTick")
		if _poison_tick_timer >= 0.5:
			_poison_tick_timer -= 0.5
			var dot_dmg: int = maxi(1, roundi(float(attribute.maxHP) * 0.01))
			if attribute.hp - dot_dmg > 0:
				attribute.hp -= dot_dmg
				refresh_hp_percent()

	# GMS2: Engulfed face-flipping animation - toggle LEFT/RIGHT every 0.5s
	# manageStatusAilments: inside 30-frame gate, engulf.image_xscale flips AND state_facing toggles
	if has_status(Constants.Status.ENGULFED) and not is_dead:
		_engulf_flip_timer += delta
		if _engulf_flip_timer >= 0.5:  # GMS2: AILMENT_UPDATE_SECONDS = 30 frames = 0.5s
			_engulf_flip_timer -= 0.5
			# GMS2: engulf.image_xscale = (engulf.image_xscale == 1) ? -1 : 1
			# Flip the fire sprite horizontally
			if is_instance_valid(_status_engulf_anim) and _status_engulf_anim.sprite:
				_status_engulf_anim.sprite.flip_h = not _status_engulf_anim.sprite.flip_h
			# GMS2: also toggles creature facing/image_index
			if mirror_image_directions:
				# For mirror-image sprites, toggle facing to trigger x-flip
				facing = Constants.Facing.RIGHT if facing == Constants.Facing.LEFT else Constants.Facing.LEFT
			elif sprite:
				sprite.flip_h = not sprite.flip_h
	else:
		_engulf_flip_timer = 0.0

	# Balloon float effect: bob sprite upward (frame-rate independent lerp)
	if has_status(Constants.Status.BALLOON) and sprite:
		_status_balloon_offset = lerpf(_status_balloon_offset, 20.0, 1.0 - pow(1.0 - 0.02, delta * 60.0))
		sprite.position.y = -z_height - _status_balloon_offset

	# Saber weapon buff: palette swap shader
	_update_saber_visual()

var _saber_shader: ShaderMaterial = null
var _saber_active: bool = false
var _current_saber_id: int = -1  ## Tracks which saber is currently shown

# Saber element → shader config: [color_channel, color_add_r, color_add_g, color_add_b]
# Values from GMS2 getWeaponShaderAtunement(): channel + RGB 0-255 normalized to 0-1
# Channel: 0=RED, 1=GREEN, 2=BLUE, 3=WHITE(all)
const SABER_SHADER_CONFIG: Dictionary = {
	Constants.Status.BUFF_WEAPON_UNDINE: [1, 0.0, 0.0, 1.0],             # Ice - Blue
	Constants.Status.BUFF_WEAPON_GNOME: [3, 0.498, 0.498, 0.498],        # Stone - Grayscale
	Constants.Status.BUFF_WEAPON_SYLPHID: [1, 0.776, 0.020, 0.765],      # Thunder - Purple
	Constants.Status.BUFF_WEAPON_SALAMANDO: [1, 1.0, 0.431, 0.196],      # Flame - Orange/Red
	Constants.Status.BUFF_WEAPON_SHADE: [3, 0.0, 0.0, 0.0],              # Dark - Black
	Constants.Status.BUFF_WEAPON_LUNA: [1, 0.729, 0.969, 0.165],         # Moon - Cyan/Teal
	Constants.Status.BUFF_WEAPON_LUMINA: [1, 0.0, 0.957, 0.620],         # Light - Green/Yellow
	Constants.Status.BUFF_WEAPON_DRYAD: [1, 0.0, 0.984, 0.365],         # Nature - Green
}

func _update_saber_visual() -> void:
	if not sprite:
		return
	var active_saber: int = _get_active_saber()
	if active_saber >= 0:
		# GMS2: performWeaponShader() re-applies the saber shader every Draw frame.
		# When switching sabers (e.g. iceSaber → flameSaber), the old status is removed
		# and the new one added. We must detect the change and update the shader colors.
		if not _saber_active or active_saber != _current_saber_id:
			_saber_active = true
			_current_saber_id = active_saber
			var config: Array = SABER_SHADER_CONFIG.get(active_saber, [3, 0.0, 0.0, 0.0])
			_saber_shader = ShaderMaterial.new()
			_saber_shader.shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
			_saber_shader.set_shader_parameter("u_color_channel", config[0])
			_saber_shader.set_shader_parameter("u_color_add", Vector3(config[1], config[2], config[3]))
			_saber_shader.set_shader_parameter("u_color_limit", 0.4)
			sprite.material = _saber_shader
	elif _saber_active:
		_saber_active = false
		_current_saber_id = -1
		_saber_shader = null
		if current_shader:
			sprite.material = current_shader
		else:
			sprite.material = null

func _get_active_saber() -> int:
	for status_id in SABER_SHADER_CONFIG:
		if has_status(status_id):
			return status_id
	return -1

# --- Animation ---

func set_sprite_sheet(texture: Texture2D, columns: int, fw: int, fh: int, origin: Vector2 = Vector2.ZERO) -> void:
	sprite_sheet = texture
	sprite_columns = columns
	frame_width = fw
	frame_height = fh
	sprite_origin = origin
	if sprite:
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.centered = false  # Required for offset = -origin to place sprite origin at node position
		sprite.region_rect = _get_frame_rect(0)
		sprite.offset = -origin

func set_frame(frame_index: int) -> void:
	# Don't change frame while a status sprite is active (frozen/petrified).
	if _status_sprite_swapped:
		return
	# AnimatedSprite2D bridge: set_frame is a no-op when using named animations.
	# (Weapon strip sync is handled separately via frame_changed signal.)
	if _use_animated_sprite:
		return
	current_frame = frame_index
	if sprite and sprite_sheet:
		sprite.region_rect = _get_frame_rect(frame_index)
		if mirror_image_directions:
			sprite.flip_h = (facing == Constants.Facing.DOWN or facing == Constants.Facing.LEFT)

func _get_frame_rect(frame_index: int) -> Rect2:
	var col := frame_index % sprite_columns
	@warning_ignore("INTEGER_DIVISION")
	var row: int = frame_index / sprite_columns
	return Rect2(col * frame_width, row * frame_height, frame_width, frame_height)

## Bridge: frame index → animation prefix map. Populated by subclasses (actor.gd).
## Maps the UP direction's ini frame to the animation name prefix.
## e.g., { 5: "walk", 83: "run", 219: "attack_slash", ... }
var _frame_to_anim_map: Dictionary = {}

## Current animation prefix set by set_default_facing_animations bridge.
var _current_anim_prefix: String = ""
## Track if animated sprite is already playing the right animation to avoid restarts.
var _last_played_anim: String = ""

func animate_sprite(speed: float = -1.0, stop_on_last: bool = false, delta: float = -1.0) -> bool:
	if _status_sprite_swapped:
		return false
	# ─── AnimatedSprite2D bridge ───
	if _use_animated_sprite and animated_sprite:
		if _current_anim_prefix != "":
			set_facing_animation(_current_anim_prefix)
		# Return true when a non-looping animation has finished
		if stop_on_last:
			return not animated_sprite.is_playing()
		return false
	# ─── Legacy Sprite2D path ───
	if speed >= 0:
		image_speed = speed

	var ini: int
	var end: int
	match facing:
		Constants.Facing.UP:
			ini = spr_up_ini; end = spr_up_end
		Constants.Facing.RIGHT:
			ini = spr_right_ini; end = spr_right_end
		Constants.Facing.DOWN:
			ini = spr_down_ini; end = spr_down_end
		Constants.Facing.LEFT:
			ini = spr_left_ini; end = spr_left_end
		_:
			ini = spr_down_ini; end = spr_down_end

	if delta < 0.0:
		delta = get_physics_process_delta_time()
	_frame_accumulator += image_speed * delta * 60.0
	if _frame_accumulator >= 1.0:
		_frame_accumulator -= 1.0
		current_frame += 1

	if current_frame > end or current_frame < ini:
		if stop_on_last:
			current_frame = end
			image_speed = 0
		else:
			current_frame = ini
		set_frame(current_frame)
		return true

	set_frame(current_frame)
	return false

func set_facing_frame(up: int, right: int, down: int, left: int) -> void:
	# ─── AnimatedSprite2D bridge ───
	if _use_animated_sprite and animated_sprite:
		# Look up animation name from the UP frame index
		var prefix: String = _frame_to_anim_map.get(up, "")
		if prefix != "":
			set_facing_animation(prefix)
			animated_sprite.stop()  # Single-frame pose — stop after showing first frame
		return
	# ─── Legacy path ───
	match facing:
		Constants.Facing.UP: set_frame(up)
		Constants.Facing.RIGHT: set_frame(right)
		Constants.Facing.DOWN: set_frame(down)
		Constants.Facing.LEFT: set_frame(left)

func set_default_facing_animations(up_ini: int, right_ini: int, down_ini: int, left_ini: int,
		up_end: int, right_end: int, down_end: int, left_end: int) -> void:
	spr_up_ini = up_ini; spr_up_end = up_end
	spr_right_ini = right_ini; spr_right_end = right_end
	spr_down_ini = down_ini; spr_down_end = down_end
	spr_left_ini = left_ini; spr_left_end = left_end
	# ─── AnimatedSprite2D bridge ───
	if _use_animated_sprite:
		var prefix: String = _frame_to_anim_map.get(up_ini, "")
		if prefix != "":
			_current_anim_prefix = prefix

func set_default_facing_index() -> void:
	# ─── AnimatedSprite2D bridge ───
	if _use_animated_sprite and animated_sprite:
		if _current_anim_prefix != "":
			set_facing_animation(_current_anim_prefix)
		return
	# ─── Legacy path ───
	set_facing_frame(spr_up_ini, spr_right_ini, spr_down_ini, spr_left_ini)

# --- AnimatedSprite2D (new system) ---

## Set up the creature to use AnimatedSprite2D with a SpriteFrames resource.
## Once called, play_animation() and set_facing_animation() become active.
## The old Sprite2D is hidden; all animation goes through AnimatedSprite2D.
func setup_animated_sprite(sprite_frames: SpriteFrames, origin: Vector2 = Vector2.ZERO) -> void:
	if not sprite_frames:
		push_warning("setup_animated_sprite: null SpriteFrames")
		return
	_use_animated_sprite = true
	if not animated_sprite:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.offset = -origin
	animated_sprite.centered = false
	animated_sprite.visible = true
	# Hide old sprite
	if sprite:
		sprite.visible = false

## Play a named animation (e.g., "walk_up", "attack_slash_down").
func play_animation(anim_name: String, speed_override: float = -1.0) -> void:
	if not _use_animated_sprite or not animated_sprite:
		return
	if _status_sprite_swapped:
		return
	if animated_sprite.sprite_frames.has_animation(anim_name):
		var changed := (animated_sprite.animation != anim_name)
		if speed_override > 0:
			animated_sprite.speed_scale = speed_override
		else:
			animated_sprite.speed_scale = 1.0
		animated_sprite.play(anim_name)
		if changed:
			_on_animated_sprite_started()

## Play the animation matching prefix + direction suffix based on current facing.
## e.g., set_facing_animation("walk") plays "walk_up"/"walk_right"/etc.
## Handles mirror_image_directions automatically.
func set_facing_animation(prefix: String) -> void:
	if not _use_animated_sprite or not animated_sprite:
		return
	if _status_sprite_swapped:
		return
	var dir_suffix: String
	var do_flip: bool = false
	if mirror_image_directions:
		match facing:
			Constants.Facing.UP: dir_suffix = "_up"; do_flip = false
			Constants.Facing.RIGHT: dir_suffix = "_right"; do_flip = false
			Constants.Facing.DOWN: dir_suffix = "_up"; do_flip = true
			Constants.Facing.LEFT: dir_suffix = "_right"; do_flip = true
			_: dir_suffix = "_up"; do_flip = true
	else:
		match facing:
			Constants.Facing.UP: dir_suffix = "_up"
			Constants.Facing.RIGHT: dir_suffix = "_right"
			Constants.Facing.DOWN: dir_suffix = "_down"
			Constants.Facing.LEFT: dir_suffix = "_left"
			_: dir_suffix = "_down"
	var anim_name := prefix + dir_suffix
	if animated_sprite.sprite_frames.has_animation(anim_name):
		var changed := (animated_sprite.animation != anim_name)
		animated_sprite.play(anim_name)
		animated_sprite.flip_h = do_flip
		if changed:
			_on_animated_sprite_started()
	elif animated_sprite.sprite_frames.has_animation(prefix):
		var changed := (animated_sprite.animation != prefix)
		animated_sprite.play(prefix)
		animated_sprite.flip_h = do_flip
		if changed:
			_on_animated_sprite_started()

## Virtual callback: called when an animation starts playing via the new system.
## Subclasses (actor.gd) override to sync weapon strips on the first frame.
func _on_animated_sprite_started() -> void:
	pass

## Check if the current animation has finished playing (for non-looping animations).
func is_animation_finished() -> bool:
	if _use_animated_sprite and animated_sprite:
		return not animated_sprite.is_playing()
	return true

## Stop the current animation on the current frame.
func stop_animation() -> void:
	if _use_animated_sprite and animated_sprite:
		animated_sprite.stop()

## Get the name of the currently playing animation.
func get_current_animation() -> String:
	if _use_animated_sprite and animated_sprite:
		return animated_sprite.animation
	return ""

# --- Status Effects ---

## Mutually exclusive hard-CC debuffs (GMS2: applying any one clears the rest)
const EXCLUSIVE_CC_GROUP: Array[int] = [
	Constants.Status.PYGMIZED,
	Constants.Status.PETRIFIED,
	Constants.Status.FROZEN,
	Constants.Status.BALLOON,
	Constants.Status.ENGULFED,
	Constants.Status.FAINT,
	Constants.Status.SNARED,
]

## Statuses that TRIGGER the exclusive CC group cleanup (includes CONFUSED which is not itself removed)
const CC_TRIGGER_GROUP: Array[int] = [
	Constants.Status.PYGMIZED,
	Constants.Status.FAINT,
	Constants.Status.CONFUSED,
	Constants.Status.BALLOON,
	Constants.Status.PETRIFIED,
	Constants.Status.ENGULFED,
	Constants.Status.SNARED,
	Constants.Status.FROZEN,
]

## All weapon atunement statuses (only one active at a time)
const WEAPON_ATUNEMENT_GROUP: Array[int] = [
	Constants.Status.BUFF_WEAPON_UNDINE,
	Constants.Status.BUFF_WEAPON_GNOME,
	Constants.Status.BUFF_WEAPON_SYLPHID,
	Constants.Status.BUFF_WEAPON_SALAMANDO,
	Constants.Status.BUFF_WEAPON_SHADE,
	Constants.Status.BUFF_WEAPON_LUNA,
	Constants.Status.BUFF_WEAPON_LUMINA,
	Constants.Status.BUFF_WEAPON_DRYAD,
]

## GMS2: getStatusBuffAtunementDeity → maps weapon buff status to element index
## Used by removeCreatureElementalAtunement when saber expires
const SABER_STATUS_TO_ELEMENT: Dictionary = {
	Constants.Status.BUFF_WEAPON_UNDINE: Constants.Element.UNDINE,
	Constants.Status.BUFF_WEAPON_GNOME: Constants.Element.GNOME,
	Constants.Status.BUFF_WEAPON_SYLPHID: Constants.Element.SYLPHID,
	Constants.Status.BUFF_WEAPON_SALAMANDO: Constants.Element.SALAMANDO,
	Constants.Status.BUFF_WEAPON_SHADE: Constants.Element.SHADE,
	Constants.Status.BUFF_WEAPON_LUNA: Constants.Element.LUNA,
	Constants.Status.BUFF_WEAPON_LUMINA: Constants.Element.LUMINA,
	Constants.Status.BUFF_WEAPON_DRYAD: Constants.Element.DRYAD,
}

## Debuffs that bosses are immune to (GMS2: isDebuff = true → successPercentage = 0)
const BOSS_IMMUNE_DEBUFFS: Array[int] = [
	Constants.Status.FROZEN,
	Constants.Status.PETRIFIED,
	Constants.Status.CONFUSED,
	Constants.Status.PYGMIZED,
	Constants.Status.FAINT,
	Constants.Status.POISONED,
	Constants.Status.BALLOON,
	Constants.Status.ENGULFED,
	Constants.Status.SNARED,
	Constants.Status.ASLEEP,
	Constants.Status.SILENCED,
	# Stat-down debuffs: bosses are immune to stat reductions
	Constants.Status.SPEED_DOWN,
	Constants.Status.ATTACK_DOWN,
	Constants.Status.DEFENSE_DOWN,
	Constants.Status.MAGIC_DOWN,
	Constants.Status.HIT_DOWN,
	Constants.Status.EVADE_DOWN,
]

# Status attribute bonuses (keyed by status ID -> Dictionary of attribute modifiers)
var _status_bonuses: Dictionary = {}

func set_status(status: int, duration: float = -1.0) -> bool:
	## Apply a status effect with incompatibility rules. Returns true if applied.
	if status < 0 or status >= Constants.STATUS_COUNT:
		return false

	# Boss immunity: bosses are immune to debuffs
	if (is_boss or creature_is_boss) and status in BOSS_IMMUNE_DEBUFFS:
		return false

	# Lucid Barrier blocks negative statuses
	if has_status(Constants.Status.LUCID_BARRIER) and status < Constants.STATUS_BUFF_START:
		if status != Constants.Status.NONE:
			return false

	# --- Incompatibility rules (GMS2: setCreatureStatus lines 245-277) ---

	# Rule A: Any status except POISONED and weapon atunements removes FAINT
	var is_atunement: bool = status in WEAPON_ATUNEMENT_GROUP
	if status != Constants.Status.POISONED and not is_atunement:
		if has_status(Constants.Status.FAINT):
			_remove_status_internal(Constants.Status.FAINT)

	# Rule B: Hard CC statuses are mutually exclusive
	if status in CC_TRIGGER_GROUP:
		for cc_status in EXCLUSIVE_CC_GROUP:
			if has_status(cc_status):
				_remove_status_internal(cc_status)

	# Rule C: Weapon atunements are mutually exclusive (only one active at a time)
	if is_atunement:
		for atune in WEAPON_ATUNEMENT_GROUP:
			if has_status(atune):
				_remove_status_internal(atune)

	# Apply the status
	status_effects[status] = true
	if duration > 0:
		# Clamp to minimumStatusTime (3 seconds) for all timed statuses
		status_timers[status] = maxf(MINIMUM_STATUS_TIME, duration)
	elif duration <= 0 and status_timers[status] <= 0:
		# No timer = permanent until manually removed
		status_timers[status] = 0.0

	# GMS2: pauseCreature() for hard CC debuffs - freezes creature during effect
	if status in [Constants.Status.PETRIFIED, Constants.Status.FROZEN,
			Constants.Status.ENGULFED, Constants.Status.BALLOON]:
		pause_creature()
		z_height = 0.0
		z_velocity = 0.0

	# Apply attribute bonuses for specific statuses (GMS2: setCreatureStatus bonuses)
	_apply_status_bonuses(status)

	# Apply visual effects
	_apply_status_visual(status)

	# GMS2: setCreatureStatus battle dialog messages for debuffs
	_show_status_battle_dialog(status)

	return true

func _remove_status_internal(status: int) -> void:
	## Internal removal without triggering side effects chain
	if status >= 0 and status < Constants.STATUS_COUNT:
		status_effects[status] = false
		status_timers[status] = 0.0
		_clear_status_bonuses(status)
		_clear_status_visual(status)
		_clear_saber_atunement(status)

func remove_status(status: int) -> void:
	if status >= 0 and status < Constants.STATUS_COUNT:
		status_effects[status] = false
		status_timers[status] = 0.0
		_clear_status_bonuses(status)
		_clear_status_visual(status)
		_clear_saber_atunement(status)
		# GMS2: refreshStatusAnimationEffects → changeStateStandDead() for hard CC
		# Unpause and restore creature state when hard CC debuffs expire
		if status in [Constants.Status.PETRIFIED, Constants.Status.FROZEN,
				Constants.Status.ENGULFED, Constants.Status.BALLOON,
				Constants.Status.FAINT, Constants.Status.SNARED]:
			paused = false
			_resume_pause_next_switch = false
			_change_state_stand_dead()

func has_status(status: int) -> bool:
	if status >= 0 and status < status_effects.size():
		return status_effects[status]
	return false

func _clear_saber_atunement(status: int) -> void:
	## GMS2: removeCreatureElementalAtunement when weapon saber buff expires
	if SABER_STATUS_TO_ELEMENT.has(status):
		var elem: int = SABER_STATUS_TO_ELEMENT[status]
		if elem >= 0 and elem < elemental_atunement.size():
			elemental_atunement[elem] = 0.0

## GMS2: setCreatureStatus battle dialog messages (only for specific debuffs)
const STATUS_DIALOG_MAP: Dictionary = {
	Constants.Status.PETRIFIED: "'s petrified!",
	Constants.Status.FROZEN: "'s frostied!",
	Constants.Status.ENGULFED: "'s engulfed!",
	Constants.Status.FAINT: "'s fainted!",
	Constants.Status.POISONED: "'s poisoned!",
}

func _show_status_battle_dialog(status: int) -> void:
	if STATUS_DIALOG_MAP.has(status):
		GameManager.add_battle_dialog(get_creature_name() + STATUS_DIALOG_MAP[status])

func cure_ailments() -> void:
	for i in range(Constants.STATUS_BUFF_START):
		remove_status(i)

func dispel_buffs() -> void:
	## Remove all buff statuses (GMS2: dispelBuffs)
	for i in range(Constants.STATUS_BUFF_START, Constants.STATUS_COUNT):
		remove_status(i)

# --- Status Attribute Bonuses (GMS2: set*Bonus per status) ---

func _apply_status_bonuses(status: int) -> void:
	## Apply stat modifiers when a status is gained
	match status:
		Constants.Status.PYGMIZED:
			_status_bonuses[status] = {
				"strength": -0.5, "constitution": -0.5,
				"agility": -0.5, "criticalRate": -0.5
			}
		Constants.Status.SPEED_UP:
			_status_bonuses[status] = {"agility": 0.25}
		Constants.Status.SPEED_DOWN:
			_status_bonuses[status] = {"agility": -0.25}
		Constants.Status.ATTACK_UP:
			_status_bonuses[status] = {"strength": 0.5}
		Constants.Status.ATTACK_DOWN:
			_status_bonuses[status] = {"strength": -0.5}
		Constants.Status.DEFENSE_UP:
			_status_bonuses[status] = {"constitution": 0.5, "strength": 0.25}
		Constants.Status.DEFENSE_DOWN:
			_status_bonuses[status] = {"constitution": -0.5}
		Constants.Status.MAGIC_UP:
			_status_bonuses[status] = {"intelligence": 0.5}
		Constants.Status.MAGIC_DOWN:
			_status_bonuses[status] = {"intelligence": -0.5}
		Constants.Status.BUFF_MANA_MAGIC:
			# GMS2: Mana Magic grants massive STR bonus (needed to damage Mana Beast)
			_status_bonuses[status] = {"strength": 3.0}  # +300% STR

	# Show battle dialog message for any stat bonuses applied
	if _status_bonuses.has(status):
		_show_bonus_battle_dialog(_status_bonuses[status])

## GMS2: set*Bonus scripts show battle dialog messages for stat changes
const STAT_BONUS_LABELS: Dictionary = {
	"strength": ["strength up", "strength down"],
	"constitution": ["defense up", "defense down"],
	"agility": ["agility up", "agility down"],
	"intelligence": ["intelligence up", "intelligence down"],
	"wisdom": ["spirit up", "spirit down"],
	"criticalRate": ["critical hit up", "critical hit down"],
	"maxHP": ["Max HP grew", "Max HP reduced"],
	"maxMP": ["Max MP grew", "Max MP reduced"],
}

func _show_bonus_battle_dialog(bonuses: Dictionary) -> void:
	## Show battle dialog messages for stat bonuses (GMS2: set*Bonus addBattleDialog)
	var cname: String = get_creature_name()
	for stat in bonuses:
		if STAT_BONUS_LABELS.has(stat):
			var labels: Array = STAT_BONUS_LABELS[stat]
			var msg: String = labels[0] if bonuses[stat] > 0 else labels[1]
			GameManager.add_battle_dialog(cname + " " + msg)

func _clear_status_bonuses(status: int) -> void:
	_status_bonuses.erase(status)

func _get_status_bonus(stat_name: String) -> float:
	## Get the cumulative bonus multiplier for a stat from all active statuses
	var total: float = 0.0
	for status_id in _status_bonuses:
		var bonuses: Dictionary = _status_bonuses[status_id]
		if bonuses.has(stat_name):
			total += bonuses[stat_name]
	return total

# --- Status Visual Effects ---

var _status_shader_frozen: ShaderMaterial = null
var _status_shader_petrified: ShaderMaterial = null
var _status_shader_poison: ShaderMaterial = null
var _status_shader_engulfed: ShaderMaterial = null
var _status_shader_snared: ShaderMaterial = null
var _status_balloon_offset: float = 0.0
var _status_balloon_anim: GenericAnimation = null  # GMS2: balloon oGenericAnimation instance
var _status_engulf_anim: GenericAnimation = null  # GMS2: engulf oGenericAnimation instance

# GMS2: frozen/petrified replaces sprite_index with spr_actor_misc (frame 0=petrified, 1=frozen)
var _status_sprite_swapped: bool = false
var _status_saved_texture: Texture2D = null
var _status_saved_columns: int = 0
var _status_saved_fw: int = 0
var _status_saved_fh: int = 0
var _status_saved_origin: Vector2 = Vector2.ZERO
var _status_saved_frame: int = 0
var _status_saved_image_speed: float = 0.0
static var _spr_actor_misc: Texture2D = null

func _apply_status_visual(status: int) -> void:
	## Apply visual changes when a status is gained
	if not sprite:
		return
	match status:
		Constants.Status.FROZEN:
			# GMS2: sprite_index = spr_actor_misc, image_index = state_sprFrozen (1)
			_swap_to_status_sprite(1)
		Constants.Status.PETRIFIED:
			# GMS2: sprite_index = spr_actor_misc, image_index = state_sprPetrified (0)
			_swap_to_status_sprite(0)
		Constants.Status.POISONED:
			if not _status_shader_poison:
				var poison_shader: Shader = load("res://assets/shaders/sha_poison.gdshader") if ResourceLoader.exists("res://assets/shaders/sha_poison.gdshader") else null
				if poison_shader:
					_status_shader_poison = ShaderMaterial.new()
					_status_shader_poison.shader = poison_shader
			if _status_shader_poison and not _saber_active:
				sprite.material = _status_shader_poison
		Constants.Status.PYGMIZED:
			sprite.scale = Vector2(0.5, 0.5)
		Constants.Status.BALLOON:
			# GMS2: balloon = instance_create_pre(x, y-20, oGenericAnimation,
			#   spr_skill_balloonRing_balloon, 0.1, calculatedTimer, 0, self, 0, -20)
			_spawn_balloon_animation()
		Constants.Status.ENGULFED:
			# Fire/flame tint (GMS2: engulf animation - orange/red glow)
			if not _status_shader_engulfed:
				_status_shader_engulfed = ShaderMaterial.new()
				_status_shader_engulfed.shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
				_status_shader_engulfed.set_shader_parameter("u_color_channel", 0)  # Red channel
				_status_shader_engulfed.set_shader_parameter("u_color_add", Vector3(0.4, 0.15, 0.0))
				_status_shader_engulfed.set_shader_parameter("u_color_limit", 0.3)
			sprite.material = _status_shader_engulfed
			# GMS2: engulf = instance_create_pre(x, y+4, oGenericAnimation,
			#   spr_actor_misc, 0, -1, 2, self, 0, 4)
			_spawn_engulf_animation()
		Constants.Status.SNARED:
			# Green/brown root tint (GMS2: snare reduces speed)
			if not _status_shader_snared:
				_status_shader_snared = ShaderMaterial.new()
				_status_shader_snared.shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
				_status_shader_snared.set_shader_parameter("u_color_channel", 1)  # Green channel
				_status_shader_snared.set_shader_parameter("u_color_add", Vector3(0.1, 0.2, 0.0))
				_status_shader_snared.set_shader_parameter("u_color_limit", 0.3)
			sprite.material = _status_shader_snared

func _clear_status_visual(status: int) -> void:
	## Remove visual changes when a status is removed
	if not sprite:
		return
	match status:
		Constants.Status.FROZEN:
			_restore_from_status_sprite()
		Constants.Status.PETRIFIED:
			_restore_from_status_sprite()
		Constants.Status.POISONED:
			_poison_tick_timer = 0.0
			_poison_sfx_timer = 0.0
			if sprite.material == _status_shader_poison:
				sprite.material = current_shader if current_shader else null
		Constants.Status.PYGMIZED:
			sprite.scale = Vector2(1.0, 1.0)
		Constants.Status.BALLOON:
			_status_balloon_offset = 0.0
			# Restore sprite Y position (GMS2: removeBalloon)
			if sprite:
				sprite.position.y = -z_height
			# GMS2: removeBalloon() - destroy the animation instance
			if is_instance_valid(_status_balloon_anim):
				_status_balloon_anim.queue_free()
			_status_balloon_anim = null
		Constants.Status.ENGULFED:
			if sprite.material == _status_shader_engulfed:
				sprite.material = current_shader if current_shader else null
			# Destroy engulf animation
			if is_instance_valid(_status_engulf_anim):
				_status_engulf_anim.queue_free()
			_status_engulf_anim = null
		Constants.Status.SNARED:
			if sprite.material == _status_shader_snared:
				sprite.material = current_shader if current_shader else null

## GMS2: frozen/petrified - swap creature sprite to spr_actor_misc (46x46, 10 frames, origin 22,35)
func _swap_to_status_sprite(frame_index: int) -> void:
	if _status_sprite_swapped:
		return
	# Pause AnimatedSprite2D if using new system
	if _use_animated_sprite and animated_sprite:
		animated_sprite.stop()
		animated_sprite.visible = false
	if not sprite:
		return
	# Load spr_actor_misc texture once
	if not _spr_actor_misc:
		var path := "res://assets/sprites/sheets/spr_actor_misc.png"
		if ResourceLoader.exists(path):
			_spr_actor_misc = load(path)
	if not _spr_actor_misc:
		return
	# Save current sprite state for restoration
	_status_saved_texture = sprite_sheet
	_status_saved_columns = sprite_columns
	_status_saved_fw = frame_width
	_status_saved_fh = frame_height
	_status_saved_origin = sprite_origin
	_status_saved_frame = current_frame
	_status_saved_image_speed = image_speed
	# Swap to spr_actor_misc
	sprite_sheet = _spr_actor_misc
	sprite_columns = 10
	frame_width = 46
	frame_height = 46
	sprite_origin = Vector2(22, 35)
	sprite.texture = _spr_actor_misc
	sprite.offset = -sprite_origin
	sprite.region_rect = Rect2(frame_index * 46, 0, 46, 46)
	image_speed = 0.0
	current_frame = frame_index
	_status_sprite_swapped = true


func _restore_from_status_sprite() -> void:
	if not _status_sprite_swapped:
		return
	# Restore AnimatedSprite2D visibility if using new system
	if _use_animated_sprite and animated_sprite:
		animated_sprite.visible = true
		# sprite was used for the status overlay; hide it again
		if sprite:
			sprite.visible = false
	if not sprite:
		_status_sprite_swapped = false
		return
	# Restore original sprite sheet
	sprite_sheet = _status_saved_texture
	sprite_columns = _status_saved_columns
	frame_width = _status_saved_fw
	frame_height = _status_saved_fh
	sprite_origin = _status_saved_origin
	image_speed = _status_saved_image_speed
	if sprite_sheet:
		sprite.texture = sprite_sheet
		sprite.offset = -sprite_origin
	current_frame = _status_saved_frame
	_status_sprite_swapped = false
	if not _use_animated_sprite:
		set_frame(current_frame)


## GMS2: Balloon ring animation attached to creature
func _spawn_balloon_animation() -> void:
	# Clean up existing
	if is_instance_valid(_status_balloon_anim):
		_status_balloon_anim.queue_free()
	# spr_skill_balloonRing_balloon: 54x54, 8 frames horizontal strip, origin (27, 53)
	var tex_path := "res://assets/sprites/sheets/spr_skill_balloonRing_balloon.png"
	if not ResourceLoader.exists(tex_path):
		return
	var tex: Texture2D = load(tex_path)
	var status_timer: float = status_timers[Constants.Status.BALLOON] if Constants.Status.BALLOON < status_timers.size() else -1.0
	var world: Node = get_parent()
	if not world:
		return
	# GMS2: image_speed=0.1, destroyOnTime=calculatedTimer, attachTo=self, offset=(0,-20)
	# GMS2 origin (27, 53) → Godot offset = (fw/2 - xorigin, fh/2 - yorigin) = (0, -26)
	_status_balloon_anim = GenericAnimation.play_attached(
		world, self, tex,
		8, 54, 54,  # 8 columns, 54x54 frames
		0, 7,  # frame_start=0, frame_end=7
		0.1,  # anim_speed
		status_timer,  # destroy_on_time (status duration in frames)
		0.0, -10.0,  # x/y offset from creature
		Vector2(0, -26)  # GMS2 origin (27,53) → centered offset (27-27, 27-53)
	)

## GMS2: Engulf fire animation attached to creature
func _spawn_engulf_animation() -> void:
	# Clean up existing
	if is_instance_valid(_status_engulf_anim):
		_status_engulf_anim.queue_free()
	# spr_actor_misc: 46x46, 10 frames, origin (22, 35)
	var tex_path := "res://assets/sprites/sheets/spr_actor_misc.png"
	if not ResourceLoader.exists(tex_path):
		return
	var tex: Texture2D = load(tex_path)
	var world: Node = get_parent()
	if not world:
		return
	# GMS2: image_speed=0, destroyOnTime=-1 (never auto-destroy), image_index=2, offset=(0,4)
	# Static frame (frame 2 = engulf visual), no animation
	_status_engulf_anim = GenericAnimation.play_attached(
		world, self, tex,
		10, 46, 46,  # 10 columns, 46x46 frames
		2, 2,  # frame_start=2, frame_end=2 (static frame)
		0.0,  # anim_speed=0 (no animation, GMS2 image_speed=0)
		-2,  # destroy_on_time=-2 (manual destroy only)
		0.0, 4.0,  # x/y offset from creature
		Vector2(1, -12)  # GMS2 origin (22,35) → centered offset (23-22, 23-35)
	)

# --- Name (GMS2: attribute.nameText) ---

func get_creature_name() -> String:
	## Override in Actor / Mob for proper name
	return name

# --- Stats (with buff/debuff modifiers) ---

func get_max_hp() -> int:
	return attribute.maxHP

func get_max_mp() -> int:
	return attribute.maxMP

func get_strength() -> int:
	var base: float = float(attribute.strength)
	base *= (1.0 + _get_status_bonus("strength"))
	return maxi(1, roundi(base))

func get_constitution() -> int:
	var base: float = float(attribute.constitution)
	base *= (1.0 + _get_status_bonus("constitution"))
	return maxi(1, roundi(base))

func get_intelligence() -> int:
	var base: float = float(attribute.intelligence)
	base *= (1.0 + _get_status_bonus("intelligence"))
	return maxi(1, roundi(base))

func get_wisdom() -> int:
	return attribute.wisdom

func get_agility() -> int:
	var base: float = float(attribute.agility)
	base *= (1.0 + _get_status_bonus("agility"))
	return maxi(1, roundi(base))

func get_luck() -> int:
	return attribute.luck

func get_critical_rate() -> float:
	var base: float = float(attribute.criticalRate)
	base *= (1.0 + _get_status_bonus("criticalRate"))
	return maxf(0.0, base)

func get_effective_move_speed() -> float:
	var base: float = move_speed
	# Speed buffs affect move speed directly
	if has_status(Constants.Status.SPEED_UP):
		base *= 1.25
	if has_status(Constants.Status.SPEED_DOWN) or has_status(Constants.Status.SNARED):
		base *= 0.5
	return base

func get_hit_rate_modifier() -> float:
	var mod: float = 0.0
	if has_status(Constants.Status.HIT_UP):
		mod += 15.0
	if has_status(Constants.Status.HIT_DOWN):
		mod -= 15.0
	return mod

func get_evade_rate_modifier() -> float:
	var mod: float = 0.0
	if has_status(Constants.Status.EVADE_UP):
		mod += 15.0
	if has_status(Constants.Status.EVADE_DOWN):
		mod -= 15.0
	return mod

func is_movement_blocked() -> bool:
	## Returns true if a status effect prevents movement
	## GMS2: BALLOON blocks movement (player floats helplessly)
	return has_status(Constants.Status.FROZEN) or \
		has_status(Constants.Status.PETRIFIED) or \
		has_status(Constants.Status.FAINT) or \
		has_status(Constants.Status.ASLEEP) or \
		has_status(Constants.Status.ENGULFED) or \
		has_status(Constants.Status.BALLOON)

func is_action_blocked() -> bool:
	## Returns true if a status effect prevents attacking/casting
	return has_status(Constants.Status.FROZEN) or \
		has_status(Constants.Status.PETRIFIED) or \
		has_status(Constants.Status.FAINT) or \
		has_status(Constants.Status.ASLEEP) or \
		has_status(Constants.Status.BALLOON) or \
		has_status(Constants.Status.ENGULFED)

func is_magic_blocked() -> bool:
	## Returns true if silenced, pygmized, transformed, confused, or otherwise cannot cast
	## GMS2: ringMenu_playerCanCast checks pygmized + confused status prevents casting
	return has_status(Constants.Status.SILENCED) or \
		has_status(Constants.Status.PYGMIZED) or \
		has_status(Constants.Status.CONFUSED) or \
		is_action_blocked()

func refresh_hp_percent() -> void:
	attribute.hpPercent = (float(attribute.hp) / float(attribute.maxHP)) * 100.0 if attribute.maxHP > 0 else 0.0

func refresh_mp_percent() -> void:
	attribute.mpPercent = (float(attribute.mp) / float(attribute.maxMP)) * 100.0 if attribute.maxMP > 0 else 0.0

func set_invulnerable_time(seconds: float) -> void:
	## Grant temporary invulnerability (post-hit recovery window, in seconds)
	_invuln_timer = seconds
	is_invulnerable = true

func apply_damage(amount: int) -> void:
	attribute.hp = max(0, attribute.hp - amount)
	refresh_hp_percent()
	if attribute.hp <= 0:
		is_dead = true

func apply_heal(amount: int) -> void:
	attribute.hp = min(attribute.maxHP, attribute.hp + amount)
	refresh_hp_percent()
	if attribute.hp > 0:
		is_dead = false
	# GMS2: every HP heal in combat triggers the "healed" directional pose.
	# Previously this was manually called per-skill (cureWater, revivifier, etc.).
	# Making it universal ensures energyAbsorb, Luna saber, items, etc. all show the pose.
	if amount > 0:
		DamageCalculator.apply_healed_pose(self)

func reduce_mp(amount: int) -> void:
	attribute.mp = max(0, attribute.mp - amount)
	refresh_mp_percent()

func restore_mp(amount: int) -> void:
	attribute.mp = min(attribute.maxMP, attribute.mp + amount)
	refresh_mp_percent()
	# GMS2: showCounter(self, amount, COUNTERTYPE_MP_GAIN) - green
	if amount > 0:
		var scene_root: Node = get_tree().current_scene if get_tree() else null
		if scene_root:
			FloatingNumber.spawn(scene_root, self, amount, FloatingNumber.CounterType.MP_GAIN)

# --- Movement helpers ---

func is_movement_input_locked() -> bool:
	return movement_input_locked

func lock_movement_input() -> void:
	movement_input_locked = true
	velocity = Vector2.ZERO  # GMS2: stop immediately on lock

func unlock_movement_input() -> void:
	movement_input_locked = false


func is_input_lock() -> bool:
	return input_locked

func lock_input() -> void:
	input_locked = true

func unlock_input() -> void:
	input_locked = false

## GMS2: pauseCreature() - freezes creature during spell/skill animations
## Stops MoveToPosition and sets paused=true.
## Auto-unpauses on state switch (via _handle_pause_on_switch in StateMachine).
func pause_creature(resume_next_switch: bool = true) -> void:
	# GMS2: stopMovementMotion() — kill path, zero speed, freeze animation
	MoveToPosition.stop(self)
	velocity = Vector2.ZERO
	paused = true
	_resume_pause_next_switch = resume_next_switch

func _change_state_stand_dead() -> void:
	## GMS2: changeStateStandDead() - restore creature to appropriate standing/dead state
	## Called when hard CC debuffs expire to resume normal behavior
	## This is the creature-level version; Actor overrides with change_state_stand_dead()
	if not state_machine_node:
		return
	# Guard: don't re-enter the current state (prevents infinite recursion when
	# Dead.enter() calls cure_ailments() → remove_status() → _change_state_stand_dead())
	var current: String = state_machine_node.current_state_name
	velocity = Vector2.ZERO
	if is_dead:
		if current.ends_with("Dead"):
			return  # Already in a Dead state
		if state_machine_node.has_state("Dead"):
			state_machine_node.switch_state("Dead")
	elif self is Actor:
		var actor: Actor = self as Actor
		if actor.player_controlled:
			if actor.control_is_moving and state_machine_node.has_state("Walk"):
				state_machine_node.switch_state("Walk")
			elif state_machine_node.has_state("Stand"):
				state_machine_node.switch_state("Stand")
		else:
			# AI companions go to IAGuard (GMS2: iaGuard)
			if state_machine_node.has_state("IAGuard"):
				state_machine_node.switch_state("IAGuard")
			elif state_machine_node.has_state("IAStand"):
				state_machine_node.switch_state("IAStand")
	else:
		# Mob: switch to idle/wander
		if state_machine_node.has_state("Idle"):
			state_machine_node.switch_state("Idle")
		elif state_machine_node.has_state("Stand"):
			state_machine_node.switch_state("Stand")

# --- Shader ---

func enable_shader(shader: ShaderMaterial) -> void:
	current_shader = shader
	if sprite:
		sprite.material = shader

func disable_shader() -> void:
	current_shader = null
	# Reset saber tracking so _update_saber_visual() re-applies the saber shader next frame.
	# GMS2: disableShader() clears the current Draw shader, but the saber shader is
	# re-applied every Draw via performWeaponShader(). Without this reset, the guard
	# in _update_saber_visual() prevents re-application.
	_saber_active = false
	_current_saber_id = -1
	if sprite:
		sprite.material = null

# --- Utility ---

func get_facing_direction() -> Vector2:
	match facing:
		Constants.Facing.UP: return Vector2.UP
		Constants.Facing.RIGHT: return Vector2.RIGHT
		Constants.Facing.DOWN: return Vector2.DOWN
		Constants.Facing.LEFT: return Vector2.LEFT
	return Vector2.DOWN

func get_facing_from_direction(dir: Vector2) -> int:
	if abs(dir.x) > abs(dir.y):
		return Constants.Facing.RIGHT if dir.x > 0 else Constants.Facing.LEFT
	else:
		return Constants.Facing.DOWN if dir.y > 0 else Constants.Facing.UP

func take_damage(result: Dictionary) -> void:
	var dmg: int = result.get("damage", 0)
	if dmg > 0:
		apply_damage(dmg)
		# GMS2: cache push direction now while source is still valid
		# (source may die before hit state reads the damage stack)
		if not result.has("push_dir"):
			var src: Node = result.get("source")
			if is_instance_valid(src) and src is Node2D:
				result["push_dir"] = (global_position - (src as Node2D).global_position).normalized()
			else:
				result["push_dir"] = Vector2.DOWN
		damage_stack.append(result)
		attacked = true

func distance_to_creature(other: Creature) -> float:
	return global_position.distance_to(other.global_position)

# --- Contact damage (Rabite jump attacks, etc.) ---
var damage_on_collision: bool = false
var _contact_damage_cooldown: float = 0.0

func _update_contact_damage(delta: float) -> void:
	## Check for contact damage (GMS2: damageOnCollision flag)
	## When active, deals WEAPON damage to any overlapping enemy creature.
	if not damage_on_collision or is_dead:
		return
	if _contact_damage_cooldown > 0:
		_contact_damage_cooldown -= delta
		return

	var contact_range: float = 20.0
	# Mobs damage players, players damage mobs
	if self is Mob:
		for player in GameManager.players:
			if is_instance_valid(player) and not player.is_dead:
				if global_position.distance_to(player.global_position) < contact_range:
					DamageCalculator.perform_attack(player, self, Constants.AttackType.WEAPON)
					_contact_damage_cooldown = 1.0  # GMS2: 60 frames = 1.0 second
					return

# --- Status Duration Calculator (GMS2 formulas) ---

const MINIMUM_STATUS_TIME: float = 3.0  # 3 seconds (was 180 frames at 60fps)

static func calculate_debuff_duration(target_wisdom: int) -> float:
	## GMS2: (30 - getWisdom(target) / 3) * 60 → now in seconds: (30 - wisdom/3)
	## Higher wisdom = shorter debuff
	@warning_ignore("INTEGER_DIVISION")
	var duration: float = float(30 - target_wisdom / 3)
	return maxf(MINIMUM_STATUS_TIME, duration)

static func calculate_buff_duration(target_wisdom: int) -> float:
	## GMS2: (getWisdom(target) / 3) * 60 → now in seconds: wisdom/3
	## Higher wisdom = longer buff
	@warning_ignore("INTEGER_DIVISION")
	var duration: float = float(target_wisdom / 3)
	return maxf(MINIMUM_STATUS_TIME, duration)

static func calculate_short_buff_duration(target_wisdom: int) -> float:
	## GMS2: (getWisdom(target) / 3) * 30 → now in seconds: wisdom/6
	## Half duration buffs (moonEnergy, defender, etc.)
	@warning_ignore("INTEGER_DIVISION")
	var duration: float = float(target_wisdom / 3) * 0.5
	return maxf(MINIMUM_STATUS_TIME, duration)

static func calculate_saber_duration(caster_wisdom: int, deity_level: int) -> float:
	## GMS2: calculatedTimer = (wisdom * 2) + ((deityLevel + 1) * 250)
	## Now in seconds: divide old frame count by 60
	## DRAIN_MAGIC_BASE_DIVIDER = 2, weaponAtunementMultiplier = 250
	var duration_frames: float = float((caster_wisdom * 2) + ((deity_level + 1) * 250))
	var duration: float = duration_frames / 60.0
	return maxf(MINIMUM_STATUS_TIME, duration)
