class_name PauseMenu
extends CanvasLayer
## Pause menu - shows when pressing Start/Enter.
## Options: Continue, Status, Save, Quit

enum Option { CONTINUE, STATUS, SAVE, QUIT }

const OPTION_LABELS: Array[String] = ["Continue", "Status", "Save", "Quit"]

var is_open: bool = false
var selected: int = 0
var custom_font: Font = preload("res://assets/fonts/sprfont_som.fnt")

# Sub-screens
var status_screen_open: bool = false
var status_player_idx: int = 0

# Save slot selection
var save_screen_open: bool = false
var save_slot_selected: int = 0
var save_message: String = ""
var save_message_timer: float = 0.0

# Visual
var panel: Control

# Sprite-based rendering (GMS2 faithful)
var _window_layout_textures: Array[Texture2D] = []

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

	panel = Control.new()
	panel.name = "PausePanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	panel.connect("draw", _on_draw)
	add_child(panel)
	_load_ui_sprites()

func _load_ui_sprites() -> void:
	for i in range(2):
		var path: String = "res://assets/sprites/ui/spr_windowLayout_1/%d.png" % i
		if ResourceLoader.exists(path):
			_window_layout_textures.append(load(path))


func _process(delta: float) -> void:
	# Save message countdown
	if save_message_timer > 0:
		save_message_timer -= delta
		if save_message_timer <= 0:
			save_message = ""
			panel.queue_redraw()

	if save_screen_open:
		_process_save_screen()
		return

	if status_screen_open:
		_process_status_screen()
		return

	if is_open:
		_process_menu()
		return

	# Check for opening pause menu
	if InputManager.is_start_pressed() and not GameManager.ring_menu_opened:
		open_menu()


func open_menu() -> void:
	if is_open:
		return
	is_open = true
	selected = 0
	save_screen_open = false
	save_message = ""
	save_message_timer = 0.0
	panel.visible = true
	GameManager.pause_game()
	panel.queue_redraw()


func close_menu() -> void:
	is_open = false
	status_screen_open = false
	save_screen_open = false
	save_message = ""
	save_message_timer = 0.0
	panel.visible = false
	GameManager.resume_game()


func _process_menu() -> void:
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_down"):
		selected = (selected + 1) % OPTION_LABELS.size()
		MusicManager.play_sfx("snd_cursor")
		panel.queue_redraw()
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
		selected = (selected - 1 + OPTION_LABELS.size()) % OPTION_LABELS.size()
		MusicManager.play_sfx("snd_cursor")
		panel.queue_redraw()
	elif Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_accept"):
		_confirm_option()
	elif Input.is_action_just_pressed("run") or Input.is_action_just_pressed("ui_cancel") or InputManager.is_start_pressed():
		MusicManager.play_sfx("snd_menuClose")
		close_menu()


func _confirm_option() -> void:
	match selected:
		Option.CONTINUE:
			MusicManager.play_sfx("snd_menuClose")
			close_menu()
		Option.STATUS:
			MusicManager.play_sfx("snd_menuSelect")
			status_screen_open = true
			status_player_idx = 0
			panel.queue_redraw()
		Option.SAVE:
			MusicManager.play_sfx("snd_menuSelect")
			save_screen_open = true
			save_slot_selected = 0
			panel.queue_redraw()
		Option.QUIT:
			MusicManager.play_sfx("snd_menuClose")
			close_menu()
			get_tree().quit()


# --- Save Screen ---

func _process_save_screen() -> void:
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_down"):
		save_slot_selected = (save_slot_selected + 1) % SaveManager.MAX_SLOTS
		MusicManager.play_sfx("snd_cursor")
		panel.queue_redraw()
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
		save_slot_selected = (save_slot_selected - 1 + SaveManager.MAX_SLOTS) % SaveManager.MAX_SLOTS
		MusicManager.play_sfx("snd_cursor")
		panel.queue_redraw()
	elif Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_accept"):
		_do_save()
	elif Input.is_action_just_pressed("run") or Input.is_action_just_pressed("ui_cancel"):
		MusicManager.play_sfx("snd_menuClose")
		save_screen_open = false
		panel.queue_redraw()


func _do_save() -> void:
	var success: bool = SaveManager.save_game(save_slot_selected)
	if success:
		MusicManager.play_sfx("snd_menuSelect")
		save_message = "Saved!"
	else:
		MusicManager.play_sfx("snd_menuError")
		save_message = "Save failed!"
	save_message_timer = 2.0
	panel.queue_redraw()


# --- Status Screen ---

