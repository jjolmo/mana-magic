class_name SkillEffect
extends Node2D
## Visual effect for magic/skill casting - replaces oSkill from GMS2
## Instantiated per-target, animates sprite frames, then applies effect and self-destructs.

# Setup properties (set before adding to tree or via setup())
var source: Creature
var target: Creature
var skill_data: Dictionary
var level: int = 0
var skill_name: String = ""
var total_affected_targets: int = 1  ## GMS2: totalAffectedTargets - used to divide heals

# Animation state
var animation_finished: bool = false

# Sprite
var effect_sprite: AnimatedSprite2D

# Skill sprite metadata (loaded from skill_sprites.json)
static var _sprite_db: Dictionary = {}
static var _sprite_db_loaded: bool = false

# Sound
var sound_played: bool = false

# Target/source state management
var target_was_frozen: bool = false  # Whether we put target in Animation state
var source_was_frozen: bool = false  # Whether we put source in Animation state (sourceWaits)

# Multi-loop animation tracking (GMS2: totalImageLoopsTillDestroy)
var _anim_loop_count: int = 0
var _anim_max_loops: int = 1

## GMS2: sourceWaits - skills where the caster freezes during animation (only burst)
const SOURCE_WAITS_SKILLS: Array = ["burst"]

## GMS2: Skills that inherit parent oSkill Step_0 behavior — check state_protect before pauseCreature().
## If target.state_protect is true, these skills skip pauseCreature() but still switch to Animation.
## All other skills (heals, sabers, beams, projectiles, etc.) call pauseCreature() unconditionally.
const STATE_PROTECT_CHECK_SKILLS: Array = [
	"thunderbolt", "fireball", "airBlast", "lucentBeam", "gemMissile", "moonEnergy",
	"freeze", "poisonGas", "darkForce", "evilGate", "confuseHoops", "dispelMagic",
	"energyAbsorb", "magicAbsorb", "earthSlide", "changeForm", "lucidBarrier", "wall",
]

# Screen darkening effect (GMS2: oColorBrightness)
var _screen_blend: ScreenBlend = null
var _owns_screen_blend: bool = false  # Whether this instance created the shared blend

# GMS2: uniqueGroupEffectId - only first skill in group creates screen darken
static var _active_screen_blend: ScreenBlend = null
static var _active_screen_blend_refcount: int = 0

## GMS2 oColorBrightness config per skill: [color, max_alpha, fade_in_frames]
const SCREEN_DARKEN_SKILLS: Dictionary = {
	"freeze": [Color.BLACK, 0.5, 30],     # c_black, 0.5 alpha, 30 frame fade-in
	"darkForce": [Color.WHITE, 0.5, 30],   # c_white, 0.5 alpha, 30 frame fade-in
	"evilGate": [Color.WHITE, 0.5, 10],    # c_white, 0.5 alpha, 10 frame fade-in (faster)
}

## Sprite key remapping for skills whose sprite name doesn't match "spr_skill_[name]"
const SPRITE_NAME_REMAP: Dictionary = {
	"freezeBeam": "spr_skill_beamFreeze",
	"petrifyBeam": "spr_skill_beamFreeze",
	"acidStorm": "spr_skill_acidStorm_dot",
	"iceSaber": "spr_skill_saber_swords",
	"flameSaber": "spr_skill_saber_swords",
	"thunderSaber": "spr_skill_saber_swords",
	"moonSaber": "spr_skill_saber_swords",
	"lightSaber": "spr_skill_saber_swords",
	"stoneSaber": "spr_skill_saber_swords",
	"fireball": "spr_skill_fireball2",  # Explosion sprite (travel sprite is manual)
	"manaMagicOffensive": "spr_skill_manaMagic",
	"manaMagicSupport": "spr_skill_manaMagic",
}

## GMS2 image_speed per skill object (only entries != 1.0)
## Formula: effective_fps = sprite.playbackSpeed * object.image_speed
## Skills not listed here inherit image_speed = 1.0 from oSkill parent
const GMS2_IMAGE_SPEED: Dictionary = {
	"balloonRing": 0.2,
	"confuseHoops": 0.2,
	"cureWater": 0.3,
	"lavaWave": 0.2,
	"lunarMagic": 0.2,
	"lucentBeam": 0.3,
	"lucidBarrier": 0.3,
	"wall": 0.3,
	"silence": 0.15,
}

## GMS2: totalImageLoopsTillDestroy — skills whose animation loops N times before finishing.
## Default is 1 (play once). Only override for skills that explicitly set > 1 in GMS2.
const MULTI_LOOP_SKILLS: Dictionary = {
	"lavaWave": 4,  # GMS2: oSkill_lavaWave Create_0 — totalImageLoopsTillDestroy = 4
}

## GMS2: Palette swap shader applied to the TARGET creature during the skill animation.
## Maps skill_name → [u_color_channel, r, g, b, u_color_limit]
## Derived from each oSkill_*/Draw_0.gml calling ani_cureWater/ani_thunderbolt/etc with(target).
## Skills NOT in this dictionary do not apply palette swap to the target (GMS2: no Draw_0 or draw_self() only).
## Channel: 0=RED, 1=GREEN, 2=BLUE, 3=WHITE(all)
const SKILL_TARGET_PALETTE_SWAP: Dictionary = {
	# --- Undine (Water) ---
	# GMS2: ani_cureWater() → GREEN, (0,0,255)/255, speed=4, limit=0.4
	"cureWater": [1, 0.0, 0.0, 1.0, 0.4],
	"remedy": [1, 0.0, 0.0, 1.0, 0.4],
	# GMS2: ani_cureWater() → GREEN, (0,0,255)/255 on target when shaderActive
	"iceSaber": [1, 0.0, 0.0, 1.0, 0.4],
	"freeze": [1, 0.0, 0.0, 1.0, 0.4],
	# GMS2: ani_yellowSwap() → BLUE, (255,255,25)/255
	"energyAbsorb": [2, 1.0, 1.0, 0.098, 0.4],

	# --- Gnome (Earth) ---
	# GMS2: ani_earthSlide() → WHITE, (127,127,127)/255
	"earthSlide": [3, 0.498, 0.498, 0.498, 0.4],
	# GMS2: ani_generatePalleteSwap with UNDINE colors on target
	"gemMissile": [1, 0.0, 0.0, 1.0, 0.4],
	# GMS2: ani_generatePalleteSwap → WHITE, (127,127,127)/255
	"stoneSaber": [3, 0.498, 0.498, 0.498, 0.4],
	# GMS2: ani_yellowSwap() in Draw_0.gml → BLUE, (255,255,25)/255
	"midgeHammer": [2, 1.0, 1.0, 0.098, 0.4],

	# --- Sylphid (Wind) ---
	# GMS2: ani_thunderbolt() → RED, (155,62,192)/255
	"thunderbolt": [0, 0.608, 0.243, 0.753, 0.4],
	# GMS2: ani_generatePalleteSwap with LUNA colors on target
	"airBlast": [1, 0.729, 0.969, 0.165, 0.4],
	# GMS2: ani_generatePalleteSwap → GREEN, (198,5,195)/255
	"thunderSaber": [1, 0.776, 0.020, 0.765, 0.4],

	# --- Salamando (Fire) ---
	# GMS2: ani_generatePalleteSwap with atunement colors on fireball collision
	"fireball": [1, 1.0, 0.431, 0.196, 0.4],
	# GMS2: ani_generatePalleteSwap → GREEN, (255,110,50)/255
	"flameSaber": [1, 1.0, 0.431, 0.196, 0.4],

	# --- Shade (Dark) ---
	# GMS2: ani_earthSlide() → WHITE, (127,127,127)/255
	"darkForce": [3, 0.498, 0.498, 0.498, 0.4],
	"evilGate": [3, 0.498, 0.498, 0.498, 0.4],
	"dispelMagic": [3, 0.498, 0.498, 0.498, 0.4],

	# --- Luna (Moon) ---
	# GMS2: ani_generatePalleteSwap with LUNA colors
	"moonEnergy": [1, 0.729, 0.969, 0.165, 0.4],
	# GMS2: inherits parent Draw_0, shaderColorComposition = ELEMENT_LUNA
	"lunarMagic": [1, 0.729, 0.969, 0.165, 0.4],
	# GMS2: ani_yellowSwap() → BLUE, (255,255,25)/255
	"magicAbsorb": [2, 1.0, 1.0, 0.098, 0.4],
	# GMS2: ani_generatePalleteSwap → GREEN, (186,247,42)/255
	"moonSaber": [1, 0.729, 0.969, 0.165, 0.4],

	# --- Lumina (Light) ---
	# GMS2: ani_earthSlide() → WHITE, (127,127,127)/255
	"lucentBeam": [3, 0.498, 0.498, 0.498, 0.4],
	# GMS2: ani_generatePalleteSwap → GREEN, (0,244,158)/255
	"lightSaber": [1, 0.0, 0.957, 0.620, 0.4],
	"lucidBarrier": [3, 0.498, 0.498, 0.498, 0.4],

	# --- Dryad (Nature) ---
	# GMS2: ani_wall() → GREEN, (0,255,0)/255, speed=0.06
	"revivifier": [1, 0.0, 1.0, 0.0, 0.4],
	"wall": [1, 0.0, 1.0, 0.0, 0.4],
	# GMS2: ani_earthSlide() → WHITE, (127,127,127)/255
	"manaMagicOffensive": [3, 0.498, 0.498, 0.498, 0.4],
	"manaMagicSupport": [3, 0.498, 0.498, 0.498, 0.4],
	# GMS2: parent oSkill Draw_0 with Dryad elemental → GREEN, (0,251,93)/255
	"burst": [1, 0.0, 0.984, 0.365, 0.4],
	"sleepFlower": [1, 0.0, 0.984, 0.365, 0.4],

	# --- Parent oSkill Draw_0 inherited (no custom Draw_0.gml) ---
	# GMS2: Salamando elemental → GREEN, (255,110,50)/255
	"lavaWave": [1, 1.0, 0.431, 0.196, 0.4],
	"exploder": [1, 1.0, 0.431, 0.196, 0.4],
	"fireBouquet": [1, 1.0, 0.431, 0.196, 0.4],
	"blazeWall": [1, 1.0, 0.431, 0.196, 0.4],
	# GMS2: Undine elemental → GREEN, (0,0,255)/255
	"acidStorm": [1, 0.0, 0.0, 1.0, 0.4],
	# GMS2: silence Create_0 overrides to Luna shader → GREEN, (186,247,42)/255
	"silence": [1, 0.729, 0.969, 0.165, 0.4],
	# GMS2: speedDown Create_0 overrides to custom GREEN, (0,255,0)/255
	"speedDown": [1, 0.0, 1.0, 0.0, 0.4],
}

## Preloaded palette swap shader (shared across all instances)
static var _palette_swap_shader: Shader = null

# Per-instance target shader state
var _target_original_material: Material = null
var _target_shader_applied: bool = false

# --- Absorb spiral effect (GMS2: oSkill_energyAbsorb / oSkill_magicAbsorb) ---
const ABSORB_SKILLS: Array = ["energyAbsorb", "magicAbsorb"]
var _is_absorb_spiral: bool = false
var _absorb_phase: int = 0
var _absorb_timer: float = 0.0
var _absorb_ball_timer: float = 0.0
var _absorb_created_balls: int = 0
var _absorb_anim_direction: float = 0.0
var _absorb_balls: Array = []       # Array of Sprite2D nodes
var _absorb_ball_lengths: Array = [] # Distance from center per ball
var _absorb_ball_speeds: Array = []  # Radial speed per ball
var _absorb_ball_texture: Texture2D = null
var _absorb_ball_frame_w: int = 16
var _absorb_ball_frame_h: int = 16
var _absorb_ball_columns: int = 10
var _absorb_ball_total_frames: int = 10
var _absorb_ball_frame_accum: Array = [] # Per-ball frame accumulator
var _absorb_ball_current_frame: Array = [] # Per-ball current frame
var _absorb_spawn_accum: float = 0.0  # Periodic accumulator for ball spawning (every 6 frames = 0.1s)
const _ABSORB_TOTAL_BALLS: int = 10
const _ABSORB_DIR_SEPARATION: float = 35.0
const _ABSORB_ANIM_SPEED: float = 0.8
const _ABSORB_BALL_IMG_SPEED: float = 0.1 # GMS2: oGenericAnimation image_speed
# --- Generic custom skill handler system ---
# Skills with complex multi-phase visuals that differ from standard sprite playback.
var _dt: float = 0.0167                # Current frame delta, set each _process for use by _step_* helpers
var _custom_handler: String = ""       # "burst", "thunderbolt", "earthSlide", etc.
var _custom_phase: int = 0
var _custom_timer: float = 0.0
var _custom_timer2: float = 0.0
var _custom_timer3: float = 0.0
var _custom_anims: Array = []          # Sub-animation nodes to cleanup on destroy
var _custom_created: int = 0           # Number of sub-animations created
var _custom_periodic_accum: float = 0.0  # Periodic accumulator for modulo-style patterns
var _burst_spawn_acc: float = 0.0        # Periodic accumulator for burst (12-frame interval)
var _exploder_spawn_acc: float = 0.0     # Periodic accumulator for exploder (12-frame interval)
var _multi_burst_spawn_acc: float = 0.0  # Periodic accumulator for sleepGas multi_burst (15-frame interval)
var _acid_storm_spawn_acc: float = 0.0   # Periodic accumulator for acid storm (4-frame interval)
var _freeze_sound_acc: float = 0.0       # Periodic accumulator for freeze sound (20-frame interval)
var _df_orb_spawn_acc: float = 0.0       # Periodic accumulator for dark force orb spawning (4-frame interval)
var _df_burst_spawn_acc: float = 0.0     # Periodic accumulator for dark force bursts (20-frame interval)
var _custom_positions: Array = []      # Spawn positions for multi-burst effects
var _custom_finished: bool = false     # Signal to finish on next step
var _effect_already_applied: bool = false  # Skip _apply_effect() in _on_animation_complete (for immediate-effect skills)
var _skip_freeze: bool = false  # Skip _freeze_target() — used when skill aborts early (e.g. balloon boss immunity)
# Skills with invisible main sprite (visual is entirely sub-animations)
const INVISIBLE_SPRITE_SKILLS: Array = ["burst", "exploder", "poisonGas", "sleepGas", "acidStorm", "darkForce", "balloon", "leadenGlare", "pygmusGlare", "changeForm"]
# Skills where the target palette swap shader is NOT applied at start (delayed activation)
# GMS2: lucentBeam Create_0 sets drawShader = false; Step_0 enables it when image_index > 22
const DELAYED_SHADER_SKILLS: Array = [
	"cureWater",
	"lucentBeam",
	"thunderbolt",  # GMS2: drawShader activates after bolt animation, not at start
	"fireball",  # GMS2: shader activates on first projectile collision, not at start
	"moonEnergy",  # GMS2: Draw_0 activates Luna shader when any projectile collides
	"airBlast",  # GMS2: Draw_0 activates Luna shader when any projectile collides
	"iceSaber", "flameSaber", "thunderSaber", "moonSaber", "lightSaber", "stoneSaber",
]
# Skills using the generic custom handler system (NOT absorb, which has its own)
const CUSTOM_HANDLER_SKILLS: Dictionary = {
	"burst": "burst", "exploder": "exploder",
	"fireball": "fireball", "moonEnergy": "moonEnergy",
	"thunderbolt": "thunderbolt", "earthSlide": "earthSlide",
	"poisonGas": "poison_gas", "sleepGas": "multi_burst",
	"acidStorm": "acid_storm",
	"wall": "wall_spark", "lucidBarrier": "wall_spark",
	"freeze": "freeze", "darkForce": "dark_force",
	"lucentBeam": "lucent_beam", "evilGate": "evil_gate",
	"cureWater": "cure_water", "remedy": "remedy",
	"iceSaber": "saber", "flameSaber": "saber", "thunderSaber": "saber",
	"moonSaber": "saber", "lightSaber": "saber", "stoneSaber": "saber",
	"airBlast": "air_blast",
	"dispelMagic": "dispel_magic",
	"confuseHoops": "confuse_hoops",
	"balloon": "balloon",
	"revivifier": "revivifier",
	"leadenGlare": "leaden_glare",
	"pygmusGlare": "pygmus_glare",
	"changeForm": "change_form",
}
## Healed pose duration for spell heals. Item heals use their own shorter duration.
## Healed pose is now triggered universally from creature.apply_heal() →
## DamageCalculator.apply_healed_pose(), so no per-skill list is needed.
const HEALED_POSE_DURATION: int = 90  # GMS2: state_payload(..., 90, ...) — 1.5 seconds at 60fps


func _ready() -> void:
	_ensure_sprite_db()
	effect_sprite = AnimatedSprite2D.new()
	effect_sprite.name = "EffectSprite"
	effect_sprite.animation_finished.connect(_on_animation_complete)
	add_child(effect_sprite)

	if skill_name.is_empty() and not skill_data.is_empty():
		skill_name = skill_data.get("name", "")

	# Multi-loop skills (GMS2: totalImageLoopsTillDestroy)
	_anim_max_loops = MULTI_LOOP_SKILLS.get(skill_name, 1)

	# Absorb spells use a custom spiral animation instead of the standard sprite playback
	if skill_name in ABSORB_SKILLS:
		_is_absorb_spiral = true
		_position_on_target()
		_setup_absorb_spiral()
	elif CUSTOM_HANDLER_SKILLS.has(skill_name):
		_custom_handler = CUSTOM_HANDLER_SKILLS[skill_name]
		_load_skill_frames()  # Some handlers still use effect_sprite
		if skill_name in INVISIBLE_SPRITE_SKILLS:
			effect_sprite.visible = false
		# Position BEFORE custom handler setup, so handlers can override if needed
		# (e.g. thunderbolt positions 65px above target, earthSlide starts above)
		_position_on_target()
		_setup_custom_handler()
	else:
		_load_skill_frames()
		_position_on_target()

	_freeze_target()
	_freeze_source()
	_start_screen_darken()


func setup(p_source: Creature, p_target: Creature, p_skill_data: Dictionary, p_level: int) -> void:
	source = p_source
	target = p_target
	skill_data = p_skill_data
	level = p_level
	skill_name = p_skill_data.get("name", "")


