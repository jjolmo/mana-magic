@tool
extends VBoxContainer

## Base class for all Mana Magic Editor tabs.
## Provides a master-detail layout: item list on the left, edit form on the right.
## Auto-saves to JSON whenever any form field changes.
## Subclasses override _get_json_filename(), _get_display_name(), _build_form(),
## _populate_form(), and _collect_form_data().

var _data: Array = []
var _current_index: int = -1
var _dirty: bool = false
var _populating: bool = false  # Guard: true while _populate_form is running (skip auto-save)

# UI references
var _toolbar: HBoxContainer
var _btn_new: Button
var _btn_delete: Button
var _btn_duplicate: Button
var _search_field: LineEdit
var _split: HSplitContainer
var _item_list: ItemList
var _scroll: ScrollContainer
var _form_container: VBoxContainer
var _status_label: Label

# Auto-save debounce timer (for text fields)
var _save_timer: Timer

func _ready() -> void:
	_build_ui()
	_load_data()

# --- Virtual methods for subclasses ---

func _get_json_filename() -> String:
	return ""

func _get_display_name(entry: Dictionary) -> String:
	if entry.has("nameText") and entry["nameText"] != "":
		return "%s - %s" % [entry.get("id", "?"), entry["nameText"]]
	if entry.has("name") and entry["name"] != "":
		return "%s - %s" % [entry.get("id", "?"), entry["name"]]
	return "ID: %s" % entry.get("id", "?")

func _build_form() -> void:
	pass

func _populate_form(_entry: Dictionary) -> void:
	pass

func _collect_form_data() -> Dictionary:
	return {}

func _create_default_entry(id: int) -> Dictionary:
	return {"id": id}

# --- UI Construction ---

func _build_ui() -> void:
	# Debounce timer for text field auto-save
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(_on_autosave_timer)
	add_child(_save_timer)

	# Toolbar
	_toolbar = HBoxContainer.new()
	_toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_toolbar)

	_btn_new = Button.new()
	_btn_new.text = "  + New  "
	_btn_new.pressed.connect(_on_new_pressed)
	_toolbar.add_child(_btn_new)

	_btn_duplicate = Button.new()
	_btn_duplicate.text = "  Duplicate  "
	_btn_duplicate.pressed.connect(_on_duplicate_pressed)
	_toolbar.add_child(_btn_duplicate)

	_btn_delete = Button.new()
	_btn_delete.text = "  Delete  "
	_btn_delete.pressed.connect(_on_delete_pressed)
	_toolbar.add_child(_btn_delete)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(spacer)

	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Search..."
	_search_field.custom_minimum_size.x = 200
	_search_field.text_changed.connect(_on_search_changed)
	_toolbar.add_child(_search_field)

	# Split container
	_split = HSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.split_offset = 220
	add_child(_split)

	# Item list (left panel)
	_item_list = ItemList.new()
	_item_list.custom_minimum_size.x = 200
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	_split.add_child(_item_list)

	# Scroll + form (right panel)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_split.add_child(_scroll)

	_form_container = VBoxContainer.new()
	_form_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_form_container)

	# Status bar
	_status_label = Label.new()
	_status_label.text = ""
	add_child(_status_label)

	# Build subclass form, then connect auto-save signals
	_build_form()
	_connect_autosave_signals(_form_container)

# --- Auto-save ---

## Recursively connect change signals on all form controls for auto-save
func _connect_autosave_signals(node: Node) -> void:
	if node is SpinBox:
		node.value_changed.connect(_on_field_changed_immediate.unbind(1))
	elif node is OptionButton:
		node.item_selected.connect(_on_field_changed_immediate.unbind(1))
	elif node is CheckBox:
		node.toggled.connect(_on_field_changed_immediate.unbind(1))
	elif node is LineEdit and node != _search_field:
		node.text_changed.connect(_on_field_changed_debounced.unbind(1))
	elif node is TextEdit:
		node.text_changed.connect(_on_field_changed_debounced)
	elif node is ItemList and node != _item_list:
		node.multi_selected.connect(_on_field_changed_immediate.unbind(2))

	for child in node.get_children():
		_connect_autosave_signals(child)

## Immediate auto-save (spinbox, option, checkbox, itemlist selection)
func _on_field_changed_immediate() -> void:
	if _populating:
		return
	_auto_save()

