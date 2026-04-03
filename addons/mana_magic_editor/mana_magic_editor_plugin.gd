@tool
extends EditorPlugin

const DockScene := preload("res://addons/mana_magic_editor/mana_magic_editor_dock.gd")

var _editor_dock: EditorDock

func _enter_tree() -> void:
	var content := MarginContainer.new()
	content.set_script(DockScene)
	content.name = "ManaMagicEditorContent"

	_editor_dock = EditorDock.new()
	_editor_dock.title = "Mana Magic"
	_editor_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	_editor_dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
	_editor_dock.add_child(content)
	add_dock(_editor_dock)

func _exit_tree() -> void:
	if _editor_dock:
		remove_dock(_editor_dock)
		_editor_dock.queue_free()
		_editor_dock = null
