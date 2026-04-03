@tool
extends "res://addons/mana_magic_editor/editors/base_editor.gd"

var _f_name: LineEdit
var _f_name_text: LineEdit
var _f_description: TextEdit
var _f_max_quantity: SpinBox
var _f_price: SpinBox
var _f_target: OptionButton
var _f_target_quantity: OptionButton
var _f_unique_group: CheckBox
var _f_value1: OptionButton
var _f_value2: LineEdit
var _f_value3: LineEdit
var _f_value4: LineEdit

## Sections MAGIC and ETC are managed by other editors (Skills, system).
## This editor only shows ITEM entries.
const HIDDEN_SECTIONS := ["MAGIC", "ETC"]
const TARGETS := ["ALLY", "ENEMY", "ALL_ALLIES", "ALL_ENEMIES", "SELF"]
const TARGET_QUANTITIES := ["TARGET_QUANTITY_ONE", "TARGET_QUANTITY_ALL"]

## Known item effect types
const EFFECT_TYPES := ["", "hp_add", "mp_add", "recover", "revive", "addStatus"]

func _get_json_filename() -> String:
	return "items.json"

func _refresh_list(filter: String = "") -> void:
	_item_list.clear()
	var search := filter.to_lower()
	for i in range(_data.size()):
		var entry: Dictionary = _data[i]
		# Hide MAGIC and ETC sections — managed elsewhere
		var section: String = str(entry.get("section", ""))
		if section in HIDDEN_SECTIONS:
			continue
		var display := _get_display_name(entry)
		if search != "" and display.to_lower().find(search) == -1:
			continue
		_item_list.add_item(display)
		_item_list.set_item_metadata(_item_list.item_count - 1, i)
	if _item_list.item_count > 0 and _current_index < 0:
		_item_list.select(0)
		_on_item_selected(0)

func _build_form() -> void:
	_add_section_label("Identity")
	_f_name = _create_line_edit("Internal name")
	_add_field("Name:", _f_name)
	_f_name_text = _create_line_edit("Display name")
	_add_field("Display Name:", _f_name_text)
	_f_description = _create_text_edit(40)
	_add_field("Description:", _f_description)

	_add_spacer()
	_add_section_label("Properties")
	_f_max_quantity = _create_spin(0, 99)
	_add_number_field("Max Quantity:", _f_max_quantity)
	_f_price = _create_spin(0, 999999)
	_add_number_field("Price:", _f_price)

	_add_spacer()
	_add_section_label("Targeting")
	_f_target = _create_option_button(TARGETS)
	_add_field("Target:", _f_target)
	_f_target_quantity = _create_option_button(TARGET_QUANTITIES)
	_add_field("Target Qty:", _f_target_quantity)
	_f_unique_group = _create_check_box("Unique Group Effect")
	_add_field("Unique:", _f_unique_group)

	_add_spacer()
	_add_section_label("Effects")
	_f_value1 = _create_option_button(EFFECT_TYPES)
	_add_field("Effect:", _f_value1)
	_f_value2 = _create_line_edit("e.g. 100")
	_add_field("Value 2:", _f_value2)
	_f_value3 = _create_line_edit("")
	_add_field("Value 3:", _f_value3)
	_f_value4 = _create_line_edit("")
	_add_field("Value 4:", _f_value4)

func _populate_form(entry: Dictionary) -> void:
	_f_name.text = str(entry.get("name", ""))
	_f_name_text.text = str(entry.get("nameText", ""))
	_f_description.text = str(entry.get("description", ""))
	_f_max_quantity.value = entry.get("maxQuantity", 0)
	_f_price.value = entry.get("price", 0)
	var tgt_idx := TARGETS.find(str(entry.get("target", "ALLY")))
	_f_target.selected = tgt_idx if tgt_idx >= 0 else 0
	var tqt_idx := TARGET_QUANTITIES.find(str(entry.get("targetQuantity", "TARGET_QUANTITY_ONE")))
	_f_target_quantity.selected = tqt_idx if tqt_idx >= 0 else 0
	_f_unique_group.button_pressed = entry.get("uniqueGroupEffect", false)

	# Effect type selector
	var v1 := str(entry.get("value1", ""))
	var v1_idx := EFFECT_TYPES.find(v1)
	_f_value1.selected = v1_idx if v1_idx >= 0 else 0

	_f_value2.text = str(entry.get("value2", ""))
	_f_value3.text = str(entry.get("value3", ""))
	_f_value4.text = str(entry.get("value4", ""))

func _collect_form_data() -> Dictionary:
	var effect: String = EFFECT_TYPES[_f_value1.selected] if _f_value1.selected >= 0 and _f_value1.selected < EFFECT_TYPES.size() else ""
	return {
		"name": _f_name.text,
		"nameText": _f_name_text.text,
		"description": _f_description.text,
		"maxQuantity": int(_f_max_quantity.value),
		"section": "ITEM",
		"quantity": 0,
		"subSection": "",
		"value1": effect,
		"value2": _parse_value(_f_value2.text),
		"value3": _parse_value(_f_value3.text),
		"value4": _parse_value(_f_value4.text),
		"target": TARGETS[_f_target.selected] if _f_target.selected >= 0 else "ALLY",
		"targetQuantity": TARGET_QUANTITIES[_f_target_quantity.selected] if _f_target_quantity.selected >= 0 else "TARGET_QUANTITY_ONE",
		"targetCondition": [],
		"uniqueGroupEffect": _f_unique_group.button_pressed,
		"price": int(_f_price.value),
	}

func _create_default_entry(id: int) -> Dictionary:
	return {
		"id": id, "name": "new_item", "nameText": "New Item",
		"description": "", "maxQuantity": 99, "section": "ITEM",
		"quantity": 0, "subSection": "",
		"value1": "", "value2": "", "value3": "", "value4": "",
		"target": "ALLY", "targetQuantity": "TARGET_QUANTITY_ONE",
		"targetCondition": [], "uniqueGroupEffect": false, "price": 0,
	}

static func _parse_value(text: String):
	if text == "":
		return ""
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text