static func _ensure_sprite_db() -> void:
	if _sprite_db_loaded:
		return
	_sprite_db_loaded = true
	var file := FileAccess.open("res://data/skill_sprites.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_sprite_db = json.data
		file.close()


func _load_skill_frames() -> void:
	# Check remap first, then default naming
	var sprite_key: String = SPRITE_NAME_REMAP.get(skill_name, "spr_skill_" + skill_name)
	var sprite_info: Dictionary = _sprite_db.get(sprite_key, {})

	if sprite_info.is_empty():
		# Try alternate naming conventions
		var default_key: String = "spr_skill_" + skill_name
		sprite_info = _sprite_db.get(default_key, {})
		if not sprite_info.is_empty():
			sprite_key = default_key

	if sprite_info.is_empty():
		# Search for any key ending with the skill name
		for key in _sprite_db:
			if key.ends_with("_" + skill_name):
				sprite_info = _sprite_db[key]
				sprite_key = key
				break

	if sprite_info.is_empty():
		push_warning("SkillEffect: No sprite data for skill '%s'" % skill_name)
		return

	# Compute effective FPS: GMS2 playbackSpeed × image_speed
	var gms2_playback: float = sprite_info.get("playback_speed", 15.0)
	var gms2_img_speed: float = GMS2_IMAGE_SPEED.get(skill_name, 1.0)
	var effective_fps: float = gms2_playback * gms2_img_speed

	# Build SpriteFrames from spritesheet
	var sf := SpriteUtils.build_sprite_frames(sprite_key, "effect", effective_fps, false)
	if sf:
		effect_sprite.sprite_frames = sf
		effect_sprite.animation = "effect"
		effect_sprite.play()

	effect_sprite.offset = SpriteUtils.get_sheet_offset(sprite_key)


func _position_on_target() -> void:
	if is_instance_valid(target):
		# GMS2: default position is target.x, target.y - 10 (parent oSkill Create_0).
		# lucentBeam: target.x, target.y (no y offset)
		# evilGate: target.x + 1, target.y - 10
		match skill_name:
			"lucentBeam":
				global_position = target.global_position
			"evilGate":
				global_position = target.global_position + Vector2(1, -10)
			_:
				global_position = target.global_position + Vector2(0, -10)
		z_index = 1000


func _freeze_target() -> void:
	if _skip_freeze:
		return
	if is_instance_valid(target) and target.state_machine_node:
		if target.state_machine_node.has_state("Animation"):
			target_was_frozen = true
			# GMS2: parent oSkill checks state_protect before pauseCreature() for some skills.
			# Heals, sabers, beams, etc. call pauseCreature() unconditionally.
			if skill_name in STATE_PROTECT_CHECK_SKILLS:
				if not target.state_protect:
					target.pause_creature()
			else:
				target.pause_creature()
			target.state_machine_node.switch_state("Animation")
			# Apply palette swap AFTER state switch — Animation.enter() calls disable_shader()
			# which would clear any shader applied before the switch.
			# Delayed-shader skills (e.g. lucentBeam) activate shader later from their handler.
			if skill_name not in DELAYED_SHADER_SKILLS:
				_apply_target_shader()


func _unfreeze_target() -> void:
	if target_was_frozen and is_instance_valid(target) and target.state_machine_node:
		# Don't override healed pose — apply_heal() already triggered StaticAnimation
		if target.state_machine_node.current_state_name == "StaticAnimation":
			return
		_change_state_stand_dead(target)


func _freeze_source() -> void:
	## GMS2: sourceWaits - freeze the caster during the spell animation
	if skill_name in SOURCE_WAITS_SKILLS and is_instance_valid(source) and source.state_machine_node:
		if source != target and source.state_machine_node.has_state("Animation"):
			source_was_frozen = true
			# GMS2: pauseCreature() + state_switch(state_ANIMATION)
			source.pause_creature()
			source.state_machine_node.switch_state("Animation")


func _unfreeze_source() -> void:
	## GMS2: unfreeze source after spell + handle creaturePausesWhenCast for mobs
	if is_instance_valid(source) and source.state_machine_node:
		# Don't override healed pose — apply_heal() already triggered StaticAnimation
		# (e.g. energyAbsorb heals the source)
		if source.state_machine_node.current_state_name == "StaticAnimation":
			return
	if source_was_frozen and is_instance_valid(source) and source.state_machine_node:
		_change_state_stand_dead(source)
	elif is_instance_valid(source) and source is Mob and source.state_machine_node:
		# GMS2: creaturePausesWhenCast=true (default for all mobs)
		# After casting, return mob to Stand/Dead so AI resumes
		_change_state_stand_dead(source)


func _change_state_stand_dead(p_creature: Creature) -> void:
	## GMS2: changeStateStandDead() - return creature to appropriate base state
	## Actors have their own routing (player → Stand/Walk, AI → IAGuard/IAStand)
	if not is_instance_valid(p_creature) or not p_creature.state_machine_node:
		return
	if p_creature is Actor:
		(p_creature as Actor).change_state_stand_dead()
	elif p_creature.is_dead:
		if p_creature.state_machine_node.has_state("Dead"):
			p_creature.state_machine_node.switch_state("Dead")
	else:
		if p_creature.state_machine_node.has_state("Stand"):
			p_creature.state_machine_node.switch_state("Stand")


func _process(delta: float) -> void:
	_dt = delta
	if animation_finished:
		return

	# GMS2: ring menu pauses all combat logic
	if GameManager.ring_menu_opened:
		if not _is_absorb_spiral and _custom_handler.is_empty() and effect_sprite.is_playing():
			effect_sprite.pause()
		return

	# Play sound on first frame
	if not sound_played:
		sound_played = true
		_play_skill_sound()

	# Custom handler routing
	if not _custom_handler.is_empty():
		_process_custom_handler(delta)
		return

	# Absorb spells use custom spiral animation
	if _is_absorb_spiral:
		_process_absorb_spiral(delta)
		return

	if not effect_sprite.is_playing() and effect_sprite.sprite_frames:
		effect_sprite.play()

	# Follow target position
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -10)


func _on_animation_complete() -> void:
	# Custom handlers control their own lifecycle via _custom_finish() —
	# ignore the AnimatedSprite2D.animation_finished signal until they're done.
	if not _custom_handler.is_empty() and not _custom_finished:
		return
	# GMS2: totalImageLoopsTillDestroy — replay animation N times before finishing
	if _anim_max_loops > 1 and _anim_loop_count < _anim_max_loops - 1:
		_anim_loop_count += 1
		effect_sprite.frame = 0
		effect_sprite.play()
		return
	animation_finished = true
	# Cleanup any sub-animations spawned by custom handlers
	for anim in _custom_anims:
		if is_instance_valid(anim):
			anim.queue_free()
	_custom_anims.clear()
	if not _effect_already_applied:
		_apply_effect()
	_remove_target_shader()
	# Healed pose is now triggered universally from creature.apply_heal() —
	# no manual _apply_healed_pose() call needed here.
	_unfreeze_target()
	_unfreeze_source()
	_stop_screen_darken()
	queue_free()


func _exit_tree() -> void:
	## Safety net: if SkillEffect is freed before _on_animation_complete() runs
	## (e.g. mob_dead._cleanup_skill_effects()), ensure screen darken and target
	## shader are properly cleaned up to avoid a permanently dark screen or
	## lingering palette swap on the target.
	if not animation_finished:
		_remove_target_shader()
		_unfreeze_target()
		_unfreeze_source()
		_stop_screen_darken()


func _start_screen_darken() -> void:
	## GMS2: oColorBrightness - full-screen color overlay that fades in during spell casting
	## Uses static refcount so multi-target spells share one overlay (GMS2: uniqueGroupEffectId)
	if not SCREEN_DARKEN_SKILLS.has(skill_name):
		return

	_active_screen_blend_refcount += 1

	# Only the first skill instance in the group creates the overlay
	if is_instance_valid(_active_screen_blend):
		_screen_blend = _active_screen_blend
		_owns_screen_blend = false
		return

	var config: Array = SCREEN_DARKEN_SKILLS[skill_name]
	var blend_color: Color = config[0]
	var max_alpha: float = config[1]
	var fade_frames: int = config[2]

	_screen_blend = ScreenBlend.create(get_tree(), blend_color, 0.0)
	if _screen_blend:
		_screen_blend.fade_on(max_alpha, fade_frames)
		_active_screen_blend = _screen_blend
		_owns_screen_blend = true


func _stop_screen_darken() -> void:
	## Reverse the screen darkening effect (GMS2: alphaBackground.reverse = true)
	## Only the last skill instance to complete fades out the overlay
	if not SCREEN_DARKEN_SKILLS.has(skill_name):
		return

	_active_screen_blend_refcount = maxi(0, _active_screen_blend_refcount - 1)

	if _active_screen_blend_refcount <= 0 and is_instance_valid(_screen_blend):
		var config: Array = SCREEN_DARKEN_SKILLS.get(skill_name, [Color.BLACK, 0.5, 30])
		var fade_frames: int = config[2]
		_screen_blend.fade_off(fade_frames)
		_active_screen_blend = null

	_screen_blend = null


func _apply_effect() -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return

	var element_idx: int = _get_element_index()

	# GMS2: status durations are wisdom-based, not hardcoded
	# Debuffs: (30 - wisdom/3) * 60 → shorter on high-wisdom targets
	# Buffs: (wisdom/3) * 60 → longer on high-wisdom targets
	# Short buffs: (wisdom/3) * 30 → half duration (moonEnergy, lunarBoost, etc.)
	var debuff_dur: int = Creature.calculate_debuff_duration(target.get_wisdom())
	var buff_dur: int = Creature.calculate_buff_duration(target.get_wisdom())
	var short_buff_dur: int = Creature.calculate_short_buff_duration(target.get_wisdom())
	# GMS2: Saber duration = (wisdom * 2) + ((deityLevel + 1) * 250)
	var saber_dur: int = Creature.calculate_saber_duration(source.get_wisdom(), level)

	# Handle every skill by name for explicit, correct behavior
	match skill_name:
		# --- Undine (Water) ---
		"cureWater":
			# GMS2: healed = (INT/4 + WIS/2) * level * healingMultiplier
			# Then: rollRandomOscillation, divide by totalAffectedTargets, clamp to healLimit
			var heal_mult: float = skill_data.get("value1", 2)
			var int_val: float = float(source.get_intelligence())
			var wis_val: float = float(source.get_wisdom())
			var heal_f: float = (int_val / 4.0 + wis_val / 2.0) * float(maxi(1, level)) * heal_mult
			# GMS2: rollRandomOscillation(healed, randomHealingPercent) - ±5% oscillation
			var rdp: float = source.attribute.get("randomHealingPercent", 5.0)
			heal_f += heal_f * randf_range(-rdp, rdp) / 100.0
			# GMS2: floor(healed / totalAffectedTargets) - split heal across multi-targets
			heal_f = floorf(heal_f / float(maxi(1, total_affected_targets)))
			var heal: int = clampi(roundi(heal_f), 0, 999)  # GMS2: healLimit = 999
			target.apply_heal(heal)
			# Show heal number directly (do NOT use damage_stack — that triggers Hit state + hit sound)
			FloatingNumber.spawn(get_tree().current_scene, target, heal, FloatingNumber.CounterType.HP_GAIN)
		"remedy":
			target.cure_ailments()
		"iceSaber":
			target.set_status(Constants.Status.BUFF_WEAPON_UNDINE, saber_dur)
			# GMS2: addCreatureElementalAtunement(deityId, target)
			target.elemental_atunement[Constants.Element.UNDINE] = 1.0
		"freezeBeam":
			# Status-only: freeze with probability
			_apply_status_with_probability(Constants.Status.FROZEN, debuff_dur)
		"petrifyBeam":
			_apply_status_with_probability(Constants.Status.PETRIFIED, debuff_dur)
		"freeze":
			# Offensive damage + possible freeze
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"acidStorm":
			# Damage + defense down
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
			target.set_status(Constants.Status.DEFENSE_DOWN, debuff_dur)
		"energyAbsorb":
			# GMS2: DRAIN_HEALTH - deals magic damage clamped to target HP, heals source full amount
			# GMS2 Phase 3: performHeal(source, source, RECOVERTYPE_HP, HEALCALCULUS_DIRECT, damageDone*totalAffectedTargets)
			var result: Dictionary = DamageCalculator.perform_attack(target, source, Constants.AttackType.DRAIN_HEALTH, element_idx, level)
			var drain: int = result.get("damage", 0)
			if drain > 0:
				var total_heal: int = drain * maxi(1, total_affected_targets)
				source.apply_heal(total_heal)
				# Show floating heal number (GMS2: performHeal spawns oBTL_counter HP_GAIN)
				var scene_root: Node = source.get_tree().current_scene if source.get_tree() else null
				if scene_root:
					FloatingNumber.spawn(scene_root, source, total_heal, FloatingNumber.CounterType.HP_GAIN)

		# --- Gnome (Earth) ---
		"earthSlide":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"gemMissile":
			# Handled by projectile system - should not reach here normally
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"stoneSaber":
			target.set_status(Constants.Status.BUFF_WEAPON_GNOME, saber_dur)
			target.elemental_atunement[Constants.Element.GNOME] = 1.0
		"speedUp":
			target.set_status(Constants.Status.SPEED_UP, buff_dur)
		"speedDown":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
			target.set_status(Constants.Status.SPEED_DOWN, debuff_dur)
		"defender":
			target.set_status(Constants.Status.DEFENSE_UP, buff_dur)
		"pygmusGlare":
			# GMS2: player-to-player pygmize uses fixed 900 frame (15s) timer + 100% success
			if source is Actor and target is Actor:
				target.set_status(Constants.Status.PYGMIZED, 900)
			else:
				_apply_status_with_probability(Constants.Status.PYGMIZED, debuff_dur)

		# --- Sylphid (Wind) ---
		"thunderbolt":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"airBlast":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"thunderSaber":
			target.set_status(Constants.Status.BUFF_WEAPON_SYLPHID, saber_dur)
			target.elemental_atunement[Constants.Element.SYLPHID] = 1.0
			# GMS2: setCriticalRateBonus(STATUS_BUFF_WEAPON_SYLPHID, 30) — +30% crit rate
			target._status_bonuses[Constants.Status.BUFF_WEAPON_SYLPHID] = {"criticalRate": 0.3}
		"confuseHoops":
			_apply_status_with_probability(Constants.Status.CONFUSED, debuff_dur)
		"silence":
			# GMS2: Silence applies STATUS_CONFUSED (skill DB value1: [3]), NO damage.
			# Description: "Confuses the enemies." — reverses movement direction.
			# 100% success rate (GMS2: successPercentage = 100 for CONFUSED).
			target.set_status(Constants.Status.CONFUSED, debuff_dur)
		"balloonRing":
			# GMS2: successPercentage = 100 — balloon always succeeds
			target.set_status(Constants.Status.BALLOON, debuff_dur)
		"balloon":
			# GMS2: successPercentage = 100 — balloon always succeeds
			target.set_status(Constants.Status.BALLOON, debuff_dur)
		"analyzer":
			_apply_analyzer_display()

		# --- Salamando (Fire) ---
		"fireball":
			# GMS2: performAttack after 80-frame post-collision wait (oSkill_fireball Step_0)
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"exploder":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"lavaWave":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"flameSaber":
			target.set_status(Constants.Status.BUFF_WEAPON_SALAMANDO, saber_dur)
			target.elemental_atunement[Constants.Element.SALAMANDO] = 1.0
		"fireBouquet":
			# Damage + attack down
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
			target.set_status(Constants.Status.ATTACK_DOWN, debuff_dur)
		"blazeWall":
			# Damage + engulfed
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
			target.set_status(Constants.Status.ENGULFED, debuff_dur)

		# --- Shade (Dark) ---
		"darkForce":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"evilGate":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"dispelMagic":
			for i in range(Constants.STATUS_BUFF_START, Constants.STATUS_COUNT):
				target.remove_status(i)
		"sleepGas":
			_apply_status_with_probability(Constants.Status.FAINT, debuff_dur)
		"leadenGlare":
			_apply_status_with_probability(Constants.Status.PETRIFIED, debuff_dur)
		"poisonGas":
			_apply_status_with_probability(Constants.Status.POISONED, debuff_dur)

		# --- Luna (Moon) ---
		"lunarMagic":
			_apply_lunar_magic_effect(element_idx, debuff_dur, short_buff_dur)
		"magicAbsorb":
			# GMS2: DRAIN_MAGIC - magic damage / 2, clamps to target MP, removes MP directly
			# Phase 3: performHeal(source, source, RECOVERTYPE_MP, HEALCALCULUS_DIRECT, damageDone*totalAffectedTargets)
			var result: Dictionary = DamageCalculator.perform_attack(target, source, Constants.AttackType.DRAIN_MAGIC, element_idx, level)
			var drain: int = result.get("damage", 0)
			if drain > 0:
				var total_mp: int = drain * maxi(1, total_affected_targets)
				source.restore_mp(total_mp)
				# Show floating MP gain number (GMS2: performHeal spawns oBTL_counter MP_GAIN)
				var scene_root: Node = source.get_tree().current_scene if source.get_tree() else null
				if scene_root:
					FloatingNumber.spawn(scene_root, source, total_mp, FloatingNumber.CounterType.MP_GAIN)
		"moonSaber":
			target.set_status(Constants.Status.BUFF_WEAPON_LUNA, saber_dur)
			target.elemental_atunement[Constants.Element.LUNA] = 1.0
		"lunarBoost":
			# GMS2: strength +50%, agility -25% (short buff duration)
			target.set_status(Constants.Status.ATTACK_UP, short_buff_dur)
			target.set_status(Constants.Status.SPEED_DOWN, short_buff_dur)
		"moonEnergy":
			# GMS2: criticalRate +100% (short buff duration)
			# Apply custom bonus directly since no dedicated crit status exists
			target.set_status(Constants.Status.HIT_UP, short_buff_dur)
			target._status_bonuses[Constants.Status.HIT_UP] = {"criticalRate": 1.0}
		"changeForm":
			_apply_change_form()

		# --- Lumina (Light) ---
		"lucentBeam":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"lightSaber":
			target.set_status(Constants.Status.BUFF_WEAPON_LUMINA, saber_dur)
			target.elemental_atunement[Constants.Element.LUMINA] = 1.0
		"lucidBarrier":
			target.set_status(Constants.Status.LUCID_BARRIER, buff_dur)

		# --- Dryad (Nature) ---
		"sleepFlower":
			_apply_status_with_probability(Constants.Status.FAINT, debuff_dur)
		"burst":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"revivifier":
			if target.is_dead and not target.reviving:
				# GMS2: reviving flag prevents double-revive
				target.reviving = true
				# GMS2: healValue = attribute.maxHP / 2 (always 50% maxHP, level-independent)
				var heal: int = roundi(target.get_max_hp() * 0.5)
				target.apply_heal(heal)
				# Show heal number directly (do NOT use damage_stack — that triggers Hit state + hit sound)
				FloatingNumber.spawn(get_tree().current_scene, target, heal, FloatingNumber.CounterType.HP_GAIN)
				# GMS2: skill_revivifier_step calls cureAilments(self) after revive
				target.cure_ailments()
				target.reviving = false
		"wall":
			target.set_status(Constants.Status.WALL, buff_dur)
		"manaMagicOffensive":
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		"manaMagicSupport":
			var heal: int = roundi(target.get_max_hp() * 0.5 * max(1, level))
			target.apply_heal(heal)
			# Show heal number directly (do NOT use damage_stack — that triggers Hit state + hit sound)
			FloatingNumber.spawn(get_tree().current_scene, target, heal, FloatingNumber.CounterType.HP_GAIN)

		_:
			# Fallback: generic handling based on type array and target
			_apply_generic_effect(element_idx, debuff_dur)


func _apply_analyzer_display() -> void:
	## GMS2: oSkill_analyzer Step_0 - at timer==20, displays target's stats via addBattleDialog
	## Shows HP, MP, and for mobs: EXP, GP, and elemental weaknesses
	if not is_instance_valid(target):
		return

	# GMS2: addBattleDialog("HP " + hp + "/" + getMaxHP(target), ALIGN_BOTTOM, false, 1)
	GameManager.add_battle_dialog("HP %d/%d" % [target.attribute.hp, target.attribute.maxHP],
		BattleDialog.Align.BOTTOM, false, 1.0)
	GameManager.add_battle_dialog("MP %d/%d" % [target.attribute.mp, target.attribute.maxMP],
		BattleDialog.Align.BOTTOM, false, 1.0)

	# Mob-specific: EXP, Money, Weaknesses
	# GMS2: if (target.creatureIsMob) { ... target.attribute.experience, target.attribute.money }
	if target is Mob:
		var mob: Mob = target as Mob
		GameManager.add_battle_dialog("EXP %d" % mob.exp_reward,
			BattleDialog.Align.BOTTOM, false, 1.0)
		GameManager.add_battle_dialog("%d GP total." % mob.money_reward,
			BattleDialog.Align.BOTTOM, false, 1.0)

		# GMS2: target.attribute.magicWeakness is a ds_list of element name strings
		# Godot: elemental_weakness is float array; > 0 means weak (same check as creature.gd:197)
		var element_names: Array = ["Undine", "Gnome", "Sylphid", "Salamando",
									"Shade", "Luna", "Lumina", "Dryad"]
		var weaknesses: Array = []
		for i in range(mini(target.elemental_weakness.size(), Constants.ELEMENT_COUNT)):
			if target.elemental_weakness[i] > 0.0:
				weaknesses.append(element_names[i])

		if weaknesses.size() > 0:
			# GMS2: builds "Element1, Element2 and Element3" string
			var fear_str: String = ""
			if weaknesses.size() == 1:
				fear_str = weaknesses[0]
			elif weaknesses.size() == 2:
				fear_str = weaknesses[0] + " and " + weaknesses[1]
			else:
				for i in range(weaknesses.size()):
					if i == weaknesses.size() - 1:
						fear_str += "and " + weaknesses[i]
					else:
						fear_str += weaknesses[i] + ", "
			GameManager.add_battle_dialog("%s fears %s" % [mob.display_name, fear_str],
				BattleDialog.Align.BOTTOM, false, 3.0)


