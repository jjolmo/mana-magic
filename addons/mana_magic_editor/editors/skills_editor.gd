@tool
extends VBoxContainer

## Skills/Magic editor organized by deity groups.
## Left panel: deity groups list (top) + skills in selected group (bottom).
## Right panel: edit form for the selected skill.
## Manages both elements.json (deity groups) and skills.json (skills).

var _elements_data: Array = []  # elements.json
var _skills_data: Array = []     # skills.json
var _selected_deity: String = ""
var _selected_skill_index: int = -1

# UI - Left panel
var _groups_toolbar: HBoxContainer
var _btn_add_group: Button
var _btn_remove_group: Button
var _btn_rename_group: Button
var _groups_list: ItemList

var _skills_toolbar: HBoxContainer
var _btn_add_skill: Button
var _btn_duplicate_skill: Button
var _btn_remove_skill: Button
var _skills_list: ItemList

# UI - Right panel
var _scroll: ScrollContainer
var _form: VBoxContainer

# Form fields
var _f_name: LineEdit
var _f_name_text: LineEdit
var _f_description: TextEdit
var _f_subimage: SpinBox
var _f_subimage_total: SpinBox
var _f_mp: SpinBox
var _f_magic_kind: OptionButton
var _f_target: OptionButton
var _f_target_quantity: OptionButton
var _f_enabled: CheckBox
var _f_unique_group: CheckBox
var _f_type: TextEdit
var _f_value1: SpinBox
var _f_value1_name: LineEdit
var _f_value2: SpinBox
var _f_value2_name: LineEdit
var _f_value3: SpinBox
var _f_value3_name: LineEdit
var _f_value4: SpinBox
var _f_value4_name: LineEdit

# Status
var _status_label: Label
var _btn_save: Button

var _magic_kinds_labels: Array = []  # loaded from magic_types.json
const TARGETS := ["ALLY", "ENEMY", "ALL_ALLIES", "ALL_ENEMIES", "SELF"]
const TARGET_QUANTITIES := ["TARGET_QUANTITY_ONE", "TARGET_QUANTITY_ALL"]

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_magic_kinds()
	_build_ui()
	_load_data()

func _build_ui() -> void:
	# Top toolbar with save
	var top_bar := HBoxContainer.new()
	add_child(top_bar)
	_btn_save = Button.new()
	_btn_save.text = "  Save All  "
	_btn_save.pressed.connect(_on_save_all)
	top_bar.add_child(_btn_save)

	# Main split: groups | skills | form
	var main_split := HSplitContainer.new()
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.split_offset = 180
	add_child(main_split)

	# --- Deity Groups column ---
	var groups_vbox := VBoxContainer.new()
	groups_vbox.custom_minimum_size.x = 160
	groups_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_child(groups_vbox)

	var groups_label := Label.new()
	groups_label.text = "Magic Groups (Deities)"
	groups_label.add_theme_font_size_override("font_size", 14)
	groups_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	groups_vbox.add_child(groups_label)

	_groups_toolbar = HBoxContainer.new()
	groups_vbox.add_child(_groups_toolbar)

	_btn_add_group = Button.new()
	_btn_add_group.text = "+ Group"
	_btn_add_group.pressed.connect(_on_add_group)
	_groups_toolbar.add_child(_btn_add_group)

	_btn_rename_group = Button.new()
	_btn_rename_group.text = "Rename"
	_btn_rename_group.pressed.connect(_on_rename_group)
	_groups_toolbar.add_child(_btn_rename_group)

	_btn_remove_group = Button.new()
	_btn_remove_group.text = "- Group"
	_btn_remove_group.pressed.connect(_on_remove_group)
	_groups_toolbar.add_child(_btn_remove_group)

	_groups_list = ItemList.new()
	_groups_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_groups_list.item_selected.connect(_on_group_selected)
	groups_vbox.add_child(_groups_list)

	# --- Skills in group column ---
	var skills_split := HSplitContainer.new()
	skills_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_split.split_offset = 200
	main_split.add_child(skills_split)

	var skills_vbox := VBoxContainer.new()
	skills_vbox.custom_minimum_size.x = 180
	skills_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skills_split.add_child(skills_vbox)

	var skills_label := Label.new()
	skills_label.text = "Skills in Group"
	skills_label.add_theme_font_size_override("font_size", 14)
	skills_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	skills_vbox.add_child(skills_label)

	_skills_toolbar = HBoxContainer.new()
	skills_vbox.add_child(_skills_toolbar)

	_btn_add_skill = Button.new()
	_btn_add_skill.text = "+ Skill"
	_btn_add_skill.pressed.connect(_on_add_skill)
	_skills_toolbar.add_child(_btn_add_skill)

	_btn_duplicate_skill = Button.new()
	_btn_duplicate_skill.text = "Duplicate"
	_btn_duplicate_skill.pressed.connect(_on_duplicate_skill)
	_skills_toolbar.add_child(_btn_duplicate_skill)

	_btn_remove_skill = Button.new()
	_btn_remove_skill.text = "- Skill"
	_btn_remove_skill.pressed.connect(_on_remove_skill)
	_skills_toolbar.add_child(_btn_remove_skill)

	_skills_list = ItemList.new()
	_skills_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skills_list.item_selected.connect(_on_skill_selected)
	skills_vbox.add_child(_skills_list)

	# --- Right panel: skill form ---
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skills_split.add_child(_scroll)

	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_form)

	_build_skill_form()

	# Start with form hidden until a skill is selected
	_scroll.visible = false

	# Status bar
	_status_label = Label.new()
	_status_label.text = ""
	add_child(_status_label)

