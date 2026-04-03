@tool
extends "res://addons/mana_magic_editor/editors/base_editor.gd"

## Editor for Magic Types (magic_types.json).
## Defines the magic schools available in the game (None, Black, White, Son of Mana, etc.)

var _f_name: LineEdit
var _f_description: TextEdit

func _get_json_filename() -> String:
	return "magic_types.json"

func _get_display_name(entry: Dictionary) -> String:
	return "%s - %s" % [entry.get("id", "?"), entry.get("name", "unnamed")]

func _build_form() -> void:
	_add_section_label("Magic Type")
	_f_name = _create_line_edit("Magic type name")
	_add_field("Name:", _f_name)
	_f_description = _create_text_edit(40)
	var desc_label := Label.new()
	desc_label.text = "Description:"
	desc_label.custom_minimum_size.x = 160
	_form_container.add_child(desc_label)
	_form_container.add_child(_f_description)

	_add_spacer()
	var hint := Label.new()
	hint.text = "ID 0 = No magic. Skills use magicKind matching these IDs.\nHeroes reference these IDs in their Magic Type field."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_form_container.add_child(hint)

func _populate_form(entry: Dictionary) -> void:
	_f_name.text = str(entry.get("name", ""))
	_f_description.text = str(entry.get("description", ""))

func _collect_form_data() -> Dictionary:
	return {
		"name": _f_name.text,
		"description": _f_description.text,
	}

func _create_default_entry(id: int) -> Dictionary:
	return {
		"id": id,
		"name": "New Magic Type",
		"description": "",
	}