## Debounced auto-save (text fields — wait 0.5s after last keystroke)
func _on_field_changed_debounced() -> void:
	if _populating:
		return
	_save_timer.start()

func _on_autosave_timer() -> void:
	_auto_save()

func _auto_save() -> void:
	_save_timer.stop()
	if _current_index < 0 or _current_index >= _data.size():
		return
	_apply_form_to_current()
	_save_data()
	_refresh_list(_search_field.text)

# --- Data Operations ---

func _load_data() -> void:
	var filename := _get_json_filename()
	if filename == "":
		return
	_data = ManaJsonHelper.load_json(filename)
	_refresh_list()
	_status_label.text = "Loaded %d entries from %s" % [_data.size(), filename]

func _save_data() -> void:
	var filename := _get_json_filename()
	if filename == "":
		return
	var err := ManaJsonHelper.save_json(filename, _data)
	if err == OK:
		_status_label.text = "Saved to %s" % filename
		_dirty = false
	else:
		_status_label.text = "ERROR saving %s" % filename

func _refresh_list(filter: String = "") -> void:
	_item_list.clear()
	var search := filter.to_lower()
	for i in range(_data.size()):
		var entry: Dictionary = _data[i]
		var display := _get_display_name(entry)
		if search != "" and display.to_lower().find(search) == -1:
			continue
		_item_list.add_item(display)
		_item_list.set_item_metadata(_item_list.item_count - 1, i)

	# Re-select the current item so it stays highlighted
	if _current_index >= 0:
		for i in range(_item_list.item_count):
			if _item_list.get_item_metadata(i) == _current_index:
				_item_list.select(i)
				_item_list.ensure_current_is_visible()
				break
	elif _item_list.item_count > 0:
		_item_list.select(0)
		_on_item_selected(0)

# --- Signal Handlers ---

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _item_list.item_count:
		return
	var data_index: int = _item_list.get_item_metadata(index)
	if data_index < 0 or data_index >= _data.size():
		return
	_current_index = data_index
	_populating = true
	_populate_form(_data[_current_index])
	_populating = false

func _on_new_pressed() -> void:
	var new_id := ManaJsonHelper.get_next_id(_data)
	var entry := _create_default_entry(new_id)
	_data.append(entry)
	_dirty = true
	_save_data()
	_refresh_list(_search_field.text)
	# Select the new entry
	for i in range(_item_list.item_count):
		if _item_list.get_item_metadata(i) == _data.size() - 1:
			_item_list.select(i)
			_on_item_selected(i)
			break
	_status_label.text = "Created new entry with ID %d (saved)" % new_id

func _on_duplicate_pressed() -> void:
	if _current_index < 0 or _current_index >= _data.size():
		return
	var source: Dictionary = _data[_current_index].duplicate(true)
	var new_id := ManaJsonHelper.get_next_id(_data)
	source["id"] = new_id
	if source.has("name"):
		source["name"] = str(source["name"]) + "_copy"
	if source.has("nameText"):
		source["nameText"] = str(source["nameText"]) + " (Copy)"
	_data.append(source)
	_dirty = true
	_save_data()
	_refresh_list(_search_field.text)
	for i in range(_item_list.item_count):
		if _item_list.get_item_metadata(i) == _data.size() - 1:
			_item_list.select(i)
			_on_item_selected(i)
			break
	_status_label.text = "Duplicated entry as ID %d (saved)" % new_id

func _on_save_pressed() -> void:
	_apply_form_to_current()
	_save_data()
	_refresh_list(_search_field.text)

func _on_delete_pressed() -> void:
	if _current_index < 0 or _current_index >= _data.size():
		return
	_data.remove_at(_current_index)
	_current_index = -1
	_dirty = true
	_save_data()
	_refresh_list(_search_field.text)
	_clear_form()
	_status_label.text = "Entry deleted (saved)"

func _on_search_changed(text: String) -> void:
	_refresh_list(text)

func _apply_form_to_current() -> void:
	if _current_index < 0 or _current_index >= _data.size():
		return
	var form_data := _collect_form_data()
	var entry: Dictionary = _data[_current_index]
	for key in form_data:
		entry[key] = form_data[key]
	_dirty = true

func _clear_form() -> void:
	# Clear all children input values - subclasses can override
	pass

# --- Form Field Helpers ---

func _add_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_form_container.add_child(label)
	var sep := HSeparator.new()
	_form_container.add_child(sep)
	return label

