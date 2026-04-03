class_name BossManaBeast
extends Mob
## Mana Beast boss - replaces oMob_manaBeast from GMS2
## Path-based flying boss with fire attacks and screen-crossing charges
## Uses FSM states: MBStand, MBFireball, MBSide, MBHit, MBDead
## GMS2: Multiple sprites: spr_manaBeast_aux (129x84, 11 frames),
##   spr_manaBeast_front (128x128, 6 frames), spr_manaBeast_fire (64x64, 1 frame)

var phase_time: int = 0

# GMS2: starts invulnerable and untargetable, only vulnerable during STAND/phase_stand
var boss_invulnerable: bool = true
var boss_untargetable: bool = true

# Fireball cycle tracking
var go_fireball: bool = true  # First cycle does fireball, subsequent do "coming"

# Skills set in _ready (GMS2: wall self-buff + lucentBeam light attack)

# GMS2: ani_earthSlide() — white palette swap shader for death animation
# Uses sha_palleteSwap with channel=3 (all/white), matching ani_generatePalleteSwap(PALLETESWAP_WHITE, 127, 127, 127, 4, 0.4)
var _earth_slide_material: ShaderMaterial = null

# Colors used in screen effects
const FLAMMIE_COLOR := Color(140.0 / 255.0, 81.0 / 255.0, 198.0 / 255.0, 1.0)
const FLAMMIE_FLESH := Color(198.0 / 255.0, 97.0 / 255.0, 57.0 / 255.0, 1.0)

# Sprite textures for different forms
var tex_aux: Texture2D = null     # Main sprite (flying, side, etc.)
var tex_front: Texture2D = null   # Front-facing (when vulnerable)
var tex_fire: Texture2D = null    # Fireball form

# Aux sprite frame ranges (spr_manaBeast_aux) - exact from GMS2 Create_0.gml
var aux_fireball_going_ini: int = 0; var aux_fireball_going_end: int = 0
var aux_fireball_prepare_ini: int = 1; var aux_fireball_prepare_end: int = 4
var aux_fireball_wait_ini: int = 5; var aux_fireball_wait_end: int = 6
var aux_coming_ini: int = 8; var aux_coming_end: int = 8
var aux_side_ini: int = 9; var aux_side_end: int = 9

# Front sprite frame ranges (spr_manaBeast_front: 6 frames, 128x128)
# GMS2: standIni=0..standEnd=5 (but only 6 total frames, so 0-3 stand, 4-5 hurt)
var front_stand_ini: int = 0; var front_stand_end: int = 5
var front_hurt_ini: int = 4; var front_hurt_end: int = 5

# Boss death signal
signal boss_defeated

func _ready() -> void:
	super._ready()
	creature_is_boss = true
	pushable = false
	mob_name = "Mana Beast"
	display_name = "Mana Beast"
	add_to_group("bosses")
	add_to_group("mobs")
	# GMS2: pierceMagic = true
	pierce_magic = true
	skill_list = ["wall", "lucentBeam"]

	# GMS2: drawShadow = false — flying boss has no shadow
	if shadow:
		shadow.visible = false

	# GMS2: trepassable = true — players can walk through the boss
	# Disable collision mask so the boss doesn't block player movement.
	# Keep collision_layer so raycasts can still detect the boss.
	collision_mask = 0

	# GMS2 stats (level 70)
	attribute["hp"] = 5000
	attribute["maxHP"] = 5000
	attribute["mp"] = 999
	attribute["maxMP"] = 999
	attribute["strength"] = 99
	attribute["constitution"] = 80
	attribute["intelligence"] = 80
	attribute["wisdom"] = 80
	attribute["level"] = 70

	passive = false

	# GMS2: pal_swap_init_system(shd_pal_swapper) — init palette swap for death effect
	_init_earth_slide_shader()

	# Load sprite textures
	_init_boss_sprites()

	# Start with aux sprite (fireball entrance state)
	use_aux_sprite()