func _build_skill_form() -> void:
	_add_section("Identity")
	_f_name = _make_line_edit("Internal name")
	_add_form_field("Name:", _f_name)
	_f_name_text = _make_line_edit("Display name")
	_add_form_field("Display Name:", _f_name_text)
	_f_description = _make_text_edit(40)
	_add_form_field("Description:", _f_description)
	_f_enabled = CheckBox.new()
	_f_enabled.text = "Enabled"
	_add_form_field("Enabled:", _f_enabled)

	_add_form_spacer()
	_add_section("Sprite")
	_f_subimage = _make_spin(0, 999)
	_add_form_field("Subimage:", _f_subimage)
	_f_subimage_total = _make_spin(0, 99)
	_add_form_field("Subimage Total:", _f_subimage_total)

	_add_form_spacer()
	_add_section("Magic Properties")
	_f_mp = _make_spin(0, 999)
	_add_form_field("MP Cost:", _f_mp)
	_f_magic_kind = _make_option_button(_magic_kinds_labels)
	_add_form_field("Magic Kind:", _f_magic_kind)

	_add_form_spacer()
	_add_section("Skill Type (one per line)")
	_f_type = _make_text_edit(60)
	_form.add_child(_f_type)
	var hint := Label.new()
	hint.text = "DAMAGE, STATUS_BUFF, STATUS_DEBUFF, HEAL, DRAIN, SUMMON, STATUS_BUFF_WEAPON_*, STATUS_*"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_form.add_child(hint)

	_add_form_spacer()
	_add_section("Targeting")
	_f_target = _make_option_button(TARGETS)
	_add_form_field("Target:", _f_target)
	_f_target_quantity = _make_option_button(TARGET_QUANTITIES)
	_add_form_field("Target Qty:", _f_target_quantity)
	_f_unique_group = CheckBox.new()
	_f_unique_group.text = "Unique Group Effect"
	_add_form_field("Unique:", _f_unique_group)

	_add_form_spacer()
	_add_section("Values")
	_f_value1 = _make_spin(-999, 99999)
	_add_form_field("Value 1:", _f_value1)
	_f_value1_name = _make_line_edit("e.g. hp_multiplier")
	_add_form_field("Value 1 Name:", _f_value1_name)
	_f_value2 = _make_spin(-999, 99999)
	_add_form_field("Value 2:", _f_value2)
	_f_value2_name = _make_line_edit("")
	_add_form_field("Value 2 Name:", _f_value2_name)
	_f_value3 = _make_spin(-999, 99999)
	_add_form_field("Value 3:", _f_value3)
	_f_value3_name = _make_line_edit("")
	_add_form_field("Value 3 Name:", _f_value3_name)
	_f_value4 = _make_spin(-999, 99999)
	_add_form_field("Value 4:", _f_value4)
	_f_value4_name = _make_line_edit("")
	_add_form_field("Value 4 Name:", _f_value4_name)

# --- Data ---

func _load_data() -> void:
	_elements_data = ManaJsonHelper.load_json("elements.json")
	_skills_data = ManaJsonHelper.load_json("skills.json")
	_load_magic_kinds()
	_refresh_groups()
	_status_label.text = "Loaded %d deity groups, %d skills" % [_elements_data.size(), _skills_data.size()]

