class_name RingMenu
extends Control
## Ring menu system - faithful port of GMS2 oRingMenu
## Displays items as icons in a circular ring around the target character

signal menu_closed
signal item_selected(section: int, item_index: int)

# --- GMS2 oRingMenu constants ---
const ROTATION_SPEED: int = 7
const OFFSET_MULTIPLIER: int = 30
const DOWN_SPEED: float = 7.0
const FIXED_DISTANCE: float = 40.0
const OFFSET_FIX_STOP: float = 6.0
const CENTER_OFFSET := Vector2(-0, 11.0)
const SELECTOR_ANCHOR := Vector2(-11.0, -62.0)
const CONFIRM_TIMER_LIMIT: int = 3

# Menu modes
enum MenuMode { RING_MENU, SELECT, STATUS_SCREEN, WEAPON_LEVELS, ACTION_GRID, CONTROLLER_EDIT, WINDOW_EDIT }

# Section indices (GMS2 order: ITEM=0, WEAPON=1, ETC=2, MAGIC=3, SKILLS=4 subsection)
# GEAR_HEAD/GEAR_ACCESSORIES/GEAR_BODY = armor equip sub-sections
# SHOP = shop buy/sell sub-section
enum Section { ITEM = 0, WEAPON = 1, ETC = 2, MAGIC = 3, SKILLS = 4, GEAR_HEAD = 5, GEAR_ACCESSORIES = 6, GEAR_BODY = 7, SHOP = 8 }

# --- State ---
var is_open: bool = false
var target_player: Actor = null
var player_who_called: Actor = null  # GMS2: playerWhoCalled - the character who opened the menu
var mode: int = MenuMode.RING_MENU

# Ring rotation
var direction_original: float = 0.0
var direction_offset: float = 0.0
var offset_length: float = 0.0
var direction_changing: int = 0
var rotate_increment: float = 0.0
var _rotation_target: float = 0.0  # Target direction_offset computed when rotation starts
var rotate_direction: int = 0
var is_rotating: bool = false
var is_changing_menu: bool = false
var is_finishing_changing_menu: bool = false
var _destroy_after_animation: bool = false  # GMS2: destroyRingAfterAnimation

# Section management
var item_menu_showed_index: int = Section.ITEM
var sections_order: Array[int] = [Section.ITEM, Section.WEAPON, Section.ETC, Section.MAGIC]
var current_element_selected: Dictionary = {}
var _last_selected_names: Dictionary = {}  # Working copy: Section → item "name" for re-selection
var _saved_section: int = -1  # Working copy: last section (-1 = first open)
var _saved_gear_mode: bool = false  # Working copy: was in gear mode
# Per-character persistent state (in-memory, keyed by Actor)
var _char_state: Dictionary = {}  # Actor → { "section", "gear_mode", "selections", "item_names", "deity" }
var option_number: int = 0
var active_items: Array[Dictionary] = []

# For returning from SKILLS subsection
var magic_deity_name: String = ""

# Confirm animation
var confirm_animation: bool = false
var confirm_timer: float = 0.0
var show_sprite_item: bool = true
var slot_selected_to_confirm: int = -1

# Icon animation (for animated icons like skill icons with subimageTotal > 1)
var image_index_icons: int = 1
var image_index_icons_step: float = 0.0

# Target selection
var selected_target: int = 0
var target_mode: int = 0
var select_skill_data: Dictionary = {}
var select_deity_level: int = 0
var valid_targets: Array = []
var selected_target_idx: int = 0  # -1 = all targets selected (GMS2: selectedTarget)
var arrow_bob_timer: float = 0.0
var _select_can_change_target: bool = true  # GMS2: canChangeTarget
var _select_target_all: bool = false  # GMS2: enableAll - targets all of that type
var _show_all_cursor_toggle: bool = true  # GMS2: showAllCursorToggle - blink when all selected
var _select_is_item: bool = false  # true = item selection, false = skill selection
var _select_item_data: Dictionary = {}  # Item being used (when _select_is_item)

# Loaded textures
var icons_general: Array[Texture2D] = []
var icons_skills: Array[Texture2D] = []
var selector_frames: Array[Texture2D] = []
var arrow_frames: Array[Texture2D] = []

# Font
var custom_font: Font = preload("res://assets/fonts/sprfont_som.fnt")

# GMS2: sha_brightBorder / sha_brightBorderNegative — icon shader effect
# Uses a child canvas item so the shader applies only to icon draw calls.
var _icon_ci: RID = RID()
var _face_ci: RID = RID()  # Child canvas item for equipped face icons (no shader, renders on top of _icon_ci)
var _icon_shader_mat: ShaderMaterial = null
var _shader_timer: float = 0.0   # GMS2: shader_timer — counts 0→20/60 sec before pulse starts
var _shader_timer2: float = 0.0  # GMS2: shader_timer2 — pulse value 0→2

# Delta time passed to _do_step for timers
var _current_delta: float = 0.0

# Input cache: accumulates just_pressed state across frames until consumed by step accumulator.
# Prevents missed inputs at high refresh rates (>60fps) where the accumulator doesn't fire every frame.
var _input_cache: Dictionary = {}

func _cache_input() -> void:
	# OR-accumulate: if any frame since last clear had just_pressed, keep it true
	_input_cache["attack"] = _input_cache.get("attack", false) or Input.is_action_just_pressed("attack")
	_input_cache["run"] = _input_cache.get("run", false) or Input.is_action_just_pressed("run")
	_input_cache["move_left"] = _input_cache.get("move_left", false) or Input.is_action_just_pressed("move_left")
	_input_cache["move_right"] = _input_cache.get("move_right", false) or Input.is_action_just_pressed("move_right")
	_input_cache["move_up"] = _input_cache.get("move_up", false) or Input.is_action_just_pressed("move_up")
	_input_cache["move_down"] = _input_cache.get("move_down", false) or Input.is_action_just_pressed("move_down")
	_input_cache["menu"] = _input_cache.get("menu", false) or Input.is_action_just_pressed("menu")
	_input_cache["misc"] = _input_cache.get("misc", false) or Input.is_action_just_pressed("misc")

func _clear_input_cache() -> void:
	_input_cache.clear()

func _input_just_pressed(action: String) -> bool:
	return _input_cache.get(action, false)

# Status/ETC screen state
var etc_player_idx: int = 0
var etc_weapon_selected: int = 0
var _etc_transition_alpha: float = 1.0  # GMS2: oMenu alpha fade-in (0→1 over ~15 frames)
var _etc_bg_scroll: float = 0.0  # GMS2: spr_bg_menuTile scroll offset
var _bg_menu_tile: Texture2D = null  # GMS2: spr_bg_menuTile tiled background
var _mana_seeds_tex: Texture2D = null  # GMS2: spr_manaSeeds cached
var _action_grid_tex: Texture2D = null  # GMS2: spr_actionGrid (128×128 checkerboard)
var _control_pad_move_tex: Texture2D = null  # GMS2: spr_controlPadMove (32×31)
var _gauge_bar_tex: Texture2D = null  # GMS2: spr_gaugeBar (64×6)
var _gauge_pos_tex: Texture2D = null  # GMS2: spr_gaugePosition (7×8, origin 3,4)
var _control_button1_tex: Texture2D = null  # GMS2: spr_controlButton1 (blue)
var _control_button2_tex: Texture2D = null  # GMS2: spr_controlButton2 (red)
var _control_button_tex: Texture2D = null  # GMS2: spr_controlButton (for weapon level swap)
var _control_pad_tex: Texture2D = null  # GMS2: spr_controlPad (24×15, origin 12,7)
var etc_weapon_magic_mode: int = 0  # GMS2: MODE_WEAPON=0, MODE_MAGIC=1
var action_grid_x: int = 4  # 1-4 attack/guard (GMS2: matrix_xIndex + 1)
var action_grid_y: int = 4  # 1-4 approach/keep away (GMS2: matrix_yIndex + 1)
var etc_action_grid_mode: int = 0  # GMS2: CHANGE_ACTION=0, CHANGE_LEVEL=1
var etc_action_level: int = 0  # GMS2: selectedLevel (weapon level 0-8)
var _etc_ag_blink_timer: float = 0.0  # GMS2: timer for blinking (incremented every step)
var _etc_ag_alpha_char: float = 0.0  # GMS2: alphaCharacter (0 or 1 toggle)
var _etc_ag_alpha_cursor: float = 0.0  # GMS2: alphaCursor (0 or 1 toggle)
var _etc_wl_enable_info: bool = false  # GMS2: enableElementInfo — press attack to start
var _etc_wl_bottom_text: String = ""  # GMS2: bottomText — dynamic bottom window text
var _etc_wl_bottom_text_right: String = ""  # GMS2: bottomTextRight — right-aligned text
var window_color: Color = Color(0.05, 0.0, 0.15)
var window_color_channel: int = 0  # 0=R, 1=G, 2=B
var etc_ctrl_selected: int = -1  # GMS2: pressedButton — currently held slot (-1 = none)
var etc_ctrl_assignments: Array = [0, 1, 2, 3]  # GMS2: saveCursor — action index per slot
var _etc_ctrl_save_assignments: Array = [0, 1, 2, 3]  # GMS2: saveCursorOrigin — backup before hold
var _etc_ctrl_old_cursor: int = -1  # GMS2: oldSelectedCursor — assignment before cycling
var _etc_ctrl_current_cursor: int = -1  # GMS2: selectedCursor — assignment being cycled to
var _etc_ctrl_held_action: String = ""  # Which action key is being held
var _etc_ctrl_enable_input: bool = false  # GMS2: enableInput — wait for all keys released first

# Gear equip state (GMS2: armor equip sub-menu)
var in_gear_mode: bool = false
var gear_sections: Array[int] = [Section.GEAR_HEAD, Section.GEAR_ACCESSORIES, Section.GEAR_BODY]
var gear_type_names: Array[String] = ["Head", "Accessories", "Body"]

# Shop state (GMS2: ringMenu shopMode)
var in_shop_mode: bool = false
var shop_is_buying: bool = true
var shop_seller_id: String = ""
var shop_data: Dictionary = {}
var _shop_feedback: String = ""
var _shop_feedback_timer: float = 0.0
const _SHOP_FEEDBACK_DURATION: float = 2.0  # 2 seconds
const MAX_EQUIPMENT_PER_KIND: int = 12

# --- Icon GUID order arrays (from GMS2 .yy files) ---


# =====================================================================
# INITIALIZATION
# =====================================================================

## Sprite-based rendering (GMS2 faithful dialog/menu windows)
var _dialog_bg_textures: Array[Texture2D] = []
var _dialog_border_textures: Array[Texture2D] = []
var _window_layout_textures: Array[Texture2D] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_load_icons()
	_load_ui_sprites()
	_setup_icon_shader()


func _setup_icon_shader() -> void:
	## Create a child canvas item for icon rendering with the bright-border shader.
	## This lets us apply the shader ONLY to icon draw calls, not the entire ring menu.
	_icon_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_icon_ci, get_canvas_item())
	# Face icons canvas item — created AFTER _icon_ci so it renders on top (no shader)
	_face_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_face_ci, get_canvas_item())
	var shader: Shader = load("res://assets/shaders/sha_brightBorder.gdshader")
	_icon_shader_mat = ShaderMaterial.new()
	_icon_shader_mat.shader = shader
	_icon_shader_mat.set_shader_parameter("u_fTime", 0.0)
	_icon_shader_mat.set_shader_parameter("negative", false)
	RenderingServer.canvas_item_set_material(_icon_ci, _icon_shader_mat.get_rid())


func _exit_tree() -> void:
	if _icon_ci.is_valid():
		RenderingServer.free_rid(_icon_ci)
	if _face_ci.is_valid():
		RenderingServer.free_rid(_face_ci)


func _draw_texture_on_ci(ci: RID, tex: Texture2D, pos: Vector2) -> void:
	## Draw a texture (including AtlasTexture) onto a RenderingServer canvas item.
	## AtlasTexture.get_rid() returns the full atlas, so we must use the region variant.
	if tex is AtlasTexture:
		var atlas_tex: AtlasTexture = tex as AtlasTexture
		if atlas_tex.atlas:
			var region: Rect2 = atlas_tex.region
			var dest := Rect2(pos, region.size)
			RenderingServer.canvas_item_add_texture_rect_region(
				ci, dest, atlas_tex.atlas.get_rid(), region)
	else:
		var sz := Vector2(tex.get_width(), tex.get_height())
		RenderingServer.canvas_item_add_texture_rect(ci, Rect2(pos, sz), tex.get_rid())


func _load_ui_sprites() -> void:
	for i in range(8):
		var path: String = "res://assets/sprites/ui/spr_scriptDialog_bg/%d.png" % i
		if ResourceLoader.exists(path):
			_dialog_bg_textures.append(load(path))
	for i in range(9):
		var path: String = "res://assets/sprites/ui/spr_scriptDialog_border/%d.png" % i
		if ResourceLoader.exists(path):
			_dialog_border_textures.append(load(path))
	for i in range(2):
		var path: String = "res://assets/sprites/ui/spr_windowLayout_1/%d.png" % i
		if ResourceLoader.exists(path):
			_window_layout_textures.append(load(path))
	# GMS2: spr_bg_menuTile — tiled background for ETC screens
	var tile_path: String = "res://assets/sprites/spr_bg_menuTile/698e698a-c810-4d92-a26f-549b65b3f2ca.png"
	if ResourceLoader.exists(tile_path):
		_bg_menu_tile = load(tile_path)
	# GMS2: spr_manaSeeds — mana seed icons for status screen
	var seeds_path: String = "res://assets/sprites/ui/spr_manaSeeds/0.png"
	if ResourceLoader.exists(seeds_path):
		_mana_seeds_tex = load(seeds_path)
	# GMS2: spr_actionGrid — 128×128 checkerboard for action grid screen
	var agrid_path: String = "res://assets/sprites/spr_actionGrid/ba861429-12ec-4461-a0d3-7d7bf466c497.png"
	if ResourceLoader.exists(agrid_path):
		_action_grid_tex = load(agrid_path)
	# GMS2: Window Edit / Controller Edit UI sprites
	var _ui_paths: Dictionary = {
		"controlPadMove": "res://assets/sprites/ui/spr_controlPadMove/0.png",
		"controlPad": "res://assets/sprites/ui/spr_controlPad/0.png",
		"gaugeBar": "res://assets/sprites/ui/spr_gaugeBar/0.png",
		"gaugePosition": "res://assets/sprites/ui/spr_gaugePosition/0.png",
		"controlButton1": "res://assets/sprites/ui/spr_controlButton1/0.png",
		"controlButton2": "res://assets/sprites/ui/spr_controlButton2/0.png",
		"controlButton": "res://assets/sprites/ui/spr_controlButton/0.png",
	}
	for key in _ui_paths:
		var p: String = _ui_paths[key]
		if ResourceLoader.exists(p):
			var tex: Texture2D = load(p)
			match key:
				"controlPadMove": _control_pad_move_tex = tex
				"controlPad": _control_pad_tex = tex
				"gaugeBar": _gauge_bar_tex = tex
				"gaugePosition": _gauge_pos_tex = tex
				"controlButton1": _control_button1_tex = tex
				"controlButton2": _control_button2_tex = tex
				"controlButton": _control_button_tex = tex

func _load_icons() -> void:
	icons_general = SpriteUtils.load_sheet_frames("spr_iconsGeneral")
	icons_skills = SpriteUtils.load_sheet_frames("spr_iconsSkills")
	selector_frames = SpriteUtils.load_sheet_frames("spr_menuSelector")
	arrow_frames = SpriteUtils.load_sheet_frames("spr_arrow")

# =====================================================================
# OPEN / CLOSE / TOGGLE
# =====================================================================

func toggle(player: Node = null, caller: Node = null) -> void:
	if is_open:
		close()
	else:
		open(player, caller)

func open(player: Node = null, caller: Node = null) -> void:
	if player:
		target_player = player as Actor
	elif GameManager.players.size() > 0:
		target_player = GameManager.get_party_leader() as Actor

	# GMS2: playerWhoCalled — who pressed the button (defaults to target)
	player_who_called = (caller as Actor) if caller else target_player

	is_open = true
	visible = true
	GameManager.ring_menu_opened = true
	GameManager.lock_global_input = true
	mode = MenuMode.RING_MENU

	# Load per-character state (GMS2: currentElementSelected = playerRingTarget.currentElementSelected)
	_load_char_state(target_player)

	# Build sections_order based on target character's magic type (GMS2: ringMenu_setSelectorBasics)
	_rebuild_sections_order()

	_resolve_saved_section()
	confirm_animation = false
	slot_selected_to_confirm = -1
	direction_changing = 1
	_populate_items()
	_restore_selection_by_name()
	_recalculate_offsets()
	MusicManager.play_sfx("snd_menuExpand")
	# GMS2: oMenu Create calls hideHud()
	if GameManager.hud:
		GameManager.hud.hide_hud()

func close() -> void:
	# Save per-character state (GMS2: target.currentElementSelected = ringMenu.currentElementSelected)
	if not in_shop_mode:
		_save_char_state(target_player)

	is_open = false
	visible = false
	GameManager.ring_menu_opened = false
	GameManager.lock_global_input = false
	# GMS2: oMenu Destroy calls showHud()
	if GameManager.hud:
		GameManager.hud.show_hud()
	confirm_animation = false
	slot_selected_to_confirm = -1
	in_gear_mode = false
	in_shop_mode = false
	shop_seller_id = ""
	shop_data = {}
	_destroy_after_animation = false
	is_changing_menu = false
	MusicManager.play_sfx("snd_menuColapse")
	menu_closed.emit()

func _start_animated_close() -> void:
	## GMS2: ringMenu_closeMenu - start section-change animation, then destroy on completion
	## Uses the same isChangingMenu + directionChanging=1 animation that section switching uses,
	## but with destroyRingAfterAnimation=true so it calls close() instead of toggling section.
	confirm_animation = false
	slot_selected_to_confirm = -1
	MusicManager.play_sfx("snd_menuExpand")
	_destroy_after_animation = true
	is_changing_menu = true
	direction_changing = 1

func _rebuild_sections_order() -> void:
	## Build sections_order based on target character's enableMagic (GMS2: ringMenu_setSelectorBasics)
	## GMS2 order: ITEM, ETC, WEAPON, then MAGIC only if enableMagic != MAGIC_NONE
	sections_order.clear()
	sections_order.append(Section.ITEM)
	sections_order.append(Section.WEAPON)
	sections_order.append(Section.ETC)
	if target_player and target_player.enable_magic != Constants.MAGIC_NONE:
		sections_order.append(Section.MAGIC)

# =====================================================================
# SECTION POPULATION
# =====================================================================

func _populate_items() -> void:
	active_items.clear()
	match item_menu_showed_index:
		Section.ITEM:
			if in_shop_mode:
				_populate_shop_items()
			else:
				_populate_consumable_items()
		Section.WEAPON:
			_populate_weapons()
		Section.ETC:
			_populate_etc_items()
		Section.MAGIC:
			_populate_magic_deities()
		Section.SKILLS:
			_populate_skills()
		Section.GEAR_HEAD:
			_populate_gear_by_type(Constants.EquipmentType.HEAD)
		Section.GEAR_ACCESSORIES:
			_populate_gear_by_type(Constants.EquipmentType.ACCESSORIES)
		Section.GEAR_BODY:
			_populate_gear_by_type(Constants.EquipmentType.BODY)
		Section.SHOP:
			_populate_shop_items()
	option_number = active_items.size()

func _populate_consumable_items() -> void:
	for item in Database.items:
		if item is Dictionary and item.get("section", "") == "ITEM":
			var item_name: String = item.get("name", "")
			var qty: int = GameManager.inventory_items.get(item_name, 0)
			if qty > 0:
				active_items.append({
					"name": item_name,
					"displayName": item.get("nameText", item_name),
					"description": item.get("description", ""),
					"icon_index": item.get("id", 0),
					"icon_total": 1,
					"icon_sprite": "general",
					"quantity": qty,
					"data": item,
				})

func _populate_weapons() -> void:
	for equip_name in GameManager.inventory_equipment:
		var equip_data: Dictionary = {}
		for eq in Database.equipments:
			if eq is Dictionary and eq.get("name", "") == equip_name:
				equip_data = eq
				break
		# Skip if not found in database or not a weapon (kind=0)
		if equip_data.is_empty():
			continue
		if equip_data.get("kind", -1) != 0:
			continue
		var is_equipped: bool = false
		if target_player:
			# Compare weapon KIND (sword, axe...) not equipment name (dragonBuster, doomAxe...)
			var aux: Dictionary = equip_data.get("auxData", {})
			var wkind: String = str(aux.get("weaponKindName", "")).to_lower()
			is_equipped = target_player.get_weapon_name() == wkind
		active_items.append({
			"name": equip_name,
			"displayName": equip_data.get("nameText", equip_name),
			"description": equip_data.get("description", ""),
			"icon_index": equip_data.get("subimage", 0),
			"icon_total": equip_data.get("subimageTotal", 1),
			"icon_sprite": "general",
			"equipped": is_equipped,
			"data": equip_data,
		})

