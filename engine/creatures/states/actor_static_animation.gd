class_name ActorStaticAnimation
extends State
## Actor STATIC ANIMATION state - replaces fsm_actor_static_animation from GMS2
## Shows a static directional frame for a set duration, then returns to stand.
## Used for cutscene poses, item pickups, etc.
## state_vars: [0]=sprUp, [1]=sprRight, [2]=sprDown, [3]=sprLeft, [4]=finishTime, [5]=savedSpeed

var mode: int = 0
var finish_time: float = 1.0
var saved_speed: float = 0.0

func enter() -> void:
	creature.velocity = Vector2.ZERO
	creature.state_protect = true
	creature.image_speed = 0
	mode = 0

	# Read state vars for sprite configuration
	var spr_up: int = state_machine.get_state_var(0, -1)
	if spr_up != -1:
		var spr_right: int = state_machine.get_state_var(1, spr_up)
		var spr_down: int = state_machine.get_state_var(2, spr_up)
		var spr_left: int = state_machine.get_state_var(3, spr_up)
		finish_time = state_machine.get_state_var(4, 60) / 60.0
		saved_speed = state_machine.get_state_var(5, 0.0)

		creature.set_facing_frame(spr_up, spr_right, spr_down, spr_left)
		mode = 1

func execute(_delta: float) -> void:
	if mode == 1 and get_timer() > finish_time:
		creature.image_speed = saved_speed
		(creature as Actor).change_state_stand_dead()

func exit() -> void:
	creature.state_protect = false
	var actor := creature as Actor
	if actor:
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)
