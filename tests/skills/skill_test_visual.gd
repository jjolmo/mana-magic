extends Node2D
## Visual Skill Test Runner — interactive scene to see and run skill tests one by one.
## Viewport: 427x240 (SNES-style). All sizes must be tiny to fit.

const ARENA_CENTER := Vector2(300, 120)  # Right side of screen for the arena

var _test_scripts: Dictionary = {}  # skill_name -> GDScript
var _skill_names: Array[String] = []
var _current_test: Node = null
var _is_running: bool = false

# UI references
var _item_list: ItemList
var _btn_run: Button
var _btn_run_all: Button
var _status_label: Label
var _log_text: RichTextLabel
var _results: Dictionary = {}  # skill_name -> {passed, message}

# Run All state
var _run_all_mode: bool = false
var _run_all_idx: int = -1

func _ready() -> void:
	_build_ui()
	_discover_tests()
	_populate_list()

	# Camera centered on arena area (right side)
	var cam := Camera2D.new()
	cam.position = ARENA_CENTER
	cam.zoom = Vector2(1.0, 1.0)  # 1:1 zoom — no magnification
	add_child(cam)

	# Dark background behind arena
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.15, 0.12, 1.0)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(427, 240)
	bg.z_index = -10
	add_child(bg)

func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	# Root control fills viewport (427x240)
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root_ctrl)

	# Left panel — 120px wide out of 427px viewport
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_right = 120
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	panel.add_child(vbox)

	# Buttons bar — tiny
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 1)
	vbox.add_child(hbox)

	_btn_run = Button.new()
	_btn_run.text = "Run"
	_btn_run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_run.add_theme_font_size_override("font_size", 7)
	_btn_run.pressed.connect(_on_run_selected)
	hbox.add_child(_btn_run)

	_btn_run_all = Button.new()
	_btn_run_all.text = "All"
	_btn_run_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_run_all.add_theme_font_size_override("font_size", 7)
	_btn_run_all.pressed.connect(_on_run_all)
	hbox.add_child(_btn_run_all)

	# Status line
	_status_label = Label.new()
	_status_label.text = "Ready"
	_status_label.add_theme_color_override("font_color", Color.GRAY)
	_status_label.add_theme_font_size_override("font_size", 6)
	vbox.add_child(_status_label)

	# Skill list — main area
	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.auto_height = false
	_item_list.add_theme_font_size_override("font_size", 6)
	_item_list.add_theme_constant_override("v_separation", 0)
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.item_activated.connect(_on_item_activated)
	vbox.add_child(_item_list)

	# Log — bottom strip
	_log_text = RichTextLabel.new()
	_log_text.custom_minimum_size = Vector2(0, 40)
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.add_theme_font_size_override("normal_font_size", 5)
	_log_text.add_theme_font_size_override("bold_font_size", 5)
	vbox.add_child(_log_text)

func _discover_tests() -> void:
	var dir := DirAccess.open("res://tests/skills/")
	if not dir:
		_log("[color=red]Cannot open tests/skills/[/color]")
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.begins_with("test_") and file.ends_with(".gd"):
			var script_path := "res://tests/skills/%s" % file
			var script := load(script_path)
			if script:
				var instance := Node.new()
				instance.set_script(script)
				if instance.has_method("get_skill_name"):
					var sname: String = instance.get_skill_name()
					if sname != "":
						_test_scripts[sname] = script
						_skill_names.append(sname)
				instance.free()
		file = dir.get_next()
	dir.list_dir_end()
	_skill_names.sort()
	_log("Found %d tests" % _skill_names.size())

func _populate_list() -> void:
	_item_list.clear()
	for sname in _skill_names:
		var skill_data: Dictionary = Database.get_skill(sname)
		var display_name: String = skill_data.get("nameText", sname)
		var idx := _item_list.add_item(display_name)

		# Color by result if already run
		if _results.has(sname):
			if _results[sname]["passed"]:
				_item_list.set_item_custom_fg_color(idx, Color.GREEN)
			else:
				_item_list.set_item_custom_fg_color(idx, Color.RED)