func _populate_etc_items() -> void:
	for item in Database.items:
		if item is Dictionary and item.get("section", "") == "ETC":
			active_items.append({
				"name": item.get("name", ""),
				"displayName": item.get("nameText", "???"),
				"description": item.get("description", ""),
				"icon_index": item.get("id", 0),
				"icon_total": 1,
				"icon_sprite": "general",
				"subSection": item.get("subSection", ""),
				"data": item,
			})

func _populate_magic_deities() -> void:
	# GMS2: ringMenu_setItemMenu filters deities by deitiesEnabled list
	# Popoie (MAGIC_BLACK) can't see Lumina (no offensive spells), Purim (MAGIC_WHITE) can't see Shade (no support spells)
	# Filter: only show deities that have at least one spell matching this caster's magic type
	var caster_magic_type: int = 0
	if target_player and target_player is Creature:
		caster_magic_type = target_player.enable_magic

	for item in Database.items:
		if item is Dictionary and item.get("section", "") == "MAGIC":
			var deity_name_check: String = item.get("name", "")
			# Check if this deity has any enabled spells for this caster's magic type
			if caster_magic_type != Constants.MAGIC_NONE and not _deity_has_spells_for_caster(deity_name_check, caster_magic_type):
				continue
			active_items.append({
				"name": deity_name_check,
				"displayName": item.get("nameText", "???"),
				"description": item.get("description", ""),
				"icon_index": item.get("id", 0),
				"icon_total": 1,
				"icon_sprite": "general",
				"subSection": item.get("subSection", ""),
				"data": item,
			})

func _deity_has_spells_for_caster(deity_name_check: String, magic_type: int) -> bool:
	## Returns true if the deity has at least one enabled spell matching the caster's magic type
	for skill in Database.skills:
		if skill is Dictionary:
			if skill.get("deity", "") == deity_name_check and skill.get("enabled", false):
				var kind: int = skill.get("magicKind", 0)
				# MAGIC_ALL sees both black (1) and white (2) spells
				if magic_type == Constants.MAGIC_ALL:
					if kind == Constants.MAGIC_BLACK or kind == Constants.MAGIC_WHITE:
						return true
				elif kind == magic_type:
					return true
	return false

func _populate_skills() -> void:
	# Show spells for the selected deity, filtered by character's magic type
	# GMS2: filter(skillsDB, SKILLSDB_MAGIC_KIND, summonMagicType, FILTER_EQUALS)
	# Uses EXACT match: magicKind == enableMagic (1=offensive, 2=support)
	# magicKind 3 (neutral/status) spells are NOT shown in ring menu - they're mob-only
	var caster_magic_type: int = 0
	if target_player and target_player is Creature:
		caster_magic_type = target_player.enable_magic

	for skill in Database.skills:
		if skill is Dictionary:
			if skill.get("deity", "") == magic_deity_name:
				if skill.get("enabled", false):
					# GMS2: exact match magicKind == summonMagicType
					# MAGIC_ALL sees both black (1) and white (2) spells
					var kind: int = skill.get("magicKind", 0)
					var show_skill: bool
					if caster_magic_type == Constants.MAGIC_ALL:
						show_skill = (kind == Constants.MAGIC_BLACK or kind == Constants.MAGIC_WHITE)
					else:
						show_skill = (kind == caster_magic_type)

					if show_skill:
						active_items.append({
							"name": skill.get("name", ""),
							"displayName": skill.get("nameText", "???"),
							"description": skill.get("description", ""),
							"icon_index": skill.get("subimage", 0),
							"icon_total": skill.get("subimageTotal", 1),
							"icon_sprite": "skills",
							"mp": skill.get("mp", 0),
							"data": skill,
						})

func _populate_gear_by_type(gear_kind: int) -> void:
	## Populate ring with owned equipment of the given kind (HEAD=1, ACCESSORIES=2, BODY=3)
	for equip_name in GameManager.inventory_equipment:
		var equip_data: Dictionary = _find_equipment_by_name(equip_name)
		if equip_data.is_empty():
			continue
		if equip_data.get("kind", -1) != gear_kind:
			continue
		# Check class compatibility
		var can_wear: bool = _can_wear_equipment(equip_data)
		# Check if currently equipped
		var is_equipped: bool = false
		if target_player:
			match gear_kind:
				Constants.EquipmentType.HEAD:
					is_equipped = (target_player.equipped_head == equip_data.get("id", -1))
				Constants.EquipmentType.ACCESSORIES:
					is_equipped = (target_player.equipped_accessory == equip_data.get("id", -1))
				Constants.EquipmentType.BODY:
					is_equipped = (target_player.equipped_body == equip_data.get("id", -1))
		# Stat comparison
		var stat_diff: String = _get_gear_stat_comparison(equip_data, gear_kind)
		active_items.append({
			"name": equip_name,
			"displayName": equip_data.get("nameText", equip_name),
			"description": stat_diff,
			"icon_index": equip_data.get("subimage", 0),
			"icon_total": equip_data.get("subimageTotal", 1),
			"icon_sprite": "general",
			"equipped": is_equipped,
			"can_wear": can_wear,
			"data": equip_data,
		})
	# GMS2: trash bin / remove item at end of ring (id=-1)
	# Allows unequipping current gear without selecting another piece
	active_items.append({
		"name": "none",
		"displayName": "---",
		"description": "",
		"icon_index": 35,  # GMS2: trash/empty icon
		"icon_total": 1,
		"icon_sprite": "general",
		"equipped": false,
		"can_wear": true,
		"data": {"id": -1, "kind": gear_kind},
	})

func _populate_shop_items() -> void:
	## Populate ring with items/equipment from the current shop
	if shop_data.is_empty():
		return
	if shop_is_buying:
		_populate_shop_buy()
	else:
		_populate_shop_sell()

func _populate_shop_buy() -> void:
	## Items available for purchase from the shop
	# Consumable items
	var shop_items: Array = shop_data.get("items", [])
	for shop_entry in shop_items:
		if not shop_entry is Dictionary:
			continue
		var item_id: int = int(shop_entry.get("itemId", -1))
		var price: int = int(shop_entry.get("price", 0))
		var stock: int = int(shop_entry.get("stock", -1))
		if stock == 0:
			continue
		var item_data: Dictionary = Database.get_item(item_id)
		if item_data.is_empty():
			continue
		var qty_owned: int = GameManager.get_item_count(item_data.get("name", ""))
		var max_qty: int = int(item_data.get("maxQuantity", 99))
		active_items.append({
			"name": item_data.get("name", ""),
			"displayName": item_data.get("nameText", "???"),
			"description": item_data.get("description", ""),
			"icon_index": item_data.get("id", 0),
			"icon_total": 1,
			"icon_sprite": "general",
			"price": price,
			"quantity": qty_owned,
			"max_quantity": max_qty,
			"shop_type": "item",
			"data": item_data,
		})
	# Equipment
	var shop_equips: Array = shop_data.get("equipment", [])
	for shop_entry in shop_equips:
		if not shop_entry is Dictionary:
			continue
		var equip_id: int = int(shop_entry.get("itemId", -1))
		var price: int = int(shop_entry.get("price", 0))
		var stock: int = int(shop_entry.get("stock", -1))
		if stock == 0:
			continue
		var equip_data: Dictionary = Database.get_equipment(equip_id)
		if equip_data.is_empty():
			continue
		active_items.append({
			"name": equip_data.get("name", ""),
			"displayName": equip_data.get("nameText", "???"),
			"description": equip_data.get("description", ""),
			"icon_index": equip_data.get("subimage", 0),
			"icon_total": equip_data.get("subimageTotal", 1),
			"icon_sprite": "general",
			"price": price,
			"shop_type": "equipment",
			"data": equip_data,
		})

func _populate_shop_sell() -> void:
	## Items the player owns that can be sold
	# Consumable items with prices
	for item_name in GameManager.inventory_items:
		var qty: int = GameManager.inventory_items[item_name]
		if qty <= 0:
			continue
		var item_data: Dictionary = Database.get_item_by_name(item_name)
		if item_data.is_empty():
			continue
		var base_price: int = int(item_data.get("price", 0))
		if base_price <= 0:
			continue
		var sell_price: int = int(floor(float(base_price) / float(Constants.SHOP_SELL_DIVISOR)))
		active_items.append({
			"name": item_name,
			"displayName": item_data.get("nameText", item_name),
			"description": item_data.get("description", ""),
			"icon_index": item_data.get("id", 0),
			"icon_total": 1,
			"icon_sprite": "general",
			"price": sell_price,
			"quantity": qty,
			"shop_type": "item",
			"data": item_data,
		})
	# Equipment (non-equipped, with prices)
	var counted_equipment: Dictionary = {}
	for equip_name in GameManager.inventory_equipment:
		var equip_data: Dictionary = _find_equipment_by_name(equip_name)
		if equip_data.is_empty():
			continue
		var base_price: int = int(equip_data.get("price", 0))
		if base_price <= 0:
			continue
		if counted_equipment.has(equip_name):
			continue
		counted_equipment[equip_name] = true
		var sell_price: int = int(floor(float(base_price) / float(Constants.SHOP_SELL_DIVISOR)))
		active_items.append({
			"name": equip_name,
			"displayName": equip_data.get("nameText", equip_name),
			"description": equip_data.get("description", ""),
			"icon_index": equip_data.get("subimage", 0),
			"icon_total": equip_data.get("subimageTotal", 1),
			"icon_sprite": "general",
			"price": sell_price,
			"shop_type": "equipment",
			"data": equip_data,
		})

# =====================================================================
# RING OFFSETS (GMS2: ringMenu_recalculateOffsets)
# =====================================================================

func _recalculate_offsets() -> void:
	var total: int = maxi(1, option_number)
	is_changing_menu = false
	is_finishing_changing_menu = true
	direction_original = 360.0 / float(total)
	is_rotating = false
	_rotation_target = 0.0
	rotate_direction = 0
	rotate_increment = direction_original / float(ROTATION_SPEED)

	var direction_length: float = float(ROTATION_SPEED * OFFSET_MULTIPLIER)
	var selected_idx: int = _get_current_selected()

	if direction_changing == 1:
		direction_offset = 40.0 + (direction_original * float(selected_idx))
		offset_length = 0.0
	else:
		direction_offset = direction_length + (direction_original * float(selected_idx))
		offset_length = direction_length + FIXED_DISTANCE

	if selected_idx >= total:
		current_element_selected[item_menu_showed_index] = total - 1

func _get_current_selected() -> int:
	return current_element_selected.get(item_menu_showed_index, 0)

func _save_current_item_name() -> void:
	var idx: int = _get_current_selected()
	if idx >= 0 and idx < active_items.size():
		_last_selected_names[item_menu_showed_index] = active_items[idx].get("name", "")

func _restore_selection_by_name() -> void:
	if active_items.is_empty():
		current_element_selected[item_menu_showed_index] = 0
		return
	var saved_name: String = _last_selected_names.get(item_menu_showed_index, "")
	if not saved_name.is_empty():
		for i in range(active_items.size()):
			if active_items[i].get("name", "") == saved_name:
				current_element_selected[item_menu_showed_index] = i
				return
	# Item not found by name — clamp index to last valid position
	var idx: int = current_element_selected.get(item_menu_showed_index, 0)
	if idx >= active_items.size():
		current_element_selected[item_menu_showed_index] = active_items.size() - 1

func _resolve_saved_section() -> void:
	if _saved_section < 0:
		item_menu_showed_index = Section.ITEM
		return
	# Shop is context-dependent, don't restore
	if _saved_section == Section.SHOP:
		item_menu_showed_index = Section.ITEM
		return
	# GEAR subsections
	if _saved_section in gear_sections:
		if Section.ETC in sections_order:
			in_gear_mode = true
			item_menu_showed_index = _saved_section
		else:
			item_menu_showed_index = sections_order[0] if not sections_order.is_empty() else Section.ITEM
		return
	# SKILLS subsection
	if _saved_section == Section.SKILLS:
		if Section.MAGIC in sections_order and not magic_deity_name.is_empty():
			item_menu_showed_index = Section.SKILLS
		elif Section.MAGIC in sections_order:
			item_menu_showed_index = Section.MAGIC
		else:
			item_menu_showed_index = sections_order[0] if not sections_order.is_empty() else Section.ITEM
		return
	# Main sections (ITEM, WEAPON, ETC, MAGIC)
	if _saved_section in sections_order:
		item_menu_showed_index = _saved_section
	else:
		item_menu_showed_index = sections_order[0] if not sections_order.is_empty() else Section.ITEM

func _save_char_state(actor: Actor) -> void:
	if not actor:
		return
	_save_current_item_name()
	_char_state[actor] = {
		"section": item_menu_showed_index,
		"gear_mode": in_gear_mode,
		"selections": current_element_selected.duplicate(),
		"item_names": _last_selected_names.duplicate(),
		"deity": magic_deity_name,
	}

func _load_char_state(actor: Actor) -> void:
	if not actor:
		return
	var state: Dictionary = _char_state.get(actor, {})
	_saved_section = state.get("section", -1)
	_saved_gear_mode = state.get("gear_mode", false)
	current_element_selected = state.get("selections", {}).duplicate()
	_last_selected_names = state.get("item_names", {}).duplicate()
	magic_deity_name = state.get("deity", "")
	# Initialize any missing section keys
	for s in [Section.ITEM, Section.WEAPON, Section.ETC, Section.MAGIC, Section.SKILLS,
			Section.GEAR_HEAD, Section.GEAR_ACCESSORIES, Section.GEAR_BODY, Section.SHOP]:
		if not current_element_selected.has(s):
			current_element_selected[s] = 0

func _check_animation_busy() -> bool:
	return not is_rotating and not is_changing_menu and not is_finishing_changing_menu

# =====================================================================
# PROCESS / STEP
# =====================================================================

func _process(delta: float) -> void:
	if not is_open:
		return

	# Cache input state so just_pressed isn't missed
	_cache_input()

	# Run step logic with delta time
	_current_delta = delta
	_do_step()
	_clear_input_cache()

	queue_redraw()

func _do_step() -> void:
	var dt: float = _current_delta

	# Shop feedback timer (GMS2: overrideHelpMessage)
	if _shop_feedback_timer > 0.0:
		_shop_feedback_timer -= dt
		if _shop_feedback_timer <= 0.0:
			_shop_feedback = ""
			_shop_feedback_timer = 0.0

	# Icon animation timer (advance icon every 10/60 sec = ~0.1667s)
	image_index_icons_step += dt
	if image_index_icons_step >= 10.0 / 60.0:
		image_index_icons_step -= 10.0 / 60.0
		image_index_icons += 1

	# GMS2: ani_ringMenuSummons — border pulse timer
	# shader_timer counts 0→20/60 sec (wait), then shader_timer2 ramps 0→2 (pulse), then both reset
	_shader_timer += dt
	if _shader_timer > 20.0 / 60.0:
		_shader_timer2 += 0.15 * 60.0 * dt  # 0.15 per frame at 60fps = 9.0 per second
		if _shader_timer2 >= 2.0:
			_shader_timer = 0.0
			_shader_timer2 = 0.0

	match mode:
		MenuMode.RING_MENU:
			_step_ring_menu()
		MenuMode.SELECT:
			_step_select()
		MenuMode.STATUS_SCREEN, MenuMode.WEAPON_LEVELS, MenuMode.ACTION_GRID, \
		MenuMode.CONTROLLER_EDIT, MenuMode.WINDOW_EDIT:
			_step_etc_screen()

func _step_ring_menu() -> void:
	var dt: float = _current_delta
	var dt60: float = dt * 60.0  # Scale factor to preserve GMS2 per-frame speeds

	# --- Rotation animation ---
	if is_rotating:
		direction_offset += float(rotate_direction) * rotate_increment * dt60
		# Stop when we reach or pass the target (direct math comparison)
		var reached: bool = false
		if rotate_direction == 1:
			reached = direction_offset >= _rotation_target
		else:
			reached = direction_offset <= _rotation_target
		if reached:
			direction_offset = _rotation_target
			is_rotating = false

	# --- Section change: finishing (icons expanding from center) ---
	if is_finishing_changing_menu:
		if direction_changing == 1:
			if offset_length < FIXED_DISTANCE - OFFSET_FIX_STOP:
				offset_length += ROTATION_SPEED * dt60
				direction_offset -= ROTATION_SPEED * dt60
			else:
				offset_length = FIXED_DISTANCE
				direction_offset = direction_original * float(_get_current_selected())
				is_finishing_changing_menu = false
		else:
			if offset_length > FIXED_DISTANCE + OFFSET_FIX_STOP:
				offset_length -= ROTATION_SPEED * dt60
				direction_offset -= ROTATION_SPEED * dt60
			else:
				offset_length = FIXED_DISTANCE
				direction_offset = direction_original * float(_get_current_selected())
				is_finishing_changing_menu = false

	# --- Section change: collapsing (icons shrinking to center) ---
	if is_changing_menu:
		if direction_changing == 1:
			if offset_length < 200:
				offset_length += DOWN_SPEED * dt60
				direction_offset -= DOWN_SPEED * dt60
			else:
				# GMS2: if destroyRingAfterAnimation, close menu instead of toggling section
				if _destroy_after_animation:
					_destroy_after_animation = false
					is_changing_menu = false
					close()
					return
				_do_toggle_section(1)
		else:
			if offset_length > 0 and direction_offset > -200:
				offset_length -= DOWN_SPEED * dt60
				direction_offset -= DOWN_SPEED * dt60
			else:
				_do_toggle_section(0)

	# --- Confirm animation ---
	if confirm_animation:
		confirm_timer += _current_delta
		if confirm_timer > CONFIRM_TIMER_LIMIT / 60.0:
			confirm_timer = 0.0
			show_sprite_item = not show_sprite_item

	# --- Input (only when not animating) ---
	if not _check_animation_busy():
		return

	# Attack = confirm
	if _input_just_pressed("attack"):
		_handle_confirm()

	# Left/Right = rotate ring
	if _input_just_pressed("move_left"):
		_rotate_ring(1)  # GMS2: left = rotateDirection 1
	elif _input_just_pressed("move_right"):
		_rotate_ring(-1)  # GMS2: right = rotateDirection -1

	# Up/Down = change section
	if _input_just_pressed("move_up"):
		if _menu_has_siblings():
			_start_section_change(1)
	elif _input_just_pressed("move_down"):
		if _menu_has_siblings():
			_start_section_change(0)

	# Menu/Run = close or back
	if _input_just_pressed("menu") or _input_just_pressed("run"):
		_handle_close_or_back()

	# Misc = switch player target (GMS2: control_miscPressed, W key / gp_face4)
	if _input_just_pressed("misc"):
		_switch_target_player()

func _step_select() -> void:
	arrow_bob_timer += _current_delta

	# Validate targets still valid (GMS2: ringMenu_switchTargetAlive / ringMenu_switchTargetDead)
	var target_qty: String = select_skill_data.get("targetQuantity", "TARGET_QUANTITY_ONE")
	if target_qty == "TARGET_QUANTITY_DEAD":
		valid_targets = valid_targets.filter(func(t: Variant) -> bool: return is_instance_valid(t) and t is Creature and (t as Creature).is_dead)
	else:
		valid_targets = valid_targets.filter(func(t: Variant) -> bool: return is_instance_valid(t) and t is Creature and not (t as Creature).is_dead)
	if valid_targets.is_empty():
		mode = MenuMode.RING_MENU
		MusicManager.play_sfx("snd_menuError")
		return
	# Clamp index, but preserve -1 (= all selected)
	if selected_target_idx >= 0:
		selected_target_idx = clampi(selected_target_idx, 0, valid_targets.size() - 1)

	if _input_just_pressed("attack"):
		_confirm_target_selection()
	elif _select_can_change_target:
		# GMS2: getNextAliveTarget / getPreviousAliveTarget with enableAll support
		# When enableAll=true, cycling goes: 0 → 1 → ... → N-1 → -1 (all) → 0 → ...
		if _input_just_pressed("move_right") or _input_just_pressed("move_down"):
			MusicManager.play_sfx("snd_menuRotate")
			selected_target_idx = _get_next_target(selected_target_idx)
		elif _input_just_pressed("move_left") or _input_just_pressed("move_up"):
			MusicManager.play_sfx("snd_menuRotate")
			selected_target_idx = _get_prev_target(selected_target_idx)

	if _input_just_pressed("menu") or _input_just_pressed("run"):
		mode = MenuMode.RING_MENU
		MusicManager.play_sfx("snd_menuColapse")