func _apply_change_form() -> void:
	## GMS2: oSkill_changeForm - on non-boss mobs, level-based roll to replace with rabite/slime
	## GMS2: STATUS_FAINT is applied during animation; after timer, mob is destroyed+replaced
	## On bosses: does nothing (boss debuff immunity)
	if not is_instance_valid(target) or not is_instance_valid(source):
		return

	# Bosses and non-mobs: immune, just return to stand
	if not (target is Mob) or target.creature_is_boss:
		_change_state_stand_dead(target)
		return

	var mob_target: Mob = target as Mob

	# GMS2 level-based success roll:
	# rollChance = (source.level - target.level) * 10, clamped to 100
	# rollNumber = floor(random_range(rollChance, 100))
	# Success if rollChance <= rollNumber
	var level_diff: int = source.attribute.level - target.attribute.level
	var roll_chance: int = clampi(level_diff * 10, 0, 100)
	var roll_number: int = floori(randf_range(float(roll_chance), 100.0))

	if roll_chance <= roll_number:
		# Success: destroy mob and spawn replacement
		# GMS2: randomly picks oMob_rabite or oMob_slime (50/50)
		var spawn_pos: Vector2 = mob_target.global_position
		var parent_node: Node = mob_target.get_parent()

		# Pick replacement: 0=rabite, 1=slime
		var selected_mob: int = randi() % 2
		var replacement_name: String = "rabite" if selected_mob == 0 else "slime"

		# Destroy the original mob
		mob_target.queue_free()

		# Spawn replacement mob
		var new_mob := Mob.new()
		new_mob.name = "mob_" + replacement_name
		new_mob.global_position = spawn_pos
		if parent_node:
			parent_node.add_child(new_mob)
	else:
		# Failure: mob recovers, return to stand/dead
		_change_state_stand_dead(target)


func _apply_lunar_magic_effect(element_idx: int, debuff_dur: int, short_buff_dur: int) -> void:
	## GMS2: Lunar Magic - random effect selection (floor(random_range(0, 4)) = 0-3)
	## Only triggers if target is not a boss
	var is_boss: bool = target is BossManaBeast or target is BossDarkLich
	if is_boss:
		# Bosses are immune to lunar magic random effects, just deal damage
		DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		return

	var random_effect: int = randi_range(0, 3)  # GMS2: floor(random_range(0, 4)) = 0,1,2,3

	match random_effect:
		0:
			# HEAL: heal target (or random creature set) up to 100% maxHP
			var targets: Array = _lunar_select_targets()
			for t in targets:
				if is_instance_valid(t) and t is Creature:
					var heal: int = t.get_max_hp()
					t.apply_heal(heal)
					t.damage_stack.append({"damage": -heal, "source": source, "attack_type": Constants.AttackType.MAGIC, "is_critical": false})
		1:
			# GMS2: STATUS_LUNAR_MAGIC - ±30% to STR, CON, AGI, CRIT (rollCoin for sign)
			var targets: Array = _lunar_select_targets()
			var is_boost: bool = randf() < 0.5  # GMS2: rollCoin()
			var pct: float = 0.3 if is_boost else -0.3
			for t in targets:
				if is_instance_valid(t) and t is Creature:
					# Use ATTACK_UP/DOWN as proxy with custom bonuses for all 4 stats
					var status: int = Constants.Status.ATTACK_UP if is_boost else Constants.Status.ATTACK_DOWN
					t.set_status(status, short_buff_dur)
					t._status_bonuses[status] = {
						"strength": pct, "constitution": pct,
						"agility": pct, "criticalRate": pct
					}
		2:
			# PYGMIZED: apply to all actors (players)
			for player in GameManager.get_alive_players():
				if is_instance_valid(player) and player is Creature:
					player.set_status(Constants.Status.PYGMIZED, debuff_dur)
		3:
			# CONFUSED: apply to all creatures (players + mobs)
			for player in GameManager.get_alive_players():
				if is_instance_valid(player) and player is Creature:
					player.set_status(Constants.Status.CONFUSED, debuff_dur)
			for mob in get_tree().get_nodes_in_group("mobs"):
				if is_instance_valid(mob) and mob is Creature and not mob.is_dead:
					mob.set_status(Constants.Status.CONFUSED, debuff_dur)


func _lunar_select_targets() -> Array:
	## GMS2: rollDice(3) - 0=target only, 1=all mobs, 2=all creatures
	var dice: int = randi_range(0, 2)
	match dice:
		0:
			return [target] if is_instance_valid(target) else []
		1:
			var mobs: Array = []
			for mob in get_tree().get_nodes_in_group("mobs"):
				if is_instance_valid(mob) and mob is Creature and not mob.is_dead:
					mobs.append(mob)
			return mobs
		2:
			var all: Array = []
			for player in GameManager.get_alive_players():
				if is_instance_valid(player):
					all.append(player)
			for mob in get_tree().get_nodes_in_group("mobs"):
				if is_instance_valid(mob) and mob is Creature and not mob.is_dead:
					all.append(mob)
			return all
	return [target] if is_instance_valid(target) else []


func _apply_status_with_probability(status: int, duration: int) -> void:
	var probability: float = 100.0
	var val1 = skill_data.get("value1", 100.0)
	if val1 is float or val1 is int:
		probability = float(val1)
	if probability >= 100.0 or randf() * 100.0 <= probability:
		target.set_status(status, duration)


func _apply_generic_effect(element_idx: int, duration: int) -> void:
	## Fallback for any unrecognized skill name
	var types_raw = skill_data.get("type", [])
	var types: Array = types_raw if types_raw is Array else ([types_raw] if types_raw is String else [])

	# Check for explicit status types in the type array
	_apply_status_from_skill(types, duration)

	# Check if it's an offensive skill
	var target_str: String = skill_data.get("target", "")
	if target_str == "ENEMY":
		DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
	elif target_str == "ALLY" and types.is_empty():
		# Generic ally skill with no type - try heal based on value1
		var value1 = skill_data.get("value1", 0)
		if value1 is float or value1 is int:
			if float(value1) > 0:
				var heal: int = roundi(float(value1) * max(1, level) * 50.0)
				target.apply_heal(heal)
				# Show heal number directly (do NOT use damage_stack — that triggers Hit state + hit sound)
				FloatingNumber.spawn(get_tree().current_scene, target, heal, FloatingNumber.CounterType.HP_GAIN)


func _apply_status_from_skill(types: Array, duration: int) -> void:
	var status_map: Dictionary = {
		"STATUS_FROZEN": Constants.Status.FROZEN,
		"STATUS_PETRIFIED": Constants.Status.PETRIFIED,
		"STATUS_CONFUSED": Constants.Status.CONFUSED,
		"STATUS_POISONED": Constants.Status.POISONED,
		"STATUS_BALLOON": Constants.Status.BALLOON,
		"STATUS_ENGULFED": Constants.Status.ENGULFED,
		"STATUS_FAINT": Constants.Status.FAINT,
		"STATUS_SILENCED": Constants.Status.SILENCED,
		"STATUS_ASLEEP": Constants.Status.ASLEEP,
		"STATUS_SNARED": Constants.Status.SNARED,
		"STATUS_PYGMIZED": Constants.Status.PYGMIZED,
		"STATUS_SPEED_UP": Constants.Status.SPEED_UP,
		"STATUS_SPEED_DOWN": Constants.Status.SPEED_DOWN,
		"STATUS_ATTACK_UP": Constants.Status.ATTACK_UP,
		"STATUS_ATTACK_DOWN": Constants.Status.ATTACK_DOWN,
		"STATUS_DEFENSE_UP": Constants.Status.DEFENSE_UP,
		"STATUS_DEFENSE_DOWN": Constants.Status.DEFENSE_DOWN,
		"STATUS_MAGIC_UP": Constants.Status.MAGIC_UP,
		"STATUS_MAGIC_DOWN": Constants.Status.MAGIC_DOWN,
		"STATUS_HIT_UP": Constants.Status.HIT_UP,
		"STATUS_HIT_DOWN": Constants.Status.HIT_DOWN,
		"STATUS_EVADE_UP": Constants.Status.EVADE_UP,
		"STATUS_EVADE_DOWN": Constants.Status.EVADE_DOWN,
		"STATUS_WALL": Constants.Status.WALL,
		"STATUS_LUCID_BARRIER": Constants.Status.LUCID_BARRIER,
		"STATUS_BUFF_WEAPON_UNDINE": Constants.Status.BUFF_WEAPON_UNDINE,
		"STATUS_BUFF_WEAPON_GNOME": Constants.Status.BUFF_WEAPON_GNOME,
		"STATUS_BUFF_WEAPON_SYLPHID": Constants.Status.BUFF_WEAPON_SYLPHID,
		"STATUS_BUFF_WEAPON_SALAMANDO": Constants.Status.BUFF_WEAPON_SALAMANDO,
		"STATUS_BUFF_WEAPON_SHADE": Constants.Status.BUFF_WEAPON_SHADE,
		"STATUS_BUFF_WEAPON_LUNA": Constants.Status.BUFF_WEAPON_LUNA,
		"STATUS_BUFF_WEAPON_LUMINA": Constants.Status.BUFF_WEAPON_LUMINA,
		"STATUS_BUFF_WEAPON_DRYAD": Constants.Status.BUFF_WEAPON_DRYAD,
	}

	var probability: float = 100.0
	var val1 = skill_data.get("value1", 100.0)
	if val1 is float or val1 is int:
		probability = float(val1)

	for type_str in types:
		if type_str is not String:
			continue
		if type_str in status_map:
			if probability >= 100.0 or randf() * 100.0 <= probability:
				target.set_status(status_map[type_str], duration)


func _get_element_index() -> int:
	var deity: String = skill_data.get("deity", "")
	match deity:
		"Undine": return Constants.Element.UNDINE
		"Gnome": return Constants.Element.GNOME
		"Sylphid": return Constants.Element.SYLPHID
		"Salamando": return Constants.Element.SALAMANDO
		"Shade": return Constants.Element.SHADE
		"Luna": return Constants.Element.LUNA
		"Lumina": return Constants.Element.LUMINA
		"Dryad": return Constants.Element.DRYAD
	return -1


func _play_skill_sound() -> void:
	var sound_map: Dictionary = {
		# Undine
		"cureWater": "snd_cure",  # GMS2: plays snd_cure (snd_healParty is for party heal)
		"remedy": "snd_remedy",
		"iceSaber": "snd_magicWeapon",
		"freezeBeam": "snd_freezeBeam",
		"petrifyBeam": "snd_freezeBeam",
		"freeze": "snd_freezeOrb",
		"acidStorm": "snd_skill_acidStorm",
		"energyAbsorb": "snd_absorb",
		# Gnome
		"earthSlide": "snd_earthSlide",
		"gemMissile": "snd_skill_gemMissile",
		"stoneSaber": "snd_magicWeapon",
		"speedUp": "snd_skill_speedUp",
		"speedDown": "snd_skill_speedDown",
		"defender": "snd_skill_defender",
		"pygmusGlare": "snd_pygmize",  # GMS2: soundPlay(snd_pygmize) in skill_pygmize_create
		# Sylphid
		"thunderbolt": "snd_thunderbolt",
		"airBlast": "snd_skill_airBlast",
		"thunderSaber": "snd_magicWeapon",
		"confuseHoops": "snd_confuseHoops",
		"silence": "snd_skill_silence",
		"balloonRing": "snd_balloon",
		"balloon": "snd_balloon",
		"analyzer": "snd_skill_analyzer",
		# Salamando
		"fireball": "snd_skill_fireball",
		"exploder": "snd_skill_exploder",
		"lavaWave": "snd_skill_lavaWave",
		"flameSaber": "snd_magicWeapon",
		"fireBouquet": "snd_skill_fireBouquet",
		"blazeWall": "snd_skill_blazeWall",
		# Shade
		"darkForce": "snd_darkForce",
		"evilGate": "snd_darkGate",
		"dispelMagic": "snd_dispel",
		"sleepGas": "snd_skill_sleepFlower",
		"leadenGlare": "snd_freezeBeam",
		"poisonGas": "snd_pygmize",  # GMS2: soundPlay(snd_pygmize) in oSkill_poisonGas Create_0
		# Luna
		"lunarMagic": "snd_skill_lunarMagic",
		"magicAbsorb": "snd_absorb",
		"moonSaber": "snd_magicWeapon",
		"lunarBoost": "snd_skill_lunarBoost",
		"moonEnergy": "snd_skill_moonEnergy",
		"changeForm": "snd_pygmize",
		# Lumina
		"lucentBeam": "snd_lucentBeam",
		"lightSaber": "snd_magicWeapon",
		"lucidBarrier": "snd_lunarBarrier",
		# Dryad
		"sleepFlower": "snd_skill_sleepFlower",
		"burst": "snd_skill_exploder",
		"revivifier": "snd_revivifier",
		"wall": "snd_lunarBarrier",
		"manaMagicOffensive": "snd_manaMagic",
		"manaMagicSupport": "snd_manaMagic",
	}

	var snd: String = sound_map.get(skill_name, "")
	if snd.is_empty():
		snd = "snd_skill_" + skill_name
	MusicManager.play_sfx(snd)


# =============================================================================
# Absorb Spiral Effect (GMS2: oSkill_energyAbsorb / oSkill_magicAbsorb)
# =============================================================================

