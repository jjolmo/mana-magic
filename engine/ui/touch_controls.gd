class_name TouchControls
extends CanvasLayer
## Virtual D-pad + action buttons for mobile/touch input.
## Shows/hides based on GameManager.is_mobile.
## Injects InputEventAction so all existing input code works unchanged.

const DPAD_RADIUS: float = 32.0
const DPAD_DEAD_ZONE: float = 8.0
const BUTTON_RADIUS: float = 18.0

# Layout positions (relative to viewport)
const DPAD_CENTER := Vector2(50, 200)  # Bottom-left
const BTN_ATTACK_POS := Vector2(387, 200)  # Bottom-right
const BTN_RUN_POS := Vector2(407, 175)
const BTN_MENU_POS := Vector2(367, 175)
const BTN_MISC_POS := Vector2(387, 150)

# Button definitions: [position, action_name, label, color]
var _buttons: Array = []

# Touch tracking
var _dpad_touch_idx: int = -1
var _dpad_dir := Vector2.ZERO
var _button_touch_map: Dictionary = {}  # touch_idx -> button_idx
var _active_dpad_actions: Array = []  # Currently pressed dpad actions

var _font: Font
var _visible: bool = false


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS

	_buttons = [
		[BTN_ATTACK_POS, "attack", "A", Color(0.2, 0.7, 0.2, 0.6)],
		[BTN_RUN_POS, "run", "B", Color(0.7, 0.2, 0.2, 0.6)],
		[BTN_MENU_POS, "menu", "X", Color(0.2, 0.2, 0.7, 0.6)],
		[BTN_MISC_POS, "misc", "Y", Color(0.7, 0.7, 0.2, 0.6)],
	]

	_font = load("res://assets/fonts/sprfont_som.fnt")

	# Create a Control to handle drawing and input
	var ctrl := Control.new()
	ctrl.name = "TouchOverlay"
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	ctrl.draw.connect(_on_draw.bind(ctrl))
	add_child(ctrl)

	_update_visibility()


func _process(_delta: float) -> void:
	var should_show: bool = GameManager.is_mobile
	if should_show != _visible:
		_visible = should_show
		_update_visibility()

	if _visible:
		get_child(0).queue_redraw()


func _input(event: InputEvent) -> void:
	if not _visible:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var pos := _screen_to_viewport(event.position)

	if event.pressed:
		# Check D-pad
		if _dpad_touch_idx < 0 and pos.distance_to(DPAD_CENTER) < DPAD_RADIUS + 10:
			_dpad_touch_idx = event.index
			_update_dpad(pos)
			return

		# Check buttons
		for i in range(_buttons.size()):
			var btn_pos: Vector2 = _buttons[i][0]
			if pos.distance_to(btn_pos) < BUTTON_RADIUS + 4:
				_button_touch_map[event.index] = i
				_inject_action(_buttons[i][1], true)
				return
	else:
		# Release
		if event.index == _dpad_touch_idx:
			_dpad_touch_idx = -1
			_release_all_dpad()
			return

		if _button_touch_map.has(event.index):
			var btn_idx: int = _button_touch_map[event.index]
			_inject_action(_buttons[btn_idx][1], false)
			_button_touch_map.erase(event.index)
			return


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _dpad_touch_idx:
		var pos := _screen_to_viewport(event.position)
		_update_dpad(pos)


func _update_dpad(touch_pos: Vector2) -> void:
	var offset := touch_pos - DPAD_CENTER
	var new_actions: Array = []

	if offset.length() > DPAD_DEAD_ZONE:
		_dpad_dir = offset.normalized()
		# 8-directional: check which actions to press
		if _dpad_dir.y < -0.4:
			new_actions.append("move_up")
		if _dpad_dir.y > 0.4:
			new_actions.append("move_down")
		if _dpad_dir.x < -0.4:
			new_actions.append("move_left")
		if _dpad_dir.x > 0.4:
			new_actions.append("move_right")
	else:
		_dpad_dir = Vector2.ZERO

	# Release actions no longer active
	for action in _active_dpad_actions:
		if action not in new_actions:
			_inject_action(action, false)

	# Press new actions
	for action in new_actions:
		if action not in _active_dpad_actions:
			_inject_action(action, true)

	_active_dpad_actions = new_actions