## GMS2: getNextAliveTarget - cycle forward through targets, with enableAll wrapping to -1
func _get_next_target(current: int) -> int:
	var total: int = valid_targets.size()
	if total == 0:
		return current
	if current == -1:
		# From "all" → go to first target
		return 0
	var next: int = current + 1
	if next > total - 1:
		# Past last target: go to "all" if enableAll, else wrap to 0
		return -1 if _select_target_all else 0
	return next

## GMS2: getPreviousAliveTarget - cycle backward through targets
func _get_prev_target(current: int) -> int:
	var total: int = valid_targets.size()
	if total == 0:
		return current
	if current == -1:
		# From "all" → go to last target
		return total - 1
	var prev: int = current - 1
	if prev < 0:
		# Before first target: go to "all" if enableAll, else wrap to last
		return -1 if _select_target_all else total - 1
	return prev

func _menu_has_siblings() -> bool:
	if in_gear_mode:
		return true  # Up/Down cycles gear types
	if in_shop_mode:
		return false  # No section switching in shop
	return item_menu_showed_index != Section.SKILLS

# =====================================================================
# RING ROTATION
# =====================================================================

func _rotate_ring(dir: int) -> void:
	MusicManager.play_sfx("snd_menuRotate")
	is_rotating = true
	rotate_direction = dir
	confirm_animation = false
	slot_selected_to_confirm = -1

	var selected: int = _get_current_selected()
	if dir == -1:  # right key
		selected = selected - 1 if selected > 0 else option_number - 1
	else:  # left key
		selected = selected + 1 if selected < option_number - 1 else 0
	current_element_selected[item_menu_showed_index] = selected
	_save_current_item_name()

	# Compute exact rotation target: current offset + one full item step
	_rotation_target = direction_offset + float(dir) * direction_original

# =====================================================================
# SECTION CHANGING
# =====================================================================

func _start_section_change(dir: int) -> void:
	confirm_animation = false
	slot_selected_to_confirm = -1
	MusicManager.play_sfx("snd_menuExpand" if dir == 1 else "snd_menuColapse")
	is_changing_menu = true
	direction_changing = dir

func _do_toggle_section(dir: int) -> void:
	_save_current_item_name()
	if in_gear_mode:
		# Cycle through gear types: HEAD → ACCESSORIES → BODY
		var idx: int = gear_sections.find(item_menu_showed_index)
		if idx == -1:
			idx = 0
		var sum: int = 1 if dir == 1 else -1
		idx = posmod(idx + sum, gear_sections.size())
		item_menu_showed_index = gear_sections[idx]
		_populate_items()
		direction_changing = dir
		_recalculate_offsets()
		return

	var idx: int = sections_order.find(item_menu_showed_index)
	if idx == -1:
		idx = 0
	var sum: int = 1 if dir == 1 else -1
	idx = posmod(idx + sum, sections_order.size())
	item_menu_showed_index = sections_order[idx]
	_populate_items()
	direction_changing = dir
	_recalculate_offsets()

func _handle_close_or_back() -> void:
	if in_gear_mode:
		# Return from gear equip to ETC section
		_save_current_item_name()
		in_gear_mode = false
		item_menu_showed_index = Section.ETC
		direction_changing = 1
		_populate_items()
		_recalculate_offsets()
		MusicManager.play_sfx("snd_menuColapse")
	elif in_shop_mode:
		# Close shop entirely - animated close
		_start_animated_close()
	elif item_menu_showed_index == Section.SKILLS:
		# Return from skills subsection to magic section
		_save_current_item_name()
		item_menu_showed_index = Section.MAGIC
		direction_changing = 1
		_populate_items()
		_recalculate_offsets()
		MusicManager.play_sfx("snd_menuColapse")
	else:
		# GMS2: ringMenu_closeMenu - animate icons away then destroy
		_start_animated_close()

# =====================================================================
# CONFIRM ACTIONS
# =====================================================================

func _handle_confirm() -> void:
	if option_number == 0:
		return
	var selected: int = _get_current_selected()
	if selected < 0 or selected >= active_items.size():
		return

	MusicManager.play_sfx("snd_menuSelect")
	var item: Dictionary = active_items[selected]

	# Shop confirm handler
	if in_shop_mode:
		_confirm_shop(item, selected)
		return

	match item_menu_showed_index:
		Section.ITEM:
			_confirm_item(item, selected)
		Section.WEAPON:
			_confirm_weapon(item, selected)
		Section.ETC:
			_confirm_etc(item)
		Section.MAGIC:
			_confirm_magic(item)
		Section.SKILLS:
			_confirm_skill(item, selected)
		Section.GEAR_HEAD, Section.GEAR_ACCESSORIES, Section.GEAR_BODY:
			_confirm_gear(item, selected)

func _confirm_item(item: Dictionary, selected: int) -> void:
	# GMS2: ringMenu_playerCanUseItems check before allowing item use
	if not _player_can_use_items():
		MusicManager.play_sfx("snd_menuError")
		return
	# GMS2: items enter MODE_SELECT for target selection (like spells)
	if not confirm_animation:
		confirm_animation = true
		slot_selected_to_confirm = selected
		return
	elif selected != slot_selected_to_confirm:
		slot_selected_to_confirm = selected
		return

	# Check item quantity
	var item_name: String = item.get("name", "")
	if not GameManager.has_item(item_name):
		MusicManager.play_sfx("snd_menuError")
		confirm_animation = false
		slot_selected_to_confirm = -1
		return

	# GMS2: check targetCondition before allowing use (callFlammie, useRope, etc.)
	var item_data: Dictionary = item.get("data", {})
	var conditions: Array = item_data.get("targetCondition", [])
	if not conditions.is_empty():
		if not _check_item_conditions(conditions):
			MusicManager.play_sfx("snd_menuError")
			confirm_animation = false
			slot_selected_to_confirm = -1
			return

	# Get item targeting data
	var target_type: String = str(item_data.get("target", "ALLY"))
	var target_qty: String = str(item_data.get("targetQuantity", "TARGET_QUANTITY_ONE"))

	# Build target list (reuse spell targeting logic)
	var targets: Array = _get_valid_targets_for_spell(target_type, target_qty)
	if targets.is_empty():
		MusicManager.play_sfx("snd_menuError")
		confirm_animation = false
		slot_selected_to_confirm = -1
		return

	# Enter SELECT mode for item target selection
	_select_is_item = true
	_select_item_data = item
	select_skill_data = item_data  # Reuse for target qty checking in _step_select
	valid_targets = targets
	arrow_bob_timer = 0.0
	_select_can_change_target = true
	_select_target_all = false

	match target_qty:
		"TARGET_QUANTITY_ONE":
			selected_target_idx = _get_initial_target_idx(targets, target_type)
			_select_can_change_target = true
			_select_target_all = false
		"TARGET_QUANTITY_ALL":
			selected_target_idx = _get_initial_target_idx(targets, target_type)
			_select_can_change_target = true
			_select_target_all = true
		"TARGET_QUANTITY_ONLY_ALL":
			selected_target_idx = -1
			_select_can_change_target = false
			_select_target_all = true
		"TARGET_QUANTITY_SELF":
			selected_target_idx = _find_target_in_list(targets, target_player as Creature)
			_select_can_change_target = false
			_select_target_all = false
		"TARGET_QUANTITY_DEAD":
			selected_target_idx = 0
			_select_can_change_target = true
			_select_target_all = false
		_:
			selected_target_idx = 0

	mode = MenuMode.SELECT
	confirm_animation = false
	slot_selected_to_confirm = -1
	MusicManager.play_sfx("snd_menuSelect")

func _confirm_weapon(item: Dictionary, selected: int) -> void:
	# GMS2: isTargetAvailable check before weapon equip
	if not _is_target_available():
		MusicManager.play_sfx("snd_menuError")
		return
	if not confirm_animation:
		confirm_animation = true
		slot_selected_to_confirm = selected
		return
	elif selected != slot_selected_to_confirm:
		slot_selected_to_confirm = selected
		return

	# Equip the weapon
	_equip_weapon(item)
	confirm_animation = false
	slot_selected_to_confirm = -1
	close()

func _confirm_etc(item: Dictionary) -> void:
	var item_name: String = item.get("name", "")
	# GMS2: ETC screens should start showing the player who opened the ring menu
	var invoker_idx: int = maxi(GameManager.players.find(target_player), 0)

	match item_name:
		"status":
			etc_player_idx = invoker_idx
			_etc_transition_alpha = 0.0
			_etc_bg_scroll = 0.0
			mode = MenuMode.STATUS_SCREEN
			MusicManager.play_sfx("snd_menuSelect")
		"weaponMagicLevel":
			etc_player_idx = invoker_idx
			etc_weapon_selected = 0
			etc_weapon_magic_mode = 0  # GMS2: start in MODE_WEAPON
			_etc_wl_enable_info = false  # GMS2: must press Attack to start navigation
			_etc_wl_bottom_text = "CHECK THE WEAPON SKILL/LEVEL DATA HERE.\nPUSH \"ATTACK\" BUTTON TO START. CHOOSE A WEAPON WITH\nTHE CONTROL PAD. PUSH \"ATTACK\" TO SEE DATA."
			_etc_wl_bottom_text_right = ""
			_etc_transition_alpha = 0.0
			_etc_bg_scroll = 0.0
			mode = MenuMode.WEAPON_LEVELS
			MusicManager.play_sfx("snd_menuSelect")
		"equipArmor":
			_enter_gear_mode()
		"actionGrid":
			# Load current strategy patterns from target player
			if target_player:
				action_grid_x = target_player.strategy_attack_guard
				action_grid_y = target_player.strategy_approach_keep_away
			etc_action_grid_mode = 0  # GMS2: CHANGE_ACTION
			etc_action_level = 0
			_etc_ag_blink_timer = 0.0
			_etc_ag_alpha_char = 0.0
			_etc_ag_alpha_cursor = 0.0
			_etc_transition_alpha = 0.0
			_etc_bg_scroll = 0.0
			mode = MenuMode.ACTION_GRID
			MusicManager.play_sfx("snd_menuSelect")
		"controllerEdit":
			etc_ctrl_selected = -1  # No slot selected initially
			etc_ctrl_assignments = [0, 1, 2, 3]  # Default: Y→menu, X→misc, B→attack, A→dash
			_etc_ctrl_save_assignments = [0, 1, 2, 3]
			_etc_ctrl_old_cursor = -1
			_etc_ctrl_current_cursor = -1
			_etc_ctrl_held_action = ""
			_etc_ctrl_enable_input = false  # GMS2: wait for all keys released before accepting input
			_etc_transition_alpha = 0.0
			_etc_bg_scroll = 0.0
			mode = MenuMode.CONTROLLER_EDIT
			MusicManager.play_sfx("snd_menuSelect")
		"windowEdit":
			_etc_transition_alpha = 0.0
			_etc_bg_scroll = 0.0
			mode = MenuMode.WINDOW_EDIT
			window_color_channel = 0
			window_color = Color(GameManager.dialog_color_rgb.r, GameManager.dialog_color_rgb.g, GameManager.dialog_color_rgb.b)
			MusicManager.play_sfx("snd_menuSelect")
		_:
			MusicManager.play_sfx("snd_menuError")

func _confirm_magic(item: Dictionary) -> void:
	# GMS2: ringMenu_playerCanCast check before entering magic subsection
	if not _player_can_cast():
		MusicManager.play_sfx("snd_menuError")
		return
	var sub_section: String = item.get("subSection", "")
	if sub_section == "SKILLS":
		# Enter skills subsection for this deity
		_save_current_item_name()
		magic_deity_name = item.get("name", "")
		item_menu_showed_index = Section.SKILLS
		direction_changing = 1
		_populate_items()
		_recalculate_offsets()
	else:
		MusicManager.play_sfx("snd_menuError")

func _confirm_skill(item: Dictionary, _selected: int) -> void:
	if not target_player or not target_player is Creature:
		return
	var spell_data: Dictionary = item.get("data", {})
	var skill_name: String = spell_data.get("name", "")
	if skill_name.is_empty():
		return

	# GMS2: ringMenu_playerCanCast — checks states + statuses (more comprehensive than is_magic_blocked)
	if not _player_can_cast():
		MusicManager.play_sfx("snd_menuError")
		return

	# Check MP
	var mp_cost: int = spell_data.get("mp", 0)
	if (target_player as Creature).attribute.mp < mp_cost:
		MusicManager.play_sfx("snd_menuError")
		return

	# Determine deity level for the caster
	var deity_level: int = 0
	if target_player is Actor:
		var deity_name: String = spell_data.get("deity", "")
		var element_idx: int = _get_element_index(deity_name)
		if element_idx >= 0:
			deity_level = (target_player as Actor).deity_levels[element_idx]

	var target_type: String = spell_data.get("target", "ALLY")
	var target_qty: String = spell_data.get("targetQuantity", "TARGET_QUANTITY_ONE")

	# GMS2: ALL spells enter MODE_SELECT with hand cursor (ringMenu_processSelectedConditions)
	# canChangeTarget and selectedTarget vary by targetQuantity
	var targets: Array = _get_valid_targets_for_spell(target_type, target_qty)
	if targets.is_empty():
		MusicManager.play_sfx("snd_menuError")
		return

	# Enter target selection mode
	_select_is_item = false  # This is a skill, not an item
	select_skill_data = spell_data
	select_deity_level = deity_level
	valid_targets = targets
	arrow_bob_timer = 0.0
	_select_can_change_target = true  # Default: can cycle targets
	_select_target_all = false  # Default: target one

	match target_qty:
		"TARGET_QUANTITY_ONE":
			selected_target_idx = _get_initial_target_idx(targets, target_type)
			_select_can_change_target = true
			_select_target_all = false
		"TARGET_QUANTITY_ALL":
			selected_target_idx = _get_initial_target_idx(targets, target_type)
			_select_can_change_target = true
			_select_target_all = true
		"TARGET_QUANTITY_ONLY_ALL":
			selected_target_idx = -1  # GMS2: selectedTarget = -1 = all targets
			_select_can_change_target = false
			_select_target_all = true
		"TARGET_QUANTITY_SELF":
			# Auto-target self (caster)
			selected_target_idx = _find_target_in_list(targets, target_player as Creature)
			_select_can_change_target = false
			_select_target_all = false
		"TARGET_QUANTITY_DEAD":
			selected_target_idx = 0
			_select_can_change_target = true
			_select_target_all = false
		_:
			selected_target_idx = 0

	mode = MenuMode.SELECT
	MusicManager.play_sfx("snd_menuSelect")


func _get_valid_targets_for_spell(target_type: String, target_qty: String) -> Array:
	## GMS2: ringMenu_processSelectedConditions - build target list based on target type and quantity
	var targets: Array = []
	match target_type:
		"ENEMY":
			# GMS2: scr_collision_rectangle_list with camera bounds, filter assets
			for m in target_player.get_tree().get_nodes_in_group("mobs"):
				if is_instance_valid(m) and m is Creature and not (m as Creature).is_dead:
					targets.append(m)
			for b in target_player.get_tree().get_nodes_in_group("bosses"):
				if is_instance_valid(b) and b is Creature and not (b as Creature).is_dead:
					targets.append(b)
		"ALLY":
			if target_qty == "TARGET_QUANTITY_DEAD":
				# Only dead allies (for revive)
				for p in GameManager.players:
					if is_instance_valid(p) and p is Creature and (p as Creature).is_dead:
						targets.append(p)
			elif target_qty == "TARGET_QUANTITY_SELF":
				# Self only
				if target_player:
					targets.append(target_player)
			else:
				targets = GameManager.get_alive_players()
	# Sort by x position for consistent left/right cycling
	targets.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
	return targets

func _get_initial_target_idx(targets: Array, target_type: String) -> int:
	## GMS2: for ENEMY, selectedTarget=0; for ALLY, selectedTarget=target.identifier
	if target_type == "ALLY" and target_player:
		var idx: int = _find_target_in_list(targets, target_player as Creature)
		if idx >= 0:
			return idx
	return 0

func _find_target_in_list(targets: Array, creature: Creature) -> int:
	for i in range(targets.size()):
		if targets[i] == creature:
			return i
	return 0


func _cast_skill_via_summon(spell_data: Dictionary, _deity_level: int, target: Creature, target_all: bool = false) -> void:
	if not target_player is Actor:
		return
	var actor: Actor = target_player as Actor
	actor.summon_magic = spell_data.get("name", "")
	var deity_name: String = spell_data.get("deity", "")
	actor.summon_magic_deity = _get_element_index(deity_name)
	actor.summon_target = target
	actor.summon_target_all = target_all  # GMS2: selectedTarget == -1 → all
	if actor.state_machine_node and actor.state_machine_node.has_state("Summon"):
		actor.state_machine_node.switch_state("Summon")
	close()

# =====================================================================
# ITEM USAGE / WEAPON EQUIPPING
# =====================================================================

func _check_item_conditions(conditions: Array) -> bool:
	## GMS2: targetCondition validation - room/context checks before item use
	for condition in conditions:
		match str(condition):
			"callFlammie":
				# GMS2: can only use Flammie Drum in outdoor rooms
				# Check if current room allows Flammie (rooms must have a flag or be in a list)
				if not GameManager.current_room_allows_flammie:
					return false
			"useRope":
				# GMS2: can only use Magic Rope in dungeons
				if not GameManager.current_room_allows_rope:
					return false
			_:
				push_warning("Unknown item condition: " + str(condition))
				return false
	return true

func _can_use_item_on_target(is_revive: bool = false) -> bool:
	## GMS2: ringMenu_playerCanUseItem - check target state/status before item use
	if not target_player or not target_player is Creature:
		return false
	var c: Creature = target_player as Creature
	# Revive items can only be used on dead targets
	if is_revive:
		return c.is_dead
	# Block if in combat/animation states
	if c.state_machine_node:
		var state: String = c.state_machine_node.current_state_name
		if state in ["StaticAnimation", "Animation", "Dead", "Summon", "Hit", "Hit2"]:
			return false
	# Block if target has disabling statuses
	if c.has_status(Constants.Status.FAINT) or c.has_status(Constants.Status.FROZEN) \
			or c.has_status(Constants.Status.BALLOON) or c.has_status(Constants.Status.ENGULFED) \
			or c.has_status(Constants.Status.PETRIFIED):
		return false
	return true

func _player_can_cast() -> bool:
	## GMS2: ringMenu_playerCanCast(target) — checks states AND statuses
	## Blocks: STATIC_ANIMATION, ANIMATION, DEAD, SUMMON, HIT, HIT2
	## + CONFUSED, PYGMIZED, FAINT, FROZEN, BALLOON, ENGULF, PETRIFIED
	if not target_player or not target_player is Creature:
		return false
	var c: Creature = target_player as Creature
	if c.state_machine_node:
		var state: String = c.state_machine_node.current_state_name
		if state in ["StaticAnimation", "Animation", "Dead", "Summon", "Hit", "Hit2"]:
			return false
	if c.has_status(Constants.Status.CONFUSED) or c.has_status(Constants.Status.PYGMIZED) \
			or c.has_status(Constants.Status.FAINT) or c.has_status(Constants.Status.FROZEN) \
			or c.has_status(Constants.Status.BALLOON) or c.has_status(Constants.Status.ENGULFED) \
			or c.has_status(Constants.Status.PETRIFIED):
		return false
	if c.is_dead:
		return false
	return true

func _player_can_use_items() -> bool:
	## GMS2: ringMenu_playerCanUseItems(target) — same states but fewer statuses
	## Does NOT block on CONFUSED or PYGMIZED (you CAN use items while confused/pygmized)
	if not target_player or not target_player is Creature:
		return false
	var c: Creature = target_player as Creature
	if c.state_machine_node:
		var state: String = c.state_machine_node.current_state_name
		if state in ["StaticAnimation", "Animation", "Dead", "Summon", "Hit", "Hit2"]:
			return false
	if c.has_status(Constants.Status.FAINT) or c.has_status(Constants.Status.FROZEN) \
			or c.has_status(Constants.Status.BALLOON) or c.has_status(Constants.Status.ENGULFED) \
			or c.has_status(Constants.Status.PETRIFIED):
		return false
	if c.is_dead:
		return false
	return true