func _setup_absorb_spiral() -> void:
	## Load the ball sprite texture and hide the standard effect sprite.
	effect_sprite.visible = false
	# Load ball texture
	var sprite_key: String = "spr_skill_" + skill_name
	var sheet_path: String = "res://assets/sprites/sheets/%s.png" % sprite_key
	var json_path: String = sheet_path.replace(".png", ".json")
	if ResourceLoader.exists(sheet_path):
		_absorb_ball_texture = load(sheet_path)
	if FileAccess.file_exists(json_path):
		var f := FileAccess.open(json_path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(f.get_as_text()) == OK:
			var meta: Dictionary = json.data
			_absorb_ball_frame_w = meta.get("frame_width", 16)
			_absorb_ball_frame_h = meta.get("frame_height", 16)
			_absorb_ball_columns = meta.get("columns", 10)
			_absorb_ball_total_frames = meta.get("total_frames", 10)
	# Initialize arrays
	for i in range(_ABSORB_TOTAL_BALLS):
		_absorb_ball_lengths.append(10.0)  # GMS2: initialMovement = 10
		_absorb_ball_speeds.append(0.5)
		_absorb_ball_frame_accum.append(0.0)
		_absorb_ball_current_frame.append(0)
	_absorb_phase = 0
	_absorb_timer = 0
	_absorb_ball_timer = 0.0
	_absorb_created_balls = 0
	_absorb_anim_direction = 0.0


func _process_absorb_spiral(delta: float) -> void:
	_absorb_timer += delta
	match _absorb_phase:
		0: _absorb_phase_outward(delta)
		1: _absorb_phase_transition()
		2: _absorb_phase_inward(delta)
		3: _absorb_phase_finish()


func _absorb_phase_outward(delta: float) -> void:
	## Phase 0: Balls spiral outward from target.
	_absorb_ball_timer += delta
	# Create a new ball every 6 frames (0.1s)
	_absorb_spawn_accum += delta
	while _absorb_spawn_accum >= 6.0 / 60.0 and _absorb_created_balls < _ABSORB_TOTAL_BALLS:
		_absorb_spawn_accum -= 6.0 / 60.0
		_create_absorb_ball()
		_absorb_ball_timer = 0.0
	# Rotate spiral
	_absorb_anim_direction -= _ABSORB_ANIM_SPEED * delta * 60.0
	# Update ball positions
	for i in range(_absorb_created_balls):
		_absorb_ball_lengths[i] += _absorb_ball_speeds[i] * delta * 60.0
		var angle: float = _absorb_anim_direction - (i * _ABSORB_DIR_SEPARATION)
		var center: Vector2 = target.global_position if is_instance_valid(target) else global_position
		_absorb_balls[i].global_position = center + _lengthdir(_absorb_ball_lengths[i], angle)
		# Fade out when far (GMS2: image_alpha -= 0.1, then clamp(0,1))
		if _absorb_ball_lengths[i] > 70.0:
			_absorb_balls[i].modulate.a -= 0.1 * delta * 60.0
		_absorb_balls[i].modulate.a = clampf(_absorb_balls[i].modulate.a, 0.0, 1.0)
		_absorb_ball_speeds[i] += 0.2 * delta * 60.0
		# Animate ball sprite
		_animate_absorb_ball(i, delta)
	# End phase when all balls created and waited 15 frames (0.25s)
	if _absorb_created_balls >= _ABSORB_TOTAL_BALLS and _absorb_ball_timer > 15.0 / 60.0:
		_absorb_phase = 1


func _absorb_phase_transition() -> void:
	## Phase 1: Destroy all balls and prepare inward spiral.
	for ball in _absorb_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	_absorb_balls.clear()
	_absorb_created_balls = 0
	_absorb_ball_timer = 0.0
	# Reset ball arrays for phase 2
	for i in range(_ABSORB_TOTAL_BALLS):
		_absorb_ball_lengths[i] = 100.0  # GMS2: start at distance 100
		_absorb_ball_speeds[i] = 6.0
		_absorb_ball_frame_accum[i] = 0.0
		_absorb_ball_current_frame[i] = 0
	_absorb_phase = 2


func _absorb_phase_inward(delta: float) -> void:
	## Phase 2: Balls spiral inward toward source.
	# GMS2: animDirection decremented BEFORE ball creation (line 52 in Step_0)
	_absorb_anim_direction -= _ABSORB_ANIM_SPEED * delta * 60.0
	# Create a new ball every 6 frames (0.1s)
	_absorb_spawn_accum += delta
	while _absorb_spawn_accum >= 6.0 / 60.0 and _absorb_created_balls < _ABSORB_TOTAL_BALLS:
		_absorb_spawn_accum -= 6.0 / 60.0
		_absorb_ball_lengths[_absorb_created_balls] = 100.0
		_absorb_ball_speeds[_absorb_created_balls] = 6.0
		_create_absorb_ball()
		# Position the new ball at its starting orbit position
		var idx: int = _absorb_created_balls - 1
		var angle: float = _absorb_anim_direction - (idx * _ABSORB_DIR_SEPARATION)
		var center: Vector2 = target.global_position if is_instance_valid(target) else global_position
		_absorb_balls[idx].global_position = center + _lengthdir(_absorb_ball_lengths[idx], angle)
		_absorb_ball_timer = 0.0
	# Update ball positions — spiral toward source
	var src_pos: Vector2 = source.global_position if is_instance_valid(source) else global_position
	for i in range(_absorb_created_balls):
		_absorb_ball_speeds[i] -= 0.2 * delta * 60.0
		_absorb_ball_speeds[i] = clampf(_absorb_ball_speeds[i], 3.0, 6.0)
		_absorb_ball_lengths[i] -= _absorb_ball_speeds[i] * delta * 60.0
		_absorb_ball_lengths[i] = clampf(_absorb_ball_lengths[i], 0.0, 500.0)
		var angle: float = _absorb_anim_direction - (i * _ABSORB_DIR_SEPARATION)
		_absorb_balls[i].global_position = src_pos + _lengthdir(_absorb_ball_lengths[i], angle)
		# Fade in as they approach, fade out when very close (GMS2: clamp(0,1))
		if _absorb_ball_lengths[i] > 10.0:
			_absorb_balls[i].modulate.a += 0.2 * delta * 60.0
		else:
			_absorb_balls[i].modulate.a -= 0.2 * delta * 60.0
		_absorb_balls[i].modulate.a = clampf(_absorb_balls[i].modulate.a, 0.0, 1.0)
		_animate_absorb_ball(i, delta)
	# GMS2: end condition checked BEFORE ballTimer++ (lines 94 vs 97 in Step_0)
	if _absorb_created_balls >= _ABSORB_TOTAL_BALLS and _absorb_ball_timer > 30.0 / 60.0:
		_absorb_phase = 3
	_absorb_ball_timer += delta


func _absorb_phase_finish() -> void:
	## Phase 3: Destroy balls, apply effect, and clean up.
	for ball in _absorb_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	_absorb_balls.clear()
	# Trigger the standard effect application path
	_on_animation_complete()


func _create_absorb_ball() -> void:
	## Create a single ball Sprite2D for the spiral effect.
	var ball := Sprite2D.new()
	if _absorb_ball_texture:
		ball.texture = _absorb_ball_texture
		ball.region_enabled = true
		ball.region_rect = Rect2(0, 0, _absorb_ball_frame_w, _absorb_ball_frame_h)
		ball.offset = -Vector2(_absorb_ball_frame_w * 0.5, _absorb_ball_frame_h * 0.5)
	else:
		ball.visible = false
	ball.z_index = 1000
	get_parent().add_child(ball)
	_absorb_balls.append(ball)
	_absorb_created_balls += 1


func _animate_absorb_ball(idx: int, delta: float = 0.0) -> void:
	## Animate a single ball sprite (GMS2: image_speed = 0.1).
	if idx >= _absorb_balls.size() or not is_instance_valid(_absorb_balls[idx]):
		return
	_absorb_ball_frame_accum[idx] += _ABSORB_BALL_IMG_SPEED * delta * 60.0
	if _absorb_ball_frame_accum[idx] >= 1.0:
		_absorb_ball_frame_accum[idx] -= 1.0
		_absorb_ball_current_frame[idx] += 1
		if _absorb_ball_current_frame[idx] >= _absorb_ball_total_frames:
			_absorb_ball_current_frame[idx] = 0
		var frame: int = _absorb_ball_current_frame[idx]
		var col: int = frame % _absorb_ball_columns
		@warning_ignore("INTEGER_DIVISION")
		var row: int = frame / _absorb_ball_columns
		_absorb_balls[idx].region_rect = Rect2(
			col * _absorb_ball_frame_w, row * _absorb_ball_frame_h,
			_absorb_ball_frame_w, _absorb_ball_frame_h)


static func _lengthdir(length: float, direction_deg: float) -> Vector2:
	## GMS2 lengthdir_x/y: polar to cartesian. GMS2 angles: 0°=right, 90°=up (screen y down).
	var rad: float = deg_to_rad(direction_deg)
	return Vector2(length * cos(rad), -length * sin(rad))


# =============================================================================
# Generic Custom Skill Visual Handlers
# =============================================================================

func _setup_custom_handler() -> void:
	match _custom_handler:
		"burst": _setup_burst()
		"exploder": _setup_exploder()
		"fireball": _setup_fireball()
		"moonEnergy": _setup_moon_energy()
		"thunderbolt": _setup_thunderbolt()
		"earthSlide": _setup_earth_slide()
		"multi_burst": _setup_multi_burst()
		"acid_storm": _setup_acid_storm()
		"wall_spark": _setup_wall_spark()
		"freeze": _setup_freeze()
		"dark_force": _setup_dark_force()
		"lucent_beam": _setup_lucent_beam()
		"evil_gate": _setup_evil_gate()
		"cure_water": _setup_cure_water()
		"remedy": _setup_remedy()
		"saber": _setup_saber()
		"air_blast": _setup_air_blast()
		"dispel_magic": _setup_dispel_magic()
		"confuse_hoops": _setup_confuse_hoops()
		"poison_gas": _setup_poison_gas()
		"balloon": _setup_balloon()
		"revivifier": _setup_revivifier()
		"leaden_glare": _setup_leaden_glare()
		"pygmus_glare": _setup_pygmus_glare()
		"change_form": _setup_change_form()


func _process_custom_handler(delta: float) -> void:
	_custom_timer += delta
	match _custom_handler:
		"burst": _step_burst()
		"exploder": _step_exploder()
		"fireball": _step_fireball()
		"moonEnergy": _step_moon_energy()
		"thunderbolt": _step_thunderbolt()
		"earthSlide": _step_earth_slide()
		"multi_burst": _step_multi_burst()
		"acid_storm": _step_acid_storm()
		"wall_spark": _step_wall_spark()
		"freeze": _step_freeze()
		"dark_force": _step_dark_force()
		"lucent_beam": _step_lucent_beam()
		"evil_gate": _step_evil_gate()
		"cure_water": _step_cure_water()
		"remedy": _step_remedy()
		"saber": _step_saber()
		"air_blast": _step_air_blast()
		"dispel_magic": _step_dispel_magic()
		"confuse_hoops": _step_confuse_hoops()
		"poison_gas": _step_poison_gas()
		"balloon": _step_balloon()
		"revivifier": _step_revivifier()
		"leaden_glare": _step_leaden_glare()
		"pygmus_glare": _step_pygmus_glare()
		"change_form": _step_change_form()


func _custom_finish() -> void:
	## Common finish path for all custom handlers.
	_custom_finished = true
	_on_animation_complete()


## Spawn a GenericAnimation at a position using SpriteUtils data.
func _spawn_anim(sprite_key: String, pos: Vector2, img_speed: float = 1.0) -> GenericAnimation:
	_ensure_sprite_db()
	var info: Dictionary = _sprite_db.get(sprite_key, {})
	if info.is_empty():
		return null
	var sheet_path: String = "res://assets/sprites/sheets/%s.png" % sprite_key
	if not ResourceLoader.exists(sheet_path):
		return null
	var tex: Texture2D = load(sheet_path)
	var fw: int = info.get("frame_width", 32)
	var fh: int = info.get("frame_height", 32)
	var cols: int = info.get("columns", 1)
	var total: int = info.get("total_frames", 1)
	var playback: float = info.get("playback_speed", 15.0)
	# GMS2: effective speed = playback * image_speed / 60
	var effective_speed: float = (playback * img_speed) / 60.0
	var ox: int = info.get("origin_x", fw / 2)
	var oy: int = info.get("origin_y", fh / 2)
	var anim := GenericAnimation.play_at(
		get_parent(), pos, tex, cols, fw, fh, 0, total - 1, effective_speed)
	anim.sprite_offset = -Vector2(ox, oy)
	_custom_anims.append(anim)
	return anim


# --- burst (GMS2: oSkill_burst) ---
# 10 sequential explosions: 5 around source, 5 around target, every 12 frames.
# sourceWaits=true. After 5th: pause 30 frames, sound repeat, then 5 more.
# After all 10 + 60 frame wait → finish.

func _setup_burst() -> void:
	var src_pos: Vector2 = source.global_position if is_instance_valid(source) else global_position
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	_custom_positions = [
		src_pos + Vector2(20, -10), src_pos + Vector2(-15, 10),
		src_pos + Vector2(0, 0), src_pos + Vector2(-15, -25), src_pos + Vector2(8, 10),
		tgt_pos + Vector2(20, -10), tgt_pos + Vector2(-15, 10),
		tgt_pos + Vector2(0, 0), tgt_pos + Vector2(-15, -25), tgt_pos + Vector2(8, 10),
	]
	_custom_created = 0
	_custom_timer2 = 0.0
	_burst_spawn_acc = 0.0

func _step_burst() -> void:
	# GMS2: event_inherited() runs parent Step_0 (timer increments there too)
	var total: int = _custom_positions.size()  # 10
	if _custom_created < 5 or (_custom_created >= 5 and _custom_timer > 30.0 / 60.0 and _custom_created < total):
		_burst_spawn_acc += _dt
		while _burst_spawn_acc >= 12.0 / 60.0:
			_burst_spawn_acc -= 12.0 / 60.0
			if _custom_created < 5 or (_custom_created >= 5 and _custom_created < total):
				if _custom_created == 5:
					MusicManager.play_sfx("snd_skill_exploder")
				_spawn_anim("spr_skill_burst", _custom_positions[_custom_created], 1.0)
				_custom_created += 1
				if _custom_created < 5:
					_custom_timer = 0.0
	if _custom_created >= total:
		_custom_timer2 += _dt
		if _custom_timer2 > 60.0 / 60.0:
			_custom_finish()


# --- exploder (GMS2: oSkill_exploder) ---
# 5 explosions around target, every 12 frames. After all 5 + 60 frame wait → finish.

func _setup_exploder() -> void:
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	_custom_positions = [
		tgt_pos + Vector2(20, -10), tgt_pos + Vector2(-15, 10),
		tgt_pos + Vector2(0, 0), tgt_pos + Vector2(-15, -25), tgt_pos + Vector2(8, 10),
	]
	_custom_created = 0
	_custom_timer2 = 0.0
	_exploder_spawn_acc = 0.0

func _step_exploder() -> void:
	if _custom_created < _custom_positions.size():
		_exploder_spawn_acc += _dt
		while _exploder_spawn_acc >= 12.0 / 60.0:
			_exploder_spawn_acc -= 12.0 / 60.0
			if _custom_created < _custom_positions.size():
				_spawn_anim("spr_skill_exploder", _custom_positions[_custom_created], 1.0)
				_custom_created += 1
	if _custom_created >= _custom_positions.size():
		_custom_timer2 += _dt
		if _custom_timer2 > 60.0 / 60.0:
			_custom_finish()


# --- fireball (GMS2: oSkill_fireball + oSkill_fireball_projectile) ---
# GMS2 behavior:
#   oSkill_fireball Create_0: spawns 3 oSkill_fireball_projectile from source → target
#     - Projectile 0: dir + rand(±1), delay 0
#     - Projectile 1: dir + 90,        delay 10
#     - Projectile 2: dir - 90,        delay 20
#     dir = point_direction(source, target) + 180 (initially AWAY from target, curves back)
#   oSkill_fireball_projectile (isSaber=false):
#     - Sprite: spr_skill_fireball (32×32, 4 frames, image_speed=0.2 → 12fps)
#     - Phase 0: hidden during executionDelay
#     - Phase 1: homing flight (dirSpeed += 0.06, maxSpeed=5, dirSpeedMax=4)
#     - Flickering: image_alpha toggles every frame (not isQuickBall)
#     - image_angle rotates with direction
#     - Collision: timer2 > 45+delay AND within 24px, OR timer2 > 180
#     - On collision: switch to spr_skill_fireball2 (64×64, 14 frames, 15fps), play at target
#   oSkill_fireball Step_0: all 3 collided → reset timer, wait 80 frames → performAttack

var _fb_sparks: Array = []          # 3 Sprite2D nodes (travel fireballs)
var _fb_spark_dirs: Array = []      # GMS2 direction per projectile (degrees, CCW)
var _fb_spark_dir_speeds: Array = []
var _fb_spark_collided: Array = []
var _fb_spark_timer2: Array = []    # Per-projectile frame timer
var _fb_initial_dist: float = 0.0
var _fb_same_target: bool = false
var _fb_explosion_playing: bool = false
var _fb_post_collision_timer: float = 0.0
var _fb_shader_activated: bool = false
# Fireball travel sprite metadata
var _fb_spark_tex: Texture2D = null
var _fb_spark_fw: int = 32
var _fb_spark_fh: int = 32
var _fb_spark_cols: int = 4
var _fb_spark_total: int = 4

const _FB_DELAYS: Array = [0.0, 10.0 / 60.0, 20.0 / 60.0]  # GMS2 frames → seconds
const _FB_MIN_SPEED: float = 1.5
const _FB_MAX_SPEED: float = 5.0       # GMS2: projectileMaxSpeed=5 (not isQuickBall)
const _FB_DIR_SPEED_MIN: float = 0.5
const _FB_DIR_SPEED_MAX: float = 4.0   # GMS2: dirSpeedMax=4 (not isQuickBall)
const _FB_DIR_ACCEL: float = 0.06
const _FB_COLLISION_RADIUS: float = 24.0
const _FB_POST_COLLISION_WAIT: float = 80.0 / 60.0  # GMS2: timer > 80 frames after all collide

func _setup_fireball() -> void:
	var src_pos: Vector2 = source.global_position if is_instance_valid(source) else global_position
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	_fb_initial_dist = src_pos.distance_to(tgt_pos)
	_fb_same_target = _fb_initial_dist < 1.0
	_fb_explosion_playing = false
	_fb_post_collision_timer = 0.0
	_fb_shader_activated = false

	# Hide explosion effect_sprite — only shown after all sparks collide
	effect_sprite.visible = false
	effect_sprite.stop()

	# Calculate initial directions (GMS2: dir = point_direction + 180, away from target)
	var gms2_dir_to_target: float = -rad_to_deg((tgt_pos - src_pos).angle()) if _fb_initial_dist > 0.5 else 0.0
	var away_dir: float = gms2_dir_to_target + 180.0
	var rand_sign: float = 1.0 if randf() > 0.5 else -1.0

	_fb_spark_dirs = [away_dir + rand_sign, away_dir + 90.0, away_dir - 90.0]
	_fb_spark_dir_speeds = [_FB_DIR_SPEED_MIN, _FB_DIR_SPEED_MIN, _FB_DIR_SPEED_MIN]
	_fb_spark_collided = [false, false, false]
	_fb_spark_timer2 = [0.0, 0.0, 0.0]

	# Load fireball travel sprite texture
	_ensure_sprite_db()
	var info: Dictionary = _sprite_db.get("spr_skill_fireball", {})
	_fb_spark_fw = info.get("frame_width", 32)
	_fb_spark_fh = info.get("frame_height", 32)
	_fb_spark_cols = info.get("columns", 4)
	_fb_spark_total = info.get("total_frames", 4)
	var sheet_path: String = "res://assets/sprites/sheets/spr_skill_fireball.png"
	if ResourceLoader.exists(sheet_path):
		_fb_spark_tex = load(sheet_path)

	# Build palette swap shader for projectiles (GMS2: Draw_0 applies shader to draw_self)
	var proj_shader_mat: ShaderMaterial = null
	if SKILL_TARGET_PALETTE_SWAP.has(skill_name):
		if _palette_swap_shader == null:
			_palette_swap_shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
		if _palette_swap_shader:
			var params: Array = SKILL_TARGET_PALETTE_SWAP[skill_name]
			proj_shader_mat = ShaderMaterial.new()
			proj_shader_mat.shader = _palette_swap_shader
			proj_shader_mat.set_shader_parameter("u_color_channel", params[0])
			proj_shader_mat.set_shader_parameter("u_color_add", Vector3(params[1], params[2], params[3]))
			proj_shader_mat.set_shader_parameter("u_color_limit", params[4])

	# Create 3 fireball projectile Sprite2D nodes at source position
	for i in range(3):
		var spr := Sprite2D.new()
		spr.texture = _fb_spark_tex
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, _fb_spark_fw, _fb_spark_fh)
		spr.z_index = 1000
		spr.visible = false  # Hidden during execution delay
		spr.global_position = src_pos
		if proj_shader_mat:
			spr.material = proj_shader_mat.duplicate()
		get_parent().add_child(spr)
		_fb_sparks.append(spr)
		_custom_anims.append(spr)


func _step_fireball() -> void:
	# Phase: explosion playing — wait for it to finish via effect_sprite animation
	if _fb_explosion_playing:
		# Wait for all 3 to collide (they should already be), then count post-collision frames
		_fb_post_collision_timer += _dt
		if effect_sprite.sprite_frames:
			var fc: int = effect_sprite.sprite_frames.get_frame_count("effect")
			# GMS2: wait 80 frames after all collide, then finish
			if _fb_post_collision_timer > _FB_POST_COLLISION_WAIT:
				_custom_finish()
		return

	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	var all_done: bool = true
	var any_collided: bool = false

	for i in range(3):
		if _fb_spark_collided[i]:
			any_collided = true
			continue

		# Execution delay (GMS2: phase 0 → hidden until timer > executionDelay)
		if _custom_timer <= _FB_DELAYS[i]:
			all_done = false
			continue

		all_done = false
		_fb_spark_timer2[i] += _dt

		# Make visible when delay expires
		if i < _fb_sparks.size() and is_instance_valid(_fb_sparks[i]) and not _fb_sparks[i].visible:
			_fb_sparks[i].visible = true

		if i >= _fb_sparks.size() or not is_instance_valid(_fb_sparks[i]):
			_fb_spark_collided[i] = true
			continue

		var spark_pos: Vector2 = _fb_sparks[i].global_position

		# Homing movement (GMS2: oSkill_fireball_projectile Step_0, phase 1)
		var dist: float = spark_pos.distance_to(tgt_pos)
		var spd: float
		if _fb_same_target:
			spd = 1.5
		else:
			var dist_pct: float = dist / maxf(_fb_initial_dist, 1.0)
			spd = lerpf(_FB_MAX_SPEED, _FB_MIN_SPEED, dist_pct)

		# Steering acceleration
		_fb_spark_dir_speeds[i] += _FB_DIR_ACCEL
		_fb_spark_dir_speeds[i] = clampf(_fb_spark_dir_speeds[i], _FB_DIR_SPEED_MIN, _FB_DIR_SPEED_MAX)

		# GMS2: point_direction(x, y, tgt_x, tgt_y) → angle to target
		var gms2_target_dir: float = -rad_to_deg((tgt_pos - spark_pos).angle()) if dist > 0.5 else _fb_spark_dirs[i]

		# GMS2: dir += sign(dsin(a - dir)) * dirSpeed
		var dir_movement: float
		if _fb_same_target and _fb_spark_timer2[i] < 15.0 / 60.0:
			dir_movement = 9.0
		else:
			var angle_diff: float = gms2_target_dir - _fb_spark_dirs[i]
			dir_movement = sign(sin(deg_to_rad(angle_diff))) * _fb_spark_dir_speeds[i]

		_fb_spark_dirs[i] += dir_movement

		# Move (GMS2: motion_set(dir, speed))
		_fb_sparks[i].global_position += _lengthdir(spd, _fb_spark_dirs[i])

		# GMS2: image_angle = dir — rotate projectile to face movement direction
		_fb_sparks[i].rotation = -deg_to_rad(_fb_spark_dirs[i])

		# Animate fireball frames (GMS2: image_speed=0.2 at playback 60fps → 12fps effective)
		@warning_ignore("INTEGER_DIVISION")
		var frame_idx: int = int(_fb_spark_timer2[i] * 12.0) % _fb_spark_total
		var col: int = frame_idx % _fb_spark_cols
		var row: int = frame_idx / _fb_spark_cols
		_fb_sparks[i].region_rect = Rect2(col * _fb_spark_fw, row * _fb_spark_fh, _fb_spark_fw, _fb_spark_fh)

		# GMS2: image_alpha flicker — toggle every frame (not isQuickBall)
		_fb_sparks[i].modulate.a = 0.0 if (int(_fb_spark_timer2[i] * 60.0) % 2 == 0) else 1.0

		# Collision check (GMS2: timer2 > 45+executionDelay AND within 24px, OR timeout at 180)
		# Note: In GMS2 timer2 counts from frame 0 (including delay), so "45 + delay" = 45 frames of flight.
		# Here _fb_spark_timer2 starts AFTER delay, so we just check > 45.
		if (_fb_spark_timer2[i] > 45.0 / 60.0 and dist < _FB_COLLISION_RADIUS) or _fb_spark_timer2[i] > 180.0 / 60.0:
			_fb_spark_collided[i] = true
			_fb_sparks[i].visible = false
			# GMS2: soundPlayOverlap(soundEffect2) — play collision sound
			MusicManager.play_sfx("snd_skill_fireball2")
			any_collided = true

	# GMS2 Draw_0: shader activates on target when ANY projectile has collided
	if any_collided and not _fb_shader_activated:
		_fb_shader_activated = true
		_apply_target_shader()

	# When all 3 have collided → show explosion animation at target
	if all_done and _fb_spark_collided[0] and _fb_spark_collided[1] and _fb_spark_collided[2]:
		_fb_explosion_playing = true
		_fb_post_collision_timer = 0.0
		# Destroy projectile sprites
		for spr in _fb_sparks:
			if is_instance_valid(spr):
				spr.queue_free()
		_fb_sparks.clear()
		_custom_anims = _custom_anims.filter(func(a): return is_instance_valid(a))
		# Show explosion animation (spr_skill_fireball2) at target position
		effect_sprite.visible = true
		global_position = tgt_pos + Vector2(0, -10)
		if effect_sprite.sprite_frames:
			effect_sprite.frame = 0
			effect_sprite.play()


