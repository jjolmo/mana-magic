class_name DialogBox
extends Control
## Dialog box UI - replaces oScriptDialog from GMS2

signal dialog_finished(dialog_name: String)
signal question_answered(dialog_name: String, answer: int)

enum Phase { ANIMATION_IN, PREPARE, RUN, ANIMATION_OUT, ANIMATION_IN_OUT }

var dialogs: Array = []
var dialog_index: int = 0
var dialog_name: String = ""
var anchor: int = 0 # 0=top, 1=bottom
var block_controls: bool = true
var show_marquee: bool = true
var auto_dialog: bool = false

# Animation
var phase: int = Phase.ANIMATION_IN
var dialog_width: float = 0.0
var dialog_height: float = 0.0
var max_dialog_width: float = 277.0
var max_dialog_height: float = 67.0
var grow_timer: float = 0.0
var grow_timer_speed: float = 1.5
var center_screen: Vector2 = Vector2.ZERO
var x_anchor: float = 0.0
var y_anchor: float = 0.0
var orig_y_anchor: float = 0.0
var reopen_dialog: bool = false

# Text
var time: float = 0.0
var timer_speed: float = 0.5
var timer_speed_base: float = 0.5
var timer_speed_max: float = 2.0  # GMS2: dialog_speed[2]
var finished_dialog_page: bool = false
var finished_dialog: bool = false
var stop_time: bool = false
var stop_time_temporary: bool = false
var stop_time_temporary_timer: float = 0.0
var stop_temporary_timer_limit: float = 1.0
var _last_pause_index: int = -1  # GMS2: lastSpecialDetected - prevents ¬ re-trigger
var _last_stop_index: int = -1   # Prevents ~ re-trigger (same mechanism as ¬)
var extra_dialog: String = ""
var current_display_text: String = ""
var _wrapped_lines: Array = []  # Pre-calculated word-wrapped lines for full page text

# Questions
var pause: bool = false
var show_options: bool = false
var options: Array = []
var options_size: int = 0
var selected_option: int = 0
var shown_questions: bool = false

# Margin/scale
var margin: float = 6.0
var text_scale: float = 1.0
var chars_per_line: int = 35
var line_height: float = 18.0
var font_size: int = 16
var custom_font: Font = null

# Sprite-based rendering (GMS2 faithful: spr_scriptDialog_bg + spr_scriptDialog_border)
var _dialog_bg_textures: Array[Texture2D] = []
var _dialog_border_textures: Array[Texture2D] = []

func _ready() -> void:
	# Load BMFont from original game
	custom_font = load("res://assets/fonts/sprfont_som.fnt")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fill the viewport
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_ui_sprites()

func _load_ui_sprites() -> void:
	for i in range(8):
		var path: String = "res://assets/sprites/ui/spr_scriptDialog_bg/%d.png" % i
		if ResourceLoader.exists(path):
			_dialog_bg_textures.append(load(path))
	for i in range(9):
		var path: String = "res://assets/sprites/ui/spr_scriptDialog_border/%d.png" % i
		if ResourceLoader.exists(path):
			_dialog_border_textures.append(load(path))

func show_dialog(dialog: Dictionary) -> void:
	dialogs = dialog.get("text", "").split("\n")
	# Strip trailing empty pages (from trailing \n in dialog text)
	while dialogs.size() > 0 and dialogs[dialogs.size() - 1].strip_edges() == "":
		dialogs.remove_at(dialogs.size() - 1)
	if dialogs.size() == 0:
		return
	dialog_name = dialog.get("id", "")
	anchor = dialog.get("anchor", 0)
	block_controls = dialog.get("block_controls", true)
	show_marquee = dialog.get("marquee", true)
	auto_dialog = dialog.get("auto_dialog", false)

	# Always reset options — prevents leftover questions from previous dialog
	# from re-appearing on dialogs that have no questions of their own
	options = dialog.get("questions", [])
	options_size = options.size()

	# Read dialog speed from config (GMS2: timerSpeedBase = game.dialog_speedBase)
	timer_speed_base = GameManager.get_dialog_speed_base()
	timer_speed = timer_speed_base
	timer_speed_max = GameManager.DIALOG_SPEEDS[2]  # Always fastest for button-hold

	visible = true
	dialog_index = 0
	time = 0.0
	_prepare_page_text()
	finished_dialog = false
	finished_dialog_page = false
	stop_time = false
	extra_dialog = ""
	current_display_text = ""
	shown_questions = false
	show_options = false
	selected_option = 0
	reopen_dialog = false
	_last_pause_index = -1
	_last_stop_index = -1

	center_screen = get_viewport().get_visible_rect().size / 2
	dialog_width = 0.0
	dialog_height = 0.0
	# Position based on anchor: TOP near top, MIDDLE centered, BOTTOM near bottom
	var viewport_h: float = get_viewport().get_visible_rect().size.y
	if anchor == Constants.DialogAnchor.BOTTOM:
		y_anchor = viewport_h - max_dialog_height / 2.0 - 10.0
	elif anchor == Constants.DialogAnchor.MIDDLE:
		# GMS2: getDialogAnchorScreen ANCHOR_MIDDLE = view_hport / 2
		y_anchor = viewport_h / 2.0
	else:
		y_anchor = max_dialog_height / 2.0 + 10.0
	orig_y_anchor = y_anchor
	grow_timer = 0.0
	phase = Phase.ANIMATION_IN

	if block_controls:
		GameManager.lock_global_input = true

	queue_redraw()

