class_name State
extends Node
## Base state for FSM - each state extends this

var state_machine: StateMachine
var creature: Node  # The creature (actor/mob) this state belongs to

func enter() -> void:
	pass

func execute(_delta: float) -> void:
	pass

func exit() -> void:
	pass

# Helper to check if this is the first frame of the state
func is_new() -> bool:
	return state_machine.is_new_state()

func get_timer() -> float:
	return state_machine.get_state_timer()

func reset_timer() -> void:
	state_machine.reset_state_timer()

func switch_to(state_name: String, vars: Array = []) -> void:
	state_machine.switch_state(state_name, false, vars)

func push_to(state_name: String) -> void:
	state_machine.switch_state(state_name, true)

func pop_state() -> void:
	state_machine.pop_state()
