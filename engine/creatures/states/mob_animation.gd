class_name MobAnimation
extends State
## Mob ANIMATION state - replaces fsm_mob_animation from GMS2
## Generic animation state for mobs. Delegates to same logic as actor animation.
## Handles status effects, timed returns, and damage processing.

var change_state_time_limit: float = -1.0
var status: int = -1
var fainted: bool = false

func enter() -> void:
	creature.velocity = Vector2.ZERO
	creature.state_protect = true
	creature.change_state = false
	fainted = false
	status = -1
	change_state_time_limit = -1.0

	if not creature.is_dead:
		creature.disable_shader()

	# Check for timed mode
	var mode_var: Variant = state_machine.get_state_var(0, null)
	if mode_var is int and mode_var == -1:
		change_state_time_limit = state_machine.get_state_var(1, 60) / 60.0

	# Check for status effect mode
	var status_var: Variant = state_machine.get_state_var(4, null)
	if status_var is int:
		status = status_var
		if status == Constants.Status.FAINT:
			creature.z_velocity = 2.0
			MusicManager.play_sfx("snd_hurt")

func execute(_delta: float) -> void:
	# Faint animation
	if status == Constants.Status.FAINT and not fainted:
		if creature.animate_sprite(0.15, true):
			fainted = true

	# Timed return
	if change_state_time_limit >= 0.0 and get_timer() >= change_state_time_limit:
		if creature.is_dead:
			switch_to("Dead")
		else:
			switch_to("Stand")

func exit() -> void:
	creature.state_protect = false
	creature.velocity = Vector2.ZERO