func hide_dialog() -> void:
	visible = false
	finished_dialog = true
	GameManager.lock_global_input = false

func _process(delta: float) -> void:
	if not visible:
		return

	# Handle input every frame for responsive controls
	if phase == Phase.RUN:
		_handle_dialog_input()

	# Timer/animation logic using delta time
	match phase:
		Phase.ANIMATION_IN:
			_animate_in()
		Phase.PREPARE:
			phase = Phase.RUN
		Phase.RUN:
			_run_dialog_tick(delta)
		Phase.ANIMATION_OUT:
			_animate_out()
		Phase.ANIMATION_IN_OUT:
			grow_timer = 0.0
			phase = Phase.ANIMATION_OUT
			reopen_dialog = true

	queue_redraw()

func _animate_in() -> void:
	grow_timer += grow_timer_speed
	if dialog_width < max_dialog_width or dialog_height < max_dialog_height:
		var width_grow: float = grow_timer * max_dialog_width / 100.0
		var height_grow: float = grow_timer * max_dialog_height / 100.0
		if dialog_width < max_dialog_width - width_grow:
			dialog_width += width_grow
		elif dialog_height < max_dialog_height - height_grow:
			dialog_height += height_grow
			y_anchor -= height_grow / 2.0
		else:
			dialog_width = max_dialog_width
			dialog_height = max_dialog_height
	else:
		dialog_width = max_dialog_width
		dialog_height = max_dialog_height
		phase = Phase.PREPARE
	x_anchor = center_screen.x - (dialog_width / 2.0)

func _animate_out() -> void:
	grow_timer += grow_timer_speed
	if dialog_width > 50 or dialog_height > 50:
		var width_grow: float = grow_timer * max_dialog_width / 100.0
		var height_grow: float = grow_timer * max_dialog_height / 100.0
		if dialog_height > 50:
			dialog_height -= height_grow
			y_anchor += height_grow / 2.0
		elif dialog_width > 50:
			dialog_width -= width_grow
		else:
			dialog_width = 50
			dialog_height = 50
	else:
		if reopen_dialog:
			reopen_dialog = false
			phase = Phase.ANIMATION_IN
			grow_timer = 0.0
			y_anchor = orig_y_anchor
		else:
			finished_dialog = true
			visible = false
			GameManager.lock_global_input = false
			dialog_finished.emit(dialog_name)
			# hide_dialog() may process queue and call show_dialog() on us,
			# so visible must be false BEFORE this call
			DialogManager.hide_dialog()
	x_anchor = center_screen.x - (dialog_width / 2.0)

func _run_dialog_tick(delta: float) -> void:
	## Timer/text logic using delta time
	if pause:
		return

	# Handle text advancement
	if not stop_time and not stop_time_temporary:
		time += timer_speed

	# Build display text
	if dialog_index < dialogs.size():
		var full_text: String = dialogs[dialog_index]
		var char_count: int = int(time)
		var text_body: String = full_text

		# Process special characters
		var processed: String = ""
		var real_count: int = 0
		for i in range(text_body.length()):
			var ch: String = text_body[i]
			if ch == "~" and real_count <= char_count:
				if i > _last_stop_index:
					stop_time = true
					_last_stop_index = i
					# Clamp: don't show chars past the stop marker, resume from here
					char_count = real_count
					time = float(real_count)
				continue
			elif ch == "\u00ac" and real_count <= char_count: # ¬ character - pause
				if i > _last_pause_index and not stop_time_temporary:
					stop_time_temporary = true
					stop_time_temporary_timer = 0
					_last_pause_index = i
					# Clamp: don't show chars past the pause marker, resume from here
					char_count = real_count
					time = float(real_count)
				continue
			processed += ch
			real_count += 1

		var visible_chars: int = mini(char_count, processed.length())
		current_display_text = processed.substr(0, visible_chars)

		if visible_chars >= processed.length():
			finished_dialog_page = true

	# Handle stop temporary timer
	if stop_time_temporary:
		stop_time_temporary_timer += delta
		if stop_time_temporary_timer >= stop_temporary_timer_limit:
			stop_time_temporary = false
			stop_time_temporary_timer = 0

	# Auto-dialog timer advancement (not input-driven)
	if auto_dialog and finished_dialog_page and not show_options:
		time += timer_speed
		if time > 2.0:
			_next_page()