func _is_target_available() -> bool:
	## GMS2: isTargetAvailable(target) — for weapon section
	if not target_player or not target_player is Creature:
		return false
	var c: Creature = target_player as Creature
	if c.is_dead:
		return false
	if c.has_status(Constants.Status.FAINT) or c.has_status(Constants.Status.PETRIFIED) \
			or c.has_status(Constants.Status.BALLOON) or c.has_status(Constants.Status.ENGULFED) \
			or c.has_status(Constants.Status.FROZEN):
		return false
	return true

func _is_section_blocked() -> bool:
	## GMS2: Draw_0.gml lines 30-38 — determines if current section should show grayed-out icons
	if in_shop_mode:
		return false
	match item_menu_showed_index:
		Section.MAGIC, Section.SKILLS:
			return not _player_can_cast()
		Section.WEAPON:
			if not _is_target_available():
				return true
			# GMS2: also blocks if player is in ANIMATION state
			if target_player and target_player is Creature:
				var c: Creature = target_player as Creature
				if c.state_machine_node and c.state_machine_node.current_state_name == "Animation":
					return true
			return false
		Section.ITEM:
			return not _player_can_use_items()
	return false

func _use_item(item: Dictionary) -> void:
	## Legacy: use item on the current target_player (called for non-SELECT paths)
	if target_player is Creature:
		_use_item_on_target(item, target_player as Creature)
		_finish_item_use()

func _use_item_on_target(item: Dictionary, creature: Creature) -> void:
	## Apply an item's effect to a specific creature target
	var item_data: Dictionary = item.get("data", {})
	var effect: String = str(item_data.get("value1", ""))
	var value: int = int(item_data.get("value2", 0))
	match effect:
		"hp_add":
			# GMS2: spawns oSkill_candy with spr_skill_cureWater animation + snd_cure
			ItemHealEffect.spawn(creature, "hp_add", value)
		"mp_add":
			# GMS2: spawns oSkill_magicWalnut with spr_skill_cureWater animation (green tint)
			ItemHealEffect.spawn(creature, "mp_add", value)
		"recover":
			# GMS2: medicalHerb creates oSkill_medicalHerb which calls
			# skill_remedy_create/step/draw — same animation as the remedy spell.
			# Spawn a SkillEffect with remedy data so the full animation plays
			# (spr_skill_remedy sprite + snd_remedy sound + cureWater shader).
			# cure_ailments() is applied by the remedy handler at animation end.
			var remedy_scene: PackedScene = preload("res://scenes/effects/skill_effect.tscn")
			var remedy_effect: SkillEffect = remedy_scene.instantiate() as SkillEffect
			remedy_effect.setup(creature, creature, {"name": "remedy"}, 0)
			var world: Node = creature.get_parent()
			if world:
				world.add_child(remedy_effect)
			else:
				creature.get_tree().current_scene.add_child(remedy_effect)
		"revive":
			if creature.is_dead:
				creature.is_dead = false
				# GMS2: revive with 50% of max HP (not raw value)
				@warning_ignore("INTEGER_DIVISION")
				var revive_hp: int = maxi(1, creature.attribute.maxHP / 2)
				creature.attribute.hp = revive_hp
				creature.refresh_hp_percent()
				creature.cure_ailments()
				FloatingNumber.spawn_text(creature, creature.global_position, "Revive", Color(1.0, 1.0, 0.3))
		"addStatus":
			# Items like Midge Hammer: value2 = status ID to apply
			var status_id: int = int(item_data.get("value2", 0))
			if status_id > 0:
				creature.set_status(status_id, 300)

func _finish_item_use() -> void:
	## Remove consumed item and close menu (GMS2: ringMenu_toggle closes immediately after item use)
	var item_name: String = _select_item_data.get("name", "")
	if item_name.is_empty():
		return
	if not GameManager.has_item(item_name):
		return
	GameManager.remove_item(item_name)
	# GMS2: after using an item in MODE_SELECT, the ring menu closes immediately
	close()

func _equip_weapon(item: Dictionary) -> void:
	if not target_player or not target_player is Actor:
		return
	var equip_data: Dictionary = item.get("data", {})
	var aux_data: Dictionary = equip_data.get("auxData", {})
	# Use weaponKindName ("Sword","Axe","Spear"...) to find the Weapon enum value
	var weapon_kind: String = str(aux_data.get("weaponKindName", "")).to_lower()
	var weapon_id: int = -1
	for w in Constants.Weapon.values():
		if Constants.Weapon.keys()[w].to_lower() == weapon_kind:
			weapon_id = w
			break
	if weapon_id < 0:
		return
	var actor: Actor = target_player as Actor
	# GMS2: setPlayerEquipment always removes MANA_MAGIC on any equipment change
	if actor.has_status(Constants.Status.BUFF_MANA_MAGIC):
		actor.remove_status(Constants.Status.BUFF_MANA_MAGIC)
	# Handle weapon swap with other party members (GMS2: collision detection)
	var collision_actor: Actor = null
	for p in GameManager.players:
		if p != actor and p is Actor and (p as Actor).equipped_weapon_id == weapon_id:
			collision_actor = p as Actor
			break
	if collision_actor:
		# Get icon textures for the swap animation
		var icon_for_target: Texture2D = _get_weapon_icon(equip_data)
		var old_weapon_data: Dictionary = _find_equipment_for_weapon(actor.equipped_weapon_id)
		var icon_for_collision: Texture2D = _get_weapon_icon(old_weapon_data)
		# Give the other player our current weapon
		collision_actor.set_weapon(actor.equipped_weapon_id)
		# Spawn visual swap effect
		WeaponSwapEffect.create(actor, collision_actor, icon_for_target, icon_for_collision)
	actor.set_weapon(weapon_id)
	# Apply weapon-specific data from auxData
	actor.weapon_attack_type = _map_attack_animation_type(int(aux_data.get("attackAnimationType", 0)))
	# Store equipment stat bonuses in attribute.gear
	_apply_equipment_stats(actor, equip_data)

func _map_attack_animation_type(gms2_type: int) -> int:
	## Map GMS2 attackAnimationType to Constants.WeaponAttackType
	## GMS2: 0=SLASH, 1=PIERCE, 2=SWING, 3=BOW, 4=THROW
	match gms2_type:
		0: return Constants.WeaponAttackType.SLASH
		1: return Constants.WeaponAttackType.PIERCE
		2: return Constants.WeaponAttackType.SWING
		3: return Constants.WeaponAttackType.BOW
		4: return Constants.WeaponAttackType.THROW
	return Constants.WeaponAttackType.SLASH

func _apply_equipment_stats(actor: Actor, _equip_data: Dictionary) -> void:
	## Rebuild all gear stats from all equipped gear
	actor.recalculate_gear()

func _get_weapon_icon(equip_data: Dictionary) -> Texture2D:
	## Get the icon texture for an equipment entry
	var subimage: int = int(equip_data.get("subimage", 0))
	if subimage >= 0 and subimage < icons_general.size():
		return icons_general[subimage]
	return null

func _find_equipment_for_weapon(weapon_id: int) -> Dictionary:
	## Find equipment data for a given weapon enum ID
	var weapon_name: String = Constants.Weapon.keys()[weapon_id].to_lower() if weapon_id >= 0 and weapon_id < Constants.Weapon.size() else ""
	for eq in Database.equipments:
		if eq is Dictionary and eq.get("kind", -1) == 0:
			var aux: Dictionary = eq.get("auxData", {})
			if str(aux.get("weaponKindName", "")).to_lower() == weapon_name:
				return eq
	return {}

# =====================================================================
# GEAR EQUIPPING (GMS2: armor sub-menu in ring menu)
# =====================================================================

func _enter_gear_mode() -> void:
	## Enter armor equip mode from ETC section
	_save_current_item_name()
	in_gear_mode = true
	# Find first gear type that has items
	var found: bool = false
	for gs in gear_sections:
		item_menu_showed_index = gs
		_populate_items()
		if active_items.size() > 0:
			found = true
			break
	if not found:
		# No gear in inventory - show empty HEAD section
		item_menu_showed_index = Section.GEAR_HEAD
		_populate_items()
	direction_changing = 1
	_recalculate_offsets()
	MusicManager.play_sfx("snd_menuSelect")

func _confirm_gear(item: Dictionary, selected: int) -> void:
	## Confirm equip/unequip a piece of gear
	if not confirm_animation:
		confirm_animation = true
		slot_selected_to_confirm = selected
		return
	elif selected != slot_selected_to_confirm:
		slot_selected_to_confirm = selected
		return

	confirm_animation = false
	slot_selected_to_confirm = -1

	if not target_player or not target_player is Actor:
		return

	var equip_data: Dictionary = item.get("data", {})
	var can_wear: bool = item.get("can_wear", false)
	if not can_wear:
		MusicManager.play_sfx("snd_menuError")
		return

	var equip_id: int = equip_data.get("id", -1)
	var gear_kind: int = equip_data.get("kind", -1)
	var actor: Actor = target_player as Actor
	var is_equipped: bool = item.get("equipped", false)

	# GMS2: trash bin / "None" item (id=-1) — unequip current gear
	if equip_id == -1:
		var current_id: int = _get_equipped_gear_id(actor, gear_kind)
		if current_id != -1:
			_remove_gear(actor, gear_kind)
			MusicManager.play_sfx("snd_menuSelect")
		else:
			MusicManager.play_sfx("snd_menuError")
		_populate_items()
		_recalculate_offsets()
		return

	if is_equipped:
		# Unequip - set to none
		_remove_gear(actor, gear_kind)
		MusicManager.play_sfx("snd_menuSelect")
	else:
		# Equip this gear - check if another party member has it
		var collision_actor: Actor = null
		for p in GameManager.players:
			if p != actor and p is Actor:
				var other: Actor = p as Actor
				var other_equipped: int = _get_equipped_gear_id(other, gear_kind)
				if other_equipped == equip_id:
					collision_actor = other
					break

		if collision_actor:
			# Swap: give other player our current gear
			var our_current: int = _get_equipped_gear_id(actor, gear_kind)
			_set_gear(collision_actor, gear_kind, our_current)
			_apply_gear_stats(collision_actor, gear_kind)

		_set_gear(actor, gear_kind, equip_id)
		_apply_gear_stats(actor, gear_kind)
		MusicManager.play_sfx("snd_menuSelect")

	# Refresh display
	_populate_items()
	_recalculate_offsets()

func _set_gear(actor: Actor, gear_kind: int, equip_id: int) -> void:
	# GMS2: setPlayerEquipment always removes MANA_MAGIC on any equipment change
	if actor.has_status(Constants.Status.BUFF_MANA_MAGIC):
		actor.remove_status(Constants.Status.BUFF_MANA_MAGIC)
	match gear_kind:
		Constants.EquipmentType.HEAD:
			actor.equipped_head = equip_id
		Constants.EquipmentType.ACCESSORIES:
			actor.equipped_accessory = equip_id
		Constants.EquipmentType.BODY:
			actor.equipped_body = equip_id

func _remove_gear(actor: Actor, gear_kind: int) -> void:
	_set_gear(actor, gear_kind, -1)
	_apply_gear_stats(actor, gear_kind)

func _get_equipped_gear_id(actor: Actor, gear_kind: int) -> int:
	match gear_kind:
		Constants.EquipmentType.HEAD:
			return actor.equipped_head
		Constants.EquipmentType.ACCESSORIES:
			return actor.equipped_accessory
		Constants.EquipmentType.BODY:
			return actor.equipped_body
	return -1

func _apply_gear_stats(actor: Actor, _gear_kind: int) -> void:
	## Rebuild all gear stats - delegates to actor.recalculate_gear()
	actor.recalculate_gear()

func _can_wear_equipment(equip_data: Dictionary) -> bool:
	## Check if target_player's class can wear this equipment (GMS2: playerCanWearEquipment)
	if not target_player or not target_player is Actor:
		return false
	var classes: Array = equip_data.get("class", [])
	if classes.is_empty():
		return true
	var actor_class: int = (target_player as Actor).character_id + 1  # character_id 0-2 → class 1-3
	# JSON.parse() returns floats for all numbers in Godot 4, so we must cast
	# to int before comparing, otherwise `in` operator fails (int vs float).
	for c in classes:
		if int(c) == -1 or int(c) == actor_class:
			return true
	return false

func _get_gear_stat_comparison(equip_data: Dictionary, gear_kind: int) -> String:
	## GMS2: ringMenu_setCurrentEquipedAttributeValue - shows STR for weapons, CON for armor
	if not target_player or not target_player is Actor:
		return ""
	var actor: Actor = target_player as Actor
	# GMS2: playerCanWearEquipment check - show "..." if player can't wear this
	if not _can_wear_equipment(equip_data):
		return "..."
	# GMS2: weapons show STRENGTH, armor shows CONSTITUTION
	var attr_id: int = Constants.Attribute.STRENGTH if gear_kind == Constants.EquipmentType.WEAPON else Constants.Attribute.CONSTITUTION
	var attr_label: String = "STR" if gear_kind == Constants.EquipmentType.WEAPON else "CON"
	var current_equip_id: int = _get_equipped_gear_id(actor, gear_kind)
	var current_val: int = 0
	if current_equip_id >= 0:
		var current_eq: Dictionary = Database.get_equipment(current_equip_id)
		for attr in current_eq.get("attributes", []):
			if attr is Dictionary and int(attr.get("id", -1)) == attr_id:
				current_val = int(attr.get("value", 0))
	var new_val: int = 0
	for attr in equip_data.get("attributes", []):
		if attr is Dictionary and int(attr.get("id", -1)) == attr_id:
			new_val = int(attr.get("value", 0))
	if current_val == 0 and new_val == 0:
		return ""
	return "%s: %d > %d" % [attr_label, current_val, new_val]

func _find_equipment_by_name(equip_name: String) -> Dictionary:
	for eq in Database.equipments:
		if eq is Dictionary and eq.get("name", "") == equip_name:
			return eq
	return {}

# =====================================================================
# SHOP SYSTEM (GMS2: ringMenu shopMode buy/sell)
# =====================================================================

func open_shop(seller_id: String, buying: bool = true, player: Node = null) -> void:
	## Open the ring menu in shop mode (called by NPCs)
	if player:
		target_player = player as Actor
	elif GameManager.players.size() > 0:
		target_player = GameManager.get_party_leader() as Actor

	is_open = true
	visible = true
	GameManager.ring_menu_opened = true
	GameManager.lock_global_input = true
	mode = MenuMode.RING_MENU

	for s in [Section.ITEM, Section.WEAPON, Section.ETC, Section.MAGIC, Section.SKILLS,
			Section.GEAR_HEAD, Section.GEAR_ACCESSORIES, Section.GEAR_BODY, Section.SHOP]:
		if not current_element_selected.has(s):
			current_element_selected[s] = 0

	in_shop_mode = true
	shop_is_buying = buying
	shop_seller_id = seller_id
	shop_data = _find_shop_by_seller(seller_id)

	item_menu_showed_index = Section.SHOP
	confirm_animation = false
	slot_selected_to_confirm = -1
	direction_changing = 1
	_populate_items()
	_recalculate_offsets()
	MusicManager.play_sfx("snd_menuExpand")

func _find_shop_by_seller(seller_id: String) -> Dictionary:
	for s in Database.shops:
		if s is Dictionary and s.get("sellerId", "") == seller_id:
			return s
	return {}

func _double_shop_item_price(item_name: String) -> void:
	## GMS2: Capitalist Tomato doubles in price after each purchase.
	## Modifies the shop_data in-place (persists for this game session).
	var shop_items: Array = shop_data.get("items", [])
	for shop_entry in shop_items:
		if shop_entry is Dictionary and shop_entry.get("itemId", -1) >= 0:
			var item_data: Dictionary = Database.get_item(int(shop_entry.get("itemId", -1)))
			if item_data.get("name", "") == item_name:
				shop_entry["price"] = int(shop_entry.get("price", 0)) * 2

func _decrement_shop_stock(item_name: String, shop_type: String) -> void:
	## GMS2: reduce stock count when buying an item (stock -1 = unlimited)
	var list_key: String = "items" if shop_type == "item" else "equipment"
	var shop_list: Array = shop_data.get(list_key, [])
	for shop_entry in shop_list:
		if not shop_entry is Dictionary:
			continue
		var entry_id: int = int(shop_entry.get("itemId", -1))
		var entry_stock: int = int(shop_entry.get("stock", -1))
		if entry_stock < 0:
			continue  # Unlimited stock
		# Match by name
		var entry_data: Dictionary = {}
		if shop_type == "item":
			entry_data = Database.get_item(entry_id)
		else:
			entry_data = Database.get_equipment(entry_id)
		if entry_data.get("name", "") == item_name:
			shop_entry["stock"] = entry_stock - 1
			break

func _confirm_shop(item: Dictionary, selected: int) -> void:
	if not confirm_animation:
		confirm_animation = true
		slot_selected_to_confirm = selected
		return
	elif selected != slot_selected_to_confirm:
		slot_selected_to_confirm = selected
		return

	confirm_animation = false
	slot_selected_to_confirm = -1

	if shop_is_buying:
		_buy_item(item)
	else:
		_sell_item(item)

func _buy_item(item: Dictionary) -> void:
	var price: int = item.get("price", 0)
	var shop_type: String = item.get("shop_type", "item")
	var item_name: String = item.get("name", "")

	# Validate purchase
	if shop_type == "item":
		var qty: int = item.get("quantity", 0)
		var max_qty: int = item.get("max_quantity", 99)
		if max_qty > 0 and qty >= max_qty:
			MusicManager.play_sfx("snd_menuError")
			_shop_feedback = "Sorry, you can't carry more of that!"
			_shop_feedback_timer = _SHOP_FEEDBACK_DURATION
			return
	elif shop_type == "equipment":
		# Check bag space for this gear kind
		var equip_data: Dictionary = item.get("data", {})
		var gear_kind: int = equip_data.get("kind", -1)
		if gear_kind >= 0:
			var count: int = 0
			for en in GameManager.inventory_equipment:
				var ed: Dictionary = _find_equipment_by_name(en)
				if ed.get("kind", -1) == gear_kind:
					count += 1
			if count >= MAX_EQUIPMENT_PER_KIND:
				MusicManager.play_sfx("snd_menuError")
				_shop_feedback = "Sorry, you don't have space for more items!"
				_shop_feedback_timer = _SHOP_FEEDBACK_DURATION
				return

	# Check money
	if GameManager.party_money < price:
		MusicManager.play_sfx("snd_menuError")
		_shop_feedback = "Sorry, you don't have money to buy this!"
		_shop_feedback_timer = _SHOP_FEEDBACK_DURATION
		return

	# Purchase!
	GameManager.remove_money(price)
	if shop_type == "item":
		GameManager.add_item(item_name)
	else:
		GameManager.add_equipment(item_name)

	MusicManager.play_sfx("snd_payment")
	_shop_feedback = "Thank you!"
	_shop_feedback_timer = _SHOP_FEEDBACK_DURATION

	# GMS2: Capitalist Tomato price doubles after each purchase
	if item_name == "capitalistTomato":
		_double_shop_item_price(item_name)

	# GMS2: decrement stock if not unlimited (-1 = unlimited)
	_decrement_shop_stock(item_name, shop_type)

	# Refresh display
	_populate_items()
	_recalculate_offsets()

func _sell_item(item: Dictionary) -> void:
	var price: int = item.get("price", 0)
	var shop_type: String = item.get("shop_type", "item")
	var item_name: String = item.get("name", "")

	if shop_type == "item":
		if not GameManager.has_item(item_name):
			MusicManager.play_sfx("snd_menuError")
			_shop_feedback = "Sorry, I don't want this item!"
			_shop_feedback_timer = _SHOP_FEEDBACK_DURATION
			return
		GameManager.remove_item(item_name)
	elif shop_type == "equipment":
		# Can't sell equipment currently worn by a player
		var equip_data: Dictionary = item.get("data", {})
		var equip_id: int = equip_data.get("id", -1)
		var gear_kind: int = equip_data.get("kind", -1)
		for p in GameManager.players:
			if p is Actor:
				var a: Actor = p as Actor
				if gear_kind == 0:
					# Weapon - check by kind name
					var aux: Dictionary = equip_data.get("auxData", {})
					if a.get_weapon_name() == str(aux.get("weaponKindName", "")).to_lower():
						MusicManager.play_sfx("snd_menuError")
						_shop_feedback = "Sorry, I can't let you go naked!"
						_shop_feedback_timer = _SHOP_FEEDBACK_DURATION
						return
				elif _get_equipped_gear_id(a, gear_kind) == equip_id:
					MusicManager.play_sfx("snd_menuError")
					_shop_feedback = "Sorry, I can't let you go naked!"
					_shop_feedback_timer = _SHOP_FEEDBACK_DURATION
					return
		if not GameManager.remove_equipment(item_name):
			MusicManager.play_sfx("snd_menuError")
			_shop_feedback = "Sorry, I don't want this item!"
			_shop_feedback_timer = _SHOP_FEEDBACK_DURATION
			return

	GameManager.add_money(price)
	MusicManager.play_sfx("snd_payment")
	_shop_feedback = "Thank you!"
	_shop_feedback_timer = _SHOP_FEEDBACK_DURATION

	# Refresh display - may need to scroll
	_populate_items()
	if active_items.size() == 0:
		# No more items to sell
		close()
		return
	var sel: int = _get_current_selected()
	if sel >= active_items.size():
		current_element_selected[item_menu_showed_index] = maxi(0, active_items.size() - 1)
	_recalculate_offsets()