func _init_boss_sprites() -> void:
	## Try AnimatedSprite2D from .tres (new system)
	var anim_lib_path := "res://assets/animations/bosses/mana_beast/mana_beast.tres"
	if ResourceLoader.exists(anim_lib_path):
		var sf: SpriteFrames = load(anim_lib_path)
		if sf:
			setup_animated_sprite(sf, Vector2(65, 42))
			_build_mana_beast_frame_map()
			return

	## Fallback: legacy system
	tex_aux = load("res://assets/sprites/sheets/spr_manaBeast_aux.png")
	tex_front = load("res://assets/sprites/sheets/spr_manaBeast_front.png")
	tex_fire = load("res://assets/sprites/sheets/spr_manaBeast_fire.png")

	if tex_aux:
		var meta_path := "res://assets/sprites/sheets/spr_manaBeast_aux.json"
		var columns: int = 11
		if FileAccess.file_exists(meta_path):
			var f := FileAccess.open(meta_path, FileAccess.READ)
			if f:
				var json := JSON.new()
				if json.parse(f.get_as_text()) == OK:
					var data: Dictionary = json.data
					columns = data.get("columns", 11)
				f.close()
		set_sprite_sheet(tex_aux, columns, 129, 84, Vector2(65, 42))

func _build_mana_beast_frame_map() -> void:
	_frame_to_anim_map.clear()
	# Aux animations
	_frame_to_anim_map[aux_fireball_going_ini] = "aux_fireball_going"
	_frame_to_anim_map[aux_fireball_prepare_ini] = "aux_fireball_prepare"
	_frame_to_anim_map[aux_fireball_wait_ini] = "aux_fireball_wait"
	_frame_to_anim_map[aux_coming_ini] = "aux_coming"
	_frame_to_anim_map[aux_side_ini] = "aux_side"
	# Front animations
	_frame_to_anim_map[front_stand_ini] = "front_stand"
	_frame_to_anim_map[front_hurt_ini] = "front_hurt"

func use_aux_sprite() -> void:
	## Switch to the auxiliary sprite (flying/side/fireball forms)
	if _use_animated_sprite and animated_sprite:
		# AnimatedSprite2D: change offset for aux size and play aux animation
		animated_sprite.offset = -Vector2(65, 42)
		spr_walk_up_ini = aux_fireball_going_ini
		spr_walk_up_end = aux_fireball_going_end
		_current_anim_prefix = "aux_fireball_going"
		set_facing_animation("aux_fireball_going")
		return
	# Legacy
	if tex_aux:
		var columns: int = 11
		set_sprite_sheet(tex_aux, columns, 129, 84, Vector2(65, 42))
		spr_walk_up_ini = aux_fireball_going_ini; spr_walk_up_end = aux_fireball_going_end
		spr_walk_right_ini = aux_fireball_going_ini; spr_walk_right_end = aux_fireball_going_end
		spr_walk_down_ini = aux_fireball_going_ini; spr_walk_down_end = aux_fireball_going_end
		spr_walk_left_ini = aux_fireball_going_ini; spr_walk_left_end = aux_fireball_going_end
		set_default_facing_animations(
			spr_walk_up_ini, spr_walk_right_ini,
			spr_walk_down_ini, spr_walk_left_ini,
			spr_walk_up_end, spr_walk_right_end,
			spr_walk_down_end, spr_walk_left_end
		)

