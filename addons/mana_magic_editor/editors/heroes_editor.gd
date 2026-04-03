@tool
extends "res://addons/mana_magic_editor/editors/base_editor.gd"

# Fields
var _f_name: LineEdit
var _f_base_str: SpinBox
var _f_base_con: SpinBox
var _f_base_agi: SpinBox
var _f_base_lck: SpinBox
var _f_base_int: SpinBox
var _f_base_wis: SpinBox
var _f_grow_str: SpinBox
var _f_grow_con: SpinBox
var _f_grow_agi: SpinBox
var _f_grow_lck: SpinBox
var _f_grow_int: SpinBox
var _f_grow_wis: SpinBox
var _f_weakness: Array = []   # Array of CheckBox
var _f_protection: Array = [] # Array of CheckBox
var _f_atunement: Array = []  # Array of CheckBox

func _get_json_filename() -> String:
	return "ally_classes.json"

func _get_display_name(entry: Dictionary) -> String:
	return "%s - %s" % [entry.get("id", "?"), entry.get("name", "unnamed")]

func _build_form() -> void:
	_add_section_label("General")
	_f_name = _create_line_edit("Class name")
	_add_field("Name:", _f_name)

	_add_spacer()
	_add_section_label("Base Stats")
	_f_base_str = _create_spin(0, 999)
	_add_number_field("Strength:", _f_base_str)
	_f_base_con = _create_spin(0, 999)
	_add_number_field("Constitution:", _f_base_con)
	_f_base_agi = _create_spin(0, 999)
	_add_number_field("Agility:", _f_base_agi)
	_f_base_lck = _create_spin(0, 999)
	_add_number_field("Luck:", _f_base_lck)
	_f_base_int = _create_spin(0, 999)
	_add_number_field("Intelligence:", _f_base_int)
	_f_base_wis = _create_spin(0, 999)
	_add_number_field("Wisdom:", _f_base_wis)

	_add_spacer()
	_add_section_label("Growth Multipliers")
	_f_grow_str = _create_spin(0, 10, 0.1)
	_add_number_field("STR Growth:", _f_grow_str)
	_f_grow_con = _create_spin(0, 10, 0.1)
	_add_number_field("CON Growth:", _f_grow_con)
	_f_grow_agi = _create_spin(0, 10, 0.1)
	_add_number_field("AGI Growth:", _f_grow_agi)
	_f_grow_lck = _create_spin(0, 10, 0.1)
	_add_number_field("LCK Growth:", _f_grow_lck)
	_f_grow_int = _create_spin(0, 10, 0.1)
	_add_number_field("INT Growth:", _f_grow_int)
	_f_grow_wis = _create_spin(0, 10, 0.1)
	_add_number_field("WIS Growth:", _f_grow_wis)

	_add_spacer()
	_add_section_label("Elemental Affinities")
	_f_weakness = _add_elemental_checkbox_field("Weaknesses:")
	_f_protection = _add_elemental_checkbox_field("Protections:")
	_f_atunement = _add_elemental_checkbox_field("Attunements:")

func _populate_form(entry: Dictionary) -> void:
	_f_name.text = str(entry.get("name", ""))
	_f_base_str.value = entry.get("base_strength", 0)
	_f_base_con.value = entry.get("base_constitution", 0)
	_f_base_agi.value = entry.get("base_agility", 0)
	_f_base_lck.value = entry.get("base_luck", 0)
	_f_base_int.value = entry.get("base_intelligence", 0)
	_f_base_wis.value = entry.get("base_wisdom", 0)
	_f_grow_str.value = entry.get("growth_strength", 0)
	_f_grow_con.value = entry.get("growth_constitution", 0)
	_f_grow_agi.value = entry.get("growth_agility", 0)
	_f_grow_lck.value = entry.get("growth_luck", 0)
	_f_grow_int.value = entry.get("growth_intelligence", 0)
	_f_grow_wis.value = entry.get("growth_wisdom", 0)
	_set_elemental_checkboxes(_f_weakness, entry.get("magic_weakness", []))
	_set_elemental_checkboxes(_f_protection, entry.get("magic_protection", []))
	_set_elemental_checkboxes(_f_atunement, entry.get("magic_atunement", []))

func _collect_form_data() -> Dictionary:
	return {
		"name": _f_name.text,
		"base_strength": int(_f_base_str.value),
		"base_constitution": int(_f_base_con.value),
		"base_agility": int(_f_base_agi.value),
		"base_luck": int(_f_base_lck.value),
		"base_intelligence": int(_f_base_int.value),
		"base_wisdom": int(_f_base_wis.value),
		"growth_strength": _f_grow_str.value,
		"growth_constitution": _f_grow_con.value,
		"growth_agility": _f_grow_agi.value,
		"growth_luck": _f_grow_lck.value,
		"growth_intelligence": _f_grow_int.value,
		"growth_wisdom": _f_grow_wis.value,
		"magic_weakness": _get_elemental_checkbox_strings(_f_weakness),
		"magic_protection": _get_elemental_checkbox_strings(_f_protection),
		"magic_atunement": _get_elemental_checkbox_strings(_f_atunement),
	}

func _create_default_entry(id: int) -> Dictionary:
	return {
		"id": id, "name": "new_class",
		"base_strength": 5, "base_constitution": 5, "base_agility": 5,
		"base_luck": 5, "base_intelligence": 5, "base_wisdom": 5,
		"growth_strength": 1.5, "growth_constitution": 1.5, "growth_agility": 1.5,
		"growth_luck": 1.5, "growth_intelligence": 1.5, "growth_wisdom": 1.5,
		"magic_weakness": [], "magic_protection": [], "magic_atunement": [],
	}