# --- moonEnergy (GMS2: oSkill_moonEnergy) ---
# Uses 3 oSkill_fireball_projectile objects (same as fireball) with quickBall parameters.
# GMS2 Create_0: dir = point_direction(source, target); projectiles at dir+40, dir+80, dir-80
#   Delays: [5, 0, 10]; isQuickBall=true → speedMax=6, dirSpeedMax=9
#   image_speed=0 during flight (static frame), image_speed=1 on collision
#   No image_angle rotation (isQuickBall), no alpha flicker (isQuickBall)
# GMS2 Step_0: phase 2 first collider destroys others; when all collided wait 60 frames → apply buff
# GMS2 Draw_0: Luna palette swap activates when ANY projectile collides

var _me_sparks: Array = []          # 3 Sprite2D nodes (projectiles)
var _me_spark_dirs: Array = []      # GMS2 direction per projectile (degrees, CCW)
var _me_spark_dir_speeds: Array = []
var _me_spark_collided: Array = []
var _me_spark_timer2: Array = []    # Per-projectile frame timer (counts after delay)
var _me_initial_dist: float = 0.0
var _me_same_target: bool = false
var _me_impact_playing: bool = false
var _me_post_collision_timer: float = 0.0
var _me_shader_activated: bool = false
# moonEnergy sprite metadata
var _me_spark_tex: Texture2D = null
var _me_spark_fw: int = 32
var _me_spark_fh: int = 32
var _me_spark_cols: int = 5
var _me_spark_total: int = 5

const _ME_DELAYS: Array = [5.0 / 60.0, 0.0, 10.0 / 60.0]  # GMS2 frames → seconds
const _ME_MIN_SPEED: float = 1.5
const _ME_MAX_SPEED: float = 6.0       # GMS2: projectileMaxSpeed=6 (isQuickBall)
const _ME_DIR_SPEED_MIN: float = 0.5
const _ME_DIR_SPEED_MAX: float = 9.0   # GMS2: dirSpeedMax=9 (isQuickBall)
const _ME_DIR_ACCEL: float = 0.06
const _ME_COLLISION_RADIUS: float = 24.0
const _ME_POST_COLLISION_WAIT: float = 60.0 / 60.0  # GMS2: timer > 60 frames after all collide


func _setup_moon_energy() -> void:
	var src_pos: Vector2 = source.global_position if is_instance_valid(source) else global_position
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	_me_initial_dist = src_pos.distance_to(tgt_pos)
	_me_same_target = _me_initial_dist < 1.0
	_me_impact_playing = false
	_me_post_collision_timer = 0.0
	_me_shader_activated = false

	# Hide effect_sprite — moonEnergy uses projectile sprites, not the main effect sprite
	effect_sprite.visible = false
	effect_sprite.stop()

	# GMS2: dir = point_direction(source, target) — direction TO target (not away)
	# point_direction returns GMS2 degrees (0°=right, 90°=up, CCW)
	var gms2_dir_to_target: float = -rad_to_deg((tgt_pos - src_pos).angle()) if _me_initial_dist > 0.5 else 0.0

	# GMS2: projectiles at dir+40, dir+80, dir-80
	_me_spark_dirs = [gms2_dir_to_target + 40.0, gms2_dir_to_target + 80.0, gms2_dir_to_target - 80.0]
	_me_spark_dir_speeds = [_ME_DIR_SPEED_MIN, _ME_DIR_SPEED_MIN, _ME_DIR_SPEED_MIN]
	_me_spark_collided = [false, false, false]
	_me_spark_timer2 = [0.0, 0.0, 0.0]

	# Load moonEnergy sprite texture
	_ensure_sprite_db()
	var info: Dictionary = _sprite_db.get("spr_skill_moonEnergy", {})
	_me_spark_fw = info.get("frame_width", 32)
	_me_spark_fh = info.get("frame_height", 32)
	_me_spark_cols = info.get("columns", 5)
	_me_spark_total = info.get("total_frames", 5)
	var sheet_path: String = "res://assets/sprites/sheets/spr_skill_moonEnergy.png"
	if ResourceLoader.exists(sheet_path):
		_me_spark_tex = load(sheet_path)

	# Build palette swap shader for projectiles (GMS2: Draw_0 applies shader to draw_self)
	var proj_shader_mat: ShaderMaterial = null
	if SKILL_TARGET_PALETTE_SWAP.has(skill_name):
		if _palette_swap_shader == null:
			_palette_swap_shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
		if _palette_swap_shader:
			var params: Array = SKILL_TARGET_PALETTE_SWAP[skill_name]
			proj_shader_mat = ShaderMaterial.new()
			proj_shader_mat.shader = _palette_swap_shader
			proj_shader_mat.set_shader_parameter("u_color_channel", params[0])
			proj_shader_mat.set_shader_parameter("u_color_add", Vector3(params[1], params[2], params[3]))
			proj_shader_mat.set_shader_parameter("u_color_limit", params[4])

	# Create 3 projectile Sprite2D nodes at source position
	for i in range(3):
		var spr := Sprite2D.new()
		spr.texture = _me_spark_tex
		spr.region_enabled = true
		# GMS2: image_speed=0 during flight — show first frame only
		spr.region_rect = Rect2(0, 0, _me_spark_fw, _me_spark_fh)
		spr.z_index = 1000
		spr.visible = false  # Hidden during execution delay
		spr.global_position = src_pos
		if proj_shader_mat:
			spr.material = proj_shader_mat.duplicate()
		get_parent().add_child(spr)
		_me_sparks.append(spr)
		_custom_anims.append(spr)


func _step_moon_energy() -> void:
	# Phase: impact playing — wait for post-collision timer
	if _me_impact_playing:
		_me_post_collision_timer += _dt
		# GMS2: wait 60 frames after all collide, then apply buff and finish
		if _me_post_collision_timer > _ME_POST_COLLISION_WAIT:
			_custom_finish()
		return

	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	var all_done: bool = true
	var any_collided: bool = false

	for i in range(3):
		if _me_spark_collided[i]:
			any_collided = true
			continue

		# Execution delay (GMS2: phase 0 → hidden until timer > executionDelay)
		if _custom_timer <= _ME_DELAYS[i]:
			all_done = false
			continue

		all_done = false
		_me_spark_timer2[i] += _dt

		# Make visible when delay expires
		if i < _me_sparks.size() and is_instance_valid(_me_sparks[i]) and not _me_sparks[i].visible:
			_me_sparks[i].visible = true

		if i >= _me_sparks.size() or not is_instance_valid(_me_sparks[i]):
			_me_spark_collided[i] = true
			continue

		var spark_pos: Vector2 = _me_sparks[i].global_position

		# Homing movement (GMS2: oSkill_fireball_projectile Step_0, phase 1)
		var dist: float = spark_pos.distance_to(tgt_pos)
		var spd: float
		if _me_same_target:
			spd = 1.5
		else:
			var dist_pct: float = dist / maxf(_me_initial_dist, 1.0)
			spd = lerpf(_ME_MAX_SPEED, _ME_MIN_SPEED, dist_pct)

		# Steering acceleration
		_me_spark_dir_speeds[i] += _ME_DIR_ACCEL
		_me_spark_dir_speeds[i] = clampf(_me_spark_dir_speeds[i], _ME_DIR_SPEED_MIN, _ME_DIR_SPEED_MAX)

		# GMS2: point_direction(x, y, tgt_x, tgt_y) → angle to target
		var gms2_target_dir: float = -rad_to_deg((tgt_pos - spark_pos).angle()) if dist > 0.5 else _me_spark_dirs[i]

		# GMS2: dir += sign(dsin(a - dir)) * dirSpeed
		var dir_movement: float
		if _me_same_target and _me_spark_timer2[i] < 15.0 / 60.0:
			dir_movement = 9.0
		else:
			var angle_diff: float = gms2_target_dir - _me_spark_dirs[i]
			dir_movement = sign(sin(deg_to_rad(angle_diff))) * _me_spark_dir_speeds[i]

		_me_spark_dirs[i] += dir_movement

		# Move (GMS2: motion_set(dir, speed))
		_me_sparks[i].global_position += _lengthdir(spd, _me_spark_dirs[i])

		# GMS2: isQuickBall → NO image_angle rotation (sprite stays upright)
		# GMS2: isQuickBall → NO alpha flicker (always fully visible)

		# GMS2: image_speed=0 during flight — static first frame, no animation
		# (region_rect stays at frame 0, set in _setup_moon_energy)

		# Collision check (GMS2: timer2 > 45+executionDelay AND within 24px, OR timeout at 180)
		# _me_spark_timer2 starts AFTER delay, so just check > 45
		if (_me_spark_timer2[i] > 45.0 / 60.0 and dist < _ME_COLLISION_RADIUS) or _me_spark_timer2[i] > 180.0 / 60.0:
			_me_spark_collided[i] = true
			# GMS2: on collision, snap to target and hide
			# (GMS2 phase 2 plays animation at target, but first collider destroys others,
			# so only one ever shows the impact anim — we use effect_sprite for that)
			_me_sparks[i].visible = false
			# GMS2: soundPlayOverlap(soundEffect2)
			MusicManager.play_sfx("snd_skill_moonEnergy2")
			any_collided = true

	# GMS2 Draw_0: shader activates on target when ANY projectile has collided
	if any_collided and not _me_shader_activated:
		_me_shader_activated = true
		_apply_target_shader()

	# When all 3 have been resolved → start impact animation at target
	if all_done and _me_spark_collided[0] and _me_spark_collided[1] and _me_spark_collided[2]:
		_me_impact_playing = true
		_me_post_collision_timer = 0.0
		# Destroy all projectile sprites (the surviving one already played its collision)
		for spr in _me_sparks:
			if is_instance_valid(spr):
				spr.queue_free()
		_me_sparks.clear()
		_custom_anims = _custom_anims.filter(func(a): return is_instance_valid(a))
		# GMS2 phase 2: moonEnergy sprite plays at target with image_speed=1
		# Show the main effect_sprite for the impact animation at target position
		effect_sprite.visible = true
		global_position = tgt_pos + Vector2(0, -10)
		if effect_sprite.sprite_frames:
			effect_sprite.frame = 0
			effect_sprite.play()


# --- thunderbolt (GMS2: oSkill_thunderbolt) ---
# Phase 0: Bolt plays twice (second flipped), flickers yellow/white every 4 frames.
# Phase 1: Flash (8 strobes) + 5 burst sprites at target offsets, each delayed 10 frames.
# Phase 2: Wait for last burst → finish.

var _tb_anim_step: int = 0
var _tb_anims_created: bool = false
var _tb_burst_subimage: Array = [0, 0, 0, 0, 0]
var _tb_burst_sprites: Array = []  # Sprite2D nodes for burst drawing
var _tb_finish_anim: bool = false
const _TB_BURST_X: Array = [0, -30, 30, -20, 20]
const _TB_BURST_Y: Array = [0, -30, 30, 10, -30]
const _TB_BURST_TIME_OFFSET: float = 10.0 / 60.0
const _TB_BURST_LAST_SUBIMAGE: int = 17

func _setup_thunderbolt() -> void:
	_tb_anim_step = 0
	_tb_anims_created = false
	_tb_finish_anim = false
	_custom_phase = 0
	# Position bolt above target
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -65)
	# Start playing the bolt animation
	if effect_sprite.sprite_frames:
		effect_sprite.play()
	effect_sprite.visible = true

func _step_thunderbolt() -> void:
	_custom_timer3 += _dt
	if _custom_phase == 0:
		# Phase 0: Bolt animation playing (handled by AnimatedSprite2D)
		# Flicker yellow/white every 4 frames
		if _custom_timer > 4.0 / 60.0:
			effect_sprite.modulate = Color.YELLOW
			_custom_timer = 0.0
		else:
			effect_sprite.modulate = Color.WHITE
		# Check for animation completion via frame count
		if effect_sprite.sprite_frames and effect_sprite.frame >= effect_sprite.sprite_frames.get_frame_count("effect") - 1:
			if _tb_anim_step == 0:
				# First pass done → flip and replay
				_tb_anim_step = 1
				effect_sprite.flip_h = true
				effect_sprite.frame = 0
				effect_sprite.play()
			elif _tb_anim_step >= 1 and not _tb_anims_created:
				# Second pass done → create flash + bursts
				_tb_anims_created = true
				_custom_timer = 0.0
				effect_sprite.stop()
				effect_sprite.modulate = Color.WHITE
				# GMS2: go_flash(8) — 8 strobe flashes
				ScreenFlash.create_strobe(get_tree(), 8)
				# Apply shader to target now
				_apply_target_shader()
				_custom_phase = 1
				_custom_timer2 = 0.0
	elif _custom_phase == 1:
		# Phase 1: 5 burst sprites at target offsets, staggered by 10 frames
		_custom_timer2 += _dt
		var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
		for i in range(5):
			if _custom_timer2 > _TB_BURST_TIME_OFFSET * i:
				if i >= _tb_burst_sprites.size():
					# Create burst sprite using GenericAnimation
					var pos: Vector2 = tgt_pos + Vector2(_TB_BURST_X[i], _TB_BURST_Y[i])
					var anim := _spawn_anim("spr_skill_thunderbolt_burst", pos, 1.0)
					_tb_burst_sprites.append(anim)
				# Check if last burst is done (freed = animation finished)
				if i == 4 and _tb_burst_sprites.size() > 4:
					if not is_instance_valid(_tb_burst_sprites[4]):
						_custom_finish()


# --- earthSlide (GMS2: oSkill_earthSlide) ---
# Rock falls from above target with acceleration. On impact: shake + flicker + damage.

var _es_dir_speed: float = -3.0
var _es_old_pos: Vector2 = Vector2.ZERO
var _es_impacted: bool = false
var _es_impact_frame: float = 0.0

func _setup_earth_slide() -> void:
	_es_dir_speed = -3.0
	_es_impacted = false
	_es_impact_frame = 0.0
	_es_old_pos = target.global_position if is_instance_valid(target) else global_position
	# Start above target
	if is_instance_valid(target):
		global_position = Vector2(target.global_position.x, target.global_position.y - 65)
	# Don't play animation yet — control manually
	if effect_sprite.sprite_frames:
		effect_sprite.stop()
		effect_sprite.frame = 0

func _step_earth_slide() -> void:
	var tgt_y: float = _es_old_pos.y - 10
	if not _es_impacted:
		# Falling phase
		_es_dir_speed += 0.2
		_es_dir_speed = clampf(_es_dir_speed, -3.0, 5.0)
		global_position.y += _es_dir_speed
		if global_position.y > tgt_y:
			# Impact!
			_es_impacted = true
			global_position.y = tgt_y
			_apply_target_shader()
			# Start impact animation at frame 1
			if effect_sprite.sprite_frames:
				effect_sprite.frame = 1
	else:
		# Impact phase — advance frames slowly (GMS2: rockImageSpeed=0.2)
		_es_impact_frame += _dt * 60.0
		# GMS2: image_speed=0.2 means ~1 frame every 5 steps
		if int(_es_impact_frame) % 5 == 0:
			var current_frame: int = effect_sprite.frame + 1
			if effect_sprite.sprite_frames:
				if current_frame < effect_sprite.sprite_frames.get_frame_count("effect"):
					effect_sprite.frame = current_frame
		# Shake target sprite (oscillate x±2)
		if is_instance_valid(target):
			target.global_position.x = _es_old_pos.x + (2 if int(_es_impact_frame) % 2 == 0 else -2)
		# Flicker effect sprite visibility
		effect_sprite.visible = (int(_es_impact_frame) % 2 == 0)
		# GMS2: finish at frame 7
		if effect_sprite.sprite_frames and effect_sprite.frame >= 7:
			# Restore target position
			if is_instance_valid(target):
				target.global_position = _es_old_pos
			_custom_finish()


# --- multi_burst (GMS2: oSkill_sleepGas) ---
# 3 burst animations at staggered positions around target, then wait and apply.
# Note: poisonGas now uses its own "poison_gas" handler for GMS2-accurate immediate status.

func _setup_multi_burst() -> void:
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	# GMS2 positions: [-20,4], [-2,-35], [20,-8]
	_custom_positions = [
		tgt_pos + Vector2(-20, 4),
		tgt_pos + Vector2(-2, -35),
		tgt_pos + Vector2(20, -8),
	]
	_custom_created = 0
	_multi_burst_spawn_acc = 0.0

func _step_multi_burst() -> void:
	# GMS2: timeBetweenBursts = 15 (sleepGas)
	if _custom_created < _custom_positions.size():
		_multi_burst_spawn_acc += _dt
		while _multi_burst_spawn_acc >= 15.0 / 60.0:
			_multi_burst_spawn_acc -= 15.0 / 60.0
			if _custom_created < _custom_positions.size():
				var sprite_key: String = "spr_skill_" + skill_name
				_spawn_anim(sprite_key, _custom_positions[_custom_created], 0.5)
				_custom_created += 1
	else:
		# GMS2 sleepGas: finish at timer == 100
		if _custom_timer > 100.0 / 60.0:
			_custom_finish()


# --- acid_storm (GMS2: oSkill_acidStorm) ---
# 24 acid tears spawned at random positions above target, falling down.
# Simplified: spawn GenericAnimation dots that fall, no splash phase.

var _as_tear_positions: Array = []

func _setup_acid_storm() -> void:
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	var tear_height: float = 100.0
	for i in range(24):
		_as_tear_positions.append(Vector2(
			randf_range(tgt_pos.x - 25, tgt_pos.x + 25),
			randf_range(tgt_pos.y - 10 - tear_height, tgt_pos.y + 10 - tear_height)
		))
	_custom_created = 0
	_custom_timer2 = 0.0
	_acid_storm_spawn_acc = 0.0

func _step_acid_storm() -> void:
	# GMS2: timeBetweenTears = 4, total 24
	if _custom_created < 24:
		_acid_storm_spawn_acc += _dt
		while _acid_storm_spawn_acc >= 4.0 / 60.0:
			_acid_storm_spawn_acc -= 4.0 / 60.0
			if _custom_created < 24:
				var anim := _spawn_anim("spr_skill_acidStorm_dot", _as_tear_positions[_custom_created], 1.0)
				if anim:
					# GMS2: motion_set(270, 4) → speed increases to 5 after 4 frames.
					# Tears travel ~96px downward (20 frames × avg speed 4.8) to reach target.
					# maxDistancePerTear=20 (frames, not pixels). After hitting, they switch to
					# smoke sprite moving upward — simplified here as a fall-to-target tween.
					var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
					var end_pos: Vector2 = Vector2(_as_tear_positions[_custom_created].x, tgt_pos.y + randf_range(-5, 5))
					# GMS2: 20 frames at 60fps ≈ 0.33s for the fall phase
					var tween := anim.create_tween()
					tween.tween_property(anim, "global_position", end_pos, 0.33)
				_custom_created += 1
	if _custom_created >= 24:
		_custom_timer2 += _dt
		if _custom_timer2 > 30.0 / 60.0:
			_custom_finish()


