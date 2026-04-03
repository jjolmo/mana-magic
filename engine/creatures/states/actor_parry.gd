class_name ActorParry
extends State
## Actor PARRY state - replaces fsm_actor_parry from GMS2
## Three random patterns: parry1 (static block), parry2 (static block), avoid (dodge backwards)

var go_static: bool = false
var rnd_parry: int = 0
var parry_time: float = 0.5
var move_vec: Vector2 = Vector2.ZERO

func enter() -> void:
	var actor := creature as Actor
	creature.velocity = Vector2.ZERO
	creature.disable_shader()
	creature.image_speed = 0

	MusicManager.play_sfx("snd_parry")

	go_static = false
	rnd_parry = randi_range(0, 2)
	parry_time = 0.5

	if rnd_parry == 0:
		# Parry pattern 1 - static block
		creature.set_facing_frame(
			actor.spr_parry1_up, actor.spr_parry1_right,
			actor.spr_parry1_down, actor.spr_parry1_left
		)
		go_static = true

	elif rnd_parry == 1:
		# Parry pattern 2 - static block (different pose)
		creature.set_facing_frame(
			actor.spr_parry2_up, actor.spr_parry2_right,
			actor.spr_parry2_down, actor.spr_parry2_left
		)
		go_static = true

	elif rnd_parry == 2:
		# Avoid - dodge backwards
		creature.set_default_facing_animations(
			actor.spr_avoid_up_ini, actor.spr_avoid_right_ini,
			actor.spr_avoid_down_ini, actor.spr_avoid_left_ini,
			actor.spr_avoid_up_end, actor.spr_avoid_right_end,
			actor.spr_avoid_down_end, actor.spr_avoid_left_end
		)
		creature.set_default_facing_index()
		# Move away from facing direction
		var dodge_dir: Vector2 = -creature.get_facing_direction()
		move_vec = dodge_dir * actor.battle_avoid_speed

func execute(_delta: float) -> void:
	if not go_static:
		# Dodge movement
		creature.velocity = move_vec * 60.0
		(creature as CharacterBody2D).move_and_slide()

		if creature.animate_sprite(creature.image_speed):
			(creature as Actor).go_idle()
	else:
		# Static block - wait then return
		if get_timer() > parry_time:
			(creature as Actor).go_idle()

func exit() -> void:
	creature.velocity = Vector2.ZERO
	var actor := creature as Actor
	if actor:
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)
