@tool
extends "res://addons/mana_magic_editor/editors/base_editor.gd"

var _f_name: LineEdit
var _f_name_text: LineEdit
var _f_subimage: SpinBox

func _get_json_filename() -> String:
	return "elements.json"

func _get_display_name(entry: Dictionary) -> String:
	return "%s - %s" % [entry.get("id", "?"), entry.get("nameText", entry.get("name", "?"))]

func _build_form() -> void:
	_add_section_label("Element / Deity")
	_f_name = _create_line_edit("Internal name")
	_add_field("Name:", _f_name)
	_f_name_text = _create_line_edit("Display name")
	_add_field("Display Name:", _f_name_text)
	_f_subimage = _create_spin(0, 999)
	_add_number_field("Subimage:", _f_subimage)

func _populate_form(entry: Dictionary) -> void:
	_f_name.text = str(entry.get("name", ""))
	_f_name_text.text = str(entry.get("nameText", ""))
	_f_subimage.value = entry.get("subimage", 0)

func _collect_form_data() -> Dictionary:
	return {
		"name": _f_name.text,
		"nameText": _f_name_text.text,
		"subimage": int(_f_subimage.value),
	}

func _create_default_entry(id: int) -> Dictionary:
	return {
		"id": id, "name": "new_element",
		"nameText": "New Element", "subimage": 0,
	}
