class_name ScreenFlash
extends CanvasLayer
## Quick screen flash effect - replaces go_flash / oFlash from GMS2.
## GMS2: Binary strobe — full-screen white every other frame, N total flashes.
## Also supports smooth fade mode for other callers.

var color_rect: ColorRect
var flash_alpha: float = 1.0
var fade_speed: float = 0.05
var _initial_color: Color = Color.WHITE

# Strobe mode (GMS2: oFlash)
var _strobe_mode: bool = false
var _strobe_total: int = 1
var _strobe_count: int = 0
var _strobe_timer: float = 0.0


func _ready() -> void:
	layer = 101  # Must be above MapTransition (layer 100)
	process_mode = Node.PROCESS_MODE_ALWAYS

	color_rect = ColorRect.new()
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = _initial_color
	add_child(color_rect)


func _process(delta: float) -> void:
	if _strobe_mode:
		_process_strobe(delta)
	else:
		_process_fade(delta)


func _process_fade(delta: float) -> void:
	flash_alpha -= fade_speed * delta
	if flash_alpha <= 0.0:
		queue_free()
		return
	color_rect.color.a = flash_alpha


func _process_strobe(delta: float) -> void:
	## GMS2: oFlash Draw_0 — every 2 frames, draw white rect THEN increment count.
	## The white rect is drawn BEFORE incrementing, so totalFlashes=1 gets 1 visible frame.
	_strobe_timer += delta
	if _strobe_timer > 2.0 / 60.0:
		_strobe_timer = 0.0
		# GMS2: draw_rectangle_color(...) — show white FIRST
		color_rect.color.a = 1.0
		_strobe_count += 1
	else:
		color_rect.color.a = 0.0
	# GMS2: if (flashes >= totalFlashes) instance_destroy() — checked NEXT frame
	if _strobe_count >= _strobe_total:
		queue_free()


## Static helper: create a smooth fade flash effect
static func create(tree: SceneTree, color: Color = Color.WHITE, duration_frames: int = 20) -> ScreenFlash:
	var flash := ScreenFlash.new()
	flash.flash_alpha = color.a
	# Convert frame duration to per-second speed
	var duration_secs := float(maxi(1, duration_frames)) / 60.0
	flash.fade_speed = color.a / duration_secs
	flash._initial_color = color
	flash.name = "ScreenFlash"
	tree.root.add_child(flash)
	return flash


## Static helper: create a GMS2-style strobe flash (N blinks, binary on/off)
static func create_strobe(tree: SceneTree, total_flashes: int = 1, color: Color = Color.WHITE) -> ScreenFlash:
	var flash := ScreenFlash.new()
	flash._strobe_mode = true
	flash._strobe_total = maxi(1, total_flashes)
	flash._strobe_count = 0
	flash._strobe_timer = 0
	flash._initial_color = color
	flash.name = "ScreenFlash"
	tree.root.add_child(flash)
	return flash
