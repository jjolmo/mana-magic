class_name ActorAnimation
extends State
## Actor ANIMATION state - replaces fsm_actor_animation from GMS2
## Generic animation state for status effects, debuffs, and scripted animations.
## Modes: ACTION_DAMAGE_CREATURE, ACTION_CHANGE_SPRITE_DEBUFF, timed auto-return

# Mode constants (matching GMS2 game.ACTION_*)
const ACTION_DAMAGE_CREATURE := 0
const ACTION_CHANGE_SPRITE_DEBUFF := 1
const ACTION_CHANGE_SPRITE_DEBUFF_DAMAGE := 2
const ACTION_TIMED := -1  # Special: timed return to stand

var has_mode: bool = false
var status: int = -1
var anim_timer_limit: float = 0.0
var change_state_time_limit: float = -1.0
var performing_damage: bool = false
var fainted: bool = false

func enter() -> void:
	var actor := creature as Actor
	if not actor:
		return

	if not actor.is_actor_dead():
		creature.disable_shader()

	anim_timer_limit = 0.0
	status = -1
	creature.change_state = false
	fainted = false
	performing_damage = false
	creature.state_protect = true

	# Check state vars for mode
	var mode_var: Variant = state_machine.get_state_var(0, null)
	has_mode = mode_var != null

	if has_mode:
		var mode_action: int = mode_var if mode_var is int else -1

		if mode_action == ACTION_TIMED:
			# Timed animation: var[1] = time limit (was frames, convert to seconds)
			change_state_time_limit = state_machine.get_state_var(1, 60) / 60.0

		elif mode_action == ACTION_DAMAGE_CREATURE:
			# Damage + status animation
			status = state_machine.get_state_var(1, -1)

			if status == Constants.Status.FROZEN or status == Constants.Status.PETRIFIED:
				creature.set_frame(state_machine.get_state_var(2, 0))
				creature.image_speed = state_machine.get_state_var(3, 0)
			elif status == Constants.Status.ENGULFED:
				creature.image_speed = 0
				creature.set_facing_frame(
					creature.spr_stand_up, creature.spr_stand_right,
					creature.spr_stand_down, creature.spr_stand_left
				)

			# Process damage
			performing_damage = true
			if creature.damage_stack.size() > 0:
				var dmg_data: Variant = creature.damage_stack.pop_front()
				if dmg_data is Dictionary:
					creature.apply_damage(dmg_data.get("damage", 0))
					if creature.is_dead:
						switch_to("Dead")
						return

		elif mode_action == ACTION_CHANGE_SPRITE_DEBUFF or mode_action == ACTION_CHANGE_SPRITE_DEBUFF_DAMAGE:
			creature.image_speed = 0
			anim_timer_limit = state_machine.get_state_var(3, 0) / 60.0
			status = state_machine.get_state_var(4, -1)

			if status == Constants.Status.FAINT:
				creature.z_velocity = 2.0
				MusicManager.play_sfx("snd_hurt")
				# Use hit2 frames for faint animation
				creature.set_default_facing_animations(
					actor.spr_hit2_up_ini, actor.spr_hit2_right_ini,
					actor.spr_hit2_down_ini, actor.spr_hit2_left_ini,
					actor.spr_hit2_up_end, actor.spr_hit2_right_end,
					actor.spr_hit2_down_end, actor.spr_hit2_left_end
				)
				creature.image_speed = actor.img_speed_hurt
				creature.set_default_facing_index()

			if mode_action == ACTION_CHANGE_SPRITE_DEBUFF_DAMAGE:
				performing_damage = true
				if creature.damage_stack.size() > 0:
					var dmg_data: Variant = creature.damage_stack.pop_front()
					if dmg_data is Dictionary:
						creature.apply_damage(dmg_data.get("damage", 0))
						if creature.is_dead:
							switch_to("Dead")
							return

func execute(_delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# Faint animation
	if status == Constants.Status.FAINT and not fainted:
		if creature.animate_sprite(actor.img_speed_hurt, true):
			fainted = true

	# Timed return to stand
	if change_state_time_limit >= 0.0:
		if get_timer() >= change_state_time_limit:
			actor.change_state_stand_dead()

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
