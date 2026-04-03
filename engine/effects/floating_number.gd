class_name FloatingNumber
extends Node2D
## Floating damage/heal number - faithful port of oBTL_counter from GMS2.
## Uses sprfont_counter sprite font with per-character rendering.
## GMS2: draw_text_transformed_color with vertex color gradient (top→bottom).

## GMS2 counter types: COUNTERTYPE_HP_DONE=0, HP_LOSS=1, HP_GAIN=2, MP_LOSS=3, MP_GAIN=4
enum CounterType { HP_DONE, HP_LOSS, HP_GAIN, MP_LOSS, MP_GAIN }

var text: String = ""
var color1: Color = Color.WHITE    # GMS2: top vertex color
var color2: Color = Color.WHITE    # GMS2: bottom vertex color
var outline_color: Color = Color.BLACK
var dmg_font_size: float = 0.15    # GMS2 scale factor (0.15 - 0.3)
var counter_type: int = CounterType.HP_DONE
var _is_text_mode: bool = false    # True for spawn_text (MISS, BLOCK, Level X!) - uses sprfont_som

# Movement (GMS2: anchor_y=-15, xPivot=0, yPivot=random(-5,5))
var anchor_y: float = -15.0
var x_pivot: float = 0.0
var y_pivot: float = 0.0

# Tracking
var attached_object: Node2D = null  # GMS2: attachedObject - follow creature
var is_dead: bool = false           # GMS2: isDead - stop tracking

# Timing
var time: float = 0.0
var counter_alpha: float = 0.0     # GMS2: counterAlpha - starts at 0, fades in
var lifetime: float = 95.0 / 60.0  # GMS2: time > 95 frames → destroy

# Sprite font atlas (GMS2: game.font_counter = font_add_sprite(sprfont_counter, ord("!"), 1, 1))
static var _atlas: Texture2D = null
static var _char_widths: Dictionary = {}  # char_code → xadvance
const _GLYPH_W: int = 60   # Per-glyph width in atlas
const _GLYPH_H: int = 65   # Per-glyph height in atlas
const _ATLAS_COLS: int = 10 # Columns in atlas
const _FIRST_CHAR: int = 33 # ASCII '!'
const _CHAR_COUNT: int = 95

# Fallback font for spawn_text (non-counter text like "Level X!", "MISS", "BLOCK")
static var _text_font: Font = null

# Gradient shader for per-character vertex color gradient
static var _gradient_shader: Shader = null


static func _ensure_atlas() -> void:
	if _atlas != null:
		return
	_atlas = load("res://assets/fonts/sprfont_counter.png") as Texture2D
	_text_font = load("res://assets/fonts/sprfont_som.fnt") as Font

	# Create gradient shader (replicates GMS2 draw_text_transformed_color vertex gradient)
	_gradient_shader = Shader.new()
	_gradient_shader.code = "shader_type canvas_item;\n" + \
		"uniform vec4 color_top : source_color = vec4(1.0);\n" + \
		"uniform vec4 color_bottom : source_color = vec4(1.0);\n" + \
		"void fragment() {\n" + \
		"    vec4 tex = texture(TEXTURE, UV);\n" + \
		"    vec4 grad = mix(color_top, color_bottom, UV.y);\n" + \
		"    COLOR = vec4(tex.rgb * grad.rgb, tex.a * grad.a);\n" + \
		"}\n"

	# Parse .fnt to get per-character advance widths
	if FileAccess.file_exists("res://assets/fonts/sprfont_counter.fnt"):
		var f := FileAccess.open("res://assets/fonts/sprfont_counter.fnt", FileAccess.READ)
		if f:
			while not f.eof_reached():
				var line: String = f.get_line()
				if line.begins_with("char id="):
					var parts := line.split(" ")
					var char_id: int = 0
					var xadvance: int = _GLYPH_W
					for part in parts:
						if part.begins_with("id="):
							char_id = int(part.substr(3))
						elif part.begins_with("xadvance="):
							xadvance = int(part.substr(9))
					_char_widths[char_id] = xadvance


## CanvasLayer that renders floating numbers above the game world but below HUD.
## Uses follow_viewport so world-space positions still work correctly.
static var _canvas_layer: CanvasLayer = null