func _load_magic_kinds() -> void:
	var mt_data := ManaJsonHelper.load_json("magic_types.json")
	_magic_kinds_labels.clear()
	for mt in mt_data:
		_magic_kinds_labels.append("%s - %s" % [mt.get("id", "?"), mt.get("name", "?")])
	# Rebuild magic kind dropdown if it exists
	if _f_magic_kind:
		var prev := _f_magic_kind.selected
		_f_magic_kind.clear()
		for label in _magic_kinds_labels:
			_f_magic_kind.add_item(label)
		if prev >= 0 and prev < _f_magic_kind.item_count:
			_f_magic_kind.selected = prev

func _refresh_groups() -> void:
	_groups_list.clear()
	for elem in _elements_data:
		var deity_name: String = elem.get("nameText", elem.get("name", "?"))
		var skill_count := _count_skills_for_deity(elem.get("name", ""))
		_groups_list.add_item("%s (%d skills)" % [deity_name, skill_count])
	if _groups_list.item_count > 0 and _selected_deity == "":
		_groups_list.select(0)
		_on_group_selected(0)

func _refresh_skills_for_deity() -> void:
	_skills_list.clear()
	_selected_skill_index = -1
	_scroll.visible = false
	if _selected_deity == "":
		return
	for i in range(_skills_data.size()):
		var skill: Dictionary = _skills_data[i]
		if _deity_matches(skill.get("deity", ""), _selected_deity):
			var display := "%s - %s" % [skill.get("id", "?"), skill.get("nameText", skill.get("name", "?"))]
			_skills_list.add_item(display)
			_skills_list.set_item_metadata(_skills_list.item_count - 1, i)

func _count_skills_for_deity(deity_name: String) -> int:
	var count := 0
	for skill in _skills_data:
		if _deity_matches(skill.get("deity", ""), deity_name):
			count += 1
	return count

func _deity_matches(skill_deity: String, element_name: String) -> bool:
	return skill_deity.to_lower() == element_name.to_lower()

func _get_deity_name_for_index(idx: int) -> String:
	if idx >= 0 and idx < _elements_data.size():
		return _elements_data[idx].get("name", "")
	return ""

func _get_deity_display_for_index(idx: int) -> String:
	if idx >= 0 and idx < _elements_data.size():
		return _elements_data[idx].get("nameText", _elements_data[idx].get("name", ""))
	return ""

# --- Group actions ---

func _on_group_selected(index: int) -> void:
	_selected_deity = _get_deity_name_for_index(index)
	_refresh_skills_for_deity()

func _on_add_group() -> void:
	var new_id := ManaJsonHelper.get_next_id(_elements_data)
	var new_elem := {
		"id": new_id,
		"name": "new_deity_%d" % new_id,
		"nameText": "New Deity",
		"subimage": 0,
	}
	_elements_data.append(new_elem)
	_refresh_groups()
	# Select the new group
	_groups_list.select(_groups_list.item_count - 1)
	_on_group_selected(_groups_list.item_count - 1)
	_status_label.text = "Added new deity group '%s'" % new_elem["nameText"]

func _on_rename_group() -> void:
	var selected := _groups_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= _elements_data.size():
		return
	# Use a popup for renaming
	var dialog := AcceptDialog.new()
	dialog.title = "Rename Deity Group"
	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)
	var lbl_name := Label.new()
	lbl_name.text = "Internal name:"
	vbox.add_child(lbl_name)
	var edit_name := LineEdit.new()
	edit_name.text = _elements_data[idx].get("name", "")
	vbox.add_child(edit_name)
	var lbl_display := Label.new()
	lbl_display.text = "Display name:"
	vbox.add_child(lbl_display)
	var edit_display := LineEdit.new()
	edit_display.text = _elements_data[idx].get("nameText", "")
	vbox.add_child(edit_display)
	var lbl_subimage := Label.new()
	lbl_subimage.text = "Subimage:"
	vbox.add_child(lbl_subimage)
	var edit_subimage := SpinBox.new()
	edit_subimage.min_value = 0
	edit_subimage.max_value = 999
	edit_subimage.value = _elements_data[idx].get("subimage", 0)
	vbox.add_child(edit_subimage)

	dialog.confirmed.connect(func():
		var old_name: String = _elements_data[idx].get("name", "")
		var new_name: String = edit_name.text
		var new_display: String = edit_display.text
		_elements_data[idx]["name"] = new_name
		_elements_data[idx]["nameText"] = new_display
		_elements_data[idx]["subimage"] = int(edit_subimage.value)
		# Update all skills that reference the old deity name
		if old_name != new_name:
			for skill in _skills_data:
				if _deity_matches(skill.get("deity", ""), old_name):
					# Preserve original casing style: capitalize first letter
					skill["deity"] = new_name.substr(0, 1).to_upper() + new_name.substr(1)
		_selected_deity = new_name
		_refresh_groups()
		_refresh_skills_for_deity()
		_status_label.text = "Renamed deity group to '%s'" % new_display
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(300, 250))