func _handle_dialog_input() -> void:
	## Input handling runs every frame for responsive controls
	if pause:
		return

	if finished_dialog_page and not show_options:
		# Show question options on the LAST page
		if options.size() > 0 and not shown_questions and dialog_index >= dialogs.size() - 1:
			shown_questions = true
			show_options = true
			selected_option = 0
		elif not auto_dialog:
			if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("run"):
				_next_page()
	elif stop_time:
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("run"):
			stop_time = false
	else:
		# Speed up with button hold
		if Input.is_action_pressed("attack"):
			timer_speed = timer_speed_max
		elif Input.is_action_pressed("run"):
			timer_speed = timer_speed_max * 3.0
		else:
			timer_speed = timer_speed_base

	# Handle question input
	if show_options:
		if Input.is_action_just_pressed("move_right"):
			selected_option = (selected_option + 1) % options_size
			MusicManager.play_sfx("snd_cursor")  # GMS2: snd_cursor on option navigate
		elif Input.is_action_just_pressed("move_left"):
			selected_option = (selected_option - 1 + options_size) % options_size
			MusicManager.play_sfx("snd_cursor")  # GMS2: snd_cursor on option navigate
		elif Input.is_action_just_pressed("attack"):
			show_options = false
			MusicManager.play_sfx("snd_menuSelect")  # GMS2: snd_menuSelect on answer confirm
			question_answered.emit(dialog_name, selected_option)
			DialogManager.answer_question(selected_option)
			_next_page()

func _next_page() -> void:
	if dialog_index < dialogs.size() - 1:
		dialog_index += 1
		time = 0.0
		finished_dialog_page = false
		current_display_text = ""
		stop_time = false
		_last_pause_index = -1
		_last_stop_index = -1
		_prepare_page_text()

		# Empty string means close and reopen (GMS2: section break between dialog array elements)
		if dialogs[dialog_index] == "":
			dialog_index += 1
			if dialog_index >= dialogs.size():
				# No more pages after section break, just close
				phase = Phase.ANIMATION_OUT
				grow_timer = 0.0
			else:
				_prepare_page_text()  # Re-calculate for page after section break
				phase = Phase.ANIMATION_IN_OUT
	else:
		phase = Phase.ANIMATION_OUT
		grow_timer = 0.0

func show_question(question_options: Array) -> void:
	if not shown_questions and finished_dialog_page:
		options = question_options
		options_size = options.size()
		shown_questions = true
		selected_option = 0
		show_options = true