func _process_status_screen() -> void:
	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("move_left"):
		status_player_idx = (status_player_idx - 1 + GameManager.total_players) % maxi(1, GameManager.total_players)
		MusicManager.play_sfx("snd_cursor")
		panel.queue_redraw()
	elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("move_right"):
		status_player_idx = (status_player_idx + 1) % maxi(1, GameManager.total_players)
		MusicManager.play_sfx("snd_cursor")
		panel.queue_redraw()
	elif Input.is_action_just_pressed("run") or Input.is_action_just_pressed("ui_cancel"):
		MusicManager.play_sfx("snd_menuClose")
		status_screen_open = false
		panel.queue_redraw()


# --- Drawing ---

func _on_draw() -> void:
	if save_screen_open:
		_draw_save_screen()
	elif status_screen_open:
		_draw_status_screen()
	elif is_open:
		_draw_pause_menu()


func _draw_pause_menu() -> void:
	var vp_size: Vector2 = panel.get_viewport_rect().size
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font

	# Dim background
	panel.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0, 0, 0, 0.6))

	# Menu panel
	var menu_w: float = 100.0
	var menu_h: float = 12.0 * OPTION_LABELS.size() + 16.0
	var menu_x: float = (vp_size.x - menu_w) / 2.0
	var menu_y: float = (vp_size.y - menu_h) / 2.0

	if _window_layout_textures.size() > 0:
		UIUtils.draw_window(panel, _window_layout_textures[0],
			menu_x - 4, menu_y - 4, menu_w + 8, menu_h + 8,
			GameManager.GUI_SCALE, 1.0, Color.WHITE)
	else:
		panel.draw_rect(Rect2(menu_x, menu_y, menu_w, menu_h), Color(0.1, 0.1, 0.2, 0.9))
		panel.draw_rect(Rect2(menu_x, menu_y, menu_w, menu_h), Color(0.4, 0.4, 0.8, 0.8), false, 1.0)

	# Title
	panel.draw_string(font, Vector2(menu_x + 8, menu_y + 10), "PAUSED",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.84, 0))

	# Options
	for i in range(OPTION_LABELS.size()):
		var opt_y: float = menu_y + 22 + i * 12.0
		var color: Color = Color(1, 1, 1) if i != selected else Color(1, 1, 0)

		if i == selected:
			panel.draw_rect(Rect2(menu_x + 4, opt_y - 7, menu_w - 8, 10), Color(0.3, 0.3, 0.6, 0.5))

		panel.draw_string(font, Vector2(menu_x + 14, opt_y), OPTION_LABELS[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, color)

		if i == selected:
			panel.draw_string(font, Vector2(menu_x + 6, opt_y), ">",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 0))


func _draw_save_screen() -> void:
	var vp_size: Vector2 = panel.get_viewport_rect().size
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font

	# Dim background
	panel.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0, 0, 0, 0.7))

	# Save panel
	var pw: float = 180.0
	var ph: float = 14.0 * SaveManager.MAX_SLOTS + 28.0
	var px: float = (vp_size.x - pw) / 2.0
	var py: float = (vp_size.y - ph) / 2.0

	if _window_layout_textures.size() > 0:
		UIUtils.draw_window(panel, _window_layout_textures[0],
			px - 4, py - 4, pw + 8, ph + 8,
			GameManager.GUI_SCALE, 1.0, Color.WHITE)
	else:
		panel.draw_rect(Rect2(px, py, pw, ph), Color(0.1, 0.1, 0.2, 0.9))
		panel.draw_rect(Rect2(px, py, pw, ph), Color(0.4, 0.4, 0.8, 0.8), false, 1.0)

	# Title
	panel.draw_string(font, Vector2(px + 8, py + 10), "SAVE GAME",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.84, 0))

	# Slots
	for i in range(SaveManager.MAX_SLOTS):
		var slot_y: float = py + 24 + i * 14.0
		var color: Color = Color(1, 1, 1) if i != save_slot_selected else Color(1, 1, 0)

		if i == save_slot_selected:
			panel.draw_rect(Rect2(px + 4, slot_y - 7, pw - 8, 12), Color(0.3, 0.3, 0.6, 0.5))

		var slot_info: Dictionary = SaveManager.get_save_info(i)
		var slot_label: String
		if slot_info.is_empty():
			slot_label = "Slot %d: --- Empty ---" % (i + 1)
		else:
			var leader: String = str(slot_info.get("leader_name", "???"))
			var lv: int = int(slot_info.get("leader_level", 1))
			var room: String = str(slot_info.get("room", "???"))
			slot_label = "Slot %d: %s Lv%d  %s" % [i + 1, leader, lv, room]

		panel.draw_string(font, Vector2(px + 14, slot_y), slot_label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 5, color)

		if i == save_slot_selected:
			panel.draw_string(font, Vector2(px + 6, slot_y), ">",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(1, 1, 0))

	# Save message
	if not save_message.is_empty():
		var msg_y: float = py + ph - 6
		var msg_color: Color = Color(0.3, 1, 0.3) if save_message == "Saved!" else Color(1, 0.3, 0.3)
		panel.draw_string(font, Vector2(px + 8, msg_y), save_message,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, msg_color)