# --- wall_spark (GMS2: oSkill_wall / oSkill_lucidBarrier) ---
# Play main animation for 90 frames, then switch to spark sprite, finish when spark done.

var _ws_changed_spark: bool = false
var _ws_spark_sprite_key: String = ""

func _setup_wall_spark() -> void:
	_ws_changed_spark = false
	if skill_name == "wall":
		_ws_spark_sprite_key = "spr_skill_wallSpark"
	else:
		_ws_spark_sprite_key = "spr_skill_lucidBarrierSpark"
	# GMS2: wall animation loops continuously while timer counts to 90
	if effect_sprite.sprite_frames:
		effect_sprite.sprite_frames.set_animation_loop("effect", true)

func _step_wall_spark() -> void:
	if not _ws_changed_spark:
		if _custom_timer > 90.0 / 60.0:
			# Switch to spark sprite
			_ws_changed_spark = true
			# GMS2: image_speed = 0.3 (set in Create), stays 0.3 when switching to spark.
			# Effective FPS = playback_speed(60) × image_speed(0.3) = 18
			var sf := SpriteUtils.build_sprite_frames(_ws_spark_sprite_key, "spark", 18.0, false)
			if sf:
				effect_sprite.sprite_frames = sf
				effect_sprite.animation = "spark"
				effect_sprite.frame = 0
				effect_sprite.play()
				effect_sprite.offset = SpriteUtils.get_sheet_offset(_ws_spark_sprite_key)
				# Reconnect animation_finished since we're playing a new animation
				if not effect_sprite.animation_finished.is_connected(_on_spark_finished):
					effect_sprite.animation_finished.connect(_on_spark_finished)
	# Follow target
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -12)

func _on_spark_finished() -> void:
	_custom_finish()


# --- freeze (GMS2: oSkill_freeze) ---
# Wait 50 frames. Then 4 progressive ice bursts at target (alternating flip),
# each delayed by 10 "half-frames" (timer2 += 0.5). Sound every 20 frames.
# Finish at timer > 135.

var _fr_draw_ice: bool = false
var _fr_ice_timer: float = 0.0
var _fr_ice_sprites: Array = []  # 4 Sprite2D for ice burst overlay
var _fr_ice_frames: Array = [0, 0, 0, 0]
var _fr_freeze_played: int = 0

func _setup_freeze() -> void:
	_fr_draw_ice = false
	_fr_ice_timer = 0.0
	_fr_freeze_played = 0
	_freeze_sound_acc = 0.0
	effect_sprite.visible = false  # GMS2: no main sprite for freeze

func _step_freeze() -> void:
	if _custom_timer > 50.0 / 60.0:
		if not _fr_draw_ice:
			_fr_draw_ice = true
			_apply_target_shader()
			# Create 4 Sprite2D for ice bursts
			_ensure_sprite_db()
			var info: Dictionary = _sprite_db.get("spr_skill_freeze", {})
			var sheet_path: String = "res://assets/sprites/sheets/spr_skill_freeze.png"
			if ResourceLoader.exists(sheet_path) and not info.is_empty():
				var tex: Texture2D = load(sheet_path)
				var fw: int = info.get("frame_width", 124)
				var fh: int = info.get("frame_height", 160)
				var ox: int = info.get("origin_x", 61)
				var oy: int = info.get("origin_y", 115)
				for i in range(4):
					var spr := Sprite2D.new()
					spr.texture = tex
					spr.centered = false
					spr.region_enabled = true
					spr.region_rect = Rect2(0, 0, fw, fh)
					spr.offset = Vector2(-ox, -oy)
					spr.z_index = 1000
					spr.visible = false
					# GMS2: alternating xscale: 1, -1, 1, -1
					if i % 2 == 1:
						spr.scale.x = -1
					get_parent().add_child(spr)
					_fr_ice_sprites.append(spr)
					_custom_anims.append(spr)
		# Advance ice timer (GMS2: timer2 += 0.5 per frame → 30/s at 60fps)
		_fr_ice_timer += 0.5 * _dt * 60.0
		var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
		var info2: Dictionary = _sprite_db.get("spr_skill_freeze", {})
		var fw2: int = info2.get("frame_width", 124)
		var fh2: int = info2.get("frame_height", 160)
		var cols2: int = info2.get("columns", 10)
		var burst_time_offset: int = 10
		var burst_last_subimage: int = 17
		for i in range(4):
			if _fr_ice_timer > burst_time_offset * i:
				if i < _fr_ice_sprites.size() and is_instance_valid(_fr_ice_sprites[i]):
					_fr_ice_sprites[i].visible = true
					_fr_ice_sprites[i].global_position = tgt_pos
					if _fr_ice_frames[i] <= burst_last_subimage:
						var ice_frame: int = int(_fr_ice_frames[i])
						var col: int = ice_frame % cols2
						@warning_ignore("INTEGER_DIVISION")
						var row: int = ice_frame / cols2
						_fr_ice_sprites[i].region_rect = Rect2(col * fw2, row * fh2, fw2, fh2)
						_fr_ice_frames[i] += _dt * 60.0
		# Sound every 20 frames, up to 4 times
		_freeze_sound_acc += _dt
		while _freeze_sound_acc >= 20.0 / 60.0:
			_freeze_sound_acc -= 20.0 / 60.0
			if _fr_freeze_played < 4:
				MusicManager.play_sfx("snd_freezeOrb")
				_fr_freeze_played += 1
	# Finish
	if _custom_timer > 135.0 / 60.0:
		_custom_finish()


# --- dark_force (GMS2: oSkill_darkForce) ---
# Mode 0: 20 orbs spawn at evenly spaced angles, move toward target.
# Mode 1: Destroy orbs.
# Mode 2: 5 burst sprites near target, moving outward.
# Mode 3: Wait 70 frames → finish.

var _df_orb_positions: Array = []  # Starting positions for 20 orbs
var _df_orb_speeds: Array = []
var _df_orb_timers: Array = []
var _df_created_orbs: int = 0
var _df_created_bursts: int = 0
var _df_burst_anims: Array = []
const _DF_TOTAL_ORBS: int = 20
const _DF_TOTAL_BURSTS: int = 5
const _DF_BURST_DIRS: Array = [315.0, 135.0, 270.0, 35.0, 225.0]
const _DF_BURST_OFFSETS_X: Array = [5, -5, 2, 2, -3]
const _DF_BURST_OFFSETS_Y: Array = [0, -5, 4, -5, 3]

func _setup_dark_force() -> void:
	_custom_phase = 0
	_df_created_orbs = 0
	_df_created_bursts = 0
	_df_orb_spawn_acc = 0.0
	_df_burst_spawn_acc = 0.0
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	var max_length: float = 220.0
	var dir_offset: float = -45.0
	var dir_augment: float = 60.0
	for i in range(_DF_TOTAL_ORBS):
		var angle: float = dir_offset + (i * dir_augment)
		_df_orb_positions.append(tgt_pos + _lengthdir(max_length, angle))
		_df_orb_speeds.append(0.4)
		_df_orb_timers.append(0.0)
	effect_sprite.visible = false

func _step_dark_force() -> void:
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	if _custom_phase == 0:
		# Move existing orbs toward target
		for i in range(_df_created_orbs):
			if i < _custom_anims.size() and is_instance_valid(_custom_anims[i]):
				_df_orb_speeds[i] += 0.28
				_df_orb_speeds[i] = clampf(_df_orb_speeds[i], 0.0, 6.0)
				_df_orb_timers[i] += _dt * 60.0
				var dir: Vector2 = (tgt_pos - _custom_anims[i].global_position).normalized()
				_custom_anims[i].global_position += dir * _df_orb_speeds[i]
				if _df_orb_timers[i] > 90:
					_custom_anims[i].visible = false
					# Check if last orb done
					if i == _DF_TOTAL_ORBS - 1:
						_custom_phase = 1
		# Create new orbs
		if _df_created_orbs < _DF_TOTAL_ORBS:
			_df_orb_spawn_acc += _dt
			while _df_orb_spawn_acc >= 4.0 / 60.0:
				_df_orb_spawn_acc -= 4.0 / 60.0
				if _df_created_orbs < _DF_TOTAL_ORBS:
					_spawn_anim("spr_skill_darkForce", _df_orb_positions[_df_created_orbs], 1.7)
					_df_created_orbs += 1
	elif _custom_phase == 1:
		# Destroy all orbs
		for anim in _custom_anims:
			if is_instance_valid(anim):
				anim.queue_free()
		_custom_anims.clear()
		_custom_phase = 2
		_custom_timer2 = 0.0
	elif _custom_phase == 2:
		# Spawn 5 burst sprites
		_custom_timer2 += _dt
		if _df_created_bursts < _DF_TOTAL_BURSTS:
			_df_burst_spawn_acc += _dt
			while _df_burst_spawn_acc >= 20.0 / 60.0:
				_df_burst_spawn_acc -= 20.0 / 60.0
				if _df_created_bursts < _DF_TOTAL_BURSTS:
					var pos: Vector2 = tgt_pos + Vector2(_DF_BURST_OFFSETS_X[_df_created_bursts], _DF_BURST_OFFSETS_Y[_df_created_bursts])
					var anim := _spawn_anim("spr_skill_darkForce_burst", pos, 0.5)
					if anim:
						# GMS2: motion_set(direction, 0.7) — simple drift
						var drift: Vector2 = _lengthdir(0.7, _DF_BURST_DIRS[_df_created_bursts])
						var tween := anim.create_tween()
						tween.tween_property(anim, "global_position", pos + drift * 60, 1.0)
					_df_created_bursts += 1
					if _df_created_bursts >= _DF_TOTAL_BURSTS:
						_custom_phase = 3
						_custom_timer = 0.0
	elif _custom_phase == 3:
		if _custom_timer > 30.0 / 60.0:
			_stop_screen_darken()
		if _custom_timer > 70.0 / 60.0:
			_custom_finish()


# --- lucent_beam (GMS2: oSkill_lucentBeam) ---
# GMS2 behavior:
#   Create_0: drawShader = false, image_speed = 0.3, pos = target.x/target.y (no -10 offset)
#   Step_0:   image_index > 22 → drawShader = true (delayed palette swap)
#             image_index > 10 → image_speed = 1 (speed up beam)
#             image_index >= image_number-1 → image_speed = 0 (stop at last frame)
#             timer > 100 → apply damage & destroy
# lucentBeam sprite: 200×200, 31 frames, 60fps base.
# Effective FPS at 0.3: 18 fps. At 1.0: 60 fps.

var _lb_speed_changed: bool = false
var _lb_shader_applied: bool = false

func _setup_lucent_beam() -> void:
	_lb_speed_changed = false
	_lb_shader_applied = false
	# GMS2 starts at image_speed = 0.3, already built into SpriteFrames via GMS2_IMAGE_SPEED
	# The animation plays at 18 fps (60 * 0.3). We'll change speed_scale later.
	if effect_sprite.sprite_frames:
		# GMS2: animation does NOT loop — it freezes on last frame (image_speed = 0)
		# then destroys at timer > 100. Without this, Godot loops back to frame 0.
		effect_sprite.sprite_frames.set_animation_loop("effect", false)
		effect_sprite.play()

func _step_lucent_beam() -> void:
	# Speed up animation after frame 10 (GMS2: image_speed = 0.3 → 1.0)
	if not _lb_speed_changed and effect_sprite.sprite_frames:
		if effect_sprite.frame > 10:
			# SpriteFrames was built at 18fps (0.3 × 60). To reach 60fps, scale = 1.0/0.3
			effect_sprite.speed_scale = 1.0 / 0.3
			_lb_speed_changed = true

	# Activate shader after frame 22 (GMS2: drawShader becomes true)
	if not _lb_shader_applied and effect_sprite.sprite_frames:
		if effect_sprite.frame > 22:
			_apply_target_shader()
			_lb_shader_applied = true

	# Stop at last frame (GMS2: image_speed = 0)
	if effect_sprite.sprite_frames:
		var frame_count: int = effect_sprite.sprite_frames.get_frame_count("effect")
		if effect_sprite.frame >= frame_count - 1:
			effect_sprite.stop()

	# Timer-based destruction (GMS2: timer > 100)
	if _custom_timer > 100.0 / 60.0:
		_custom_finish()


# --- evil_gate (GMS2: oSkill_evilGate) ---
# GMS2 behavior:
#   Create_0: drawShader = true, image_speed = 1, pos = target.x+1/target.y-10
#             Creates oColorBrightness (c_white, 0.5 alpha, 10 frame fade-in)
#   Step_0:   timer > 180 → alphaBackground.reverse = true (start screen blend fade-out)
#             timer > 210 → apply damage & destroy
# evilGate sprite: 48×48, 15 frames, 60fps. Loops continuously.

var _eg_blend_fading: bool = false

func _setup_evil_gate() -> void:
	_eg_blend_fading = false
	# GMS2: evilGate animation loops while the timer counts to 210
	if effect_sprite.sprite_frames:
		effect_sprite.sprite_frames.set_animation_loop("effect", true)
		effect_sprite.play()

func _step_evil_gate() -> void:
	# At timer > 180: start fading out the screen blend (GMS2: alphaBackground.reverse = true)
	if _custom_timer > 180.0 / 60.0 and not _eg_blend_fading:
		_eg_blend_fading = true
		_stop_screen_darken()
	# At timer > 210: apply damage & destroy (GMS2: timer > 180 + 30)
	if _custom_timer > 210.0 / 60.0:
		_custom_finish()


# --- remedy (GMS2: oSkill_remedy) ---
# GMS2 behavior:
#   Create_0: image_speed = 1, soundPlay(snd_remedy), timesLooped = 0, pauseCreature+state_ANIMATION
#   Step_0:   image_index >= image_number-1 → timesLooped++, image_index = 0
#             timesLooped > 1 → disableShader, cureAilments, destroy
#   Draw_0:   draw_self(); ani_cureWater() on target (palette swap shader)
# The animation loops 2 complete times before applying the effect.

var _rem_times_looped: int = 0
var _rem_last_frame: int = -1

func _setup_remedy() -> void:
	_rem_times_looped = 0
	_rem_last_frame = -1
	# Enable looping so the animation restarts automatically
	# GMS2: animation plays 2 complete loops before applying cureAilments
	if effect_sprite.sprite_frames:
		effect_sprite.sprite_frames.set_animation_loop("effect", true)
		effect_sprite.play()
	# Target shader is applied automatically by _freeze_target() (not in DELAYED_SHADER_SKILLS)

func _step_remedy() -> void:
	if not effect_sprite.sprite_frames:
		return
	# Follow target position
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -10)
	# Detect loop completion: when frame wraps back to 0 from a higher frame
	var cur_frame: int = effect_sprite.frame
	var frame_count: int = effect_sprite.sprite_frames.get_frame_count("effect")
	if _rem_last_frame >= frame_count - 2 and cur_frame < _rem_last_frame:
		_rem_times_looped += 1
		if _rem_times_looped >= 2:
			_custom_finish()
			return
	_rem_last_frame = cur_frame


# --- cure_water (GMS2: oSkill_cureWater) ---
# GMS2 behavior:
#   Create_0: image_speed = 1 (full speed), soundPlayed = false, pos = target.x/target.y-10
#   Step_0:   image_index > 20 → image_speed = 0.3, play snd_cure (once)
#             image_index >= image_number-1 → disableShader, healed pose, performHeal, destroy
#   Draw_0:   draw_self() always; image_index > 20 → ani_cureWater() on target

var _cw_speed_changed: bool = false
var _cw_shader_applied: bool = false
var _cw_sound_played: bool = false

func _setup_cure_water() -> void:
	_cw_speed_changed = false
	_cw_shader_applied = false
	_cw_sound_played = false
	# GMS2 Create_0: image_speed = 1, but SpriteFrames was built at 0.3 speed (18fps).
	# Scale up to full speed (60fps) to match GMS2's initial image_speed = 1.
	if effect_sprite.sprite_frames:
		effect_sprite.speed_scale = 1.0 / 0.3
		effect_sprite.play()
	# GMS2: sound is delayed until frame > 20, prevent auto-play
	sound_played = true

func _step_cure_water() -> void:
	if not effect_sprite.sprite_frames:
		return

	var cur_frame: int = effect_sprite.frame

	# After frame 20: slow down animation (GMS2: image_speed = 0.3)
	if not _cw_speed_changed and cur_frame > 20:
		effect_sprite.speed_scale = 1.0  # Back to the built-in 18fps (= GMS2 0.3)
		_cw_speed_changed = true

	# After frame 20: play snd_cure (once)
	if not _cw_sound_played and cur_frame > 20:
		MusicManager.play_sfx("snd_cure")
		_cw_sound_played = true

	# After frame 20: apply palette swap shader to target (GMS2 Draw_0: ani_cureWater)
	if not _cw_shader_applied and cur_frame > 20:
		_apply_target_shader()
		_cw_shader_applied = true

	# Animation reached last frame → healed pose + heal + destroy
	var frame_count: int = effect_sprite.sprite_frames.get_frame_count("effect")
	if cur_frame >= frame_count - 1:
		_cure_water_finish()

func _cure_water_finish() -> void:
	## GMS2 cureWater Step_0: on animation end → _custom_finish() runs the shared
	## _on_animation_complete() path which handles heal + healed pose + cleanup.
	_custom_finish()


# --- saber (GMS2: oSkill_*Saber + oSkill_fireball_projectile) ---
# GMS2 behavior:
#   skill_saber_create: spawns 3 oSkill_fireball_projectile from source → target
#     - Projectile 0: dir + rand(±1), delay 0
#     - Projectile 1: dir + 90,        delay 10
#     - Projectile 2: dir - 90,        delay 20
#     dir = point_direction(source, target) + 180 (initially AWAY from target, curves back)
#   oSkill_fireball_projectile (isSaber=true):
#     - Sprite: spr_skill_saber_spark (20×20, 8 frames, 10fps)
#     - Phase 0: hidden during executionDelay
#     - Phase 1: homing flight (dirSpeed += 0.06, maxSpeed=6, dirSpeedMax=9)
#     - Collision: timer2 > 45 AND within 24px, OR timer2 > 180
#     - On collision: switch to spr_skill_saber_swords, play at target position
#     - Phase 2: first collider's swords plays, destroys others
#   skill_saber_step (parent): all 3 collided → wait 40 frames → apply status

var _sb_sparks: Array = []        # 3 Sprite2D nodes
var _sb_spark_dirs: Array = []    # GMS2 direction per spark (degrees, CCW)
var _sb_spark_dir_speeds: Array = []
var _sb_spark_collided: Array = []
var _sb_spark_timer2: Array = []  # Per-spark frame timer (GMS2: timer2)
var _sb_initial_dist: float = 0.0
var _sb_same_target: bool = false
var _sb_swords_playing: bool = false
var _sb_spark_frame_acc: Array = []
# Spark sprite metadata
var _sb_spark_tex: Texture2D = null
var _sb_spark_fw: int = 20
var _sb_spark_fh: int = 20
var _sb_spark_cols: int = 8
var _sb_spark_total: int = 8

const _SB_DELAYS: Array = [0.0, 10.0 / 60.0, 20.0 / 60.0]  # GMS2 frames → seconds
const _SB_MIN_SPEED: float = 1.5
const _SB_MAX_SPEED: float = 6.0       # isQuickBall = true
const _SB_DIR_SPEED_MIN: float = 0.5
const _SB_DIR_SPEED_MAX: float = 9.0   # isQuickBall = true
const _SB_DIR_ACCEL: float = 0.06
const _SB_COLLISION_RADIUS: float = 24.0

