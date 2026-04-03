@tool
extends "res://addons/mana_magic_editor/editors/base_editor.gd"

var _enemy_classes: Array = []
var _anim_lib_state: Dictionary = {}

# Fields
var _f_name: LineEdit
var _f_name_text: LineEdit
var _f_info: TextEdit
var _f_class: OptionButton
var _f_passive: CheckBox
var _f_max_hp: SpinBox
var _f_max_mp: SpinBox
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
var _f_base_exp: SpinBox
var _f_base_money: SpinBox
var _f_grow_exp: SpinBox
var _f_grow_money: SpinBox
var _f_weakness: Array = []   # Array of CheckBox
var _f_protection: Array = [] # Array of CheckBox
var _f_atunement: Array = []  # Array of CheckBox

func _get_json_filename() -> String:
	return "monsters.json"

func _get_display_name(entry: Dictionary) -> String:
	var nt = entry.get("nameText", "")
	if nt != "" and nt != "DUMMY":
		return "%s - %s" % [entry.get("id", "?"), nt]
	return "%s - %s" % [entry.get("id", "?"), entry.get("name", "unnamed")]

func _build_form() -> void:
	_enemy_classes = ManaJsonHelper.load_json("enemy_classes.json")
	var class_names: Array = []
	for ec in _enemy_classes:
		class_names.append(ec.get("name", "?"))

	_add_section_label("Identity")
	_f_name = _create_line_edit("Internal name")
	_add_field("Name:", _f_name)
	_f_name_text = _create_line_edit("Display name")
	_add_field("Display Name:", _f_name_text)
	_f_info = _create_text_edit(50)
	_add_field("Description:", _f_info)
	_f_class = _create_option_button(class_names)
	_add_field("Class:", _f_class)
	_f_passive = _create_check_box("Passive")
	_add_field("Behavior:", _f_passive)

	_add_spacer()
	_add_section_label("Animation Library")
	_anim_lib_state = _add_animation_library_section("res://assets/animations/mobs/")

	_add_spacer()
	_add_section_label("Vitals")
	_f_max_hp = _create_spin(-1, 99999)
	_add_number_field("Max HP:", _f_max_hp)
	_f_max_mp = _create_spin(-1, 99999)
	_add_number_field("Max MP:", _f_max_mp)

	_add_spacer()
	_add_section_label("Base Stats")
	_f_base_str = _create_spin(-1, 999)
	_add_number_field("Strength:", _f_base_str)
	_f_base_con = _create_spin(-1, 999)
	_add_number_field("Constitution:", _f_base_con)
	_f_base_agi = _create_spin(-1, 999)
	_add_number_field("Agility:", _f_base_agi)
	_f_base_lck = _create_spin(-1, 999)
	_add_number_field("Luck:", _f_base_lck)
	_f_base_int = _create_spin(-1, 999)
	_add_number_field("Intelligence:", _f_base_int)
	_f_base_wis = _create_spin(-1, 999)
	_add_number_field("Wisdom:", _f_base_wis)

	_add_spacer()
	_add_section_label("Growth Rates")
	_f_grow_str = _create_spin(-1, 999)
	_add_number_field("STR Growth:", _f_grow_str)
	_f_grow_con = _create_spin(-1, 999)
	_add_number_field("CON Growth:", _f_grow_con)
	_f_grow_agi = _create_spin(-1, 999)
	_add_number_field("AGI Growth:", _f_grow_agi)
	_f_grow_lck = _create_spin(-1, 999)
	_add_number_field("LCK Growth:", _f_grow_lck)
	_f_grow_int = _create_spin(-1, 999)
	_add_number_field("INT Growth:", _f_grow_int)
	_f_grow_wis = _create_spin(-1, 999)
	_add_number_field("WIS Growth:", _f_grow_wis)

	_add_spacer()
	_add_section_label("Rewards")
	_f_base_exp = _create_spin(-1, 99999)
	_add_number_field("Base EXP:", _f_base_exp)
	_f_base_money = _create_spin(-1, 99999)
	_add_number_field("Base Money:", _f_base_money)
	_f_grow_exp = _create_spin(-1, 99999)
	_add_number_field("EXP Growth:", _f_grow_exp)
	_f_grow_money = _create_spin(-1, 99999)
	_add_number_field("Money Growth:", _f_grow_money)

	_add_spacer()
	_add_section_label("Elemental Affinities")
	_f_weakness = _add_elemental_checkbox_field("Weaknesses:")
	_f_protection = _add_elemental_checkbox_field("Protections:")
	_f_atunement = _add_elemental_checkbox_field("Attunements:")

