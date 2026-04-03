class_name ActorRecover
extends State
## Actor RECOVER state - replaces fsm_actor_recover from GMS2
## Recovery from fainted status - plays get-up animation

var anim_phase: int = 1
var sprite_index_ini: int = 0
var sprite_index_end: int = 0

func enter() -> void:
	var actor := creature as Actor
	anim_phase = 1
	creature.velocity = Vector2.ZERO

	# Set recover animation
	creature.set_default_facing_animations(
		actor.spr_recover_up_ini, actor.spr_recover_right_ini,
		actor.spr_recover_down_ini, actor.spr_recover_left_ini,
		actor.spr_recover_up_end, actor.spr_recover_right_end,
		actor.spr_recover_down_end, actor.spr_recover_left_end
	)

	creature.image_speed = actor.img_speed_faint
	creature.set_default_facing_index()

	# Store initial/end frames for this direction
	match creature.facing:
		Constants.Facing.UP:
			sprite_index_ini = actor.spr_recover_up_ini
			sprite_index_end = actor.spr_recover_up_end
		Constants.Facing.RIGHT:
			sprite_index_ini = actor.spr_recover_right_ini
			sprite_index_end = actor.spr_recover_right_end
		Constants.Facing.DOWN:
			sprite_index_ini = actor.spr_recover_down_ini
			sprite_index_end = actor.spr_recover_down_end
		Constants.Facing.LEFT:
			sprite_index_ini = actor.spr_recover_left_ini
			sprite_index_end = actor.spr_recover_left_end

func execute(_delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	if anim_phase == 1:
		# Pause on first frame for a bit
		if creature.current_frame >= sprite_index_ini + 1:
			creature.image_speed = 0

		if get_timer() > 40.0 / 60.0:
			anim_phase = 2

	elif anim_phase == 2:
		# Resume animation to finish
		creature.image_speed = actor.img_speed_faint
		if creature.current_frame >= sprite_index_end:
			switch_to("Stand")

	creature.animate_sprite()

func exit() -> void:
	var actor := creature as Actor
	if actor:
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)