func _switch_target_player() -> void:
	## GMS2: ringMenu_getNextPlayerInRotation — cycles through alive players
	## excluding both the current target AND the player who called the ring menu.
	var total: int = GameManager.players.size()
	if total <= 1:
		return

	var current_idx: int = -1
	for i in range(total):
		if GameManager.players[i] == target_player:
			current_idx = i
			break
	if current_idx == -1:
		return

	# Find next player excluding current target and caller
	var new_target: Actor = null
	var next_idx: int = (current_idx + 1) % total
	for _i in range(total):
		var candidate: Actor = GameManager.players[next_idx] as Actor
		if candidate and candidate != target_player and candidate != player_who_called:
			if not (candidate is Creature and (candidate as Creature).is_dead):
				new_target = candidate
				break
		next_idx = (next_idx + 1) % total

	if not new_target or new_target == target_player:
		return

	# Save current target's state, load new target's state (GMS2: per-character persistence)
	_save_char_state(target_player)
	target_player = new_target
	_load_char_state(target_player)

	confirm_animation = false
	slot_selected_to_confirm = -1
	# Rebuild sections for new target (magic availability may differ)
	_rebuild_sections_order()
	_resolve_saved_section()
	_populate_items()
	_restore_selection_by_name()
	direction_changing = 1
	_recalculate_offsets()
	MusicManager.play_sfx("snd_menuExpand")

func _confirm_target_selection() -> void:
	if valid_targets.is_empty():
		mode = MenuMode.RING_MENU
		return

	# GMS2: summonTarget = (selectedTarget == -1) ? selectedTargetList : selectedTargetList[selectedTarget]
	# When -1, passes the entire list (target all). When >= 0, passes single creature.
	if selected_target_idx == -1:
		# Target all — pass first valid target (summon_effect handles all via target list)
		var first_target: Creature = valid_targets[0] as Creature
		if not is_instance_valid(first_target):
			mode = MenuMode.RING_MENU
			return
		MusicManager.play_sfx("snd_menuSelect")
		if _select_is_item:
			# Use item on all valid targets
			for t: Variant in valid_targets:
				if is_instance_valid(t) and t is Creature:
					_use_item_on_target(_select_item_data, t as Creature)
			_finish_item_use()
		else:
			_cast_skill_via_summon(select_skill_data, select_deity_level, first_target, true)
	else:
		# Target one specific creature
		if selected_target_idx < 0 or selected_target_idx >= valid_targets.size():
			mode = MenuMode.RING_MENU
			return
		var selected_creature: Creature = valid_targets[selected_target_idx] as Creature
		if not is_instance_valid(selected_creature):
			mode = MenuMode.RING_MENU
			return
		# GMS2: check if dead target is already being revived
		var target_qty: String = select_skill_data.get("targetQuantity", "")
		if target_qty == "TARGET_QUANTITY_DEAD" and selected_creature.has_meta("reviving") and selected_creature.get_meta("reviving"):
			MusicManager.play_sfx("snd_menuError")
			return
		MusicManager.play_sfx("snd_menuSelect")
		if _select_is_item:
			_use_item_on_target(_select_item_data, selected_creature)
			_finish_item_use()
		else:
			_cast_skill_via_summon(select_skill_data, select_deity_level, selected_creature)

func _get_element_index(deity_name: String) -> int:
	match deity_name:
		"Undine": return Constants.Element.UNDINE
		"Gnome": return Constants.Element.GNOME
		"Sylphid": return Constants.Element.SYLPHID
		"Salamando": return Constants.Element.SALAMANDO
		"Shade": return Constants.Element.SHADE
		"Luna": return Constants.Element.LUNA
		"Lumina": return Constants.Element.LUMINA
		"Dryad": return Constants.Element.DRYAD
	return -1

# =====================================================================
# DRAWING
# =====================================================================

func _get_target_screen_pos() -> Vector2:
	if not is_instance_valid(target_player):
		return get_viewport_rect().size / 2.0
	# Convert world position to screen position
	var viewport: Viewport = get_viewport()
	if viewport:
		return viewport.get_canvas_transform() * target_player.global_position
	return get_viewport_rect().size / 2.0

func _get_icon_texture(item_index: int) -> Texture2D:
	if item_index < 0 or item_index >= active_items.size():
		return null
	var item: Dictionary = active_items[item_index]
	var icon_idx: int = item.get("icon_index", 0)
	var icon_total: int = item.get("icon_total", 1)
	var sprite_type: String = item.get("icon_sprite", "general")
	var anim_idx: int = icon_idx + (image_index_icons % maxi(1, icon_total))
	var icons_array: Array[Texture2D] = icons_skills if sprite_type == "skills" else icons_general
	if anim_idx >= 0 and anim_idx < icons_array.size():
		return icons_array[anim_idx]
	return null

func _draw() -> void:
	if not is_open:
		# Clear shader canvas items when menu is closed
		if _icon_ci.is_valid():
			RenderingServer.canvas_item_clear(_icon_ci)
		if _face_ci.is_valid():
			RenderingServer.canvas_item_clear(_face_ci)
		return

	var screen_pos: Vector2 = _get_target_screen_pos()
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font

	# Clear shader canvas items — _draw_ring will repopulate them if in RING_MENU mode
	if _icon_ci.is_valid():
		RenderingServer.canvas_item_clear(_icon_ci)
	if _face_ci.is_valid():
		RenderingServer.canvas_item_clear(_face_ci)

	# Semi-transparent black overlay (GMS2 Draw_0: draw_rectangle_color alpha 0.5)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, 0.5))

	match mode:
		MenuMode.RING_MENU:
			_draw_ring(screen_pos, font)
			_draw_dialog(font)
			if in_shop_mode:
				_draw_money_dialog(font)
		MenuMode.SELECT:
			_draw_select(screen_pos, font)
			_draw_dialog(font)
			if in_shop_mode:
				_draw_money_dialog(font)
		MenuMode.STATUS_SCREEN:
			_draw_etc_status(font)
		MenuMode.WEAPON_LEVELS:
			_draw_etc_weapon_levels(font)
		MenuMode.ACTION_GRID:
			_draw_etc_action_grid(font)
		MenuMode.CONTROLLER_EDIT:
			_draw_etc_controller_edit(font)
		MenuMode.WINDOW_EDIT:
			_draw_etc_window_edit(font)

func _draw_ring(screen_pos: Vector2, _font: Font) -> void:
	if option_number == 0:
		return

	# GMS2: Draw_0.gml lines 30-38 — set shader before drawing icons
	var section_blocked: bool = _is_section_blocked()

	# Update shader uniforms (GMS2: ani_ringMenuSummons → shc_brightBorder)
	if _icon_shader_mat:
		_icon_shader_mat.set_shader_parameter("u_fTime", _shader_timer2)
		_icon_shader_mat.set_shader_parameter("negative", section_blocked)

	# Draw icons in circular ring around character
	for i in range(option_number):
		var angle_deg: float = float(i) * direction_original - direction_offset
		var angle_rad: float = deg_to_rad(angle_deg)

		# GMS2 polar positioning:
		# pointX = target.x - xOffset - lengthdir_y(offsetLength, angle)
		# pointY = target.y - yOffset - lengthdir_x(offsetLength, angle)
		# lengthdir_x(len, deg) = len * cos(deg2rad(deg))
		# lengthdir_y(len, deg) = len * -sin(deg2rad(deg))
		var point_x: float = screen_pos.x - CENTER_OFFSET.x + offset_length * sin(angle_rad)
		var point_y: float = screen_pos.y - CENTER_OFFSET.y - offset_length * cos(angle_rad)

		# Confirm animation: blink the confirmed item
		var show: bool = true
		if confirm_animation and i == slot_selected_to_confirm:
			show = show_sprite_item

		if show:
			var icon_tex: Texture2D = _get_icon_texture(i)
			if icon_tex:
				# Center the 16x16 icon on the point
				# Draw to child canvas item so the shader applies
				var icon_pos := Vector2(point_x - 8.0, point_y - 8.0)
				if _icon_ci.is_valid():
					_draw_texture_on_ci(_icon_ci, icon_tex, icon_pos)
				else:
					draw_texture(icon_tex, icon_pos)

	# Draw selector sprite near character (GMS2: spr_menuSelector with characterId)
	# Drawn on self (no shader) — selector is not affected by blocking
	if not is_finishing_changing_menu and not is_changing_menu:
		var selector_idx: int = 0
		if target_player:
			selector_idx = target_player.character_id
		if selector_idx >= 0 and selector_idx < selector_frames.size() and selector_frames[selector_idx]:
			var sel_tex: Texture2D = selector_frames[selector_idx]
			# Offset by half sprite size (11px) to visually center on anchor point
			draw_texture(sel_tex,
				Vector2(screen_pos.x + SELECTOR_ANCHOR.x, screen_pos.y + SELECTOR_ANCHOR.y))

	# GMS2: ringMenu_drawEquipedFaces — draw character face icons on equipped items
	if item_menu_showed_index == Section.WEAPON or item_menu_showed_index in gear_sections:
		_draw_equipped_faces(screen_pos)

func _draw_equipped_faces(screen_pos: Vector2) -> void:
	## GMS2: ringMenu_drawEquipedFaces — draw character face indicators on equipped items
	## Shows which party members have each weapon/armor equipped (spr_menuSelector frames 3-5)
	for i in range(option_number):
		if i >= active_items.size():
			break
		var item: Dictionary = active_items[i]

		# GMS2: skip trashbin items (id == -1) — they match unequipped actors
		var item_id: int = item.get("data", {}).get("id", -1)
		if item_id == -1:
			continue

		var angle_deg: float = float(i) * direction_original - direction_offset
		var angle_rad: float = deg_to_rad(angle_deg)
		var point_x: float = screen_pos.x - CENTER_OFFSET.x + offset_length * sin(angle_rad)
		var point_y: float = screen_pos.y - CENTER_OFFSET.y - offset_length * cos(angle_rad)

		for actor in GameManager.players:
			if not is_instance_valid(actor) or not actor is Actor:
				continue
			var a: Actor = actor as Actor
			var is_equipped: bool = false
			if item_menu_showed_index == Section.WEAPON:
				# Compare weapon kind name (sword, axe, etc.)
				var aux: Dictionary = item.get("data", {}).get("auxData", {})
				var wkind: String = str(aux.get("weaponKindName", "")).to_lower()
				is_equipped = a.get_weapon_name() == wkind
			else:
				# Gear sections: compare equipment ID
				match item_menu_showed_index:
					Section.GEAR_HEAD:
						is_equipped = (a.equipped_head == item_id)
					Section.GEAR_ACCESSORIES:
						is_equipped = (a.equipped_accessory == item_id)
					Section.GEAR_BODY:
						is_equipped = (a.equipped_body == item_id)
			if is_equipped:
				var face_idx: int = a.character_id + 3  # GMS2: spr_menuSelector frames 3-5
				if face_idx >= 0 and face_idx < selector_frames.size() and selector_frames[face_idx]:
					# GMS2: draw_sprite uses origin (11,11) for 22x22 face sprite
					# Draw on _face_ci (child canvas item without shader) so faces render ON TOP of icons
					var face_pos := Vector2(point_x - 11.0, point_y - 11.0)
					if _face_ci.is_valid():
						_draw_texture_on_ci(_face_ci, selector_frames[face_idx], face_pos)
					else:
						draw_texture(selector_frames[face_idx], face_pos)

func _draw_select(_screen_pos: Vector2, _font: Font) -> void:
	# GMS2: MODE_SELECT uses spr_iconsGeneral frame 0 as the selector cursor
	# Position offsets: xSelectorOffset = 7, ySelectorOffset = 20
	if valid_targets.is_empty():
		return

	var cursor_tex: Texture2D = null
	if icons_general.size() > 0:
		cursor_tex = icons_general[0]
	if cursor_tex == null:
		return

	const X_SELECT_OFFSET: float = 7.0
	const Y_SELECT_OFFSET: float = 20.0

	if selected_target_idx == -1:
		# "All targets" mode - draw cursor on all valid targets with blink toggle
		# GMS2: showAllCursorToggle flips every draw frame
		if _show_all_cursor_toggle:
			for t: Variant in valid_targets:
				if is_instance_valid(t):
					var pos: Vector2 = get_viewport().get_canvas_transform() * (t as Node2D).global_position
					draw_texture(cursor_tex, Vector2(pos.x + X_SELECT_OFFSET, pos.y - Y_SELECT_OFFSET))
		_show_all_cursor_toggle = not _show_all_cursor_toggle
	else:
		# Single target mode
		if selected_target_idx >= 0 and selected_target_idx < valid_targets.size():
			var target_node: Node2D = valid_targets[selected_target_idx] as Node2D
			if is_instance_valid(target_node):
				var pos: Vector2 = get_viewport().get_canvas_transform() * target_node.global_position
				draw_texture(cursor_tex, Vector2(pos.x + X_SELECT_OFFSET, pos.y - Y_SELECT_OFFSET))

