@tool
extends "res://addons/mana_magic_editor/editors/base_editor.gd"

var _f_name: LineEdit
var _f_name_text: LineEdit
var _f_description: TextEdit
var _f_subimage: SpinBox
var _f_subimage_total: SpinBox
var _f_kind: OptionButton
var _f_subkind: OptionButton
var _anim_lib_state: Dictionary = {}
var _anim_lib_section: VBoxContainer
var _f_price: SpinBox
var _f_classes: TextEdit
var _f_attributes: TextEdit
var _f_protection: Array = []  # Array of CheckBox
var _f_atunement: Array = []   # Array of CheckBox
var _f_weakness: Array = []    # Array of CheckBox

# Subkind container to show/hide based on kind
var _subkind_row: HBoxContainer

const KINDS := ["0 - Weapon", "1 - Head", "2 - Accessories", "3 - Body"]

# Subkind mapping: weapon subtypes
const SUBKINDS := [
	{"id": -1, "name": "None"},
	{"id": 19, "name": "Sword"},
	{"id": 20, "name": "Axe"},
	{"id": 21, "name": "Spear"},
	{"id": 22, "name": "Whip"},
	{"id": 23, "name": "Bow"},
	{"id": 24, "name": "Boomerang"},
	{"id": 25, "name": "Javelin"},
]

func _get_json_filename() -> String:
	return "equipments.json"

func _build_form() -> void:
	_add_section_label("Identity")
	_f_name = _create_line_edit("Internal name")
	_add_field("Name:", _f_name)
	_f_name_text = _create_line_edit("Display name")
	_add_field("Display Name:", _f_name_text)
	_f_description = _create_text_edit(40)
	_add_field("Description:", _f_description)

	_add_spacer()
	_add_section_label("Sprite")
	_f_subimage = _create_spin(0, 999)
	_add_number_field("Subimage:", _f_subimage)
	_f_subimage_total = _create_spin(0, 99)
	_add_number_field("Subimage Total:", _f_subimage_total)

	_add_spacer()
	_add_section_label("Equipment Type")
	_f_kind = _create_option_button(KINDS)
	_f_kind.item_selected.connect(_on_kind_changed)
	_add_field("Kind:", _f_kind)

	# Subkind as a selector (only visible for weapons)
	_f_subkind = OptionButton.new()
	for sk in SUBKINDS:
		_f_subkind.add_item("%d: %s" % [sk["id"], sk["name"]])
	_subkind_row = _add_field("Weapon Type:", _f_subkind)

	# Animation Library section (only for weapons)
	_anim_lib_section = VBoxContainer.new()
	_anim_lib_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_container.add_child(_anim_lib_section)
	# Temporarily redirect _form_container to build inside section
	var saved_container := _form_container
	_form_container = _anim_lib_section
	_add_spacer()
	_add_section_label("Weapon Animation")
	_anim_lib_state = _add_animation_library_section("res://assets/animations/weapons/")
	_form_container = saved_container

	_f_price = _create_spin(0, 999999)
	_add_number_field("Price:", _f_price)

	_add_spacer()
	_add_section_label("Class Restrictions (one class ID per line)")
	_f_classes = _create_text_edit(40)
	_form_container.add_child(_f_classes)
	var hint := Label.new()
	hint.text = "Class IDs: 1=warrior, 2=mage, 3=priest"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_form_container.add_child(hint)

	_add_spacer()
	_add_section_label("Attributes (one per line: id,value)")
	_f_attributes = _create_text_edit(50)
	_form_container.add_child(_f_attributes)
	var hint2 := Label.new()
	hint2.text = "Format: attribute_id,value (e.g. 1,150)"
	hint2.add_theme_font_size_override("font_size", 11)
	hint2.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_form_container.add_child(hint2)

	_add_spacer()
	_add_section_label("Elemental Affinities")
	_f_protection = _add_elemental_checkbox_field("Protections:")
	_f_atunement = _add_elemental_checkbox_field("Attunements:")
	_f_weakness = _add_elemental_checkbox_field("Weaknesses:")