func _on_remove_group() -> void:
	var selected := _groups_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= _elements_data.size():
		return
	var deity_name: String = _elements_data[idx].get("name", "")
	var skill_count := _count_skills_for_deity(deity_name)
	if skill_count > 0:
		var dialog := AcceptDialog.new()
		dialog.title = "Cannot Remove"
		dialog.dialog_text = "Cannot remove deity '%s' — it still has %d skills.\nRemove all skills in this group first." % [deity_name, skill_count]
		dialog.confirmed.connect(func(): dialog.queue_free())
		dialog.canceled.connect(func(): dialog.queue_free())
		add_child(dialog)
		dialog.popup_centered()
		return
	_elements_data.remove_at(idx)
	_selected_deity = ""
	_refresh_groups()
	_skills_list.clear()
	_status_label.text = "Removed deity group '%s'" % deity_name

# --- Skill actions ---

func _on_skill_selected(index: int) -> void:
	if index < 0 or index >= _skills_list.item_count:
		_scroll.visible = false
		return
	var data_idx: int = _skills_list.get_item_metadata(index)
	if data_idx < 0 or data_idx >= _skills_data.size():
		_scroll.visible = false
		return
	_selected_skill_index = data_idx
	_scroll.visible = true
	_populate_form(_skills_data[_selected_skill_index])

func _on_add_skill() -> void:
	if _selected_deity == "":
		_status_label.text = "Select a deity group first"
		return
	var new_id := ManaJsonHelper.get_next_id(_skills_data)
	# Capitalize deity name for the JSON field
	var deity_capitalized := _selected_deity.substr(0, 1).to_upper() + _selected_deity.substr(1)
	var new_skill := {
		"id": new_id, "name": "new_skill_%d" % new_id, "nameText": "New Skill",
		"description": "", "subimage": 0, "subimageTotal": 2,
		"mp": 1, "deity": deity_capitalized, "magicKind": 1,
		"type": ["DAMAGE"], "value1": 0, "value2": 0, "value3": 0, "value4": 0,
		"value1_name": "", "value2_name": "", "value3_name": "", "value4_name": "",
		"target": "ENEMY", "targetQuantity": "TARGET_QUANTITY_ONE",
		"targetCondition": [], "uniqueGroupEffect": false, "enabled": true,
	}
	_skills_data.append(new_skill)
	_refresh_skills_for_deity()
	_refresh_groups()
	# Select the new skill
	for i in range(_skills_list.item_count):
		if _skills_list.get_item_metadata(i) == _skills_data.size() - 1:
			_skills_list.select(i)
			_on_skill_selected(i)
			break
	_status_label.text = "Added new skill in group '%s'" % deity_capitalized

func _on_duplicate_skill() -> void:
	if _selected_skill_index < 0 or _selected_skill_index >= _skills_data.size():
		return
	var source: Dictionary = _skills_data[_selected_skill_index].duplicate(true)
	var new_id := ManaJsonHelper.get_next_id(_skills_data)
	source["id"] = new_id
	source["name"] = str(source.get("name", "")) + "_copy"
	source["nameText"] = str(source.get("nameText", "")) + " (Copy)"
	_skills_data.append(source)
	_refresh_skills_for_deity()
	_refresh_groups()
	for i in range(_skills_list.item_count):
		if _skills_list.get_item_metadata(i) == _skills_data.size() - 1:
			_skills_list.select(i)
			_on_skill_selected(i)
			break
	_status_label.text = "Duplicated skill as ID %d" % new_id

func _on_remove_skill() -> void:
	if _selected_skill_index < 0 or _selected_skill_index >= _skills_data.size():
		return
	_skills_data.remove_at(_selected_skill_index)
	_selected_skill_index = -1
	_refresh_skills_for_deity()
	_refresh_groups()
	_status_label.text = "Skill removed"

# --- Save ---