func _draw_dialog(font: Font) -> void:
	# Dialog box — identical rendering to BattleDialog (same size, margins, scale)
	var vp_size: Vector2 = get_viewport_rect().size
	var dialog_w: float = 277.0
	var dialog_h: float = 20.0
	var dialog_x: float = (vp_size.x - dialog_w) / 2.0
	var dialog_y: float = vp_size.y - dialog_h - 10.0
	var font_size: int = 8

	# Box rendering — exact same as BattleDialog._draw()
	if _dialog_bg_textures.size() > 0 and _dialog_border_textures.size() > 0:
		var bg_idx: int = clampi(GameManager.dialog_background_index, 0, _dialog_bg_textures.size() - 1)
		var border_idx: int = clampi(GameManager.dialog_border_index, 0, _dialog_border_textures.size() - 1)
		UIUtils.draw_sprite_tiled_area(self, _dialog_bg_textures[bg_idx], 0,
			0, 0,
			dialog_x, dialog_y,
			dialog_x + dialog_w, dialog_y + dialog_h,
			GameManager.dialog_color_rgb, 1.0, 1, 1.0 / 3.0)
		UIUtils.draw_window(self, _dialog_border_textures[border_idx],
			dialog_x - 4, dialog_y - 4,
			dialog_w + 8, dialog_h + 8,
			GameManager.GUI_SCALE, 1.0, Color.WHITE)
	else:
		draw_rect(Rect2(dialog_x, dialog_y, dialog_w, dialog_h),
			Color(0.0, 0.0, 0.31, 0.9))
		draw_rect(Rect2(dialog_x, dialog_y, dialog_w, dialog_h),
			Color(0.8, 0.7, 0.4, 1.0), false, 1.0)

	# SELECT mode: show target name instead of item info (GMS2 Draw_64.gml lines 117-135)
	if mode == MenuMode.SELECT:
		var target_name: String = ""
		if selected_target_idx == -1:
			target_name = "All"
		elif selected_target_idx >= 0 and selected_target_idx < valid_targets.size():
			var t = valid_targets[selected_target_idx]
			if is_instance_valid(t) and t is Creature:
				target_name = (t as Creature).get_creature_name()
		if target_name != "":
			var text_y: float = dialog_y + (dialog_h + float(font_size)) / 2.0
			var text_left: float = dialog_x + 8.0
			draw_string(font, Vector2(text_left, text_y),
				target_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		return

	if option_number == 0 or active_items.size() == 0:
		return

	var selected: int = _get_current_selected()
	if selected < 0 or selected >= active_items.size():
		return

	var item: Dictionary = active_items[selected]
	var display_name: String = item.get("displayName", "???")
	var description: String = item.get("description", "")
	var text_y: float = dialog_y + (dialog_h + float(font_size)) / 2.0
	var text_left: float = dialog_x + 8.0
	var text_right: float = dialog_x + dialog_w - 8.0
	# Godot 4 draw_string RIGHT alignment: text is right-aligned within [pos.x, pos.x + width]
	# So to end at text_right, position at (text_right - right_w)
	var right_w: int = int(dialog_w / 2.0 - 8.0)
	var right_x: float = text_right - float(right_w)

	# Shop mode: show prices and gold
	if in_shop_mode:
		if _shop_feedback != "" and _shop_feedback_timer > 0:
			draw_string(font, Vector2(text_left, text_y),
				_shop_feedback,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.84, 0))
			draw_string(font, Vector2(right_x, text_y),
				"%dGP" % GameManager.party_money,
				HORIZONTAL_ALIGNMENT_RIGHT, right_w, font_size, Color(1, 0.84, 0))
		else:
			var price: int = item.get("price", 0)
			draw_string(font, Vector2(text_left, text_y),
				"%s  %dGP" % [display_name, price],
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			draw_string(font, Vector2(right_x, text_y),
				"%dGP" % GameManager.party_money,
				HORIZONTAL_ALIGNMENT_RIGHT, right_w, font_size, Color(1, 0.84, 0))
		return

	# Gear equip mode
	if in_gear_mode:
		var equipped_marker: String = " [E]" if item.get("equipped", false) else ""
		var can_wear: bool = item.get("can_wear", true)
		var name_color: Color = Color.WHITE if can_wear else Color(0.5, 0.5, 0.5)
		draw_string(font, Vector2(text_left, text_y),
			display_name + equipped_marker,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, name_color)
		if description != "":
			draw_string(font, Vector2(right_x, text_y),
				description,
				HORIZONTAL_ALIGNMENT_RIGHT, right_w, font_size, Color(0.8, 1.0, 0.8))
		return

	# Normal sections: name (+ quantity/MP) on left, description on right
	var left_text: String = display_name
	match item_menu_showed_index:
		Section.ITEM:
			var qty: int = item.get("quantity", 0)
			left_text = "%s X%d" % [display_name, qty]
		Section.SKILLS:
			var mp: int = item.get("mp", 0)
			left_text = "%s  MP%2d" % [display_name, mp]

	draw_string(font, Vector2(text_left, text_y),
		left_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	if description != "":
		draw_string(font, Vector2(right_x, text_y),
			description,
			HORIZONTAL_ALIGNMENT_RIGHT, right_w, font_size, Color.WHITE)

# =====================================================================
# ETC SCREEN INPUT
# =====================================================================

func _step_etc_screen() -> void:
	# Controller Edit has its own exit logic — all 4 action buttons are used for slot selection
	if mode == MenuMode.CONTROLLER_EDIT:
		_step_controller_edit()
		return
	# Action Grid handles its own exit (only from CHANGE_ACTION mode, not CHANGE_LEVEL)
	if mode == MenuMode.ACTION_GRID:
		_step_action_grid()
		return
	# Window Edit uses menu/run as color buttons — needs own exit (B button = misc)
	if mode == MenuMode.WINDOW_EDIT:
		_step_window_edit()
		return

	# Back button always returns to ring menu (for other ETC screens)
	if _input_just_pressed("run") or _input_just_pressed("menu"):
		mode = MenuMode.RING_MENU
		MusicManager.play_sfx("snd_menuColapse")
		return

	match mode:
		MenuMode.STATUS_SCREEN:
			_step_status_screen()
		MenuMode.WEAPON_LEVELS:
			_step_weapon_levels()

func _step_status_screen() -> void:
	# GMS2 oMenu: alpha fade-in over 15 frames, bg scroll at -0.2
	if _etc_transition_alpha < 1.0:
		_etc_transition_alpha = minf(_etc_transition_alpha + (60.0 / 15.0) * _current_delta, 1.0)
	_etc_bg_scroll -= 0.2 * 60.0 * _current_delta

	if _input_just_pressed("move_left"):
		etc_player_idx = (etc_player_idx - 1 + maxi(1, GameManager.total_players)) % maxi(1, GameManager.total_players)
		MusicManager.play_sfx("snd_menuRotate")
	elif _input_just_pressed("move_right"):
		etc_player_idx = (etc_player_idx + 1) % maxi(1, GameManager.total_players)
		MusicManager.play_sfx("snd_menuRotate")

func _step_weapon_levels() -> void:
	## GMS2: oMenuWeapons Step_0.gml — faithful port with enableElementInfo two-stage interaction
	# GMS2 oMenu: alpha fade-in over 15 frames, bg scroll at -0.2
	if _etc_transition_alpha < 1.0:
		_etc_transition_alpha = minf(_etc_transition_alpha + (60.0 / 15.0) * _current_delta, 1.0)
	_etc_bg_scroll -= 0.2 * 60.0 * _current_delta

	# GMS2: control_swapActorPressed toggles weapon/magic mode (with blend screen)
	if _input_just_pressed("misc"):
		var player: Node = GameManager.get_player(etc_player_idx)
		if player is Actor and (player as Actor).enable_magic != Constants.MAGIC_NONE:
			etc_weapon_magic_mode = 1 - etc_weapon_magic_mode  # Toggle 0↔1
			_etc_wl_enable_info = false
			etc_weapon_selected = 0
			_etc_wl_bottom_text = "CHECK THE WEAPON SKILL/LEVEL DATA HERE.\nPUSH \"ATTACK\" BUTTON TO START. CHOOSE A WEAPON WITH\nTHE CONTROL PAD. PUSH \"ATTACK\" TO SEE DATA."
			_etc_wl_bottom_text_right = ""
			MusicManager.play_sfx("snd_menuSelect")
		else:
			MusicManager.play_sfx("snd_menuError")

	# GMS2: Navigation only works when enableElementInfo is true
	if _etc_wl_enable_info:
		# GMS2: right/left are CLAMPED (not wrapping)
		if _input_just_pressed("move_right") and etc_weapon_selected < 4:
			etc_weapon_selected += 4
			MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("move_left") and etc_weapon_selected >= 4:
			etc_weapon_selected -= 4
			MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("move_up"):
			if etc_weapon_selected > 0 and etc_weapon_selected != 4:
				etc_weapon_selected -= 1
				MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("move_down"):
			if etc_weapon_selected < 7 and etc_weapon_selected != 3:
				etc_weapon_selected += 1
				MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("attack"):
			# GMS2: Attack shows weapon type/description or spirit magic list
			MusicManager.play_sfx("snd_menuSelect")
			_weapon_levels_show_info()

	# GMS2: enableElementInfo gate — press Attack first to start navigation
	if not _etc_wl_enable_info:
		if _input_just_pressed("attack"):
			_etc_wl_enable_info = true
			etc_weapon_selected = 0
			MusicManager.play_sfx("snd_menuSelect")
			_etc_wl_bottom_text = "CHECK THE WEAPON SKILL/LEVEL DATA HERE.\nPUSH \"ATTACK\" BUTTON TO START. CHOOSE A WEAPON WITH\nTHE CONTROL PAD. PUSH \"ATTACK\" TO SEE DATA."
			_etc_wl_bottom_text_right = ""

func _weapon_levels_show_info() -> void:
	## GMS2: oMenuWeapons Step_0 lines 55-103 — show weapon data or spirit magic list
	var player: Node = GameManager.get_player(etc_player_idx)
	if not player is Actor:
		return
	var actor := player as Actor
	var is_magic: bool = (etc_weapon_magic_mode == 1)

	if not is_magic:
		# --- WEAPON MODE: show weapon type and description ---
		# GMS2: items = filterList(game.bag.equipment, kind, GEARTYPE_WEAPON)
		# Then items[selectedElement] gives the weapon data
		var weapons: Array = []
		for eq in Database.equipments:
			if int(eq.get("kind", -1)) == 0:  # kind 0 = weapon
				weapons.append(eq)
		if etc_weapon_selected >= 0 and etc_weapon_selected < weapons.size():
			var equip_data: Dictionary = weapons[etc_weapon_selected]
			var weapon_kind: String = equip_data.get("auxData", {}).get("weaponKindName", "")
			var desc: String = equip_data.get("description", "")
			_etc_wl_bottom_text = "TYPE   " + weapon_kind + "\n" + desc
			_etc_wl_bottom_text_right = "ENERGY ORB 9/ 9"
	else:
		# --- MAGIC MODE: show all spells this spirit has for this caster ---
		# GMS2: filter skillsDB by deity, then by magicKind (summonMagicType), then enabled
		var deity_names: Array = ["Undine", "Gnome", "Sylphid", "Salamando", "Shade", "Luna", "Lumina", "Dryad"]
		if etc_weapon_selected >= 0 and etc_weapon_selected < deity_names.size():
			var deity_name: String = deity_names[etc_weapon_selected]
			var magic_kind: int = actor.enable_magic  # GMS2: summonMagicType
			var skill_text: String = ""
			_etc_wl_bottom_text_right = ""
			for skill in Database.skills:
				if skill.get("deity", "") != deity_name:
					continue
				if int(skill.get("magicKind", 0)) != magic_kind:
					continue
				if not skill.get("enabled", false):
					continue
				var sname: String = skill.get("nameText", skill.get("name", ""))
				var sdesc: String = skill.get("description", "")
				# GMS2: pad name to 16 characters with spaces
				var padded: String = sname
				while padded.length() < 16:
					padded += " "
				skill_text += padded + ": " + sdesc + "\n"
			if skill_text.is_empty():
				skill_text = "(No spells available)"
			_etc_wl_bottom_text = skill_text

func _step_action_grid() -> void:
	## GMS2: oMenuActionGrid Step_0.gml — faithful port
	# GMS2 oMenu: alpha fade-in over 15 frames, bg scroll at -0.2
	if _etc_transition_alpha < 1.0:
		_etc_transition_alpha = minf(_etc_transition_alpha + (60.0 / 15.0) * _current_delta, 1.0)
	_etc_bg_scroll -= 0.2 * 60.0 * _current_delta
	# GMS2 blink timer (incremented using delta, used in draw for toggling)
	_etc_ag_blink_timer += _current_delta

	if etc_action_grid_mode == 0:
		# --- CHANGE_ACTION: Navigate the 4×4 grid ---
		# GMS2 priority order: up, right, down, left
		if _input_just_pressed("move_up"):
			action_grid_y -= 1
			if action_grid_y < 1: action_grid_y = 4
			MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("move_right"):
			action_grid_x += 1
			if action_grid_x > 4: action_grid_x = 1
			MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("move_down"):
			action_grid_y += 1
			if action_grid_y > 4: action_grid_y = 1
			MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("move_left"):
			action_grid_x -= 1
			if action_grid_x < 1: action_grid_x = 4
			MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("attack"):
			# GMS2: Switch to CHANGE_LEVEL mode
			etc_action_grid_mode = 1
			MusicManager.play_sfx("snd_menuSelect")
		# GMS2: menu or toggleController closes from CHANGE_ACTION only
		elif _input_just_pressed("menu") or _input_just_pressed("run"):
			MusicManager.play_sfx("snd_menuDialogClose")
			mode = MenuMode.RING_MENU
	elif etc_action_grid_mode == 1:
		# --- CHANGE_LEVEL: Navigate weapon level sidebar (0-8) ---
		# GMS2: only up/down + attack work here; menu/run do nothing
		if _input_just_pressed("move_up"):
			etc_action_level -= 1
			if etc_action_level < 0: etc_action_level = 8
			MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("move_down"):
			etc_action_level += 1
			if etc_action_level > 8: etc_action_level = 0
			MusicManager.play_sfx("snd_cursor")
		elif _input_just_pressed("attack"):
			# GMS2: Save strategy patterns + level, then close
			if target_player:
				target_player.strategy_attack_guard = action_grid_x
				target_player.strategy_approach_keep_away = action_grid_y
			MusicManager.play_sfx("snd_menuDialogClose")
			mode = MenuMode.RING_MENU

func _step_controller_edit() -> void:
	## GMS2: oMenuControllerEdit Step_0.gml — hold-button + LEFT/RIGHT to cycle, release to set
	## Buttons: menu=slot0(Y), misc=slot1(X), attack=slot2(B), run=slot3(A)
	## Exit: when no button is held, UP or DOWN exits (GMS2 uses START, unavailable on keyboard)
	if _etc_transition_alpha < 1.0:
		_etc_transition_alpha = minf(_etc_transition_alpha + (60.0 / 15.0) * _current_delta, 1.0)
	_etc_bg_scroll -= 0.2 * 60.0 * _current_delta

	var action_keys: Array[String] = ["menu", "misc", "attack", "run"]

	# GMS2: enableInput — wait for all keys to be released before accepting input
	# This prevents the button that opened the menu from immediately selecting a slot
	if not _etc_ctrl_enable_input:
		var any_held: bool = false
		for ak in action_keys:
			if Input.is_action_pressed(ak):
				any_held = true
				break
		if not any_held:
			_etc_ctrl_enable_input = true
		return

	# --- Check if a DIFFERENT button was pressed while holding one (GMS2: revert) ---
	if etc_ctrl_selected != -1:
		# A button is being held — check for wrong-button press
		for i in range(4):
			if i != etc_ctrl_selected and _input_just_pressed(action_keys[i]):
				# GMS2: revert saveCursor to saveCursorOrigin
				etc_ctrl_assignments = _etc_ctrl_save_assignments.duplicate()
				etc_ctrl_selected = -1
				_etc_ctrl_held_action = ""
				MusicManager.play_sfx("snd_menuError")
				return

	# --- Detect button PRESS (start holding) ---
	if etc_ctrl_selected == -1:
		# No button held — check for new press
		for i in range(4):
			if _input_just_pressed(action_keys[i]):
				etc_ctrl_selected = i
				_etc_ctrl_held_action = action_keys[i]
				_etc_ctrl_save_assignments = etc_ctrl_assignments.duplicate()
				_etc_ctrl_old_cursor = etc_ctrl_assignments[i]
				_etc_ctrl_current_cursor = etc_ctrl_assignments[i]
				MusicManager.play_sfx("snd_cursor")
				return

		# No button pressed — check for EXIT (GMS2: START button = Enter key)
		if Input.is_key_pressed(KEY_ENTER) or Input.is_joy_button_pressed(0, JOY_BUTTON_START):
			MusicManager.play_sfx("snd_menuColapse")
			mode = MenuMode.RING_MENU
		return

	# --- A button IS being held ---
	# Check if it was released
	if not Input.is_action_pressed(_etc_ctrl_held_action):
		# GMS2: key released — save the swap (collision)
		if _etc_ctrl_current_cursor != _etc_ctrl_old_cursor:
			# Find which slot had the new action and swap (GMS2: foundCollision)
			var collision_slot: int = -1
			for j in range(4):
				if _etc_ctrl_save_assignments[j] == _etc_ctrl_current_cursor:
					collision_slot = j
					break
			if collision_slot != -1:
				# Swap: collision slot gets the old cursor's assignment
				etc_ctrl_assignments[collision_slot] = _etc_ctrl_save_assignments[etc_ctrl_selected]
			etc_ctrl_assignments[etc_ctrl_selected] = _etc_ctrl_current_cursor
			MusicManager.play_sfx("snd_menuSelect")
		else:
			MusicManager.play_sfx("snd_menuSelect")
		etc_ctrl_selected = -1
		_etc_ctrl_held_action = ""
		return

	# Still held — LEFT/RIGHT cycles the action assignment
	if _input_just_pressed("move_left"):
		_etc_ctrl_current_cursor = (_etc_ctrl_current_cursor + 1) % 4  # GMS2: selectedCursor++
		etc_ctrl_assignments[etc_ctrl_selected] = _etc_ctrl_current_cursor
		# Update text immediately (GMS2: inputGroupText[pressedButton] = actionTexts[selectedCursor])
		MusicManager.play_sfx("snd_cursor")
	elif _input_just_pressed("move_right"):
		_etc_ctrl_current_cursor = (_etc_ctrl_current_cursor - 1 + 4) % 4  # GMS2: selectedCursor--
		etc_ctrl_assignments[etc_ctrl_selected] = _etc_ctrl_current_cursor
		MusicManager.play_sfx("snd_cursor")

func _step_window_edit() -> void:
	## GMS2: oMenuWindowEdit Step_0.gml — faithful port
	## Hold A(button1)=R, Y(button2)=G, X(button4)=B + left/right to adjust color
	## When no color button held: up/down = border, left/right = background
	## B(button3) or SELECT to save and exit
	if _etc_transition_alpha < 1.0:
		_etc_transition_alpha = minf(_etc_transition_alpha + (60.0 / 15.0) * _current_delta, 1.0)
	_etc_bg_scroll -= 0.2 * 60.0 * _current_delta
	_etc_ag_blink_timer += _current_delta  # Reuse timer for gauge update rate

	# GMS2: colorButtonHeld = button1 || button2 || button4
	# In Godot: button1=attack(A), button2=menu(Y), button4=run(X)
	var color_button_held: bool = Input.is_action_pressed("attack") or \
		Input.is_action_pressed("menu") or Input.is_action_pressed("run")

	if color_button_held:
		# Determine which color channel is being modified
		var selected_color: int = -1
		if Input.is_action_pressed("attack"):
			selected_color = 0  # R (button1 = A)
		elif Input.is_action_pressed("menu"):
			selected_color = 1  # G (button2 = Y)
		elif Input.is_action_pressed("run"):
			selected_color = 2  # B (button4 = X)

		if selected_color >= 0:
			window_color_channel = selected_color
			# GMS2: timer mod 4 == 0 — adjust every 4/60 sec for smooth scrolling
			if fmod(_etc_ag_blink_timer, 4.0 / 60.0) < _current_delta:
				if Input.is_action_pressed("move_left"):
					_adjust_window_color_int(selected_color, -8)
					MusicManager.play_sfx("snd_cursor")
				elif Input.is_action_pressed("move_right"):
					_adjust_window_color_int(selected_color, 8)
					MusicManager.play_sfx("snd_cursor")
	else:
		# No color button held: up/down cycles border, left/right cycles background
		if _input_just_pressed("move_up") or _input_just_pressed("move_down"):
			MusicManager.play_sfx("snd_cursor")
			var total_borders: int = _dialog_border_textures.size()
			if total_borders > 0:
				if _input_just_pressed("move_up"):
					GameManager.dialog_border_index += 1
				else:
					GameManager.dialog_border_index -= 1
				# GMS2: borderIndex wraps 0..(borderTotalSubimage-2)
				if GameManager.dialog_border_index >= total_borders - 1:
					GameManager.dialog_border_index = 0
				elif GameManager.dialog_border_index < 0:
					GameManager.dialog_border_index = total_borders - 2

		if _input_just_pressed("move_left") or _input_just_pressed("move_right"):
			MusicManager.play_sfx("snd_cursor")
			var total_bgs: int = _dialog_bg_textures.size()
			if total_bgs > 0:
				if _input_just_pressed("move_left"):
					GameManager.dialog_background_index += 1
				else:
					GameManager.dialog_background_index -= 1
				if GameManager.dialog_background_index >= total_bgs:
					GameManager.dialog_background_index = 0
				elif GameManager.dialog_background_index < 0:
					GameManager.dialog_background_index = total_bgs - 1

	# GMS2: B button (button3=misc) or SELECT (toggleController) saves and exits
	# GMS2 Step_0 line 111: button3Pressed || control_toggleControllerPressed
	if _input_just_pressed("misc"):
		# Save config to GameManager
		GameManager.dialog_color_rgb = Color(window_color.r, window_color.g, window_color.b)
		MusicManager.play_sfx("snd_menuDialogClose")
		mode = MenuMode.RING_MENU

func _adjust_window_color_int(channel: int, delta: int) -> void:
	## GMS2: bgColor[channel] += delta (0-255 integer space), then reconvert to color
	var val: int = 0
	match channel:
		0: val = int(window_color.r * 255.0)
		1: val = int(window_color.g * 255.0)
		2: val = int(window_color.b * 255.0)
	val = clampi(val + delta, 0, 255)
	var f: float = float(val) / 255.0
	match channel:
		0: window_color.r = f
		1: window_color.g = f
		2: window_color.b = f
	# Sync to GameManager so dialog preview updates in real-time
	GameManager.dialog_color_rgb = Color(window_color.r, window_color.g, window_color.b, 1.0)

# =====================================================================
# ETC SCREEN DRAWING
# =====================================================================

func _draw_etc_panel(font: Font, title: String) -> Dictionary:
	## Helper: draws background + panel + title, returns layout positions
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.7))
	var px: float = 12.0
	var py: float = 8.0
	var pw: float = vp.x - 24.0
	var ph: float = vp.y - 16.0
	# GMS2: drawWindow(spr_windowLayout_1, ...) for ETC sub-screens
	if _window_layout_textures.size() > 0:
		UIUtils.draw_window(self, _window_layout_textures[0],
			px - 4, py - 4, pw + 8, ph + 8,
			GameManager.GUI_SCALE, 1.0, Color.WHITE)
	else:
		draw_rect(Rect2(px, py, pw, ph), Color(0.05, 0.02, 0.15, 0.95))
		draw_rect(Rect2(px, py, pw, ph), Color(0.4, 0.4, 0.8, 0.7), false, 1.0)
	draw_string(font, Vector2(px + 6, py + 10), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.84, 0))
	return {"px": px, "py": py, "pw": pw, "ph": ph, "vp": vp}

