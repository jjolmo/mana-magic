class_name StateMachine
extends Node
## FSM implementation - replaces GMS2 state_machine_init/state_create/state_execute/state_switch

signal state_changed(old_state: String, new_state: String)

@export var initial_state: NodePath

var current_state: State = null
var current_state_name: String = ""
var state_timer: float = 0.0
var state_new: bool = false
var state_var: Array = []
var state_stack: Array[String] = []
var can_interrupt: bool = true

var _states: Dictionary = {}
var _owner_node: Node = null

func _ready() -> void:
	_owner_node = get_parent()
	# Register all child State nodes
	for child in get_children():
		if child is State:
			_states[child.name] = child
			child.state_machine = self
			child.creature = _owner_node

	# Initialize with the initial state
	if initial_state:
		var state_node := get_node_or_null(initial_state)
		if state_node and state_node is State:
			_switch_to(state_node.name, false)
	elif _states.size() > 0:
		_switch_to(_states.keys()[0], false)

func _physics_process(_delta: float) -> void:
	# GMS2: game.ringMenuOpened pauses ALL creature state execution
	if GameManager.ring_menu_opened:
		return
	# GMS2: pauseCreature() stops state execution until unpaused
	# BUT paused creatures can still be hit — temporarily unpause so Hit state
	# can run its full cycle (120 frames), then re-pause on return to Stand.
	if _owner_node is Creature and (_owner_node as Creature).paused:
		var c: Creature = _owner_node as Creature
		if c.damage_stack.size() > 0 and _states.has("Hit"):
			# Unpause so Hit state can execute normally
			c.paused = false
			c._resume_pause_next_switch = false
			switch_state("Hit")
			return
		return
	# GMS2: AI actors freeze completely during cutscenes (lock_all_players).
	# Skip state execution entirely so AI doesn't move, search targets, or change state.
	# Only applies to non-player-controlled actors (player Stand/Walk states check this themselves).
	# IMPORTANT: Do NOT zero velocity here — cutscene scripts (MoveToPosition / go_run)
	# control velocity directly. Zeroing it every frame would fight the script commands.
	# Velocity is zeroed once when lock_movement_input() is first called.
	if _owner_node is Actor and not (_owner_node as Actor).player_controlled:
		if (_owner_node as Creature).movement_input_locked:
			return
	# Delta-time based: state_timer accumulates real seconds, execute() receives actual delta.
	if current_state:
		state_timer += _delta
		state_new = (state_timer <= _delta)  # True only during the first execution frame
		current_state.execute(_delta)
	# GMS2: zAxisController runs in End Step AFTER the Step event.
	# Process z-axis here (after state execution) so _do_bounce() z_velocity is applied
	# in the same physics frame. This eliminates cross-callback timing issues between
	# _physics_process (where states set z_velocity) and _process (where rendering happens).
	if _owner_node is Creature:
		(_owner_node as Creature)._update_z_axis(_delta)

func switch_state(new_state_name: String, push_to_stack: bool = false, vars: Array = []) -> void:
	if not _states.has(new_state_name):
		push_warning("State not found: " + new_state_name)
		return
	_switch_to(new_state_name, push_to_stack, vars)

func _switch_to(new_state_name: String, push_to_stack: bool, vars: Array = []) -> void:
	var old_name := current_state_name

	if current_state:
		if push_to_stack:
			state_stack.append(current_state_name)
		current_state.exit()

	# GMS2: state_switch() auto-resumes paused creatures
	# First switch after pauseCreature(): clear resumePauseInNextSwitch flag, stay paused
	# Second switch: clear paused entirely
	if _owner_node is Creature:
		var c: Creature = _owner_node as Creature
		if c.paused:
			if c._resume_pause_next_switch:
				c._resume_pause_next_switch = false
			else:
				c.paused = false

	current_state_name = new_state_name
	current_state = _states[new_state_name]
	state_timer = 0.0
	state_new = true
	# Only overwrite state_var if vars were explicitly provided.
	# Many states use set_state_var() BEFORE switch_to() to pass data to the
	# next state — clearing state_var with the default [] would wipe that data.
	if not vars.is_empty():
		state_var = vars

	current_state.enter()
	state_changed.emit(old_name, new_state_name)

func pop_state() -> void:
	if state_stack.size() > 0:
		var prev: String = state_stack.pop_back()
		_switch_to(prev, false)

func initialize() -> void:
	## Manual re-initialization for when states are added dynamically after _ready()
	_owner_node = get_parent()
	_states.clear()
	for child in get_children():
		if child is State:
			_states[child.name] = child
			child.state_machine = self
			child.creature = _owner_node
	# Start in Stand state if available, else first state
	if _states.has("Stand"):
		_switch_to("Stand", false)
	elif _states.size() > 0:
		_switch_to(_states.keys()[0], false)


func has_state(state_name: String) -> bool:
	return _states.has(state_name)

func get_state_timer() -> float:
	return state_timer

func reset_state_timer() -> void:
	state_timer = 0.0

func is_new_state() -> bool:
	return state_new

func set_state_var(index: int, value: Variant) -> void:
	while state_var.size() <= index:
		state_var.append(null)
	state_var[index] = value

func get_state_var(index: int, default: Variant = null) -> Variant:
	if index < state_var.size():
		return state_var[index]
	return default