func _setup_saber() -> void:
	var src_pos: Vector2 = source.global_position if is_instance_valid(source) else global_position
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	_sb_initial_dist = src_pos.distance_to(tgt_pos)
	_sb_same_target = _sb_initial_dist < 1.0  # source == target (self-saber)
	_sb_swords_playing = false

	# GMS2: skill_saber_create comments out sound — only plays on collision (snd_magicWeapon)
	sound_played = true  # Skip _play_skill_sound() in _process

	# Hide swords effect_sprite — only shown after sparks arrive
	effect_sprite.visible = false
	effect_sprite.stop()

	# Calculate initial directions (GMS2: dir = point_direction + 180, away from target)
	var gms2_dir_to_target: float = -rad_to_deg((tgt_pos - src_pos).angle()) if _sb_initial_dist > 0.5 else 0.0
	var away_dir: float = gms2_dir_to_target + 180.0
	var rand_sign: float = 1.0 if randf() > 0.5 else -1.0

	_sb_spark_dirs = [away_dir + rand_sign, away_dir + 90.0, away_dir - 90.0]
	_sb_spark_dir_speeds = [_SB_DIR_SPEED_MIN, _SB_DIR_SPEED_MIN, _SB_DIR_SPEED_MIN]
	_sb_spark_collided = [false, false, false]
	_sb_spark_timer2 = [0.0, 0.0, 0.0]
	_sb_spark_frame_acc = [0.0, 0.0, 0.0]

	# Load spark texture
	_ensure_sprite_db()
	var info: Dictionary = _sprite_db.get("spr_skill_saber_spark", {})
	_sb_spark_fw = info.get("frame_width", 20)
	_sb_spark_fh = info.get("frame_height", 20)
	_sb_spark_cols = info.get("columns", 8)
	_sb_spark_total = info.get("total_frames", 8)
	var sheet_path: String = "res://assets/sprites/sheets/spr_skill_saber_spark.png"
	if ResourceLoader.exists(sheet_path):
		_sb_spark_tex = load(sheet_path)

	# Build palette swap shader for sparks (GMS2: projectile Draw_0 applies shader to itself)
	var spark_shader_mat: ShaderMaterial = null
	if SKILL_TARGET_PALETTE_SWAP.has(skill_name):
		if _palette_swap_shader == null:
			_palette_swap_shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
		if _palette_swap_shader:
			var params: Array = SKILL_TARGET_PALETTE_SWAP[skill_name]
			spark_shader_mat = ShaderMaterial.new()
			spark_shader_mat.shader = _palette_swap_shader
			spark_shader_mat.set_shader_parameter("u_color_channel", params[0])
			spark_shader_mat.set_shader_parameter("u_color_add", Vector3(params[1], params[2], params[3]))
			spark_shader_mat.set_shader_parameter("u_color_limit", params[4])

	# Create 3 spark Sprite2D nodes at source position
	for i in range(3):
		var spr := Sprite2D.new()
		spr.texture = _sb_spark_tex
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, _sb_spark_fw, _sb_spark_fh)
		spr.z_index = 1000
		spr.visible = false  # Hidden during execution delay
		spr.global_position = src_pos
		if spark_shader_mat:
			spr.material = spark_shader_mat.duplicate()
		get_parent().add_child(spr)
		_sb_sparks.append(spr)
		_custom_anims.append(spr)


func _step_saber() -> void:
	# Phase 2: swords animation playing — wait for it to finish
	if _sb_swords_playing:
		if effect_sprite.sprite_frames:
			var fc: int = effect_sprite.sprite_frames.get_frame_count("effect")
			if effect_sprite.frame >= fc - 1:
				_custom_finish()
		return

	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	var all_done: bool = true

	for i in range(3):
		if _sb_spark_collided[i]:
			continue

		# Execution delay (GMS2: phase 0 → hidden until timer > executionDelay)
		if _custom_timer <= _SB_DELAYS[i]:
			all_done = false
			continue

		all_done = false
		_sb_spark_timer2[i] += _dt * 60.0

		# Make visible when delay expires
		if i < _sb_sparks.size() and is_instance_valid(_sb_sparks[i]) and not _sb_sparks[i].visible:
			_sb_sparks[i].visible = true

		if i >= _sb_sparks.size() or not is_instance_valid(_sb_sparks[i]):
			_sb_spark_collided[i] = true
			continue

		var spark_pos: Vector2 = _sb_sparks[i].global_position

		# Homing movement (GMS2: oSkill_fireball_projectile Step_0, phase 1)
		var dist: float = spark_pos.distance_to(tgt_pos)
		var spd: float
		if _sb_same_target:
			spd = 1.5
		else:
			var dist_pct: float = dist / maxf(_sb_initial_dist, 1.0)
			spd = lerpf(_SB_MAX_SPEED, _SB_MIN_SPEED, dist_pct)

		# Steering acceleration
		_sb_spark_dir_speeds[i] += _SB_DIR_ACCEL
		_sb_spark_dir_speeds[i] = clampf(_sb_spark_dir_speeds[i], _SB_DIR_SPEED_MIN, _SB_DIR_SPEED_MAX)

		# GMS2: point_direction(x, y, tgt_x, tgt_y) → angle to target
		var gms2_target_dir: float = -rad_to_deg((tgt_pos - spark_pos).angle()) if dist > 0.5 else _sb_spark_dirs[i]

		# GMS2: dir += sign(dsin(a - dir)) * dirSpeed
		# Special case: self-cast circular motion for first 15+delay frames
		var dir_movement: float
		if _sb_same_target and _sb_spark_timer2[i] < 15 + _SB_DELAYS[i] * 60.0:
			dir_movement = 9.0
		else:
			var angle_diff: float = gms2_target_dir - _sb_spark_dirs[i]
			dir_movement = sign(sin(deg_to_rad(angle_diff))) * _sb_spark_dir_speeds[i]

		_sb_spark_dirs[i] += dir_movement

		# Move (GMS2: motion_set(dir, speed))
		_sb_sparks[i].global_position += _lengthdir(spd, _sb_spark_dirs[i])

		# Rotate spark to face movement direction (GMS2: image_angle = dir)
		# GMS2 angle → Godot rotation: Godot CW = -GMS2 CCW
		_sb_sparks[i].rotation = -deg_to_rad(_sb_spark_dirs[i])

		# Animate spark frames (GMS2: image_speed=1 at playback 10fps)
		_sb_spark_frame_acc[i] += 10.0 / 60.0
		if _sb_spark_frame_acc[i] >= 1.0:
			_sb_spark_frame_acc[i] -= 1.0
		@warning_ignore("INTEGER_DIVISION")
		var frame_idx: int = int(_sb_spark_timer2[i] * 10.0 / 60.0) % _sb_spark_total
		var col: int = frame_idx % _sb_spark_cols
		var row: int = frame_idx / _sb_spark_cols
		_sb_sparks[i].region_rect = Rect2(col * _sb_spark_fw, row * _sb_spark_fh, _sb_spark_fw, _sb_spark_fh)

		# Collision check (GMS2: timer2 > 45 AND within 24px, OR timeout at 180)
		if (_sb_spark_timer2[i] > 45 and dist < _SB_COLLISION_RADIUS) or _sb_spark_timer2[i] > 180:
			_sb_spark_collided[i] = true
			_sb_sparks[i].visible = false

	# When all 3 sparks have collided → show swords animation
	if all_done and _sb_spark_collided[0] and _sb_spark_collided[1] and _sb_spark_collided[2]:
		_sb_swords_playing = true
		# Destroy spark sprites
		for spr in _sb_sparks:
			if is_instance_valid(spr):
				spr.queue_free()
		_sb_sparks.clear()
		# Remove from _custom_anims since we freed them manually
		_custom_anims = _custom_anims.filter(func(a): return is_instance_valid(a))
		# Show swords animation at target position
		effect_sprite.visible = true
		global_position = tgt_pos + Vector2(0, -10)
		if effect_sprite.sprite_frames:
			effect_sprite.frame = 0
			effect_sprite.play()
		# GMS2 Draw_0: palette swap applied to draw_self() in ALL phases,
		# including swords. Apply same shader to the swords effect_sprite.
		if SKILL_TARGET_PALETTE_SWAP.has(skill_name):
			if _palette_swap_shader == null:
				_palette_swap_shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
			if _palette_swap_shader:
				var params: Array = SKILL_TARGET_PALETTE_SWAP[skill_name]
				var swords_mat := ShaderMaterial.new()
				swords_mat.shader = _palette_swap_shader
				swords_mat.set_shader_parameter("u_color_channel", params[0])
				swords_mat.set_shader_parameter("u_color_add", Vector3(params[1], params[2], params[3]))
				swords_mat.set_shader_parameter("u_color_limit", params[4])
				effect_sprite.material = swords_mat
		# Apply palette swap shader to target creature
		_apply_target_shader()
		# GMS2: soundEffect2 = snd_magicWeapon, played on collision
		MusicManager.play_sfx("snd_magicWeapon")


func _apply_target_shader() -> void:
	## GMS2: Each oSkill's Draw_0 applies sha_palleteSwap to the target creature
	## during the skill animation. Applied AFTER Animation.enter() (which calls disable_shader()).
	if not SKILL_TARGET_PALETTE_SWAP.has(skill_name):
		return
	if not is_instance_valid(target) or not target.sprite:
		return

	if _palette_swap_shader == null:
		_palette_swap_shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
	if _palette_swap_shader == null:
		return

	var params: Array = SKILL_TARGET_PALETTE_SWAP[skill_name]
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = _palette_swap_shader
	shader_mat.set_shader_parameter("u_color_channel", params[0])
	shader_mat.set_shader_parameter("u_color_add", Vector3(params[1], params[2], params[3]))
	shader_mat.set_shader_parameter("u_color_limit", params[4])

	# Save current material so we can restore it when the effect ends
	_target_original_material = target.sprite.material
	target.sprite.material = shader_mat
	_target_shader_applied = true


func _remove_target_shader() -> void:
	## Restore target's original material after skill animation ends
	if not _target_shader_applied:
		return
	_target_shader_applied = false
	if is_instance_valid(target) and target.sprite:
		target.sprite.material = _target_original_material
	_target_original_material = null


# =============================================================================
# airBlast (GMS2: oSkill_airBlast + oSkill_fireball_projectile)
# =============================================================================
# GMS2: 3 oSkill_fireball_projectile (quickBall) from source → target with Luna colors.
#   Projectile 0: dir + randDir(±1), delay 20
#   Projectile 1: dir + 90,          delay 0
#   Projectile 2: dir - 90,          delay 10
#   dir = point_direction(source, target) — direction TOWARD target (not away)
#   quickBall params: speedMax=6, dirSpeedMax=9, no rotation, no alpha flicker
#   After all 3 collide → reset timer → wait 80 frames → performAttack(MAGIC)

var _ab_sparks: Array = []
var _ab_spark_dirs: Array = []
var _ab_spark_dir_speeds: Array = []
var _ab_spark_collided: Array = []
var _ab_spark_timer2: Array = []
var _ab_initial_dist: float = 0.0
var _ab_same_target: bool = false
var _ab_impact_playing: bool = false
var _ab_post_collision_timer: float = 0.0
var _ab_shader_activated: bool = false
var _ab_spark_tex: Texture2D = null
var _ab_spark_fw: int = 20
var _ab_spark_fh: int = 20
var _ab_spark_cols: int = 3
var _ab_spark_total: int = 3

const _AB_DELAYS: Array = [20.0 / 60.0, 0.0, 10.0 / 60.0]  # GMS2 frames → seconds
const _AB_MIN_SPEED: float = 1.5
const _AB_MAX_SPEED: float = 6.0       # GMS2: projectileMaxSpeed=6 (isQuickBall)
const _AB_DIR_SPEED_MIN: float = 0.5
const _AB_DIR_SPEED_MAX: float = 9.0   # GMS2: dirSpeedMax=9 (isQuickBall)
const _AB_DIR_ACCEL: float = 0.06
const _AB_COLLISION_RADIUS: float = 24.0
const _AB_POST_COLLISION_WAIT: float = 80.0 / 60.0  # GMS2: timer > 80 frames after all collide

func _setup_air_blast() -> void:
	var src_pos: Vector2 = source.global_position if is_instance_valid(source) else global_position
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	_ab_initial_dist = src_pos.distance_to(tgt_pos)
	_ab_same_target = _ab_initial_dist < 1.0
	_ab_impact_playing = false
	_ab_post_collision_timer = 0.0
	_ab_shader_activated = false

	# Hide effect_sprite — airBlast is entirely projectile-based
	effect_sprite.visible = false
	effect_sprite.stop()

	# GMS2: dir = point_direction(source, target) — direction TO target
	var gms2_dir_to_target: float = -rad_to_deg((tgt_pos - src_pos).angle()) if _ab_initial_dist > 0.5 else 0.0
	var rand_sign: float = 1.0 if randf() > 0.5 else -1.0

	# GMS2: projectiles at dir+randDir, dir+90, dir-90
	_ab_spark_dirs = [gms2_dir_to_target + rand_sign, gms2_dir_to_target + 90.0, gms2_dir_to_target - 90.0]
	_ab_spark_dir_speeds = [_AB_DIR_SPEED_MIN, _AB_DIR_SPEED_MIN, _AB_DIR_SPEED_MIN]
	_ab_spark_collided = [false, false, false]
	_ab_spark_timer2 = [0.0, 0.0, 0.0]

	# Load airBlast sprite texture (20×20, 3 frames, 15fps)
	_ensure_sprite_db()
	var info: Dictionary = _sprite_db.get("spr_skill_airBlast", {})
	_ab_spark_fw = info.get("frame_width", 20)
	_ab_spark_fh = info.get("frame_height", 20)
	_ab_spark_cols = info.get("columns", 3)
	_ab_spark_total = info.get("total_frames", 3)
	var sheet_path: String = "res://assets/sprites/sheets/spr_skill_airBlast.png"
	if ResourceLoader.exists(sheet_path):
		_ab_spark_tex = load(sheet_path)

	# Build palette swap shader for projectiles (GMS2: Luna colors)
	var proj_shader_mat: ShaderMaterial = null
	if SKILL_TARGET_PALETTE_SWAP.has(skill_name):
		if _palette_swap_shader == null:
			_palette_swap_shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
		if _palette_swap_shader:
			var params: Array = SKILL_TARGET_PALETTE_SWAP[skill_name]
			proj_shader_mat = ShaderMaterial.new()
			proj_shader_mat.shader = _palette_swap_shader
			proj_shader_mat.set_shader_parameter("u_color_channel", params[0])
			proj_shader_mat.set_shader_parameter("u_color_add", Vector3(params[1], params[2], params[3]))
			proj_shader_mat.set_shader_parameter("u_color_limit", params[4])

	# Create 3 projectile Sprite2D nodes at source position
	for i in range(3):
		var spr := Sprite2D.new()
		spr.texture = _ab_spark_tex
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, _ab_spark_fw, _ab_spark_fh)
		spr.z_index = 1000
		spr.visible = false
		spr.global_position = src_pos
		if proj_shader_mat:
			spr.material = proj_shader_mat.duplicate()
		get_parent().add_child(spr)
		_ab_sparks.append(spr)
		_custom_anims.append(spr)


func _step_air_blast() -> void:
	# Post-collision wait phase
	if _ab_impact_playing:
		_ab_post_collision_timer += _dt
		if _ab_post_collision_timer > _AB_POST_COLLISION_WAIT:
			_custom_finish()
		return

	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	var all_done: bool = true
	var any_collided: bool = false

	for i in range(3):
		if _ab_spark_collided[i]:
			any_collided = true
			continue

		# Execution delay
		if _custom_timer <= _AB_DELAYS[i]:
			all_done = false
			continue

		all_done = false
		_ab_spark_timer2[i] += _dt * 60.0

		# Make visible when delay expires
		if i < _ab_sparks.size() and is_instance_valid(_ab_sparks[i]) and not _ab_sparks[i].visible:
			_ab_sparks[i].visible = true

		if i >= _ab_sparks.size() or not is_instance_valid(_ab_sparks[i]):
			_ab_spark_collided[i] = true
			continue

		var spark_pos: Vector2 = _ab_sparks[i].global_position

		# Homing movement (same formula as fireball projectile)
		var dist: float = spark_pos.distance_to(tgt_pos)
		var spd: float
		if _ab_same_target:
			spd = 1.5
		else:
			var dist_pct: float = dist / maxf(_ab_initial_dist, 1.0)
			spd = lerpf(_AB_MAX_SPEED, _AB_MIN_SPEED, dist_pct)

		# Steering acceleration
		_ab_spark_dir_speeds[i] += _AB_DIR_ACCEL
		_ab_spark_dir_speeds[i] = clampf(_ab_spark_dir_speeds[i], _AB_DIR_SPEED_MIN, _AB_DIR_SPEED_MAX)

		var gms2_target_dir: float = -rad_to_deg((tgt_pos - spark_pos).angle()) if dist > 0.5 else _ab_spark_dirs[i]

		var dir_movement: float
		if _ab_same_target and _ab_spark_timer2[i] < 15:
			dir_movement = 9.0
		else:
			var angle_diff: float = gms2_target_dir - _ab_spark_dirs[i]
			dir_movement = sign(sin(deg_to_rad(angle_diff))) * _ab_spark_dir_speeds[i]

		_ab_spark_dirs[i] += dir_movement
		_ab_sparks[i].global_position += _lengthdir(spd, _ab_spark_dirs[i])

		# GMS2: isQuickBall → NO rotation, NO alpha flicker

		# Animate airBlast frames (GMS2: image_speed=1 at playback 15fps)
		@warning_ignore("INTEGER_DIVISION")
		var frame_idx: int = int(_ab_spark_timer2[i] * 15.0 / 60.0) % _ab_spark_total
		var col: int = frame_idx % _ab_spark_cols
		var row: int = frame_idx / _ab_spark_cols
		_ab_sparks[i].region_rect = Rect2(col * _ab_spark_fw, row * _ab_spark_fh, _ab_spark_fw, _ab_spark_fh)

		# Collision check
		if (_ab_spark_timer2[i] > 45 and dist < _AB_COLLISION_RADIUS) or _ab_spark_timer2[i] > 180:
			_ab_spark_collided[i] = true
			_ab_sparks[i].visible = false
			MusicManager.play_sfx("snd_skill_airBlast2")
			any_collided = true

	# Shader activates on target when ANY projectile has collided
	if any_collided and not _ab_shader_activated:
		_ab_shader_activated = true
		_apply_target_shader()

	# All 3 collided → enter post-collision wait
	if all_done and _ab_spark_collided[0] and _ab_spark_collided[1] and _ab_spark_collided[2]:
		_ab_impact_playing = true
		_ab_post_collision_timer = 0.0
		for spr in _ab_sparks:
			if is_instance_valid(spr):
				spr.queue_free()
		_ab_sparks.clear()
		_custom_anims = _custom_anims.filter(func(a): return is_instance_valid(a))


# =============================================================================
# dispelMagic (GMS2: oSkill_dispelMagic)
# =============================================================================
# GMS2: dispelBuffs() called at CREATE (immediate). 4 burst sprites at offsets staggered
# by 6 frames, advance every 6 timer frames. After last burst (subimage 7) → switch to
# spr_skill_dispelMagic at speed 0.2, then speed 1 when frame>=4, finish on last frame.
# ani_earthSlide() (white palette swap) on target during burst phase.

