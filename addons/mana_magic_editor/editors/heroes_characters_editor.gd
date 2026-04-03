@tool
extends "res://addons/mana_magic_editor/editors/base_editor.gd"

## Editor for Hero characters (heroes.json).
## Each hero has a name, class assignment, starting equipment, level, and magic config.

# Cached lookup data
var _class_names: Array = []   # ["normal", "warrior", ...]
var _weapon_names: Array = ["Sword", "Axe", "Spear", "Javelin", "Bow", "Boomerang", "Whip", "Knuckles", "None"]
var _magic_types: Array = []  # loaded from magic_types.json
var _equip_data: Array = []  # raw equipments.json
var _elements_data: Array = []  # loaded from elements.json

# Equipment filtered by kind: {kind_id: [{id, name}, ...]}
var _equip_by_kind: Dictionary = {}  # 1=head, 2=accessories, 3=body

# Fields
var _f_name: LineEdit
var _f_class: OptionButton
var _f_weapon: OptionButton
var _f_head: OptionButton
var _f_body: OptionButton
var _f_accessory: OptionButton
var _f_level: SpinBox
var _f_hp_mult: SpinBox
var _f_mp_mult: SpinBox
var _f_mp_mult2: SpinBox
var _f_mp_div: SpinBox
var _f_magic_type: OptionButton
var _f_deity_levels: Array = []  # Array of SpinBoxes (one per magic group)
var _f_sprite: LineEdit
var _f_is_leader: CheckBox
var _f_enabled_by_default: CheckBox

# Animation Library state (from base_editor helper)
var _anim_lib_state: Dictionary = {}

# Container for deity levels section (to show/hide as a group)
var _deity_section: VBoxContainer
var _deity_grid: GridContainer

func _get_json_filename() -> String:
	return "heroes.json"

func _get_display_name(entry: Dictionary) -> String:
	var hero_name: String = entry.get("name", "unnamed")
	var class_id: int = int(entry.get("classId", 0))
	var class_label := _get_class_label(class_id)
	var leader_tag := " ★" if entry.get("isLeader", false) else ""
	return "%s - %s (%s)%s" % [entry.get("id", "?"), hero_name, class_label, leader_tag]

func _get_class_label(class_id: int) -> String:
	if class_id >= 0 and class_id < _class_names.size():
		return _class_names[class_id]
	return "class_%d" % class_id

func _build_form() -> void:
	_load_lookup_data()

	_add_section_label("Hero Identity")
	_f_name = _create_line_edit("Hero name")
	_add_field("Name:", _f_name)

	# Sprite path — hidden, kept for runtime compatibility
	_f_sprite = _create_line_edit("")
	_f_sprite.visible = false

	_f_is_leader = _create_check_box("Party Leader")
	_add_field("Leader:", _f_is_leader)

	_f_enabled_by_default = _create_check_box("Enabled by Default")
	_add_field("Enabled:", _f_enabled_by_default)

	_add_spacer()
	_add_section_label("Animation Library")
	_anim_lib_state = _add_animation_library_section("res://assets/animations/actors/")

	_add_spacer()
	_add_section_label("Class & Level")

	_f_class = OptionButton.new()
	for i in range(_class_names.size()):
		_f_class.add_item("%d: %s" % [i, _class_names[i]], i)
	_add_field("Class:", _f_class)

	_f_level = _create_spin(1, 99)
	_add_number_field("Starting Level:", _f_level)

	_add_spacer()
	_add_section_label("Starting Equipment")

	_f_weapon = OptionButton.new()
	for i in range(_weapon_names.size()):
		_f_weapon.add_item("%d: %s" % [i, _weapon_names[i]], i)
	_add_field("Weapon:", _f_weapon)

	# Head, Body, Accessory as equipment selectors
	_f_head = _build_equip_selector(1, "Head")
	_add_field("Head:", _f_head)
	_f_body = _build_equip_selector(3, "Body")
	_add_field("Body:", _f_body)
	_f_accessory = _build_equip_selector(2, "Accessory")
	_add_field("Accessory:", _f_accessory)

	_add_spacer()
	_add_section_label("HP / MP Multipliers")
	_f_hp_mult = _create_spin(0, 100, 0.1)
	_add_number_field("HP Multiplier:", _f_hp_mult)
	_f_mp_mult = _create_spin(0, 100, 0.1)
	_add_number_field("MP Multiplier:", _f_mp_mult)
	_f_mp_mult2 = _create_spin(0, 100, 0.1)
	_add_number_field("MP Multiplier 2:", _f_mp_mult2)
	_f_mp_div = _create_spin(0.1, 100, 0.1)
	_add_number_field("MP Divisor:", _f_mp_div)

	_add_spacer()
	_add_section_label("Magic Configuration")
	_f_magic_type = OptionButton.new()
	for mt in _magic_types:
		_f_magic_type.add_item(mt)
	_f_magic_type.item_selected.connect(_on_magic_type_changed)
	_add_field("Magic Type:", _f_magic_type)

	# Deity levels section — populated dynamically from elements.json
	_deity_section = VBoxContainer.new()
	_deity_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_container.add_child(_deity_section)

	var deity_label := Label.new()
	deity_label.text = "Deity Levels"
	deity_label.add_theme_font_size_override("font_size", 14)
	deity_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_deity_section.add_child(deity_label)

	_deity_grid = GridContainer.new()
	_deity_grid.columns = 4  # label, spin, label, spin
	_deity_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deity_section.add_child(_deity_grid)

	_rebuild_deity_grid()

	# Start hidden until a hero with magic is selected
	_deity_section.visible = false