func _draw_etc_status(font: Font) -> void:
	## GMS2: oMenuStatus Draw_64.gml — 4 windows: State, Mana, Money, Status Stats
	## With tiled background, alpha fade-in, and proper font scaling
	var vp: Vector2 = get_viewport_rect().size
	var al: float = _etc_transition_alpha

	# --- Tiled background (GMS2: spr_bg_menuTile, htiled/vtiled, scroll -0.2) ---
	if _bg_menu_tile and al > 0:
		var tw: float = _bg_menu_tile.get_width()
		var th: float = _bg_menu_tile.get_height()
		if tw > 0 and th > 0:
			var ox: float = fmod(_etc_bg_scroll, tw)
			var oy: float = fmod(_etc_bg_scroll, th)
			var cy: float = oy - th
			while cy < vp.y:
				var cx: float = ox - tw
				while cx < vp.x:
					draw_texture(_bg_menu_tile, Vector2(cx, cy), Color(1, 1, 1, al))
					cx += tw
				cy += th

	if al <= 0:
		return

	var player: Node = GameManager.get_player(etc_player_idx)
	if not is_instance_valid(player) or not player is Actor:
		draw_string(font, Vector2(20, 30), "No player data",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)
		return

	var actor := player as Actor
	# GMS2: textXScale=2, textYScale=2 → 2x the normal menu font (fs=5)
	var fs: int = 10
	# GMS2: fontSeparation=28 * textYScale=2 = 56px at 1281x720 → 56/3 ≈ 19px
	var lh: float = 19.0
	# Baseline offset: Godot draw_string y = baseline, GMS2 y = text top
	var ascent: float = font.get_ascent(fs)
	var text_color := Color(1, 1, 1, al)

	# --- Window coordinates (GMS2 oMenuStatus Create_0 / 3, heights adjusted to fit) ---
	# State: GMS2 (120,30) 500x360
	var sw_x := 40.0; var sw_y := 10.0; var sw_w := 167.0; var sw_h := 120.0
	# Mana: GMS2 (120,415) 500x120 — extra height for seed icons
	var mw_x := 40.0; var mw_y := 136.0; var mw_w := 167.0; var mw_h := 48.0
	# Money: GMS2 (120,560) 500x80
	var ow_x := 40.0; var ow_y := 190.0; var ow_w := 167.0; var ow_h := 30.0
	# Status Stats: GMS2 (650,30) 500x610
	var stw_x := 217.0; var stw_y := 10.0; var stw_w := 167.0; var stw_h := 210.0

	# --- Draw 4 windows with alpha ---
	if _window_layout_textures.size() > 0:
		var wt: Texture2D = _window_layout_textures[0]
		UIUtils.draw_window(self, wt, sw_x, sw_y, sw_w, sw_h, GameManager.GUI_SCALE, al, Color.WHITE)
		UIUtils.draw_window(self, wt, mw_x, mw_y, mw_w, mw_h, GameManager.GUI_SCALE, al, Color.WHITE)
		UIUtils.draw_window(self, wt, ow_x, ow_y, ow_w, ow_h, GameManager.GUI_SCALE, al, Color.WHITE)
		UIUtils.draw_window(self, wt, stw_x, stw_y, stw_w, stw_h, GameManager.GUI_SCALE, al, Color.WHITE)

	# Right-align width for left-column windows (GMS2 right edge: stateWindow+470 → 590/3 ≈ 197, width=157)
	var ra_x: float = sw_x
	var ra_w: float = 157.0

	# ==============================================
	# STATE WINDOW — Portrait, Name, Level, HP, MP, EXP
	# ==============================================
	# Character portrait: GMS2 stateWindow + (70,160) / 3
	if actor.sprite_sheet:
		var stand_frame: int = actor.spr_stand_down
		var col: int = stand_frame % actor.sprite_columns
		@warning_ignore("INTEGER_DIVISION")
		var row: int = stand_frame / actor.sprite_columns
		var src := Rect2(col * actor.frame_width, row * actor.frame_height,
			actor.frame_width, actor.frame_height)
		var px: float = sw_x + 23.3 - actor.sprite_origin.x
		var py: float = sw_y + 53.3 - actor.sprite_origin.y
		draw_texture_rect_region(actor.sprite_sheet,
			Rect2(px, py, actor.frame_width, actor.frame_height), src,
			Color(1, 1, 1, al))

	# Labels: GMS2 stateWindow + (150,30) → offset (50,10) + ascent for baseline
	var sl_x: float = sw_x + 50.0
	var sl_y: float = sw_y + 10.0 + ascent
	draw_string(font, Vector2(sl_x, sl_y), actor.character_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	draw_string(font, Vector2(sl_x, sl_y + lh), "LEVEL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	draw_string(font, Vector2(sl_x, sl_y + lh * 2), "HP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	draw_string(font, Vector2(sl_x, sl_y + lh * 3), "MP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# Values (right-aligned): GMS2 stateWindow+470 → values on lines 1-3
	draw_string(font, Vector2(ra_x, sl_y + lh), str(actor.attribute.level),
		HORIZONTAL_ALIGNMENT_RIGHT, ra_w, fs, text_color)
	draw_string(font, Vector2(ra_x, sl_y + lh * 2),
		"%d/%d" % [actor.attribute.hp, actor.attribute.maxHP],
		HORIZONTAL_ALIGNMENT_RIGHT, ra_w, fs, text_color)
	draw_string(font, Vector2(ra_x, sl_y + lh * 3),
		"%d/%d" % [actor.attribute.mp, actor.attribute.maxMP],
		HORIZONTAL_ALIGNMENT_RIGHT, ra_w, fs, text_color)

	# EXP: GMS2 stateWindow + (30,260) → offset (10, 86.7) + ascent
	var exp_y: float = sw_y + 86.7 + ascent
	draw_string(font, Vector2(sw_x + 10.0, exp_y), "EXP.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	draw_string(font, Vector2(sw_x + 10.0, exp_y + lh), "FOR NEXT LEVEL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	draw_string(font, Vector2(ra_x, exp_y), str(actor.attribute.experience),
		HORIZONTAL_ALIGNMENT_RIGHT, ra_w, fs, text_color)
	var exp_needed: int = actor.attribute.level * Constants.EXP_MULTIPLIER
	draw_string(font, Vector2(ra_x, exp_y + lh), str(exp_needed),
		HORIZONTAL_ALIGNMENT_RIGHT, ra_w, fs, text_color)

	# ==============================================
	# MANA WINDOW — Mana Power + seed icons
	# ==============================================
	# GMS2: manaWindow + (30,24) → offset (10,8) + ascent
	var mana_y: float = mw_y + 8.0 + ascent
	draw_string(font, Vector2(mw_x + 10.0, mana_y), "MANA POWER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	draw_string(font, Vector2(mw_x, mana_y), "8",
		HORIZONTAL_ALIGNMENT_RIGHT, 157.0, fs, text_color)
	# Mana seeds: GMS2 manaWindow + (60,70) → offset (20, ~20), moved up to fit
	if _mana_seeds_tex:
		draw_texture(_mana_seeds_tex, Vector2(mw_x + 20.0, mw_y + 28.0),
			Color(1, 1, 1, al))

	# ==============================================
	# MONEY WINDOW
	# ==============================================
	# GMS2: moneyWindow + (30,30) → offset (10,10) + ascent
	var money_y: float = ow_y + 10.0 + ascent
	draw_string(font, Vector2(ow_x + 10.0, money_y), "MONEY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	draw_string(font, Vector2(ow_x, money_y), str(GameManager.party_money) + "GP",
		HORIZONTAL_ALIGNMENT_RIGHT, 157.0, fs, text_color)

	# ==============================================
	# STATUS STATS WINDOW — 10 stats with progress bars
	# ==============================================
	# GMS2 menuStatus_updateData: ATTACK=getStrength(true), DEFENSE=getConstitution(true)
	var attack_val: int = actor.get_strength()
	var defense_val: int = actor.get_constitution()
	var hit_rate: int = roundi(actor.get_critical_rate() / 2.0 + actor.get_agility() / 2.0)
	var evade_rate: int = roundi(actor.get_critical_rate() / 3.0 + actor.get_agility() / 3.0)
	var magic_def: int = actor.get_wisdom()

	var stat_labels: Array = [
		"STRENGTH", "AGILITY", "CONSTITUTION", "INTELLIGENCE", "WISDOM",
		"ATTACK", "HIT %", "DEFENSE", "EVADE %", "MAGIC DEF"]
	var stat_values: Array = [
		actor.get_strength(), actor.get_agility(), actor.get_constitution(),
		actor.get_intelligence(), actor.get_wisdom(),
		attack_val, hit_rate, defense_val, evade_rate, magic_def]
	# Bar max values (GMS2: STR/AGI/CON/INT/WIS→100, ATK→300, DEF→1000, rest→100)
	var stat_max: Array = [
		100.0, 100.0, 100.0, 100.0, 100.0,
		300.0, 100.0, 1000.0, 100.0, 100.0]

	# Bar color by class (GMS2: Warrior=red, Mage=yellow, Priest=green(0,230,0))
	var bar_color: Color
	match actor.attribute.classId:
		1: bar_color = Color.RED
		2: bar_color = Color.YELLOW
		3: bar_color = Color(0, 0.9, 0)
		_: bar_color = Color.RED

	# Labels: GMS2 statusWindow + (30,30) → offset (10,10) + ascent
	var stat_lx: float = stw_x + 10.0
	var stat_sy: float = stw_y + 10.0 + ascent
	# Values right-aligned: GMS2 statusWindow + (240,30) → width 80
	var stat_ra_x: float = stw_x
	var stat_ra_w: float = 80.0
	# Progress bars: GMS2 statusWindow + (245,51) → offset (81.7,17); width=245/3≈81.7, height=13/3≈4.3
	var bar_x: float = stw_x + 81.7
	var bar_sy: float = stw_y + 17.0
	var bar_w: float = 81.7
	var bar_h: float = 4.3

	for i in range(10):
		var sy: float = stat_sy + i * lh
		draw_string(font, Vector2(stat_lx, sy), stat_labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		draw_string(font, Vector2(stat_ra_x, sy), str(stat_values[i]),
			HORIZONTAL_ALIGNMENT_RIGHT, stat_ra_w, fs, text_color)
		# Progress bar (GMS2: draw_healthbar)
		var pct: float = clampf(float(stat_values[i]) / stat_max[i], 0.0, 1.0)
		var by: float = bar_sy + i * lh
		if pct > 0.0:
			draw_rect(Rect2(bar_x, by, bar_w * pct, bar_h),
				Color(bar_color.r, bar_color.g, bar_color.b, al))

func _draw_etc_weapon_levels(font: Font) -> void:
	## GMS2: oMenuWeapons Draw_64.gml — 8 weapon boxes (4×2 grid) + bottom info window
	## Same visual style as Status screen: tiled background, alpha fade-in, fs=10
	var vp: Vector2 = get_viewport_rect().size
	var al: float = _etc_transition_alpha

	# --- Tiled background (GMS2: spr_bg_menuTile, same as Status) ---
	if _bg_menu_tile and al > 0:
		var tw: float = _bg_menu_tile.get_width()
		var th: float = _bg_menu_tile.get_height()
		if tw > 0 and th > 0:
			var ox: float = fmod(_etc_bg_scroll, tw)
			var oy: float = fmod(_etc_bg_scroll, th)
			var cy: float = oy - th
			while cy < vp.y:
				var cx: float = ox - tw
				while cx < vp.x:
					draw_texture(_bg_menu_tile, Vector2(cx, cy), Color(1, 1, 1, al))
					cx += tw
				cy += th

	if al <= 0:
		return

	var player: Node = GameManager.get_player(etc_player_idx)
	if not is_instance_valid(player) or not player is Actor:
		draw_string(font, Vector2(20, 30), "No player data",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color.WHITE)
		return

	var actor := player as Actor
	var fs: int = 10  # GMS2: textXScale=2, textYScale=2
	var ascent: float = font.get_ascent(fs)
	var text_color := Color(1, 1, 1, al)

	# --- GMS2 Layout (coords / 3) ---
	# displayCenter = round(1281/2 - 490) = 151; stateWindow = (151, 80)
	var base_x := 50.0
	var base_y := 27.0
	# weaponBoxWidth=460/3≈153, weaponBoxHeight=82/3≈27, pivotWidth=480/3=160
	var box_w := 153.0
	var box_h := 27.0
	var col2_offset := 160.0
	# Row stride: (82+22)/3 = 34.7
	var row_stride := 34.7

	# --- Header text: GMS2 stateWindow + (30,-60) → (10,-20) + ascent ---
	var header_y: float = base_y - 20.0 + ascent
	var is_magic_mode: bool = (etc_weapon_magic_mode == 1)
	var magic_user: bool = (actor.enable_magic != Constants.MAGIC_NONE)
	var header_label: String = "MAGIC SKIL     " if is_magic_mode else "WEAPON SKIL     "
	draw_string(font, Vector2(base_x + 10.0, header_y),
		header_label + actor.character_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	# GMS2: show swap option if magicUser — "MAGIC/WEAPON SKILL      SWAP" at right side
	# GMS2 also draws spr_controlButton sprite next to SWAP text
	if magic_user:
		var swap_label: String = "WEAPON SKILL      SWAP" if is_magic_mode else "MAGIC SKILL      SWAP"
		draw_string(font, Vector2(base_x + col2_offset + 10.0, header_y),
			swap_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		# GMS2: spr_controlButton at stateWindow_xAnchor + 740/755 ÷3 relative
		if _control_button_tex:
			var btn_x: float = base_x + col2_offset + (135.0 if is_magic_mode else 128.0)
			draw_texture(_control_button_tex, Vector2(btn_x, header_y - ascent - 2.0), Color(1, 1, 1, al))

	# --- Item names, icons, and level data ---
	var weapon_names: Array = ["Sword", "Axe", "Spear", "Javelin", "Bow", "Boomerang", "Whip", "Knuckles"]
	var weapon_icon_idx: Array = [19, 20, 21, 25, 23, 24, 22, -1]
	var deity_names: Array = ["Undine", "Gnome", "Sylphid", "Salamando", "Shade", "Luna", "Lumina", "Dryad"]
	var deity_icon_idx: Array = [27, 34, 29, 28, 33, 30, 32, 31]  # From elements.json subimage

	# --- Draw 8 boxes (4×2 grid) ---
	# GMS2: selection highlight only shows when enableElementInfo is true
	if _window_layout_textures.size() > 0:
		for i in range(8):
			var pivot: int = i if i < 4 else i - 4
			var pw: float = col2_offset if i > 3 else 0.0
			var bx: float = base_x + pw
			var by: float = base_y + row_stride * pivot
			var is_sel: bool = (i == etc_weapon_selected and _etc_wl_enable_info)
			var wt: Texture2D = _window_layout_textures[1] if (is_sel and _window_layout_textures.size() > 1) else _window_layout_textures[0]
			UIUtils.draw_window(self, wt, bx, by, box_w, box_h,
				GameManager.GUI_SCALE, al, Color.WHITE)

	for i in range(8):
		var pivot: int = i if i < 4 else i - 4
		var pw: float = col2_offset if i > 3 else 0.0
		var ix: float = base_x + pw + 7.0
		var iy: float = base_y + row_stride * pivot + 10.0 + ascent

		if is_magic_mode:
			# --- MAGIC MODE: show deity levels ---
			var deity_enabled: bool = (i < actor.deity_levels.size())
			if not deity_enabled:
				continue
			var dlv: int = actor.deity_levels[i]
			# Deity icon
			var d_icon_sub: int = deity_icon_idx[i]
			if d_icon_sub >= 0 and d_icon_sub < icons_general.size():
				draw_texture(icons_general[d_icon_sub],
					Vector2(ix, iy - ascent - 2.0), Color(1, 1, 1, al))
			# Level:Exp (deity exp not tracked yet, show level:0)
			draw_string(font, Vector2(ix + 20.0, iy),
				"%d: 0" % dlv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
			# Deity name
			draw_string(font, Vector2(ix + 47.0, iy), deity_names[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		else:
			# --- WEAPON MODE: show weapon levels ---
			var wname: String = weapon_names[i].to_lower()
			var wlevel: int = actor.equipment_current_level.get(wname, 1)
			var wexp: int = actor.equipment_levels.get(wname, 0)
			var exp_str: String = str(wexp) if wexp >= 10 else " " + str(wexp)
			# Weapon icon
			var icon_sub: int = weapon_icon_idx[i]
			if icon_sub >= 0 and icon_sub < icons_general.size():
				draw_texture(icons_general[icon_sub],
					Vector2(ix, iy - ascent - 2.0), Color(1, 1, 1, al))
			# Level:Exp
			draw_string(font, Vector2(ix + 20.0, iy),
				"%d:%s" % [wlevel, exp_str],
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
			# Weapon name
			draw_string(font, Vector2(ix + 47.0, iy), weapon_names[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# --- Bottom info window: GMS2 stateWindow + (0, 420), size (950, 180) ---
	var info_y: float = base_y + row_stride * 4 + 4.0
	var info_w: float = box_w * 2 + col2_offset - box_w + 10.0  # (460*2+30)/3 ≈ 317
	var info_h: float = 60.0  # 180/3
	if _window_layout_textures.size() > 0:
		UIUtils.draw_window(self, _window_layout_textures[0], base_x, info_y,
			info_w, info_h, GameManager.GUI_SCALE, al, Color.WHITE)

	# Bottom text: GMS2 uses dynamic bottomText variable (changes on Attack press)
	# GMS2: fontSeparation=28 → /3 ≈ 9.3 line height, textXScale/YScale=2 → fs=10
	var info_text_y: float = info_y + 8.0 + ascent
	var info_lh: float = 9.3  # GMS2: fontSeparation=28/3
	var info_fs: int = 10  # GMS2: same textXScale/YScale=2
	# Draw dynamic bottom text (multi-line, split by \n)
	var bottom_lines: PackedStringArray = _etc_wl_bottom_text.split("\n")
	for li in range(bottom_lines.size()):
		draw_string(font, Vector2(base_x + 10.0, info_text_y + info_lh * li),
			bottom_lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, info_fs, text_color)
	# GMS2: right-aligned text (bottomTextRight) — e.g., "ENERGY ORB 9/ 9"
	if not _etc_wl_bottom_text_right.is_empty():
		draw_string(font, Vector2(base_x + info_w - 10.0, info_text_y),
			_etc_wl_bottom_text_right, HORIZONTAL_ALIGNMENT_RIGHT, -1, info_fs, text_color)

func _draw_etc_action_grid(font: Font) -> void:
	## GMS2: oMenuActionGrid Draw_64.gml — faithful port
	## 3 windows: top bar, grid area, level sidebar. spr_actionGrid checkerboard.
	var vp: Vector2 = get_viewport_rect().size
	var al: float = _etc_transition_alpha

	# --- Tiled background ---
	if _bg_menu_tile and al > 0:
		var tw: float = _bg_menu_tile.get_width()
		var th: float = _bg_menu_tile.get_height()
		if tw > 0 and th > 0:
			var ox: float = fmod(_etc_bg_scroll, tw)
			var oy: float = fmod(_etc_bg_scroll, th)
			var cy: float = oy - th
			while cy < vp.y:
				var cx: float = ox - tw
				while cx < vp.x:
					draw_texture(_bg_menu_tile, Vector2(cx, cy), Color(1, 1, 1, al))
					cx += tw
				cy += th

	if al <= 0:
		return

	var fs: int = 10  # GMS2: textXScale=2, textYScale=2
	var ascent: float = font.get_ascent(fs)
	var text_color := Color(1, 1, 1, al)

	# --- GMS2 blink logic (Draw_64 lines 32-37): toggle every 10/60 sec ---
	# alphaCharacter blinks only in CHANGE_ACTION, alphaCursor blinks only in CHANGE_LEVEL
	# Non-active element stays at 1 (visible)
	# Use period-based toggle: visible when period index is even
	var _blink_period: int = int(_etc_ag_blink_timer / (10.0 / 60.0))
	var _blink_on: bool = _blink_period % 2 == 0
	if etc_action_grid_mode == 0:  # CHANGE_ACTION
		_etc_ag_alpha_char = 1.0 if _blink_on else 0.0
		_etc_ag_alpha_cursor = 1.0
	else:  # CHANGE_LEVEL
		_etc_ag_alpha_cursor = 1.0 if _blink_on else 0.0
		_etc_ag_alpha_char = 1.0
	_etc_ag_alpha_char = minf(_etc_ag_alpha_char, al)
	_etc_ag_alpha_cursor = minf(_etc_ag_alpha_cursor, al)

	# --- GMS2 window layout (coords / 3) ---
	# Top bar: GMS2 (0, 0, view_wport-16=1265, 70) → Godot (0, 0, 422, 23)
	var top_x := 0.0; var top_y := 0.0; var top_w := vp.x - 5.0; var top_h := 23.0
	# Main grid area: GMS2 (0, 90, view_wport-200=1081, view_hport-120=600) → Godot (0, 30, 360, 200)
	var main_x := 0.0; var main_y := 30.0; var main_w := vp.x - 67.0; var main_h := 200.0
	# Level sidebar: GMS2 (view_wport-140=1141, 90, 122, 600) → Godot (380, 30, 41, 200)
	var side_x := vp.x - 47.0; var side_y := 30.0; var side_w := 41.0; var side_h := 200.0

	# --- Draw 3 windows ---
	if _window_layout_textures.size() > 0:
		var wt: Texture2D = _window_layout_textures[0]
		UIUtils.draw_window(self, wt, top_x, top_y, top_w, top_h, GameManager.GUI_SCALE, al, Color.WHITE)
		UIUtils.draw_window(self, wt, main_x, main_y, main_w, main_h, GameManager.GUI_SCALE, al, Color.WHITE)
		UIUtils.draw_window(self, wt, side_x, side_y, side_w, side_h, GameManager.GUI_SCALE, al, Color.WHITE)

	# --- Top bar text: GMS2 (24,24)/3 = (8,8) + ascent ---
	# GMS2: "Place for Action Type. Push \"ATTACK\" button to set."
	draw_string(font, Vector2(8.0, 8.0 + ascent),
		"Place for Action Type. Push \"ATTACK\" button to set.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# --- Level sidebar: numbers 0-8 (GMS2: view_wport-75, 140 + 60*i) ---
	var weapon_max_level: int = 8
	var level_x: float = vp.x - 25.0  # GMS2: view_wport-75 → /3 ≈ right side
	var level_start_y: float = 47.0  # GMS2: 140/3 ≈ 47
	var level_step: float = 20.0  # GMS2: 60/3 = 20
	for i in range(weapon_max_level + 1):
		draw_string(font, Vector2(level_x, level_start_y + level_step * i + ascent),
			str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# GMS2: spr_menuSelector frame 6 — ALWAYS drawn (solid in CHANGE_ACTION, blinks in CHANGE_LEVEL)
	# GMS2 (Draw_64 line 24): draw_sprite_ext(spr_menuSelector, 6, view_wport-102, 124 + 60*selectedLevel, ...)
	var cursor_y: float = level_start_y + level_step * etc_action_level - 2.0
	var cursor_al: float = _etc_ag_alpha_cursor
	if selector_frames.size() > 6:
		var sel_tex: Texture2D = selector_frames[6]
		# GMS2: view_wport-102 → (1281-102)/3 ≈ 393; sprite origin is (11,11) → 393-11 ≈ 382
		draw_texture(sel_tex, Vector2(level_x - 8.0, cursor_y), Color(1, 1, 1, cursor_al))

	# --- 4×4 Action Grid: use spr_actionGrid sprite (128×128 checkerboard) ---
	# GMS2: matrix_xOrigin=220, matrix_yOrigin=200 → /3: (73,67)
	# GMS2: matrix_xSeparation=96, matrix_ySeparation=96 → /3: 32
	var grid_ox: float = 73.0
	var grid_oy: float = 67.0
	var grid_sep: float = 32.0

	if _action_grid_tex:
		# GMS2 draws at GUI_SCALE (3x), Godot viewport is /3, so draw at 1.0 scale
		draw_texture(_action_grid_tex, Vector2(grid_ox, grid_oy), Color(1, 1, 1, al))
	else:
		# Fallback: procedural grid if texture not loaded
		var grid_total: float = grid_sep * 4.0
		draw_rect(Rect2(grid_ox, grid_oy, grid_total, grid_total),
			Color(0.1, 0.1, 0.2, al * 0.8))
		for i in range(5):
			var lp: float = float(i) * grid_sep
			draw_line(Vector2(grid_ox + lp, grid_oy), Vector2(grid_ox + lp, grid_oy + grid_total),
				Color(0.4, 0.4, 0.6, al), 1.0)
			draw_line(Vector2(grid_ox, grid_oy + lp), Vector2(grid_ox + grid_total, grid_oy + lp),
				Color(0.4, 0.4, 0.6, al), 1.0)

	# --- Labels around grid (GMS2 coords / 3) ---
	# GMS2: "APPROACH" at (330,140) → (110,47)
	draw_string(font, Vector2(110.0, 47.0 + ascent), "APPROACH",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	# GMS2: "GUARD" at (610,375) → (203,125)
	draw_string(font, Vector2(grid_ox + 128.0 + 5.0, 125.0 + ascent), "GUARD",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	# GMS2: "KEEP AWAY" at (330,600) → (110,200)
	draw_string(font, Vector2(110.0, 200.0 + ascent), "KEEP AWAY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	# GMS2: "ATTACK" at (90,375) → (30,125)
	draw_string(font, Vector2(30.0, 125.0 + ascent), "ATTACK",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# --- Player sprite cursor (GMS2: blinking character at grid position) ---
	# GMS2: matrix_xOriginPlayer = matrix_xOrigin + 45 → 73+15=88
	# GMS2: matrix_yOriginPlayer = matrix_yOrigin + 60 → 67+20=87
	# Position = originPlayer + separation * index (0-based: action_grid - 1)
	if target_player and target_player is Actor:
		var actor := target_player as Actor
		if actor.sprite_sheet:
			var stand_frame: int = actor.spr_stand_down
			var col: int = stand_frame % actor.sprite_columns
			@warning_ignore("INTEGER_DIVISION")
			var row: int = stand_frame / actor.sprite_columns
			var src := Rect2(col * actor.frame_width, row * actor.frame_height,
				actor.frame_width, actor.frame_height)
			# GMS2 blink: alphaCharacter toggles on/off (0 or 1)
			var char_al: float = _etc_ag_alpha_char
			var px: float = 88.0 + grid_sep * (action_grid_x - 1) - actor.sprite_origin.x
			var py: float = 87.0 + grid_sep * (action_grid_y - 1) - actor.sprite_origin.y
			draw_texture_rect_region(actor.sprite_sheet,
				Rect2(px, py, actor.frame_width, actor.frame_height), src,
				Color(1, 1, 1, char_al))

func _draw_etc_controller_edit(font: Font) -> void:
	## GMS2: oMenuControllerEdit Draw_64.gml — Title window, 4 button boxes, bottom info
	## Layout: spr_windowLayout_1 for all windows, 2x2 button grid, bottom help text
	var vp: Vector2 = get_viewport_rect().size
	var al: float = _etc_transition_alpha

	# --- Tiled background (GMS2: spr_bg_menuTile, htiled/vtiled, scroll -0.2) ---
	if _bg_menu_tile and al > 0:
		var tw: float = _bg_menu_tile.get_width()
		var th: float = _bg_menu_tile.get_height()
		if tw > 0 and th > 0:
			var ox: float = fmod(_etc_bg_scroll, tw)
			var oy: float = fmod(_etc_bg_scroll, th)
			var cy: float = oy - th
			while cy < vp.y:
				var cx: float = ox - tw
				while cx < vp.x:
					draw_texture(_bg_menu_tile, Vector2(cx, cy), Color(1, 1, 1, al))
					cx += tw
				cy += th

	if al <= 0:
		return

	var fs: int = 10
	var ascent: float = font.get_ascent(fs)
	var text_color: Color = Color(1, 1, 1, al)

	# --- Title window (GMS2: drawWindow(spr_windowLayout_1, 0, 0, 300, 70) ÷3) ---
	if _window_layout_textures.size() > 0:
		UIUtils.draw_window(self, _window_layout_textures[0],
			0, 0, 100, 23, GameManager.GUI_SCALE, al, Color.WHITE)
	# GMS2: "Controller  Edit" at (50, 24) ÷3
	draw_string(font, Vector2(17, 8.0 + ascent), "Controller  Edit",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	# GMS2: spr_controlPad at (1000, 40) ÷3, origin (12,7)
	if _control_pad_tex:
		draw_texture(_control_pad_tex, Vector2(1000.0/3.0 - 12.0, 40.0/3.0 - 7.0), Color(1, 1, 1, al))

	# --- 4 button assignment boxes (GMS2: 2x2 grid layout) ---
	# GMS2 anchors: [0]=(190,100) [1]=(690,100) [2]=(190,210) [3]=(690,210)
	# Window at (80+anchorX, anchorY, 300, 80)
	# Button text at (anchorX, anchorY+30), action text at (anchorX+120, anchorY+30)
	# Button sprite at (anchorX+30, anchorY+20)
	var btn_ax: Array = [190.0, 690.0, 190.0, 690.0]
	var btn_ay: Array = [100.0, 100.0, 210.0, 210.0]
	var btn_labels: Array = ["Y", "X", "B", "A"]
	# GMS2 actionTexts: indexed by etc_ctrl_assignments[slot]
	var action_texts: Array = ["Your icons/Cancel", "Ally's icons", "Attack/Ok", "Dash"]

	for i in range(4):
		var bx: float = btn_ax[i] / 3.0
		var by: float = btn_ay[i] / 3.0
		# Window at (80+anchorX, anchorY, 300, 80) ÷3
		var wx: float = (80.0 + btn_ax[i]) / 3.0
		# GMS2: pressedButton == i → use subimage 1 (selected window)
		var win_idx: int = 1 if etc_ctrl_selected == i else 0
		if _window_layout_textures.size() > win_idx:
			UIUtils.draw_window(self, _window_layout_textures[win_idx],
				wx, by, 100, 27, GameManager.GUI_SCALE, al, Color.WHITE)
		# Button letter at (anchorX, anchorY+30) ÷3
		var text_y: float = (btn_ay[i] + 30.0) / 3.0 + ascent
		draw_string(font, Vector2(bx, text_y), btn_labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		# GMS2: spr_controlButton1 (blue) for i<2, spr_controlButton2 (red) for i>=2
		var btn_spr: Texture2D = _control_button1_tex if i < 2 else _control_button2_tex
		var spr_x: float = (btn_ax[i] + 30.0) / 3.0
		var spr_y: float = (btn_ay[i] + 20.0) / 3.0
		if btn_spr:
			draw_texture(btn_spr, Vector2(spr_x, spr_y), Color(1, 1, 1, al))
		# Action text: dynamic from etc_ctrl_assignments (GMS2: inputGroupText[i])
		var assigned_action: int = etc_ctrl_assignments[i] if i < etc_ctrl_assignments.size() else i
		var act_text: String = action_texts[assigned_action] if assigned_action < action_texts.size() else "---"
		draw_string(font, Vector2((btn_ax[i] + 120.0) / 3.0, text_y), act_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# --- D-pad indicator (GMS2: spr_controlPad at (1000, 40) ÷3) ---
	# spr_controlPad: 24×15, origin (12,7) — so subtract origin when drawing
	var pad_cx: float = 1000.0 / 3.0 - 12.0  # GMS2 x=1000 ÷3 minus origin.x
	var pad_cy: float = 40.0 / 3.0 - 7.0  # GMS2 y=40 ÷3 minus origin.y
	if _control_pad_move_tex:
		# spr_controlPadMove is more appropriate here (GMS2 uses it too)
		draw_texture(_control_pad_move_tex, Vector2((vp.x / 2.0) - 16.0, 117.0), Color(1, 1, 1, al))
	# GMS2 Draw_64: "SELECT" labels at padCenter+130 and padCenter-120
	var pc: float = vp.x / 2.0 - 16.0
	draw_string(font, Vector2(pc + 43, 125.0 + ascent), "SELECT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	draw_string(font, Vector2(pc - 40, 125.0 + ascent), "SELECT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# --- Bottom info window (GMS2: 0, 480, view_wport-16, 220 ÷3) ---
	if _window_layout_textures.size() > 0:
		UIUtils.draw_window(self, _window_layout_textures[0],
			0, 160, vp.x - 5, 73, GameManager.GUI_SCALE, al, Color.WHITE)
	# GMS2 bottomText at (30, 510) ÷3 = (10, 170), sep=24 → actual sep=48÷3=16
	var bottom_lines: PackedStringArray = [
		"TO CHANGE THE BUTTON ASSIGNMENT, KEEP THE",
		"BUTTON DOWN, AND PUSH RIGHT/LEFT ON THE",
		"CONTROL PAD. RELEASE TO SET.",
		"PUSH START TO EXIT."
	]
	for li in range(bottom_lines.size()):
		draw_string(font, Vector2(10, 170.0 + ascent + li * 16.0),
			bottom_lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

func _draw_etc_window_edit(font: Font) -> void:
	## GMS2: oMenuWindowEdit Draw_64.gml — faithful port
	## Title window, dialog preview, color gauges with sprites, pad guide, bottom info
	var vp: Vector2 = get_viewport_rect().size
	var al: float = _etc_transition_alpha

	# --- Tiled background (GMS2: spr_bg_menuTile) ---
	if _bg_menu_tile and al > 0:
		var tw: float = _bg_menu_tile.get_width()
		var th: float = _bg_menu_tile.get_height()
		if tw > 0 and th > 0:
			var ox: float = fmod(_etc_bg_scroll, tw)
			var oy: float = fmod(_etc_bg_scroll, th)
			var cy: float = oy - th
			while cy < vp.y:
				var cx: float = ox - tw
				while cx < vp.x:
					draw_texture(_bg_menu_tile, Vector2(cx, cy), Color(1, 1, 1, al))
					cx += tw
				cy += th

	if al <= 0:
		return

	var fs: int = 10
	var ascent: float = font.get_ascent(fs)
	var text_color: Color = Color(1, 1, 1, al)
	var border_count: int = _dialog_border_textures.size()
	var bg_count: int = _dialog_bg_textures.size()

	# --- Title window (GMS2: drawWindow(spr_scriptDialog_border, 0, 0, 300, 70) ÷3) ---
	if border_count > 0:
		UIUtils.draw_window(self, _dialog_border_textures[0],
			0, 0, 100, 23, GameManager.GUI_SCALE, al, Color.WHITE)
	# GMS2: "Window Edit" at (50, 24) ÷3
	draw_string(font, Vector2(17, 8.0 + ascent), "Window Edit",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# --- Dialog preview (GMS2: dialogXPos=50, dialogYPos=180, w=500, h=80 ÷3) ---
	var dlg_x: float = 17.0  # 50÷3
	var dlg_y: float = 60.0  # 180÷3
	var dlg_w: float = 167.0  # 500÷3
	var dlg_h: float = 27.0  # 80÷3
	var dlg_margin: float = 5.0  # 16÷3

	if bg_count > 0 and border_count > 0:
		var bg_idx: int = clampi(GameManager.dialog_background_index, 0, bg_count - 1)
		var bdr_idx: int = clampi(GameManager.dialog_border_index, 0, border_count - 1)
		# Tiled background inside dialog area
		UIUtils.draw_sprite_tiled_area(self, _dialog_bg_textures[bg_idx], 0,
			0, 0, dlg_x + dlg_margin, dlg_y + dlg_margin,
			dlg_x + dlg_w - dlg_margin, dlg_y + dlg_h - dlg_margin,
			Color(window_color.r, window_color.g, window_color.b, al), al, 1, 1.0 / 3.0)
		# Border window
		UIUtils.draw_window(self, _dialog_border_textures[bdr_idx],
			dlg_x, dlg_y, dlg_w, dlg_h,
			GameManager.GUI_SCALE, al, Color.WHITE)
	else:
		draw_rect(Rect2(dlg_x, dlg_y, dlg_w, dlg_h),
			Color(window_color.r, window_color.g, window_color.b, 0.85 * al))

	# --- D-Pad sprite (GMS2: spr_controlPadMove at padXPos=250, y=350 ÷3) ---
	var pad_x: float = 83.0  # 250÷3
	var pad_y: float = 117.0  # 350÷3
	if _control_pad_move_tex:
		draw_texture(_control_pad_move_tex, Vector2(pad_x, pad_y), Color(1, 1, 1, al))
	# GMS2: "SELECT" labels at padXPos+130 and padXPos-120, y=375 ÷3
	draw_string(font, Vector2(pad_x + 43, 125.0 + ascent), "SELECT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	draw_string(font, Vector2(pad_x - 40, 125.0 + ascent), "SELECT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

	# --- Color gauges (GMS2: buttonGaugeXPos=700, buttonGaugeYPos=100, gaugeHeightSep=60 ÷3) ---
	# GMS2: buttons=["A","Y","X"], buttonColors=["R","G","B"]
	# sprites=[spr_controlButton1, spr_controlButton2, spr_controlButton2]
	var gauge_x: float = 233.0  # 700÷3
	var gauge_y0: float = 33.0  # 100÷3
	var gauge_sep: float = 20.0  # 60÷3
	var color_labels: Array = ["R", "G", "B"]
	var color_values: Array = [window_color.r, window_color.g, window_color.b]
	var btn_names: Array = ["A", "Y", "X"]
	# GMS2: spr_controlButton1 for A, spr_controlButton2 for Y and X
	var btn_sprites: Array = [_control_button1_tex, _control_button2_tex, _control_button2_tex]
	# GMS2: gaugeMaxWidth = sprite_get_width(spr_gaugeBar) * GUI_SCALE = 64*3 = 192
	# In Godot /3: 64px (native width of spr_gaugeBar)

	for i in range(3):
		var gy: float = gauge_y0 + i * gauge_sep
		# GMS2: button label at (buttonGaugeXPos, ySep) ÷3
		draw_string(font, Vector2(gauge_x, gy + ascent), btn_names[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		# GMS2: button sprite at (buttonGaugeXPos+25, ySep) ÷3
		if btn_sprites[i]:
			draw_texture(btn_sprites[i], Vector2(gauge_x + 8, gy), Color(1, 1, 1, al))
		# GMS2: color label at (buttonGaugeXPos+76, ySep) ÷3
		draw_string(font, Vector2(gauge_x + 25, gy + ascent), color_labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		# GMS2: spr_gaugeBar at (buttonGaugeXPos+110, ySep+20) ÷3
		var bar_x: float = gauge_x + 37  # 110÷3
		var bar_y: float = gy + 7  # 20÷3
		if _gauge_bar_tex:
			draw_texture(_gauge_bar_tex, Vector2(bar_x, bar_y), Color(1, 1, 1, al))
		# GMS2: spr_gaugePosition at (gaugePositionOrigin + gaugeDistance[i], ySep+29) ÷3
		# gaugePositionOrigin = buttonGaugeXPos+110 = 810 → ÷3=270 → relative: bar_x
		# gaugeDistance[i] = (bgColor[i]/256) * gaugeMaxWidth → color_values[i] * 64
		# spr_gaugePosition origin (3,4) — need to offset
		if _gauge_pos_tex:
			var gpos_x: float = bar_x + color_values[i] * 64.0 - 3.0  # origin.x = 3
			var gpos_y: float = gy + 10.0 - 4.0  # 29÷3 ≈ 9.7, origin.y = 4
			draw_texture(_gauge_pos_tex, Vector2(gpos_x, gpos_y), Color(1, 1, 1, al))

	# --- Pad guide (GMS2: 4 buttons around a center point) ---
	# GMS2: buttonGuideXAnchor=850, buttonGuideYAnchor=350 ÷3
	var bg_ax: float = 283.0  # 850÷3
	var bg_ay: float = 117.0  # 350÷3
	# GMS2 button guide positions (relative to anchor) ÷3:
	# Text[0]=(+50,-55)÷3, Text[1]=(-90,+5)÷3, Text[2]=(+110,+5)÷3, Text[3]=(-30,+65)÷3
	var bg_text_x: Array = [bg_ax + 17, bg_ax - 30, bg_ax + 37, bg_ax - 10]
	var bg_text_y: Array = [bg_ay - 18, bg_ay + 2, bg_ay + 2, bg_ay + 22]
	# Sprite positions ÷3: [0]=(0,-60), [1]=(-60,0), [2]=(+60,0), [3]=(0,+60)
	var bg_spr_x: Array = [bg_ax, bg_ax - 20, bg_ax + 20, bg_ax]
	var bg_spr_y: Array = [bg_ay - 20, bg_ay, bg_ay, bg_ay + 20]
	# GMS2: sprites=[spr_controlButton1, spr_controlButton1, spr_controlButton2, spr_controlButton2]
	var bg_sprites: Array = [_control_button1_tex, _control_button1_tex, _control_button2_tex, _control_button2_tex]
	# GMS2: text=["X","Y","A","B"]
	var bg_texts: Array = ["X", "Y", "A", "B"]

	for i in range(4):
		draw_string(font, Vector2(bg_text_x[i], bg_text_y[i] + ascent), bg_texts[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
		if bg_sprites[i]:
			draw_texture(bg_sprites[i], Vector2(bg_spr_x[i], bg_spr_y[i]), Color(1, 1, 1, al))

	# --- Bottom info window (GMS2: drawWindow(spr_scriptDialog_border, 0, 500, view_wport-16, 200) ÷3) ---
	if border_count > 0:
		UIUtils.draw_window(self, _dialog_border_textures[0],
			0, 167, vp.x - 5, 67, GameManager.GUI_SCALE, al, Color.WHITE)
	# GMS2 bottomText at (30, 530) ÷3 = (10, 177), fontSeparation=30÷3=10
	var bottom_text: String = "SELECT A WINDOW WITH THE DIRECTION KEY.\nCHANGE THE COLOR GAUGE BY PRESSING A/Y/X DOWN.\nPUSH B-BUTTON TO SET. PUSH SELECT BUTTON TO EXIT."
	var bottom_lines: PackedStringArray = bottom_text.split("\n")
	for li in range(bottom_lines.size()):
		draw_string(font, Vector2(10, 177.0 + ascent + li * 10.0),
			bottom_lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

func _draw_money_dialog(font: Font) -> void:
	## GMS2: oMoneyDialog - persistent money display during shop interaction
	## Positioned center-bottom, shows "###GP" in a styled window
	var vp_size: Vector2 = get_viewport_rect().size
	var money_w: float = 80.0
	var money_h: float = 16.0
	var money_x: float = (vp_size.x - money_w) / 2.0
	var money_y: float = vp_size.y - 16.0

	if _dialog_bg_textures.size() > 0 and _dialog_border_textures.size() > 0:
		var bg_idx: int = clampi(GameManager.dialog_background_index, 0, _dialog_bg_textures.size() - 1)
		var border_idx: int = clampi(GameManager.dialog_border_index, 0, _dialog_border_textures.size() - 1)
		UIUtils.draw_sprite_tiled_area(self, _dialog_bg_textures[bg_idx], 0,
			0, 0, money_x, money_y, money_x + money_w, money_y + money_h,
			GameManager.dialog_color_rgb, 1.0, 1, 1.0 / 3.0)
		UIUtils.draw_window(self, _dialog_border_textures[border_idx],
			money_x - 4, money_y - 4, money_w + 8, money_h + 8,
			GameManager.GUI_SCALE, 1.0, Color.WHITE)
	else:
		draw_rect(Rect2(money_x, money_y, money_w, money_h), Color(0.05, 0.0, 0.15, 0.85))
		draw_rect(Rect2(money_x, money_y, money_w, money_h), Color(0.5, 0.5, 0.8, 0.8), false, 1.0)

	var money_text: String = "%dGP" % GameManager.party_money
	draw_string(font, Vector2(money_x + money_w - 6, money_y + 12),
		money_text, HORIZONTAL_ALIGNMENT_RIGHT, int(money_w - 12), 7, Color.WHITE)

func _equip_name(equip_id: int) -> String:
	if equip_id < 0:
		return "None"
	for eq in Database.equipments:
		if eq is Dictionary and eq.get("id", -1) == equip_id:
			return eq.get("nameText", str(equip_id))
	return str(equip_id)