func _on_item_selected(_idx: int) -> void:
	pass

func _on_item_activated(idx: int) -> void:
	_run_test_at_index(idx)

func _on_run_selected() -> void:
	var selected := _item_list.get_selected_items()
	if selected.is_empty():
		_log("[color=yellow]Select a skill[/color]")
		return
	_run_test_at_index(selected[0])

func _on_run_all() -> void:
	if _is_running:
		return
	_run_all_mode = true
	_run_all_idx = -1
	_results.clear()
	_log("[color=cyan]--- Running ALL ---[/color]")
	_run_next_all()

func _run_next_all() -> void:
	_run_all_idx += 1
	if _run_all_idx >= _skill_names.size():
		_run_all_mode = false
		_print_summary()
		return
	_run_test_at_index(_run_all_idx)

func _run_test_at_index(idx: int) -> void:
	if _is_running and not _run_all_mode:
		return

	var sname := _skill_names[idx]
	_cleanup_current()

	await get_tree().process_frame
	await get_tree().process_frame

	_is_running = true
	_status_label.text = sname
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	_btn_run.disabled = true
	_btn_run_all.disabled = true

	_item_list.select(idx)
	_item_list.ensure_current_is_visible()

	var script: GDScript = _test_scripts[sname]
	_current_test = Node.new()
	_current_test.set_script(script)

	add_child(_current_test)
	_current_test.test_completed.connect(_on_test_completed)

	_log("[b]%s[/b]..." % sname)
	_current_test.run_test()

func _on_test_completed(test_name: String, passed: bool, message: String) -> void:
	var sname := test_name.replace("test_", "")
	_results[sname] = {"passed": passed, "message": message}

	if passed:
		_log("[color=green]OK[/color] %s" % sname)
		_status_label.text = "PASS"
		_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		_log("[color=red]FAIL[/color] %s: %s" % [sname, message])
		_status_label.text = "FAIL"
		_status_label.add_theme_color_override("font_color", Color.RED)

	_is_running = false
	_btn_run.disabled = false
	_btn_run_all.disabled = false
	_populate_list()

	if _run_all_mode:
		await get_tree().create_timer(0.3).timeout
		_run_next_all()

func _cleanup_current() -> void:
	if is_instance_valid(_current_test):
		if _current_test.test_completed.is_connected(_on_test_completed):
			_current_test.test_completed.disconnect(_on_test_completed)
		if _current_test._phase != "done":
			_current_test._cleanup()
		_current_test.queue_free()
		_current_test = null

	await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("players"):
		GameManager.players.erase(node)
		node.queue_free()
	for node in get_tree().get_nodes_in_group("mobs"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("skill_effects"):
		node.queue_free()
	_cleanup_effects_recursive(get_tree().root)

func _cleanup_effects_recursive(node: Node) -> void:
	if node is SkillEffect:
		node.queue_free()
		return
	for child in node.get_children():
		_cleanup_effects_recursive(child)

func _print_summary() -> void:
	var pass_count := 0
	var fail_count := 0
	for sname in _skill_names:
		if _results.has(sname):
			if _results[sname]["passed"]:
				pass_count += 1
			else:
				fail_count += 1

	_log("[color=cyan]%d/%d passed[/color]" % [pass_count, _results.size()])
	_status_label.text = "%d/%d OK" % [pass_count, _results.size()]
	if fail_count > 0:
		_status_label.add_theme_color_override("font_color", Color.RED)
	else:
		_status_label.add_theme_color_override("font_color", Color.GREEN)

func _log(msg: String) -> void:
	if is_instance_valid(_log_text):
		_log_text.append_text(msg + "\n")
	print("[VisualTest] %s" % msg)