static func _get_canvas_layer(tree: SceneTree) -> CanvasLayer:
	if is_instance_valid(_canvas_layer):
		return _canvas_layer
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "FloatingNumberLayer"
	_canvas_layer.layer = 10  # Above game world (0), below HUD (20)
	_canvas_layer.follow_viewport_enabled = true
	tree.current_scene.add_child(_canvas_layer)
	return _canvas_layer

func _ready() -> void:
	_ensure_atlas()


func _process(delta: float) -> void:
	# GMS2: pauses when ring menu is open
	if GameManager.ring_menu_opened:
		return

	# GMS2: font size calc at time==0 — dmgFontSize = clamp((damage*0.25)/999, 0.15, 0.3)
	if time == 0.0:
		var damage_val: float = 0.0
		# Strip +/- prefix for numeric parsing
		var stripped: String = text.lstrip("+-")
		if stripped.is_valid_float():
			damage_val = abs(stripped.to_float())
		if damage_val > 0:
			dmg_font_size = clampf(damage_val * 0.25 / 999.0, 0.15, 0.3)

	time += delta

	# Track creature (GMS2: x = attachedObject.x; y = attachedObject.y)
	if not is_dead and is_instance_valid(attached_object):
		global_position.x = attached_object.global_position.x
		global_position.y = attached_object.global_position.y

	# Alpha (GMS2: fade in 0.1/frame, oscillate 0.9-1.0 until frame 75, then fade out)
	if time < 75.0 / 60.0 and counter_alpha < 1.0:
		counter_alpha += 0.1 * delta * 60.0
	else:
		counter_alpha -= 0.1 * delta * 60.0
	counter_alpha = clampf(counter_alpha, 0.0, 1.0)
	modulate.a = counter_alpha

	if time > lifetime:
		queue_free()
		return

	queue_redraw()


func _get_draw_y() -> float:
	## GMS2: ease_in_sine(time+15, y-4, anchor_y=-15, duration=15)
	## ease_in_sine(t, start, change, duration) = change * (1 - cos(t/d * PI/2)) + start
	var time_frames: float = time * 60.0
	if time_frames < 50.0:
		var t: float = time_frames + 15.0
		var start: float = -4.0
		var change: float = anchor_y  # -15
		var duration: float = 15.0
		return change * (1.0 - cos(t / duration * (PI / 2.0))) + start
	else:
		return -4.0


func _draw() -> void:
	_ensure_atlas()

	# Text mode uses sprfont_som (general game font) for MISS, BLOCK, Level X!, etc.
	if _is_text_mode:
		_draw_text_mode()
		return

	if _atlas == null:
		return

	var scale_f: float = dmg_font_size
	var draw_y: float = _get_draw_y() + y_pivot

	# Calculate total text width for centering (GMS2: draw_set_halign(fa_center))
	var total_width: float = 0.0
	for i in range(text.length()):
		var char_code: int = text.unicode_at(i)
		var advance: int = _char_widths.get(char_code, _GLYPH_W)
		total_width += float(advance) * scale_f
	var start_x: float = x_pivot - total_width / 2.0

	# GMS2: draw_text_transformed_color(x, y, text, xscale, yscale, 0, c1, c1, c2, c2, alpha)
	# Per-character rendering with scaled glyphs from sprfont_counter atlas.
	var cursor_x: float = start_x
	var scaled_h: float = float(_GLYPH_H) * scale_f

	for i in range(text.length()):
		var char_code: int = text.unicode_at(i)
		var glyph_idx: int = char_code - _FIRST_CHAR
		if glyph_idx < 0 or glyph_idx >= _CHAR_COUNT:
			# Space or unsupported — just advance cursor
			cursor_x += float(_GLYPH_W) * scale_f * 0.5
			continue

		var col: int = glyph_idx % _ATLAS_COLS
		@warning_ignore("INTEGER_DIVISION")
		var row: int = glyph_idx / _ATLAS_COLS
		var src_region := Rect2(
			float(col * _GLYPH_W), float(row * _GLYPH_H),
			float(_GLYPH_W), float(_GLYPH_H)
		)

		var advance: int = _char_widths.get(char_code, _GLYPH_W)
		var scaled_w: float = float(_GLYPH_W) * scale_f

		# Outline: draw 8 offset copies in black
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				if ox == 0 and oy == 0:
					continue
				var dst := Rect2(cursor_x + ox, draw_y + oy, scaled_w, scaled_h)
				draw_texture_rect_region(_atlas, dst, src_region, outline_color)

		# Main glyph with color (color1 modulate; gradient via shader if different)
		var dst := Rect2(cursor_x, draw_y, scaled_w, scaled_h)
		draw_texture_rect_region(_atlas, dst, src_region, color1)

		cursor_x += float(advance) * scale_f