func use_front_sprite() -> void:
	## Switch to front-facing sprite (vulnerable stand phase)
	if _use_animated_sprite and animated_sprite:
		animated_sprite.offset = -Vector2(64, 96)
		spr_walk_up_ini = front_stand_ini; spr_walk_up_end = front_stand_end
		spr_hit_up = front_hurt_ini
		spr_hit_right = front_hurt_ini
		spr_hit_down = front_hurt_ini
		spr_hit_left = front_hurt_ini
		_current_anim_prefix = "front_stand"
		set_facing_animation("front_stand")
		return
	# Legacy
	if tex_front:
		var columns: int = 6
		set_sprite_sheet(tex_front, columns, 128, 128, Vector2(64, 96))
		spr_walk_up_ini = front_stand_ini; spr_walk_up_end = front_stand_end
		spr_walk_right_ini = front_stand_ini; spr_walk_right_end = front_stand_end
		spr_walk_down_ini = front_stand_ini; spr_walk_down_end = front_stand_end
		spr_walk_left_ini = front_stand_ini; spr_walk_left_end = front_stand_end
		spr_hit_up = front_hurt_ini
		spr_hit_right = front_hurt_ini
		spr_hit_down = front_hurt_ini
		spr_hit_left = front_hurt_ini
		set_default_facing_animations(
			spr_walk_up_ini, spr_walk_right_ini,
			spr_walk_down_ini, spr_walk_left_ini,
			spr_walk_up_end, spr_walk_right_end,
			spr_walk_down_end, spr_walk_left_end
		)

func use_fire_sprite() -> void:
	## Switch to fireball sprite
	if _use_animated_sprite and animated_sprite:
		animated_sprite.offset = -Vector2(32, 32)
		play_animation("fire")
		return
	# Legacy
	if tex_fire:
		set_sprite_sheet(tex_fire, 1, 64, 64, Vector2(32, 32))

func set_vulnerable(value: bool) -> void:
	## Toggle vulnerability (GMS2: only vulnerable during STAND/phase_stand)
	boss_invulnerable = not value
	boss_untargetable = not value
	is_invulnerable = not value

func cast_wall_on_self() -> void:
	## GMS2: Self-buffs with Wall spell (infinite duration)
	SkillSystem.cast_skill("wall", self, self)

func cast_lucent_beam(target: Creature) -> void:
	## GMS2: casts lucentBeam on a random player
	if is_instance_valid(target):
		SkillSystem.cast_skill("lucentBeam", self, target)

func get_random_player() -> Node:
	## Get a random living player
	var living_players: Array = []
	for player in GameManager.players:
		if is_instance_valid(player) and not player.is_dead:
			living_players.append(player)
	if living_players.size() > 0:
		return living_players[randi() % living_players.size()]
	return null

func get_camera_center() -> Vector2:
	## GMS2: getCameraCenter() returns center of the camera viewport
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam:
		return cam.get_screen_center_position()
	# Fallback to viewport center
	return get_viewport().get_visible_rect().size / 2.0

func perform_ethereal_attack_all() -> void:
	## GMS2: ATTACKTYPE_ETEREAL attack on ALL actors
	for player in GameManager.players:
		if is_instance_valid(player) and not player.is_dead:
			DamageCalculator.perform_attack(player, self, Constants.AttackType.ETEREAL)  # GMS2: ATTACKTYPE_ETEREAL bypasses defense

func _update_draw_order() -> void:
	## Override: GMS2 setCustomDepth(400) — fixed depth, no Y-sorting for flying boss.
	## The boss flies above the arena so Y-based draw order makes no sense.
	pass

func _init_earth_slide_shader() -> void:
	## GMS2: ani_earthSlide() uses ani_generatePalleteSwap(PALLETESWAP_WHITE, 127, 127, 127, 4, 0.4)
	## This creates an oscillating white palette swap effect during the death animation.
	var shader: Shader = load("res://assets/shaders/sha_palleteSwap.gdshader")
	if shader:
		_earth_slide_material = ShaderMaterial.new()
		_earth_slide_material.shader = shader
		# channel 3 = all channels (white flash), matching PALLETESWAP_WHITE
		_earth_slide_material.set_shader_parameter("u_color_channel", 3)
		# RGB(127,127,127) normalized
		_earth_slide_material.set_shader_parameter("u_color_add", Vector3(127.0 / 255.0, 127.0 / 255.0, 127.0 / 255.0))
		_earth_slide_material.set_shader_parameter("u_color_limit", 0.4)