func _release_all_dpad() -> void:
	for action in _active_dpad_actions:
		_inject_action(action, false)
	_active_dpad_actions.clear()
	_dpad_dir = Vector2.ZERO


func _inject_action(action_name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	Input.parse_input_event(event)


func _screen_to_viewport(screen_pos: Vector2) -> Vector2:
	# Convert screen coordinates to viewport coordinates
	var vp_size := get_viewport().get_visible_rect().size
	var win_size := Vector2(DisplayServer.window_get_size())
	if win_size.x <= 0 or win_size.y <= 0:
		return screen_pos
	return screen_pos * (vp_size / win_size)


func _update_visibility() -> void:
	if get_child_count() > 0:
		get_child(0).visible = _visible


func _on_draw(ctrl: Control) -> void:
	if not _visible:
		return

	# Draw D-pad background
	ctrl.draw_circle(DPAD_CENTER, DPAD_RADIUS, Color(0.2, 0.2, 0.2, 0.35))
	ctrl.draw_arc(DPAD_CENTER, DPAD_RADIUS, 0, TAU, 32, Color(0.5, 0.5, 0.5, 0.4), 1.0)

	# Draw D-pad direction indicator
	if _dpad_dir.length() > 0.1:
		var indicator_pos := DPAD_CENTER + _dpad_dir * (DPAD_RADIUS * 0.6)
		ctrl.draw_circle(indicator_pos, 8.0, Color(1.0, 1.0, 1.0, 0.5))

	# Draw D-pad arrows
	var arrow_color := Color(0.7, 0.7, 0.7, 0.4)
	var arrow_dist: float = DPAD_RADIUS * 0.55
	_draw_arrow(ctrl, DPAD_CENTER + Vector2(0, -arrow_dist), Vector2(0, -1), arrow_color)
	_draw_arrow(ctrl, DPAD_CENTER + Vector2(0, arrow_dist), Vector2(0, 1), arrow_color)
	_draw_arrow(ctrl, DPAD_CENTER + Vector2(-arrow_dist, 0), Vector2(-1, 0), arrow_color)
	_draw_arrow(ctrl, DPAD_CENTER + Vector2(arrow_dist, 0), Vector2(1, 0), arrow_color)

	# Draw action buttons
	for i in range(_buttons.size()):
		var btn_pos: Vector2 = _buttons[i][0]
		var btn_label: String = _buttons[i][2]
		var btn_color: Color = _buttons[i][3]

		# Highlight if pressed
		var is_pressed: bool = i in _button_touch_map.values()
		if is_pressed:
			btn_color.a = 0.9

		ctrl.draw_circle(btn_pos, BUTTON_RADIUS, btn_color)
		ctrl.draw_arc(btn_pos, BUTTON_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.4), 1.0)

		# Label
		if _font:
			ctrl.draw_string(_font, btn_pos + Vector2(-3, 3), btn_label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color.WHITE)


func _draw_arrow(ctrl: Control, pos: Vector2, dir: Vector2, color: Color) -> void:
	var size: float = 5.0
	var perp := Vector2(-dir.y, dir.x)
	var tip := pos + dir * size
	var base_l := pos - dir * size * 0.3 + perp * size * 0.5
	var base_r := pos - dir * size * 0.3 - perp * size * 0.5
	ctrl.draw_polygon([tip, base_l, base_r], [color, color, color])


## Static helper: create and add touch controls to the scene tree
static func create(tree: SceneTree) -> TouchControls:
	var tc := TouchControls.new()
	tc.name = "TouchControls"
	tree.root.add_child(tc)
	return tc