func _add_field(label_text: String, control: Control) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 160
	hbox.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(control)
	_form_container.add_child(hbox)
	return hbox

func _add_number_field(label_text: String, spin: SpinBox) -> SpinBox:
	spin.custom_minimum_size.x = 100
	_add_field(label_text, spin)
	return spin

func _create_spin(min_val: float = -1, max_val: float = 99999, step: float = 1) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	return spin

func _create_line_edit(placeholder: String = "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	return le

func _create_text_edit(min_height: int = 60) -> TextEdit:
	var te := TextEdit.new()
	te.custom_minimum_size.y = min_height
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return te

func _create_check_box(text: String = "") -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	return cb

func _create_option_button(options: Array) -> OptionButton:
	var ob := OptionButton.new()
	for opt in options:
		ob.add_item(str(opt))
	return ob

func _add_spacer(height: int = 8) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	_form_container.add_child(spacer)

## Elemental names used throughout the editor
const ELEMENT_NAMES := ["Undine", "Gnome", "Sylphid", "Salamando", "Shade", "Luna", "Lumina", "Dryad"]

## Creates a row of checkboxes for elemental affinities.
## Returns an Array of CheckBox references (one per element).
func _add_elemental_checkbox_field(label_text: String) -> Array:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label_text
	vbox.add_child(lbl)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var checkboxes: Array = []
	for e in ELEMENT_NAMES:
		var cb := CheckBox.new()
		cb.text = e
		flow.add_child(cb)
		checkboxes.append(cb)
	vbox.add_child(flow)
	_form_container.add_child(vbox)
	return checkboxes

## Set checkbox states from an array of element names or indices
static func _set_elemental_checkboxes(checkboxes: Array, values: Array) -> void:
	for cb in checkboxes:
		cb.button_pressed = false
	for val in values:
		var idx: int
		if val is int:
			idx = val
		else:
			idx = ELEMENT_NAMES.find(str(val))
		if idx >= 0 and idx < checkboxes.size():
			checkboxes[idx].button_pressed = true

## Get selected element names from checkboxes
static func _get_elemental_checkbox_strings(checkboxes: Array) -> Array:
	var result := []
	for i in range(checkboxes.size()):
		if checkboxes[i].button_pressed:
			result.append(ELEMENT_NAMES[i])
	return result

## Get selected element indices from checkboxes
static func _get_elemental_checkbox_ints(checkboxes: Array) -> Array:
	var result := []
	for i in range(checkboxes.size()):
		if checkboxes[i].button_pressed:
			result.append(i)
	return result

# ─── Animation Library Field ────────────────────────────────────────────────────

## Adds an Animation Library section with: path field, browse, open in editor, and
## collapsible animation list preview. Returns a Dictionary with references:
## { "line_edit": LineEdit, "toggle": Button, "tree": Tree, "container": VBoxContainer }
func _add_animation_library_section(default_browse_dir: String = "res://assets/animations/") -> Dictionary:
	var line_edit := _create_line_edit("res://assets/animations/...")
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(line_edit)

	var btn_browse := Button.new()
	btn_browse.text = " ... "
	btn_browse.tooltip_text = "Browse for SpriteFrames .tres"
	hbox.add_child(btn_browse)

	var btn_open := Button.new()
	btn_open.text = " Open ▶ "
	btn_open.tooltip_text = "Open SpriteFrames in Godot's editor"
	hbox.add_child(btn_open)

	_add_field("SpriteFrames:", hbox)

	# File dialog
	var file_dialog := EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tres", "SpriteFrames Resource")
	file_dialog.title = "Select Animation Library (.tres)"
	add_child(file_dialog)

	# Toggle button
	var toggle_btn := Button.new()
	toggle_btn.text = "▶ Show Animations"
	_form_container.add_child(toggle_btn)

	# Preview container with Tree
	var preview_container := VBoxContainer.new()
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.visible = false
	_form_container.add_child(preview_container)

	var tree := Tree.new()
	tree.custom_minimum_size.y = 200
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.columns = 4
	tree.set_column_title(0, "Animation")
	tree.set_column_title(1, "Frames")
	tree.set_column_title(2, "FPS")
	tree.set_column_title(3, "Loop")
	tree.column_titles_visible = true
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 60)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 50)
	tree.set_column_expand(3, false)
	tree.set_column_custom_minimum_width(3, 50)
	preview_container.add_child(tree)

	# State tracking
	var state := {
		"line_edit": line_edit,
		"toggle": toggle_btn,
		"tree": tree,
		"container": preview_container,
		"file_dialog": file_dialog,
		"visible": false,
		"browse_dir": default_browse_dir,
	}

	# Connect signals
	btn_browse.pressed.connect(_on_anim_lib_browse.bind(state))
	btn_open.pressed.connect(_on_anim_lib_open.bind(state))
	file_dialog.file_selected.connect(_on_anim_lib_selected.bind(state))
	toggle_btn.pressed.connect(_on_anim_lib_toggle.bind(state))

	return state