func _draw_text_mode() -> void:
	## Fallback rendering for non-counter text (MISS, BLOCK, Level X!, etc.)
	## Uses sprfont_som with simple outline, no gradient.
	if _text_font == null:
		return
	var draw_x: float = x_pivot
	var draw_y: float = _get_draw_y() + y_pivot
	var fs: int = 8  # Small fixed size for text messages

	# Outline (8-direction)
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if ox == 0 and oy == 0:
				continue
			draw_string(_text_font, Vector2(draw_x + ox, draw_y + oy), text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, fs, outline_color)
	# Main text
	draw_string(_text_font, Vector2(draw_x, draw_y), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, fs, color1)


## Static helper: spawn a floating number on a target creature
## GMS2: showCounter(target, damage, counterType)
static func spawn(parent: Node, target: Node2D, value: int, type: int = CounterType.HP_DONE) -> FloatingNumber:
	# GMS2: counters are suppressed during cutscenes (scene_running)
	if GameManager.scene_running:
		return null
	var num := FloatingNumber.new()
	num.counter_type = type

	# Set text
	match type:
		CounterType.HP_GAIN:
			num.text = "+%d" % value
		CounterType.MP_GAIN:
			num.text = "+%d" % value
		CounterType.MP_LOSS:
			num.text = "-%d" % value
		_:
			if value == 0:
				num.text = "0"  # GMS2: damage=0 shows "0" for misses
			else:
				num.text = str(value)

	# Set colors (GMS2 $BBGGRR format converted to RGB)
	match type:
		CounterType.HP_DONE:
			# White (c_white / c_white)
			num.color1 = Color(1.0, 1.0, 1.0)
			num.color2 = Color(1.0, 1.0, 1.0)
		CounterType.HP_LOSS:
			# Red to dark-red gradient (c_red / $1d1daa → #AA1D1D)
			num.color1 = Color(1.0, 0.0, 0.0)
			num.color2 = Color(0.667, 0.114, 0.114)
		CounterType.HP_GAIN:
			# Sky blue ($fac48a → #8AC4FA)
			num.color1 = Color(0.541, 0.769, 0.980)
			num.color2 = Color(0.541, 0.769, 0.980)
		CounterType.MP_LOSS:
			# Purple / magenta for MP loss
			num.color1 = Color(0.7, 0.2, 0.9)
			num.color2 = Color(0.5, 0.1, 0.7)
		CounterType.MP_GAIN:
			# Green (c_green / c_green)
			num.color1 = Color(0.0, 1.0, 0.0)
			num.color2 = Color(0.0, 1.0, 0.0)

	# Attach to creature for tracking (GMS2: attachedObject = target)
	num.attached_object = target if is_instance_valid(target) else null

	# GMS2: yPivot = random_range(-5, 5) for visual variety
	num.y_pivot = randf_range(-5.0, 5.0)

	num.global_position = target.global_position if is_instance_valid(target) else Vector2.ZERO
	# Add to dedicated CanvasLayer so counters always render above game world
	var layer: CanvasLayer = _get_canvas_layer(parent.get_tree())
	layer.add_child(num)
	return num


## Static helper: spawn floating text (non-numeric, e.g. "Level X!", "Cured", "MISS", "BLOCK")
## These use sprfont_som (the general game font), not the counter sprite font.
static func spawn_text(parent: Node, pos: Vector2, msg: String, msg_color: Color = Color.WHITE) -> FloatingNumber:
	var num := FloatingNumber.new()
	num._is_text_mode = true
	num.text = msg
	num.color1 = msg_color
	num.color2 = msg_color
	num.global_position = pos + Vector2(0, randf_range(-5.0, 5.0))
	# Add to dedicated CanvasLayer so text always renders above game world
	var layer: CanvasLayer = _get_canvas_layer(parent.get_tree())
	layer.add_child(num)
	return num
