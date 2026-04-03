class_name BattleDialog
extends Control
## Battle dialog for combat messages - replaces oBattleDialog from GMS2

enum Align { BOTTOM, TOP }

var active: bool = false
var active_dialog: String = ""
var align: int = Align.BOTTOM
var dialog_list: Array = [] # Array of [text, duration_seconds]
# GMS2: timer_active starts at timerLimit_active so the first message pops immediately
# when added (timer_active++ > timer_limit on the very first tick).
var timer_active: float = 2.0
var timer_limit: float = 2.0
var override_message: bool = false

# Positioning — same dimensions as DialogBox / ring menu (GMS2: shared dialogWidth/dialogHeight)
var dialog_width: float = 277.0
var dialog_height: float = 20.0
var y_margin_bottom: float = 10.0  # distance from viewport bottom
var y_margin_top: float = 10.0  # distance from viewport top
var custom_font: Font = preload("res://assets/fonts/sprfont_som.fnt")

# Sprite-based rendering (GMS2 faithful)
var _dialog_bg_textures: Array[Texture2D] = []
var _dialog_border_textures: Array[Texture2D] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func add_message(text: String, p_align: int = Align.BOTTOM, override: bool = false, time_seconds: float = 4.0) -> void:
	# Check for duplicates
	for bundle in dialog_list:
		if bundle[0] == text:
			return
	if active_dialog == text:
		return

	if override:
		dialog_list.clear()
		override_message = true
		timer_active = timer_limit

	var bundle := [text, time_seconds]
	dialog_list.append(bundle)
	active = true
	align = p_align

func _process(delta: float) -> void:
	if not active and not override_message:
		return

	if (active and not GameManager.ring_menu_opened) or override_message:
		timer_active += delta
		if timer_active > timer_limit:
			if dialog_list.size() > 0:
				var bundle: Array = dialog_list.pop_front()
				active_dialog = bundle[0]
				timer_limit = bundle[1]
				timer_active = 0.0
			else:
				dialog_list.clear()
				active = false
				active_dialog = ""
				timer_active = timer_limit
				override_message = false

	queue_redraw()

func _draw() -> void:
	if not active and not override_message:
		return
	if active_dialog == "":
		return
	if GameManager.ring_menu_opened and not override_message:
		return

	var font: Font = custom_font if custom_font else ThemeDB.fallback_font
	var vp_size: Vector2 = get_viewport_rect().size

	# Center horizontally, position at top/bottom margin
	var x_anchor: float = (vp_size.x - dialog_width) / 2.0
	var y_pos: float
	if align == Align.BOTTOM:
		y_pos = vp_size.y - dialog_height - y_margin_bottom
	else:
		y_pos = y_margin_top

	# GMS2: drawSpriteTiledAreaExt + drawWindow — same box as DialogBox / ring menu
	if _dialog_bg_textures.size() > 0 and _dialog_border_textures.size() > 0:
		var bg_idx: int = clampi(GameManager.dialog_background_index, 0, _dialog_bg_textures.size() - 1)
		var border_idx: int = clampi(GameManager.dialog_border_index, 0, _dialog_border_textures.size() - 1)
		UIUtils.draw_sprite_tiled_area(self, _dialog_bg_textures[bg_idx], 0,
			0, 0,
			x_anchor, y_pos,
			x_anchor + dialog_width, y_pos + dialog_height,
			GameManager.dialog_color_rgb, 1.0, 1, 1.0 / 3.0)
		UIUtils.draw_window(self, _dialog_border_textures[border_idx],
			x_anchor - 4, y_pos - 4,
			dialog_width + 8, dialog_height + 8,
			GameManager.GUI_SCALE, 1.0, Color.WHITE)
	else:
		draw_rect(Rect2(x_anchor, y_pos, dialog_width, dialog_height),
			Color(0.0, 0.0, 0.31, 0.9))
		draw_rect(Rect2(x_anchor, y_pos, dialog_width, dialog_height),
			Color(0.8, 0.7, 0.4, 1.0), false, 1.0)

	# Text centered horizontally within the dialog box
	var font_size: int = 8
	var text_width: float = font.get_string_size(active_dialog, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_x: float = x_anchor + (dialog_width - text_width) / 2.0
	var text_y: float = y_pos + (dialog_height + font_size) / 2.0
	draw_string(font, Vector2(text_x, text_y),
		active_dialog, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
