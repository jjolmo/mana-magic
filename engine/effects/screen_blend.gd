class_name ScreenBlend
extends CanvasLayer
## Screen color blend overlay - replaces go_blendScreenOn/Off from GMS2.
## Draws a persistent colored overlay that can fade in/out.
## Usage: ScreenBlend.create(tree, color, alpha) then .fade_off(duration)

var color_rect: ColorRect
var target_alpha: float = 0.0
var current_alpha: float = 0.0
var fade_speed: float = 0.0
var fading: bool = false
var destroy_on_complete: bool = false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS

	color_rect = ColorRect.new()
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(color_rect)


func _process(_delta: float) -> void:
	if not fading:
		return

	if current_alpha < target_alpha:
		current_alpha = minf(current_alpha + fade_speed * _delta, target_alpha)
	elif current_alpha > target_alpha:
		current_alpha = maxf(current_alpha - fade_speed * _delta, target_alpha)

	color_rect.color.a = current_alpha

	if absf(current_alpha - target_alpha) < 0.001:
		fading = false
		current_alpha = target_alpha
		color_rect.color.a = current_alpha
		if destroy_on_complete or current_alpha <= 0.0:
			queue_free()


func fade_on(alpha: float = 1.0, duration_frames: int = 30) -> void:
	target_alpha = alpha
	# Convert frame duration to per-second speed: alpha over (frames/60) seconds
	var duration_secs := float(maxi(1, duration_frames)) / 60.0
	fade_speed = alpha / duration_secs
	fading = true
	destroy_on_complete = false


func fade_off(duration_frames: int = 30) -> void:
	target_alpha = 0.0
	var duration_secs := float(maxi(1, duration_frames)) / 60.0
	fade_speed = current_alpha / duration_secs
	fading = true
	destroy_on_complete = true


## Static helper: create a blend overlay
static func create(tree: SceneTree, color: Color = Color.BLACK, alpha: float = 1.0) -> ScreenBlend:
	var blend := ScreenBlend.new()
	blend.name = "ScreenBlend"
	tree.root.add_child(blend)
	blend.current_alpha = alpha
	blend.call_deferred("_set_initial_color", color, alpha)
	return blend


func _set_initial_color(color: Color, alpha: float) -> void:
	if color_rect:
		color_rect.color = Color(color.r, color.g, color.b, alpha)