func _draw_status_screen() -> void:
	var vp_size: Vector2 = panel.get_viewport_rect().size
	var font: Font = custom_font if custom_font else ThemeDB.fallback_font

	# Dim background
	panel.draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0, 0, 0, 0.7))

	var player: Node = GameManager.get_player(status_player_idx)
	if not is_instance_valid(player):
		panel.draw_string(font, Vector2(20, 30), "No player data",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
		return

	# Panel
	var px: float = 16.0
	var py: float = 10.0
	var pw: float = vp_size.x - 32.0
	var ph: float = vp_size.y - 20.0
	if _window_layout_textures.size() > 0:
		UIUtils.draw_window(panel, _window_layout_textures[0],
			px - 4, py - 4, pw + 8, ph + 8,
			GameManager.GUI_SCALE, 1.0, Color.WHITE)
	else:
		panel.draw_rect(Rect2(px, py, pw, ph), Color(0.08, 0.08, 0.18, 0.95))
		panel.draw_rect(Rect2(px, py, pw, ph), Color(0.4, 0.4, 0.8, 0.7), false, 1.0)

	var fs: int = 6
	var line_h: float = 10.0
	var col1: float = px + 8
	var col2: float = px + pw / 2.0

	# Character name and level
	var name_str: String = player.character_name if "character_name" in player else "???"
	var level_str: String = "Lv. %d" % player.attribute.level
	panel.draw_string(font, Vector2(col1, py + 12), name_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.84, 0))
	panel.draw_string(font, Vector2(col2, py + 12), level_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)

	# Navigation hint
	if GameManager.total_players > 1:
		panel.draw_string(font, Vector2(px + pw - 50, py + 12), "< %d/%d >" % [status_player_idx + 1, GameManager.total_players],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.7, 0.7, 0.7))

	# HP / MP
	var y: float = py + 26
	panel.draw_string(font, Vector2(col1, y), "HP: %d / %d" % [player.attribute.hp, player.attribute.maxHP],
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	panel.draw_string(font, Vector2(col2, y), "MP: %d / %d" % [player.attribute.mp, player.attribute.maxMP],
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	# Stats
	y += line_h * 1.5
	panel.draw_string(font, Vector2(col1, y), "--- Stats ---",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.6, 0.8, 1.0))
	y += line_h
	var stats: Array = [
		["STR", player.attribute.strength],
		["CON", player.attribute.constitution],
		["AGI", player.attribute.agility],
		["INT", player.attribute.intelligence],
		["WIS", player.attribute.wisdom],
		["LUK", player.attribute.luck],
	]
	for i in range(stats.size()):
		var sx: float = col1 if i < 3 else col2
		var sy: float = y + (i % 3) * line_h
		panel.draw_string(font, Vector2(sx, sy), "%s: %d" % [stats[i][0], stats[i][1]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	# Equipment
	y += line_h * 3.5
	panel.draw_string(font, Vector2(col1, y), "--- Equipment ---",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.6, 0.8, 1.0))
	y += line_h
	if player is Actor:
		var actor := player as Actor
		var weapon_name: String = Constants.Weapon.keys()[actor.equipped_weapon_id].to_lower() if actor.equipped_weapon_id >= 0 else "None"
		panel.draw_string(font, Vector2(col1, y), "Weapon: %s" % weapon_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		panel.draw_string(font, Vector2(col1, y + line_h), "Head: %s" % _equip_id_label(actor.equipped_head),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		panel.draw_string(font, Vector2(col1, y + line_h * 2), "Body: %s" % _equip_id_label(actor.equipped_body),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		panel.draw_string(font, Vector2(col1, y + line_h * 3), "Acc: %s" % _equip_id_label(actor.equipped_accessory),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	# Deity levels
	y += line_h * 5
	if y < py + ph - 10:
		panel.draw_string(font, Vector2(col1, y), "--- Magic Levels ---",
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.6, 0.8, 1.0))
		y += line_h
		if player is Actor:
			var actor := player as Actor
			var deity_names: Array = ["Undine", "Gnome", "Sylphid", "Salamando", "Shade", "Luna", "Lumina", "Dryad"]
			for i in range(mini(deity_names.size(), actor.deity_levels.size())):
				var dx: float = col1 if i < 4 else col2
				var dy: float = y + (i % 4) * line_h
				var dlv: int = actor.deity_levels[i]
				panel.draw_string(font, Vector2(dx, dy), "%s: %d" % [deity_names[i], dlv],
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _equip_id_label(equip_id: int) -> String:
	if equip_id < 0:
		return "None"
	return str(equip_id)