## Build deity levels grid from elements.json data
func _rebuild_deity_grid() -> void:
	# Clear existing children
	for child in _deity_grid.get_children():
		child.queue_free()
	_f_deity_levels.clear()

	for elem in _elements_data:
		var display_name: String = elem.get("nameText", elem.get("name", "?"))
		var lbl := Label.new()
		lbl.text = "%s:" % display_name
		lbl.custom_minimum_size.x = 90
		_deity_grid.add_child(lbl)
		var spin := _create_spin(0, 99)
		spin.custom_minimum_size.x = 60
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_deity_grid.add_child(spin)
		_f_deity_levels.append(spin)

## ─── Animation Library Section ──────────────────────────────────────────────────

## Build an OptionButton with equipment filtered by kind
func _build_equip_selector(kind: int, label: String) -> OptionButton:
	var ob := OptionButton.new()
	ob.add_item("-1: None", -1)
	var equips: Array = _equip_by_kind.get(kind, [])
	for eq in equips:
		ob.add_item("%d: %s" % [eq["id"], eq["name"]], eq["id"])
	return ob

func _populate_form(entry: Dictionary) -> void:
	_f_name.text = str(entry.get("name", ""))
	_f_sprite.text = str(entry.get("sprite", ""))
	_anim_lib_state["line_edit"].text = str(entry.get("animationLibrary", ""))
	_f_is_leader.button_pressed = entry.get("isLeader", false)
	_f_enabled_by_default.button_pressed = entry.get("enabledByDefault", true)

	# Refresh animation preview if visible
	if _anim_lib_state.get("visible", false):
		_refresh_anim_lib_preview(_anim_lib_state)

	var class_id: int = int(entry.get("classId", 0))
	if class_id >= 0 and class_id < _f_class.item_count:
		_f_class.selected = class_id
	else:
		_f_class.selected = 0

	_f_level.value = entry.get("level", 1)

	# Refresh weapon dropdown: disable weapons already used by OTHER heroes
	_refresh_weapon_dropdown(entry)

	# Select equipment by ID in OptionButtons
	_select_equip_option(_f_head, int(entry.get("head", -1)))
	_select_equip_option(_f_body, int(entry.get("body", -1)))
	_select_equip_option(_f_accessory, int(entry.get("accessory", -1)))

	_f_hp_mult.value = entry.get("HPMultiplier", 3.8)
	_f_mp_mult.value = entry.get("MPMultiplier", 1.0)
	_f_mp_mult2.value = entry.get("MPMultiplier2", 1.0)
	_f_mp_div.value = entry.get("MPDivisor", 2.0)

	var magic_type: int = int(entry.get("enableMagic", 0))
	_f_magic_type.selected = clampi(magic_type, 0, maxi(0, _f_magic_type.item_count - 1))

	# Deity levels (array of N)
	var deity_arr: Array = entry.get("deityLevels", [])
	for i in range(_f_deity_levels.size()):
		if i < deity_arr.size():
			_f_deity_levels[i].value = int(deity_arr[i])
		else:
			_f_deity_levels[i].value = 0

	# Show/hide deity section based on magic type
	_update_deity_visibility()

## Select an item in an equipment OptionButton by its metadata ID
func _select_equip_option(ob: OptionButton, equip_id: int) -> void:
	for idx in range(ob.item_count):
		if ob.get_item_id(idx) == equip_id:
			ob.selected = idx
			return
	# If not found, select "None"
	ob.selected = 0

# --- Magic type visibility toggle ---

func _on_magic_type_changed(_index: int) -> void:
	_update_deity_visibility()

func _update_deity_visibility() -> void:
	# 0 = None → hide deity levels
	_deity_section.visible = _f_magic_type.selected != 0

