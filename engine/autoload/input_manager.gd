extends Node
## Input management - converts GMS2 input system to Godot InputMap

func _ready() -> void:
	_setup_input_map()

func _setup_input_map() -> void:
	# Movement
	_add_action("move_up", [KEY_UP], [JOY_BUTTON_DPAD_UP])
	_add_action("move_down", [KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_add_action("move_left", [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_add_action("move_right", [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])

	# Actions (matching GMS2 mapping: S=attack, D=run, A=menu, W=misc)
	_add_action("attack", [KEY_S], [JOY_BUTTON_A])  # gp_face1
	_add_action("run", [KEY_D], [JOY_BUTTON_B])      # gp_face2
	_add_action("menu", [KEY_A], [JOY_BUTTON_X])      # gp_face3
	_add_action("misc", [KEY_W], [JOY_BUTTON_Y])      # gp_face4

	# System
	_add_action("swap_actor", [KEY_SHIFT], [JOY_BUTTON_BACK])   # gp_select
	_add_action("toggle_controller", [KEY_ENTER], [JOY_BUTTON_START]) # gp_start

func _add_action(action_name: String, keys: Array, buttons: Array = []) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		InputMap.action_add_event(action_name, event)

	for btn in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = btn
		InputMap.action_add_event(action_name, event)

# --- Input query helpers matching GMS2 patterns ---

func is_moving() -> bool:
	return Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down") \
		or Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")

func get_movement_vector() -> Vector2:
	var vec := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		vec.y -= 1
	if Input.is_action_pressed("move_down"):
		vec.y += 1
	if Input.is_action_pressed("move_left"):
		vec.x -= 1
	if Input.is_action_pressed("move_right"):
		vec.x += 1
	return vec.normalized() if vec.length() > 0 else vec

func get_facing_from_input() -> int:
	if Input.is_action_pressed("move_up"):
		return Constants.Facing.UP
	if Input.is_action_pressed("move_right"):
		return Constants.Facing.RIGHT
	if Input.is_action_pressed("move_down"):
		return Constants.Facing.DOWN
	if Input.is_action_pressed("move_left"):
		return Constants.Facing.LEFT
	return -1

func is_attack_pressed() -> bool:
	return Input.is_action_just_pressed("attack")

func is_attack_held() -> bool:
	return Input.is_action_pressed("attack")

func is_run_held() -> bool:
	return Input.is_action_pressed("run")

func is_run_pressed() -> bool:
	return Input.is_action_just_pressed("run")

func is_run_released() -> bool:
	return Input.is_action_just_released("run")

func is_menu_pressed() -> bool:
	return Input.is_action_just_pressed("menu")

func is_misc_pressed() -> bool:
	return Input.is_action_just_pressed("misc")

func is_swap_pressed() -> bool:
	return Input.is_action_just_pressed("swap_actor")

func is_start_pressed() -> bool:
	return Input.is_action_just_pressed("toggle_controller")