func _on_kind_changed(_index: int) -> void:
	# Show subkind and animation library only for weapons (kind == 0)
	var is_weapon: bool = (_f_kind.selected == 0)
	_subkind_row.visible = is_weapon
	_anim_lib_section.visible = is_weapon

func _populate_form(entry: Dictionary) -> void:
	_f_name.text = str(entry.get("name", ""))
	_f_name_text.text = str(entry.get("nameText", ""))
	_f_description.text = str(entry.get("description", ""))
	_f_subimage.value = entry.get("subimage", 0)
	_f_subimage_total.value = entry.get("subimageTotal", 0)
	var kind_val = entry.get("kind", 0)
	_f_kind.selected = int(kind_val) if int(kind_val) >= 0 and int(kind_val) < KINDS.size() else 0

	# Select subkind by matching ID
	var subkind_val: int = int(entry.get("subkind", -1))
	_select_subkind(subkind_val)

	_f_price.value = entry.get("price", 0)

	# Show/hide subkind and animation library based on kind
	var is_weapon: bool = (_f_kind.selected == 0)
	_subkind_row.visible = is_weapon
	_anim_lib_section.visible = is_weapon
	_anim_lib_state["line_edit"].text = str(entry.get("animationLibrary", ""))
	if _anim_lib_state.get("visible", false):
		_refresh_anim_lib_preview(_anim_lib_state)

	# Classes array
	var classes: Array = entry.get("class", [])
	var class_lines := []
	for c in classes:
		class_lines.append(str(c))
	_f_classes.text = "\n".join(class_lines)
	# Attributes array of {id, value}
	var attrs: Array = entry.get("attributes", [])
	var attr_lines := []
	for a in attrs:
		if a is Dictionary:
			attr_lines.append("%s,%s" % [a.get("id", 0), a.get("value", 0)])
	_f_attributes.text = "\n".join(attr_lines)
	# Elemental checkboxes
	_set_elemental_checkboxes(_f_protection, entry.get("elementalProtection", []))
	_set_elemental_checkboxes(_f_atunement, entry.get("elementalAtunement", []))
	_set_elemental_checkboxes(_f_weakness, entry.get("elementalWeakness", []))

func _select_subkind(subkind_id: int) -> void:
	for i in range(SUBKINDS.size()):
		if SUBKINDS[i]["id"] == subkind_id:
			_f_subkind.selected = i
			return
	_f_subkind.selected = 0  # Default to "None"

func _get_selected_subkind_id() -> int:
	if _f_subkind.selected >= 0 and _f_subkind.selected < SUBKINDS.size():
		return SUBKINDS[_f_subkind.selected]["id"]
	return -1

func _collect_form_data() -> Dictionary:
	# Parse classes
	var classes := []
	for line in _f_classes.text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed != "" and trimmed.is_valid_int():
			classes.append(trimmed.to_int())
	# Parse attributes
	var attributes := []
	for line in _f_attributes.text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed == "":
			continue
		var parts := trimmed.split(",")
		if parts.size() >= 2:
			attributes.append({"id": parts[0].strip_edges().to_int(), "value": parts[1].strip_edges().to_int()})
	return {
		"name": _f_name.text,
		"nameText": _f_name_text.text,
		"description": _f_description.text,
		"subimage": int(_f_subimage.value),
		"subimageTotal": int(_f_subimage_total.value),
		"kind": _f_kind.selected,
		"subkind": _get_selected_subkind_id(),
		"class": classes,
		"attributes": attributes,
		"animationLibrary": _anim_lib_state["line_edit"].text,
		"auxData": {},
		"elementalProtection": _get_elemental_checkbox_ints(_f_protection),
		"elementalAtunement": _get_elemental_checkbox_ints(_f_atunement),
		"elementalWeakness": _get_elemental_checkbox_ints(_f_weakness),
		"price": int(_f_price.value),
	}

func _create_default_entry(id: int) -> Dictionary:
	return {
		"id": id, "name": "new_equipment", "nameText": "New Equipment",
		"description": "", "subimage": 0, "subimageTotal": 1,
		"kind": 0, "subkind": -1, "class": [1, 2, 3],
		"attributes": [], "auxData": {},
		"elementalProtection": [], "elementalAtunement": [], "elementalWeakness": [],
		"price": 100,
	}