func _populate_form(entry: Dictionary) -> void:
	_f_name.text = str(entry.get("name", ""))
	_f_name_text.text = str(entry.get("nameText", ""))
	_f_info.text = str(entry.get("info", ""))
	# Find class index
	var class_name_val = str(entry.get("class", "normal"))
	for i in range(_enemy_classes.size()):
		if _enemy_classes[i].get("name") == class_name_val:
			_f_class.selected = i
			break
	_f_passive.button_pressed = entry.get("passive", false)
	_anim_lib_state["line_edit"].text = str(entry.get("animationLibrary", ""))
	if _anim_lib_state.get("visible", false):
		_refresh_anim_lib_preview(_anim_lib_state)
	_f_max_hp.value = entry.get("max_hp", 0)
	_f_max_mp.value = entry.get("max_mp", -1)
	_f_base_str.value = entry.get("base_strength", -1)
	_f_base_con.value = entry.get("base_constitution", -1)
	_f_base_agi.value = entry.get("base_agility", -1)
	_f_base_lck.value = entry.get("base_luck", -1)
	_f_base_int.value = entry.get("base_intelligence", -1)
	_f_base_wis.value = entry.get("base_wisdom", -1)
	_f_grow_str.value = entry.get("growth_strength", -1)
	_f_grow_con.value = entry.get("growth_constitution", -1)
	_f_grow_agi.value = entry.get("growth_agility", -1)
	_f_grow_lck.value = entry.get("growth_luck", -1)
	_f_grow_int.value = entry.get("growth_intelligence", -1)
	_f_grow_wis.value = entry.get("growth_wisdom", -1)
	_f_base_exp.value = entry.get("base_experience", -1)
	_f_base_money.value = entry.get("base_money", -1)
	_f_grow_exp.value = entry.get("growth_experience", -1)
	_f_grow_money.value = entry.get("growth_money", -1)
	_set_elemental_checkboxes(_f_weakness, entry.get("magic_weakness", []))
	_set_elemental_checkboxes(_f_protection, entry.get("magic_protection", []))
	_set_elemental_checkboxes(_f_atunement, entry.get("magic_atunement", []))

func _collect_form_data() -> Dictionary:
	var class_name_val := "normal"
	if _f_class.selected >= 0 and _f_class.selected < _enemy_classes.size():
		class_name_val = _enemy_classes[_f_class.selected].get("name", "normal")
	return {
		"name": _f_name.text,
		"nameText": _f_name_text.text,
		"info": _f_info.text,
		"class": class_name_val,
		"passive": _f_passive.button_pressed,
		"animationLibrary": _anim_lib_state["line_edit"].text,
		"max_hp": int(_f_max_hp.value),
		"max_mp": int(_f_max_mp.value),
		"base_strength": int(_f_base_str.value),
		"base_constitution": int(_f_base_con.value),
		"base_agility": int(_f_base_agi.value),
		"base_luck": int(_f_base_lck.value),
		"base_intelligence": int(_f_base_int.value),
		"base_wisdom": int(_f_base_wis.value),
		"growth_strength": int(_f_grow_str.value),
		"growth_constitution": int(_f_grow_con.value),
		"growth_agility": int(_f_grow_agi.value),
		"growth_luck": int(_f_grow_lck.value),
		"growth_intelligence": int(_f_grow_int.value),
		"growth_wisdom": int(_f_grow_wis.value),
		"base_experience": int(_f_base_exp.value),
		"base_money": int(_f_base_money.value),
		"growth_experience": int(_f_grow_exp.value),
		"growth_money": int(_f_grow_money.value),
		"magic_weakness": _get_elemental_checkbox_strings(_f_weakness),
		"magic_protection": _get_elemental_checkbox_strings(_f_protection),
		"magic_atunement": _get_elemental_checkbox_strings(_f_atunement),
	}

func _create_default_entry(id: int) -> Dictionary:
	return {
		"id": id, "nameText": "New Monster", "name": "new_monster", "info": "",
		"class": "normal", "passive": false,
		"max_hp": 100, "max_mp": -1,
		"base_strength": -1, "base_constitution": -1, "base_agility": -1,
		"base_luck": -1, "base_intelligence": -1, "base_wisdom": -1,
		"base_experience": -1, "base_money": -1,
		"growth_strength": -1, "growth_constitution": -1, "growth_agility": -1,
		"growth_luck": -1, "growth_intelligence": -1, "growth_wisdom": -1,
		"growth_experience": -1, "growth_money": -1,
		"magic_weakness": [], "magic_protection": [], "magic_atunement": [],
		"experience": -1, "money": -1,
	}