func _on_save_all() -> void:
	_apply_form_to_current()
	ManaJsonHelper.save_json("elements.json", _elements_data)
	ManaJsonHelper.save_json("skills.json", _skills_data)
	_refresh_groups()
	_refresh_skills_for_deity()
	_status_label.text = "Saved %d deity groups and %d skills" % [_elements_data.size(), _skills_data.size()]

func _apply_form_to_current() -> void:
	if _selected_skill_index < 0 or _selected_skill_index >= _skills_data.size():
		return
	var form_data := _collect_form_data()
	var entry: Dictionary = _skills_data[_selected_skill_index]
	for key in form_data:
		entry[key] = form_data[key]

# --- Form population / collection ---

func _populate_form(entry: Dictionary) -> void:
	_f_name.text = str(entry.get("name", ""))
	_f_name_text.text = str(entry.get("nameText", ""))
	_f_description.text = str(entry.get("description", ""))
	_f_enabled.button_pressed = entry.get("enabled", true)
	_f_subimage.value = entry.get("subimage", 0)
	_f_subimage_total.value = entry.get("subimageTotal", 0)
	_f_mp.value = entry.get("mp", 0)
	var mk = entry.get("magicKind", 0)
	_f_magic_kind.selected = int(mk) if int(mk) >= 0 and int(mk) < _f_magic_kind.item_count else 0
	var types: Array = entry.get("type", [])
	_f_type.text = "\n".join(types)
	var tgt_idx := TARGETS.find(str(entry.get("target", "ALLY")))
	_f_target.selected = tgt_idx if tgt_idx >= 0 else 0
	var tqt_idx := TARGET_QUANTITIES.find(str(entry.get("targetQuantity", "TARGET_QUANTITY_ONE")))
	_f_target_quantity.selected = tqt_idx if tqt_idx >= 0 else 0
	_f_unique_group.button_pressed = entry.get("uniqueGroupEffect", false)
	_f_value1.value = entry.get("value1", 0)
	_f_value1_name.text = str(entry.get("value1_name", ""))
	_f_value2.value = entry.get("value2", 0)
	_f_value2_name.text = str(entry.get("value2_name", ""))
	_f_value3.value = entry.get("value3", 0)
	_f_value3_name.text = str(entry.get("value3_name", ""))
	_f_value4.value = entry.get("value4", 0)
	_f_value4_name.text = str(entry.get("value4_name", ""))

func _collect_form_data() -> Dictionary:
	var types := []
	for line in _f_type.text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed != "":
			types.append(trimmed)
	# Keep the deity from the current skill (it's determined by the group, not the form)
	var deity_val := ""
	if _selected_skill_index >= 0 and _selected_skill_index < _skills_data.size():
		deity_val = _skills_data[_selected_skill_index].get("deity", "")
	return {
		"name": _f_name.text,
		"nameText": _f_name_text.text,
		"description": _f_description.text,
		"subimage": int(_f_subimage.value),
		"subimageTotal": int(_f_subimage_total.value),
		"mp": int(_f_mp.value),
		"deity": deity_val,
		"magicKind": _f_magic_kind.selected,
		"type": types,
		"value1": int(_f_value1.value),
		"value2": int(_f_value2.value),
		"value3": int(_f_value3.value),
		"value4": int(_f_value4.value),
		"value1_name": _f_value1_name.text,
		"value2_name": _f_value2_name.text,
		"value3_name": _f_value3_name.text,
		"value4_name": _f_value4_name.text,
		"target": TARGETS[_f_target.selected] if _f_target.selected >= 0 else "ALLY",
		"targetQuantity": TARGET_QUANTITIES[_f_target_quantity.selected] if _f_target_quantity.selected >= 0 else "TARGET_QUANTITY_ONE",
		"targetCondition": [],
		"uniqueGroupEffect": _f_unique_group.button_pressed,
		"enabled": _f_enabled.button_pressed,
	}

# --- Form helpers ---

func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_form.add_child(label)
	_form.add_child(HSeparator.new())

func _add_form_field(label_text: String, control: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 160
	hbox.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(control)
	_form.add_child(hbox)

func _add_form_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	_form.add_child(spacer)

func _make_line_edit(placeholder: String = "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	return le

func _make_text_edit(min_height: int = 60) -> TextEdit:
	var te := TextEdit.new()
	te.custom_minimum_size.y = min_height
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return te

func _make_spin(min_val: float = -1, max_val: float = 99999, step: float = 1) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	return spin

func _make_option_button(options: Array) -> OptionButton:
	var ob := OptionButton.new()
	for opt in options:
		ob.add_item(str(opt))
	return ob