func _on_anim_lib_browse(state: Dictionary) -> void:
	var le: LineEdit = state["line_edit"]
	var fd: EditorFileDialog = state["file_dialog"]
	if le.text != "" and le.text.begins_with("res://"):
		fd.current_path = le.text
	else:
		fd.current_dir = state["browse_dir"]
	fd.popup_centered(Vector2i(700, 500))

func _on_anim_lib_selected(path: String, state: Dictionary) -> void:
	var le: LineEdit = state["line_edit"]
	le.text = path
	_refresh_anim_lib_preview(state)
	_on_field_changed_immediate()

func _on_anim_lib_open(state: Dictionary) -> void:
	var path: String = state["line_edit"].text
	if path == "" or not path.ends_with(".tres"):
		return
	var res = load(path)
	if res:
		EditorInterface.edit_resource(res)

func _on_anim_lib_toggle(state: Dictionary) -> void:
	state["visible"] = not state["visible"]
	state["container"].visible = state["visible"]
	if state["visible"]:
		state["toggle"].text = "▼ Hide Animations"
		_refresh_anim_lib_preview(state)
	else:
		state["toggle"].text = "▶ Show Animations"

func _refresh_anim_lib_preview(state: Dictionary) -> void:
	var tree: Tree = state["tree"]
	var toggle: Button = state["toggle"]
	tree.clear()

	var path: String = state["line_edit"].text
	if path == "" or not path.ends_with(".tres"):
		toggle.text = "▶ Show Animations (none)"
		return

	var res = load(path)
	if not res or not res is SpriteFrames:
		toggle.text = "▶ Show Animations (invalid)"
		return

	var sf: SpriteFrames = res
	var anim_names: PackedStringArray = sf.get_animation_names()
	var root := tree.create_item()
	tree.hide_root = true

	# Group animations by prefix
	var groups: Dictionary = {}
	for anim_name in anim_names:
		var prefix: String = anim_name
		var last_underscore := anim_name.rfind("_")
		var suffix := anim_name.substr(last_underscore + 1) if last_underscore >= 0 else ""
		if suffix in ["up", "right", "down", "left"]:
			prefix = anim_name.substr(0, last_underscore)
		if not groups.has(prefix):
			groups[prefix] = []
		groups[prefix].append(anim_name)

	var total_count := anim_names.size()
	var lbl := "▼ Hide Animations (%d)" % total_count if state["visible"] else "▶ Show Animations (%d)" % total_count
	toggle.text = lbl

	var sorted_keys: Array = groups.keys()
	sorted_keys.sort()

	for group_name in sorted_keys:
		var anims_in_group: Array = groups[group_name]
		if anims_in_group.size() == 1 and anims_in_group[0] == group_name:
			var item := tree.create_item(root)
			_set_anim_lib_tree_item(item, sf, anims_in_group[0])
		else:
			var group_item := tree.create_item(root)
			group_item.set_text(0, group_name)
			group_item.set_text(1, "%d dirs" % anims_in_group.size())
			for anim_name in anims_in_group:
				var child := tree.create_item(group_item)
				_set_anim_lib_tree_item(child, sf, anim_name)
			group_item.collapsed = true

static func _set_anim_lib_tree_item(item: TreeItem, sf: SpriteFrames, anim_name: String) -> void:
	var frame_count := sf.get_frame_count(anim_name)
	var fps := sf.get_animation_speed(anim_name)
	var loop := sf.get_animation_loop(anim_name)
	item.set_text(0, anim_name)
	item.set_text(1, str(frame_count))
	item.set_text(2, "%.1f" % fps if fps != int(fps) else str(int(fps)))
	item.set_text(3, "loop" if loop else "once")
	if loop:
		item.set_custom_color(3, Color(0.3, 0.8, 0.3))
	else:
		item.set_custom_color(3, Color(0.7, 0.7, 0.7))
