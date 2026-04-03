extends Node
## Queue-based dialog system - replaces showDialog/hideDialog GMS2 scripts

signal dialog_started(dialog_id: String)
signal dialog_finished(dialog_id: String)
signal dialog_question_answered(dialog_id: String, answer: int)

var _dialog_queue: Array[Dictionary] = []
var _current_dialog: Dictionary = {}
var _is_showing: bool = false
var _dialog_box: Node = null

func _ready() -> void:
	# Auto-create dialog box UI
	var box_scene: PackedScene = preload("res://scenes/ui/dialog_box.tscn")
	var box_layer: Node = box_scene.instantiate()
	add_child(box_layer)
	_dialog_box = box_layer.get_node("DialogBox")

func set_dialog_box(box: Node) -> void:
	_dialog_box = box

func show_dialog(text: String, options: Dictionary = {}) -> void:
	# GMS2: showDialog(dialogId, ...) looks up dialog text by ID from dialogs database.
	# If text matches a key in Database.dialogs, use the looked-up text instead.
	var resolved_text := text
	if Database.dialogs is Dictionary and Database.dialogs.has(text):
		var dialog_data: Variant = Database.dialogs[text]
		if dialog_data is Array:
			# Array of lines → join as consecutive pages with \n
			var lines: PackedStringArray = PackedStringArray()
			for line in dialog_data:
				lines.append(str(line).strip_edges(false, true))  # Strip trailing whitespace/newlines
			resolved_text = "\n".join(lines)
		elif dialog_data is String:
			resolved_text = dialog_data

	# The "id" field is used for:
	# 1. Preventing duplicate dialogs (executed_dialogs tracking)
	# 2. The dialog_finished signal payload
	# Only set "id" when explicitly provided in options — NPC dialogs are repeatable
	# and should NOT be tracked in executed_dialogs.
	var dialog := {
		"text": resolved_text,
		"id": options.get("id", ""),
		"anchor": options.get("anchor", Constants.DialogAnchor.BOTTOM),
		"block_controls": options.get("block_controls", true),
		"auto_dialog": options.get("auto_dialog", false),
		"marquee": options.get("marquee", true),
		"replace_map": options.get("replace_map", {}),
		"speaker": options.get("speaker", ""),
		"questions": options.get("questions", []),
	}

	# Apply text replacements
	var final_text := resolved_text
	for key in dialog.replace_map:
		final_text = final_text.replace("{" + key + "}", str(dialog.replace_map[key]))
	dialog.text = final_text

	# Check if already executed (prevent duplicates)
	if dialog.id != "" and GameManager.executed_dialogs.has(dialog.id):
		return

	# Check if this dialog is already showing or queued (prevent queue flooding)
	if dialog.id != "":
		if _current_dialog.get("id", "") == dialog.id:
			return
		for queued in _dialog_queue:
			if queued.get("id", "") == dialog.id:
				return

	if _is_showing:
		_dialog_queue.append(dialog)
	else:
		_show(dialog)

func hide_dialog() -> void:
	if not _is_showing:
		return
	_is_showing = false
	if _dialog_box and _dialog_box.has_method("hide_dialog"):
		_dialog_box.hide_dialog()

	var dialog_id: String = _current_dialog.get("id", "")
	# Only track in executed_dialogs for dialogs with an explicit ID (scene events).
	# NPC dialogs have no ID and should be repeatable.
	if dialog_id != "":
		GameManager.executed_dialogs[dialog_id] = true
	# GMS2: dialog_finished always fires so listeners (NPC shop flow, scene events) can react
	dialog_finished.emit(dialog_id)

	_current_dialog = {}

	# Process queue
	if _dialog_queue.size() > 0:
		var next := _dialog_queue.pop_front() as Dictionary
		_show(next)

func _show(dialog: Dictionary) -> void:
	_current_dialog = dialog
	_is_showing = true
	dialog_started.emit(dialog.get("id", ""))

	if _dialog_box and _dialog_box.has_method("show_dialog"):
		_dialog_box.show_dialog(dialog)

func is_showing() -> bool:
	return _is_showing

func dialog_exists_in_queue(dialog_id: String) -> bool:
	for d in _dialog_queue:
		if d.get("id", "") == dialog_id:
			return true
	return false

func get_current_dialog() -> Dictionary:
	return _current_dialog

func answer_question(answer_index: int) -> void:
	# GMS2: always emit so NPC shop and other listeners can react
	dialog_question_answered.emit(_current_dialog.get("id", ""), answer_index)

## GMS2: dialog.dialogIndex - current page index of active dialog
func get_dialog_index() -> int:
	if _dialog_box and _is_showing:
		return _dialog_box.dialog_index
	return -1

## GMS2: dialog.drawTextResult[1] - true when current page text fully displayed
func is_page_finished() -> bool:
	if _dialog_box and _is_showing:
		return _dialog_box.finished_dialog_page
	return false

## GMS2: dialogLock() - pause dialog text advancement and input
func dialog_lock() -> void:
	if _dialog_box:
		_dialog_box.pause = true

## GMS2: dialogUnlock() - resume dialog text advancement and input
func dialog_unlock() -> void:
	if _dialog_box:
		_dialog_box.pause = false