# --- Leader exclusivity ---

## Override auto-save: when isLeader is true, remove it from all other heroes
func _auto_save() -> void:
	_save_timer.stop()
	if _current_index < 0 or _current_index >= _data.size():
		return
	_apply_form_to_current()

	# Enforce single leader: if current hero is leader, unset all others
	var current_entry: Dictionary = _data[_current_index]
	if current_entry.get("isLeader", false):
		for i in range(_data.size()):
			if i != _current_index:
				_data[i]["isLeader"] = false

	_save_data()
	_refresh_list(_search_field.text)

# --- Weapon exclusivity ---

## Rebuild weapon OptionButton, disabling weapons taken by other heroes
func _refresh_weapon_dropdown(current_entry: Dictionary) -> void:
	var current_hero_id: int = int(current_entry.get("id", -1))
	var current_weapon: int = int(current_entry.get("weapon", 0))

	# Collect weapons used by OTHER heroes
	var taken: Dictionary = {}  # weapon_id -> hero_name
	for hero in _data:
		var hid: int = int(hero.get("id", -1))
		if hid == current_hero_id:
			continue
		var wid: int = int(hero.get("weapon", -1))
		if wid >= 0:
			taken[wid] = str(hero.get("name", "hero_%d" % hid))

	# Rebuild items
	_f_weapon.clear()
	for i in range(_weapon_names.size()):
		var label: String
		if taken.has(i):
			label = "%d: %s  [%s]" % [i, _weapon_names[i], taken[i]]
		else:
			label = "%d: %s" % [i, _weapon_names[i]]
		_f_weapon.add_item(label, i)
		if taken.has(i):
			_f_weapon.set_item_disabled(_f_weapon.item_count - 1, true)

	# Select current weapon
	for idx in range(_f_weapon.item_count):
		if _f_weapon.get_item_id(idx) == current_weapon:
			_f_weapon.selected = idx
			break

func _collect_form_data() -> Dictionary:
	# Collect deity levels array
	var deity_arr := []
	for spin in _f_deity_levels:
		deity_arr.append(int(spin.value))

	return {
		"name": _f_name.text,
		"sprite": _f_sprite.text,
		"animationLibrary": _anim_lib_state["line_edit"].text,
		"isLeader": _f_is_leader.button_pressed,
		"enabledByDefault": _f_enabled_by_default.button_pressed,
		"classId": _f_class.get_selected_id(),
		"level": int(_f_level.value),
		"weapon": _f_weapon.get_selected_id(),
		"head": _f_head.get_selected_id(),
		"body": _f_body.get_selected_id(),
		"accessory": _f_accessory.get_selected_id(),
		"HPMultiplier": _f_hp_mult.value,
		"MPMultiplier": _f_mp_mult.value,
		"MPMultiplier2": _f_mp_mult2.value,
		"MPDivisor": _f_mp_div.value,
		"enableMagic": _f_magic_type.selected,
		"deityLevels": deity_arr,
	}

func _create_default_entry(id: int) -> Dictionary:
	var deity_arr := []
	for i in range(_elements_data.size()):
		deity_arr.append(0)
	return {
		"id": id,
		"name": "new_hero",
		"classId": 0,
		"weapon": 0,
		"head": -1,
		"body": -1,
		"accessory": -1,
		"level": 1,
		"HPMultiplier": 3.8,
		"MPMultiplier": 1.0,
		"MPMultiplier2": 1.0,
		"MPDivisor": 2.0,
		"enableMagic": 0,
		"deityLevels": deity_arr,
		"sprite": "",
		"isLeader": false,
		"enabledByDefault": true,
	}

## Load class names, equipment names, magic types, and elements for dropdowns
func _load_lookup_data() -> void:
	var classes := ManaJsonHelper.load_json("ally_classes.json")
	_class_names.clear()
	for c in classes:
		_class_names.append(str(c.get("name", "class_%d" % c.get("id", 0))))

	_equip_data = ManaJsonHelper.load_json("equipments.json")
	# Organize equipment by kind
	_equip_by_kind.clear()
	for eq in _equip_data:
		var kind: int = int(eq.get("kind", 0))
		var entry := {"id": int(eq.get("id", 0)), "name": str(eq.get("nameText", eq.get("name", "?")))}
		if not _equip_by_kind.has(kind):
			_equip_by_kind[kind] = []
		_equip_by_kind[kind].append(entry)

	var mt_data := ManaJsonHelper.load_json("magic_types.json")
	_magic_types.clear()
	for mt in mt_data:
		_magic_types.append("%s (%s)" % [mt.get("name", "?"), mt.get("id", "?")])

	_elements_data = ManaJsonHelper.load_json("elements.json")