var _dm_burst_sprites: Array = []  # 4 Sprite2D for burst overlays
var _dm_burst_subimages: Array = [0, 0, 0, 0]
var _dm_show_spread: bool = false
var _dm_burst_tex: Texture2D = null
var _dm_burst_fw: int = 32
var _dm_burst_fh: int = 32
var _dm_burst_cols: int = 8
var _dm_spread_frame_acc: float = 0.0
var _dm_spread_frame: int = 0
var _dm_spread_tex: Texture2D = null
var _dm_spread_fw: int = 32
var _dm_spread_fh: int = 32
var _dm_spread_cols: int = 5
var _dm_spread_total: int = 5

const _DM_BURST_X: Array = [-15, 3, 25, -23]
const _DM_BURST_Y: Array = [-36, 20, -10, 1]
const _DM_BURST_TIME_OFFSET: float = 6.0 / 60.0
const _DM_BURST_LAST_SUBIMAGE: int = 7
const _DM_BURST_SPEED: int = 6

func _setup_dispel_magic() -> void:
	_dm_show_spread = false

	# GMS2: dispelBuffs(target) called AT CREATE — apply effect immediately
	_apply_effect()
	_effect_already_applied = true

	# Hide main effect_sprite — we manually draw bursts then switch
	effect_sprite.visible = false
	effect_sprite.stop()

	# Apply white palette swap (earthSlide shader) on target immediately
	_apply_target_shader()

	# Load burst sprite texture
	_ensure_sprite_db()
	var burst_info: Dictionary = _sprite_db.get("spr_skill_dispelMagic_burst", {})
	_dm_burst_fw = burst_info.get("frame_width", 32)
	_dm_burst_fh = burst_info.get("frame_height", 32)
	_dm_burst_cols = burst_info.get("columns", 8)
	var burst_path: String = "res://assets/sprites/sheets/spr_skill_dispelMagic_burst.png"
	if ResourceLoader.exists(burst_path):
		_dm_burst_tex = load(burst_path)

	# Load spread (main) sprite texture
	var spread_info: Dictionary = _sprite_db.get("spr_skill_dispelMagic", {})
	_dm_spread_fw = spread_info.get("frame_width", 32)
	_dm_spread_fh = spread_info.get("frame_height", 32)
	_dm_spread_cols = spread_info.get("columns", 5)
	_dm_spread_total = spread_info.get("total_frames", 5)
	var spread_path: String = "res://assets/sprites/sheets/spr_skill_dispelMagic.png"
	if ResourceLoader.exists(spread_path):
		_dm_spread_tex = load(spread_path)

	# Create 4 burst Sprite2D at target offsets
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	for i in range(4):
		var spr := Sprite2D.new()
		spr.texture = _dm_burst_tex
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, _dm_burst_fw, _dm_burst_fh)
		spr.z_index = 1000
		spr.visible = false
		spr.global_position = tgt_pos + Vector2(_DM_BURST_X[i], _DM_BURST_Y[i])
		var burst_db_info: Dictionary = _sprite_db.get("spr_skill_dispelMagic_burst", {})
		var ox: int = burst_db_info.get("xorigin", _dm_burst_fw / 2)
		var oy: int = burst_db_info.get("yorigin", _dm_burst_fh / 2)
		spr.offset = -Vector2(ox, oy)
		get_parent().add_child(spr)
		_dm_burst_sprites.append(spr)
		_custom_anims.append(spr)


func _step_dispel_magic() -> void:
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position

	if not _dm_show_spread:
		# Phase 1: 4 burst sprites staggered by 6 frames
		_custom_timer2 += _dt
		var all_bursts_done: bool = true
		for i in range(4):
			if _custom_timer2 > _DM_BURST_TIME_OFFSET * i:
				if i < _dm_burst_sprites.size() and is_instance_valid(_dm_burst_sprites[i]):
					_dm_burst_sprites[i].visible = true
					# Advance burst frame every burstSpeed frames
					if _dm_burst_subimages[i] < _DM_BURST_LAST_SUBIMAGE:
						all_bursts_done = false
						if int(_custom_timer * 60.0) % _DM_BURST_SPEED == 0:
							_dm_burst_subimages[i] += 1
							var col: int = _dm_burst_subimages[i] % _dm_burst_cols
							@warning_ignore("INTEGER_DIVISION")
							var row: int = _dm_burst_subimages[i] / _dm_burst_cols
							_dm_burst_sprites[i].region_rect = Rect2(col * _dm_burst_fw, row * _dm_burst_fh, _dm_burst_fw, _dm_burst_fh)
					# Update position to follow target
					_dm_burst_sprites[i].global_position = tgt_pos + Vector2(_DM_BURST_X[i], _DM_BURST_Y[i])
			else:
				all_bursts_done = false

		# When last burst (index 3) reaches burstLastSubimage → switch to spread sprite
		if _dm_burst_subimages[3] >= _DM_BURST_LAST_SUBIMAGE:
			_dm_show_spread = true
			_dm_spread_frame = 0
			_dm_spread_frame_acc = 0.0
			# Hide burst sprites
			for spr in _dm_burst_sprites:
				if is_instance_valid(spr):
					spr.visible = false
			# Show spread sprite via a new Sprite2D (or reuse effect_sprite position)
			global_position = tgt_pos + Vector2(2, -5)

	else:
		# Phase 2: spr_skill_dispelMagic plays, speed 0.2 initially, speed 1 after frame 4
		global_position = tgt_pos + Vector2(2, -5)
		var img_speed: float = 0.2 if _dm_spread_frame < 4 else 1.0
		_dm_spread_frame_acc += img_speed
		if _dm_spread_frame_acc >= 1.0:
			_dm_spread_frame_acc -= 1.0
			_dm_spread_frame += 1

		# Draw spread sprite on our effect_sprite
		if _dm_spread_tex and _dm_spread_frame < _dm_spread_total:
			effect_sprite.visible = false  # Don't use AnimatedSprite2D
			# Use a child sprite instead
			if _dm_burst_sprites.size() > 0 and is_instance_valid(_dm_burst_sprites[0]):
				# Reuse first burst sprite for the spread animation
				_dm_burst_sprites[0].visible = true
				_dm_burst_sprites[0].texture = _dm_spread_tex
				_dm_burst_sprites[0].global_position = tgt_pos + Vector2(2, -5)
				var spread_db_info: Dictionary = _sprite_db.get("spr_skill_dispelMagic", {})
				var ox: int = spread_db_info.get("xorigin", _dm_spread_fw / 2)
				var oy: int = spread_db_info.get("yorigin", _dm_spread_fh / 2)
				_dm_burst_sprites[0].offset = -Vector2(ox, oy)
				var col: int = _dm_spread_frame % _dm_spread_cols
				@warning_ignore("INTEGER_DIVISION")
				var row: int = _dm_spread_frame / _dm_spread_cols
				_dm_burst_sprites[0].region_rect = Rect2(col * _dm_spread_fw, row * _dm_spread_fh, _dm_spread_fw, _dm_spread_fh)

		if _dm_spread_frame >= _dm_spread_total:
			_custom_finish()


# =============================================================================
# confuseHoops (GMS2: oSkill_confuseHoops)
# =============================================================================
# GMS2: STATUS_CONFUSED applied AT CREATE, sound=snd_confuseHoops, sprite at target.y-30.
# Animation plays at image_speed=0.2, at frame>=8 → freeze, switch target to Stand, destroy.

var _ch_effect_applied: bool = false

func _setup_confuse_hoops() -> void:
	_ch_effect_applied = false

	# GMS2: status applied AT CREATE — apply immediately
	_apply_effect()
	_effect_already_applied = true

	# Position sprite at target.y - 30 (GMS2: y = target.y - 30)
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(1, -30)

	# Animation plays normally via AnimatedSprite2D (already loaded by _load_skill_frames)
	if effect_sprite.sprite_frames:
		effect_sprite.play()

func _step_confuse_hoops() -> void:
	# Follow target
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(1, -30)

	# GMS2 Draw_0: when image_index >= 8 → freeze and destroy
	if effect_sprite.sprite_frames:
		if effect_sprite.frame >= 8:
			effect_sprite.stop()
			_custom_finish()


# =============================================================================
# poison_gas (GMS2: oSkill_poisonGas)
# =============================================================================
# GMS2: STATUS_POISONED + poison shader AT CREATE. 3 burst animations (spr_skill_poisonGas)
# at staggered positions every 20 frames. After all 3 + timer>90 → performAttack(MAGIC).
# Note: GMS2 main sprite is spr_skill_evilGate (reused), but burst sprites are spr_skill_poisonGas.

var _pg_bursts_created: int = 0

func _setup_poison_gas() -> void:
	_pg_bursts_created = 0

	# GMS2: status + poison shader applied AT CREATE
	if is_instance_valid(target):
		var debuff_dur: int = Creature.calculate_debuff_duration(target.get_wisdom())
		target.set_status(Constants.Status.POISONED, debuff_dur)
	_effect_already_applied = true  # Don't re-apply status at end

	# Burst positions (GMS2: [-20,4], [-2,-35], [20,-8])
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	_custom_positions = [
		tgt_pos + Vector2(-20, 4),
		tgt_pos + Vector2(-2, -35),
		tgt_pos + Vector2(20, -8),
	]

	# Main sprite invisible (bursts are the visual)
	effect_sprite.visible = false
	effect_sprite.stop()

func _step_poison_gas() -> void:
	# GMS2: timeBetweenBursts = 20
	if _pg_bursts_created < _custom_positions.size():
		if int(_custom_timer * 60.0) % 20 == 0:
			var sprite_key: String = "spr_skill_poisonGas"
			_spawn_anim(sprite_key, _custom_positions[_pg_bursts_created], 0.5)
			_pg_bursts_created += 1
	else:
		# GMS2: timer > 90 → performAttack(MAGIC) + destroy
		if _custom_timer > 90.0 / 60.0:
			# GMS2 calls performAttack for magic damage in addition to poison status
			if is_instance_valid(source) and is_instance_valid(target):
				var element_idx: int = _get_element_index()
				DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
			_custom_finish()


# =============================================================================
# balloon (GMS2: oSkill_balloon)
# =============================================================================
# GMS2: Boss check at create → "evades spell" dialog + abort. No sprite (noone).
# Status applied at timer > 70, not animation end. pauseCreature() unconditional.

func _setup_balloon() -> void:
	# GMS2: boss immunity check
	if is_instance_valid(target) and (target.is_boss or target.creature_is_boss):
		MusicManager.play_sfx("snd_transform")
		var boss_name: String = target.display_name if target is Mob else "Enemy"
		GameManager.add_battle_dialog(boss_name + " evades spell", BattleDialog.Align.BOTTOM, false, 3.0)
		# Skip all animation/effect — just cleanup and exit
		_effect_already_applied = true
		_skip_freeze = true  # Don't freeze target (we're aborting)
		sound_played = true  # Don't play balloon sound
		call_deferred("_balloon_abort")
		return

	# GMS2: sprite_index = noone — no visible sprite
	effect_sprite.visible = false
	effect_sprite.stop()

func _balloon_abort() -> void:
	## Deferred abort for boss immunity — can't queue_free during setup
	_custom_finish()

func _step_balloon() -> void:
	# GMS2: timer > 70 → apply STATUS_BALLOON, then destroy
	if _custom_timer > 70.0 / 60.0:
		_custom_finish()


# =============================================================================
# revivifier (GMS2: skill_revivifier_create/step/draw)
# =============================================================================
# GMS2: Two-phase animation:
#   Phase 1: spr_skill_revivifier at image_speed=2, loops once
#   Phase 2: spr_skill_revivifierSpark at image_speed=1, on last frame →
#            heal maxHP/2, cureAilments, healed pose (90 frames), destroy
# Green palette swap (ani_wall) on target throughout entire animation.

var _rv_phase: int = 0  # 0=revivifier sprite, 1=spark sprite
var _rv_spark_tex: Texture2D = null
var _rv_spark_fw: int = 32
var _rv_spark_fh: int = 32
var _rv_spark_cols: int = 1
var _rv_spark_total: int = 1
var _rv_spark_playback: float = 15.0
var _rv_spark_frame: int = 0
var _rv_spark_frame_acc: float = 0.0
var _rv_spark_sprite: Sprite2D = null

func _setup_revivifier() -> void:
	_rv_phase = 0

	# GMS2: revivifier Create_0 — target.reviving = true, state_ANIMATION
	if is_instance_valid(target):
		target.reviving = true

	# GMS2: image_speed = 2 — double speed. SpriteFrames built at native fps,
	# so speed_scale = 2.0 gives us double playback speed.
	if effect_sprite.sprite_frames:
		effect_sprite.speed_scale = 2.0
		effect_sprite.play()

	# Position at target.y - 20 (GMS2: y = target.y - 20)
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -20)

	# Apply green palette swap (ani_wall) on target from start
	# revivifier is NOT in DELAYED_SHADER_SKILLS, so shader was already applied in _freeze_target()

	# Load spark sprite for phase 2
	_ensure_sprite_db()
	var spark_info: Dictionary = _sprite_db.get("spr_skill_revivifierSpark", {})
	_rv_spark_fw = spark_info.get("frame_width", 32)
	_rv_spark_fh = spark_info.get("frame_height", 32)
	_rv_spark_cols = spark_info.get("columns", 1)
	_rv_spark_total = spark_info.get("total_frames", 1)
	_rv_spark_playback = spark_info.get("playback_speed", 15.0)
	var spark_path: String = "res://assets/sprites/sheets/spr_skill_revivifierSpark.png"
	if ResourceLoader.exists(spark_path):
		_rv_spark_tex = load(spark_path)

func _step_revivifier() -> void:
	# Follow target
	if is_instance_valid(target):
		global_position = target.global_position + Vector2(0, -20)

	if _rv_phase == 0:
		# Phase 1: spr_skill_revivifier playing at speed 2
		if effect_sprite.sprite_frames:
			var fc: int = effect_sprite.sprite_frames.get_frame_count("effect")
			if effect_sprite.frame >= fc - 1:
				# Switch to spark sprite
				_rv_phase = 1
				_rv_spark_frame = 0
				_rv_spark_frame_acc = 0.0
				# Hide AnimatedSprite2D, use manual Sprite2D for spark
				effect_sprite.visible = false
				effect_sprite.stop()
				# Create spark sprite
				_rv_spark_sprite = Sprite2D.new()
				_rv_spark_sprite.texture = _rv_spark_tex
				_rv_spark_sprite.region_enabled = true
				_rv_spark_sprite.region_rect = Rect2(0, 0, _rv_spark_fw, _rv_spark_fh)
				_rv_spark_sprite.z_index = 1000
				var spark_db_info: Dictionary = _sprite_db.get("spr_skill_revivifierSpark", {})
				var ox: int = spark_db_info.get("xorigin", _rv_spark_fw / 2)
				var oy: int = spark_db_info.get("yorigin", _rv_spark_fh / 2)
				_rv_spark_sprite.offset = -Vector2(ox, oy)
				add_child(_rv_spark_sprite)

	elif _rv_phase == 1:
		# Phase 2: spr_skill_revivifierSpark at image_speed=1
		# Animate at native playback_speed fps
		_rv_spark_frame_acc += _rv_spark_playback / 60.0  # GMS2: image_speed=1 at native fps
		if _rv_spark_frame_acc >= 1.0:
			_rv_spark_frame_acc -= 1.0
			_rv_spark_frame += 1

		if _rv_spark_sprite and _rv_spark_frame < _rv_spark_total:
			var col: int = _rv_spark_frame % _rv_spark_cols
			@warning_ignore("INTEGER_DIVISION")
			var row: int = _rv_spark_frame / _rv_spark_cols
			_rv_spark_sprite.region_rect = Rect2(col * _rv_spark_fw, row * _rv_spark_fh, _rv_spark_fw, _rv_spark_fh)

		# On last frame → apply heal + cleanup
		if _rv_spark_frame >= _rv_spark_total:
			if is_instance_valid(target):
				target.reviving = false
			if _rv_spark_sprite:
				_rv_spark_sprite.queue_free()
			_custom_finish()


# =============================================================================
# leaden_glare (GMS2: oSkill_leadenGlare)
# =============================================================================
# GMS2: PETRIFIED applied at CREATE with probability roll on VALUE2.
# VALUE1 = debuffTime, VALUE2 = probability. No sprite (spr_none).
# Waits timerLimit frames, then performAttack(MAGIC) + destroy.

var _lg_timer_limit: float = 5.0  # debuffTime in seconds

func _setup_leaden_glare() -> void:
	effect_sprite.visible = false
	effect_sprite.stop()

	# GMS2: debuffTime = VALUE1, probability = VALUE2
	var debuff_time: float = float(skill_data.get("value1", 5))
	var probability: float = float(skill_data.get("value2", 100.0))
	_lg_timer_limit = debuff_time  # Already in seconds

	# GMS2: petrified = floor(random_range(0, probability)); if petrified == 0 → success
	# This means probability is the range: roll 0 in [0, probability) → 1/probability chance
	# Higher probability = lower chance of petrify
	var roll: int = floori(randf_range(0.0, probability))
	if roll == 0:
		if is_instance_valid(target):
			var debuff_dur: int = Creature.calculate_debuff_duration(target.get_wisdom())
			target.set_status(Constants.Status.PETRIFIED, debuff_dur)
	_effect_already_applied = true

func _step_leaden_glare() -> void:
	if _custom_timer > _lg_timer_limit:
		# GMS2: performAttack(MAGIC) after timerLimit
		if is_instance_valid(source) and is_instance_valid(target):
			var element_idx: int = _get_element_index()
			DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)
		_custom_finish()


# =============================================================================
# pygmus_glare (GMS2: oSkill_pygmusGlare → skill_pygmize_create/step)
# =============================================================================
# GMS2: No visible sprite. pauseCreature() + state_ANIMATION on target.
# Timer > 20: shakeSprite(oldX, oldY, target). Timer > 100: apply PYGMIZED, destroy.

var _pg_old_pos: Vector2 = Vector2.ZERO

func _setup_pygmus_glare() -> void:
	effect_sprite.visible = false
	effect_sprite.stop()

	# Save target original position for shake restoration
	if is_instance_valid(target):
		_pg_old_pos = target.global_position

func _step_pygmus_glare() -> void:
	# GMS2: timer > 20 → shakeSprite
	if _custom_timer > 20.0 / 60.0 and _custom_timer <= 100.0 / 60.0:
		if is_instance_valid(target):
			target.global_position.x = _pg_old_pos.x + (2.0 if int(_custom_timer * 60.0) % 2 == 0 else -2.0)

	# GMS2: timer > 100 → apply status, restore position, destroy
	if _custom_timer > 100.0 / 60.0:
		if is_instance_valid(target):
			target.global_position = _pg_old_pos
		_custom_finish()


# =============================================================================
# change_form (GMS2: oSkill_changeForm)
# =============================================================================
# GMS2: FAINT + telekinesis pose AT CREATE. 3 burst animations (spr_skill_sleepGas)
# every 15 frames. After all 3 + timer>70 → level-based roll to replace mob.
# Main sprite invisible (bursts are the visual).

var _cf_bursts_created: int = 0

func _setup_change_form() -> void:
	_cf_bursts_created = 0

	# Main sprite invisible
	effect_sprite.visible = false
	effect_sprite.stop()

	# GMS2: burst positions
	var tgt_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
	_custom_positions = [
		tgt_pos + Vector2(-20, 4),
		tgt_pos + Vector2(-2, -35),
		tgt_pos + Vector2(20, -8),
	]

func _step_change_form() -> void:
	# GMS2: timeBetweenBursts = 15
	if _cf_bursts_created < _custom_positions.size():
		if int(_custom_timer * 60.0) % 15 == 0:
			_spawn_anim("spr_skill_sleepGas", _custom_positions[_cf_bursts_created], 1.0)
			_cf_bursts_created += 1
	else:
		# GMS2: timer > 70 → apply changeForm effect
		if _custom_timer > 70.0 / 60.0:
			_custom_finish()