func _draw() -> void:
	if not visible:
		return

	var font: Font = custom_font if custom_font else ThemeDB.fallback_font

	if show_marquee and (dialog_width > 0 and dialog_height > 0):
		# GMS2: drawSpriteTiledAreaExt(spr_scriptDialog_bg, ...) + drawWindow(spr_scriptDialog_border, ...)
		if _dialog_bg_textures.size() > 0 and _dialog_border_textures.size() > 0:
			var bg_idx: int = clampi(GameManager.dialog_background_index, 0, _dialog_bg_textures.size() - 1)
			var border_idx: int = clampi(GameManager.dialog_border_index, 0, _dialog_border_textures.size() - 1)
			# Tiled background pattern
			UIUtils.draw_sprite_tiled_area(self, _dialog_bg_textures[bg_idx], 0,
				0, 0,
				x_anchor, y_anchor,
				x_anchor + dialog_width, y_anchor + dialog_height,
				GameManager.dialog_color_rgb, 1.0, 1, 1.0 / 3.0)
			# 9-patch border frame
			UIUtils.draw_window(self, _dialog_border_textures[border_idx],
				x_anchor - 4, y_anchor - 4,
				dialog_width + 8, dialog_height + 8,
				GameManager.GUI_SCALE, 1.0, Color.WHITE)
		else:
			# Fallback if sprites not loaded
			draw_rect(Rect2(x_anchor, y_anchor, dialog_width, dialog_height),
				Color(0.0, 0.0, 0.31, 0.9))
			draw_rect(Rect2(x_anchor, y_anchor, dialog_width, dialog_height),
				Color(0.8, 0.7, 0.4, 1.0), false, 1.0)

	if phase == Phase.RUN:
		# Draw text
		var text_x: float = x_anchor + margin
		var text_y: float = y_anchor + margin
		var text_color: Color = Color(1, 1, 1, 1)

		# Word wrap and draw - use pre-calculated lines to prevent visual jumps (GMS2 pre-calculates)
		var total_visible: int = current_display_text.length()
		var pos: int = 0
		for i in range(_wrapped_lines.size()):
			var line: String = _wrapped_lines[i]
			if pos >= total_visible:
				break
			var line_chars: int = mini(total_visible - pos, line.length())
			draw_string(font, Vector2(text_x, text_y + i * line_height + font_size),
				line.substr(0, line_chars), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
			pos += line.length()
			if i < _wrapped_lines.size() - 1:
				pos += 1  # space consumed by line break

		# Draw "more" indicator
		if finished_dialog_page and not show_options:
			var indicator_y: float = y_anchor + dialog_height - 8
			var blink: bool = fmod(Time.get_ticks_msec() / 500.0, 2.0) > 1.0
			if blink:
				draw_string(font, Vector2(x_anchor + dialog_width - 12, indicator_y),
					"v", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 0, 1))

	# Draw question options
	if show_options and options.size() > 0:
		var opt_y: float = y_anchor + dialog_height + 4
		var opt_x: float = center_screen.x
		var total_width: float = 0.0
		for opt in options:
			total_width += opt.length() * 5.0 + 10.0
		var start_x: float = opt_x - total_width / 2.0

		# Options background
		if _dialog_bg_textures.size() > 0 and _dialog_border_textures.size() > 0:
			var bg_idx2: int = clampi(GameManager.dialog_background_index, 0, _dialog_bg_textures.size() - 1)
			var border_idx2: int = clampi(GameManager.dialog_border_index, 0, _dialog_border_textures.size() - 1)
			UIUtils.draw_sprite_tiled_area(self, _dialog_bg_textures[bg_idx2], 0,
				0, 0, start_x - 4, opt_y - 2,
				start_x + total_width + 4, opt_y + 12,
				GameManager.dialog_color_rgb, 1.0, 1, 1.0 / 3.0)
			UIUtils.draw_window(self, _dialog_border_textures[border_idx2],
				start_x - 8, opt_y - 6,
				total_width + 16, 22,
				GameManager.GUI_SCALE, 1.0, Color.WHITE)
		else:
			draw_rect(Rect2(start_x - 4, opt_y - 2, total_width + 8, 14),
				Color(0.0, 0.0, 0.31, 0.85))
			draw_rect(Rect2(start_x - 4, opt_y - 2, total_width + 8, 14),
				Color(0.8, 0.7, 0.4, 1.0), false, 1.0)

		var cx: float = start_x
		for i in range(options.size()):
			var color: Color = Color(1, 1, 0, 1) if i == selected_option else Color(1, 1, 1, 0.7)
			if i == selected_option:
				draw_string(font, Vector2(cx - 6, opt_y + font_size), ">",
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			draw_string(font, Vector2(cx, opt_y + font_size), options[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			cx += options[i].length() * 5.0 + 10.0

func _prepare_page_text() -> void:
	## Pre-calculate word wrap for the full page text to prevent visual jumps during reveal.
	## GMS2: drawTextResult pre-calculates line breaks before character-by-character display.
	if dialog_index >= dialogs.size():
		_wrapped_lines = []
		return
	var full_text: String = dialogs[dialog_index]
	# Strip special characters to get clean display text
	var processed: String = ""
	for ch in full_text:
		if ch != "~" and ch != "¬":
			processed += ch
	_wrapped_lines = _word_wrap(processed, chars_per_line)

func _word_wrap(text: String, max_chars: int) -> Array:
	var lines: Array = []
	var words: PackedStringArray = text.split(" ")
	var current_line: String = ""
	for word in words:
		if current_line.length() + word.length() + 1 > max_chars and current_line != "":
			lines.append(current_line)
			current_line = word
		else:
			if current_line != "":
				current_line += " "
			current_line += word
	if current_line != "":
		lines.append(current_line)
	return lines
