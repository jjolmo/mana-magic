@tool
extends MarginContainer

const HeroesCharEditor := preload("res://addons/mana_magic_editor/editors/heroes_characters_editor.gd")
const HeroClassesEditor := preload("res://addons/mana_magic_editor/editors/heroes_editor.gd")
const EnemiesEditor := preload("res://addons/mana_magic_editor/editors/enemies_editor.gd")
const ItemsEditor := preload("res://addons/mana_magic_editor/editors/items_editor.gd")
const SkillsEditor := preload("res://addons/mana_magic_editor/editors/skills_editor.gd")
const EquipmentEditor := preload("res://addons/mana_magic_editor/editors/equipment_editor.gd")
const ShopsEditor := preload("res://addons/mana_magic_editor/editors/shops_editor.gd")
const MagicTypesEditor := preload("res://addons/mana_magic_editor/editors/magic_types_editor.gd")
const MiscEditor := preload("res://addons/mana_magic_editor/editors/misc_editor.gd")

var _tab_container: TabContainer

# Tab definitions: [name, script] — order matters for UI
var _tab_defs: Array = []

func _ready() -> void:
	name = "ManaMagicEditorDock"
	custom_minimum_size = Vector2(600, 400)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_tab_defs = [
		["Heroes", HeroesCharEditor],
		["Hero Classes", HeroClassesEditor],
		["Enemies", EnemiesEditor],
		["Items", ItemsEditor],
		["Skills / Magic", SkillsEditor],
		["Magic Types", MagicTypesEditor],
		["Equipment", EquipmentEditor],
		["Shops", ShopsEditor],
		["Misc", MiscEditor],
	]

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)

	# Top bar with refresh button
	var top_bar := HBoxContainer.new()
	main_vbox.add_child(top_bar)

	var title_label := Label.new()
	title_label.text = "Mana Magic Editor"
	title_label.add_theme_font_size_override("font_size", 15)
	top_bar.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var btn_reload := Button.new()
	btn_reload.text = "  Reload Plugin  "
	btn_reload.tooltip_text = "Fully reload the plugin (picks up script changes)"
	btn_reload.pressed.connect(_on_reload_plugin)
	top_bar.add_child(btn_reload)

	# Tab container
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_tab_container)

	_create_all_tabs()

func _create_all_tabs() -> void:
	for td in _tab_defs:
		_add_tab(td[0], td[1])

func _add_tab(tab_name: String, editor_script: GDScript) -> void:
	var editor := VBoxContainer.new()
	editor.set_script(editor_script)
	editor.name = tab_name
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(editor)

func _on_reload_plugin() -> void:
	# Use a SceneTreeTimer so the callback survives the plugin being destroyed.
	# The lambda only references the SceneTree (editor-owned) and EditorInterface
	# (singleton), so no dangling references to the freed plugin.
	var tree := get_tree()
	tree.create_timer(0.1).timeout.connect(func() -> void:
		EditorInterface.set_plugin_enabled("mana_magic_editor", false)
		tree.create_timer(0.1).timeout.connect(func() -> void:
			EditorInterface.set_plugin_enabled("mana_magic_editor", true)
		)
	)
