class_name ActorHit2
extends State
## Actor HIT2 state - replaces fsm_actor_hit2 from GMS2
## Heavy hit/faint with recovery jump. Used for critical or status-inducing hits.

var knockback_dir: Vector2 = Vector2.ZERO
var move_vec: Vector2 = Vector2.ZERO
var old_pos: Vector2 = Vector2.ZERO
var max_knockback_distance: float = 40.0
var performing_damage: bool = false
var move_knock: bool = false
var anim_phase: int = 1
var animate_list: Array[float] = []
var animate_index: int = 0
var animate_frame_counter: float = 0.0
var has_finished_anim: bool = false
var jump_recover: bool = false
var actor_is_dead: bool = false
var sprite_index_ini: int = 0
## GMS2: isAnim = getStateVar(1, undefined) — animation-only mode for cutscenes
var is_anim: bool = false

func enter() -> void:
	var actor := creature as Actor
	creature.velocity = Vector2.ZERO
	creature.disable_shader()
	creature.state_protect = true
	creature.attacked = true
	anim_phase = 1
	performing_damage = false
	has_finished_anim = false
	jump_recover = false
	actor_is_dead = false
	animate_index = 0
	animate_frame_counter = 0.0

	# GMS2: isAnim = getStateVar(1, undefined) — cutscene animation-only mode
	is_anim = creature.get_meta("hit2_is_anim", false)
	if creature.has_meta("hit2_is_anim"):
		creature.remove_meta("hit2_is_anim")

	MusicManager.play_sfx("snd_hurt")

	# Get push direction from damage stack (cached at take_damage time, safe if source died)
	# GMS2: pushDir = getStateVar(0, 0)
	if is_anim:
		# Animation-only: read push direction from meta (GMS2 degree angle)
		var push_angle: float = creature.get_meta("hit2_push_dir", 0.0)
		if creature.has_meta("hit2_push_dir"):
			creature.remove_meta("hit2_push_dir")
		# Convert GMS2 degrees to Vector2 (GMS2: 0=right, 90=up, 180=left, 270=down)
		knockback_dir = Vector2(cos(deg_to_rad(push_angle)), -sin(deg_to_rad(push_angle)))
		if knockback_dir.length() < 0.1:
			knockback_dir = Vector2.DOWN
	elif creature.damage_stack.size() > 0:
		var dmg := creature.damage_stack[0] as Dictionary
		knockback_dir = dmg.get("push_dir", Vector2.DOWN) as Vector2
		if knockback_dir.length() < 0.1:
			knockback_dir = Vector2.DOWN
	else:
		knockback_dir = Vector2.DOWN
	# GMS2: moveKnock = rollCoin() — 50% chance of knockback
	move_knock = randf() >= 0.5

	# Set hit2 animation frames (faint/heavy hit)
	# GMS2: end frames have -1 offset ("we reduce one frame because it is the frame that stops")
	creature.set_default_facing_animations(
		actor.spr_hit2_up_ini, actor.spr_hit2_right_ini,
		actor.spr_hit2_down_ini, actor.spr_hit2_left_ini,
		actor.spr_hit2_up_end - 1, actor.spr_hit2_right_end - 1,
		actor.spr_hit2_down_end - 1, actor.spr_hit2_left_end - 1
	)

	# Face direction the hit came from
	creature.facing = creature.get_facing_from_direction(-knockback_dir)
	creature.image_speed = 0
	creature.set_default_facing_index()

	# Store initial sprite frame for jump recover check
	match creature.facing:
		Constants.Facing.UP: sprite_index_ini = actor.spr_hit2_up_ini
		Constants.Facing.RIGHT: sprite_index_ini = actor.spr_hit2_right_ini
		Constants.Facing.DOWN: sprite_index_ini = actor.spr_hit2_down_ini
		Constants.Facing.LEFT: sprite_index_ini = actor.spr_hit2_left_ini

	old_pos = creature.global_position
	move_vec = knockback_dir * actor.battle_knockback_speed

	# Z-bounce (positive = going up)
	creature.z_velocity = 2.0

	# Animation timing for hit2 (longer recovery than hit1)
	if actor.has_status(Constants.Status.FAINT):
		animate_list = [0.167, 0.167, 0.167]
	else:
		animate_list = [0.167, 0.167, 1.667, 0.333, 0.167, 0.167, 0.167]

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# Process damage from stack (damage already applied by DamageCalculator)
	if not performing_damage:
		if creature.damage_stack.size() > 0:
			performing_damage = true
			creature.damage_stack.pop_front()

			actor_is_dead = actor.is_actor_dead()
			if actor_is_dead:
				animate_list = [0.167, 0.167, 1.667]

			move_vec = knockback_dir * actor.battle_knockback_speed
		elif is_anim:
			# GMS2: isAnim pathway — play animation without damage data
			move_knock = false
			performing_damage = true
		else:
			creature.state_protect = false
			actor.change_state_stand_dead()
			return

	# Phase 1: Knockback + animate
	if anim_phase == 1:
		# Per-axis collision matching GMS2 place_free behavior (no wall sliding)
		var distance_moved: float = creature.global_position.distance_to(old_pos)
		if distance_moved >= max_knockback_distance:
			move_knock = false
		elif move_knock:
			var body := creature as CharacterBody2D
			# Y-axis first (GMS2 order)
			body.velocity = Vector2(0, move_vec.y) * 60.0
			body.move_and_slide()
			if body.get_slide_collision_count() > 0:
				move_knock = false
			# X-axis second — still runs this frame even if Y hit
			body.velocity = Vector2(move_vec.x, 0) * 60.0
			body.move_and_slide()
			if body.get_slide_collision_count() > 0:
				move_knock = false

		# Recovery jump at frame 4 of animation
		if not jump_recover and animate_index >= 4:
			creature.z_velocity = 1.0
			jump_recover = true

		if _animate_step(delta):
			has_finished_anim = true

		if has_finished_anim:
			anim_phase = 2
			if actor.is_actor_dead():
				creature.image_speed = 0
				creature.state_protect = false
				switch_to("Dead")
				return

	elif anim_phase == 2:
		creature.velocity = Vector2.ZERO
		if not actor_is_dead:
			if creature.damage_stack.size() > 0:
				anim_phase = 1
				performing_damage = false
				has_finished_anim = false
				animate_index = 0
				animate_frame_counter = 0.0
				MusicManager.play_sfx("snd_hurt")
			else:
				creature.state_protect = false
				actor.change_state_stand_dead()
		else:
			creature.state_protect = false
			switch_to("Dead")

func exit() -> void:
	creature.velocity = Vector2.ZERO
	creature.state_protect = false
	creature.attacked = false
	# Brief post-hit invulnerability to prevent instant re-hit
	if not creature.is_dead:
		creature.set_invulnerable_time(20.0 / 60.0)
	var actor := creature as Actor
	if actor:
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)

func _animate_step(delta: float) -> bool:
	if animate_index >= animate_list.size():
		return true
	animate_frame_counter += delta
	if animate_frame_counter >= animate_list[animate_index]:
		animate_frame_counter = 0.0
		animate_index += 1
		creature.current_frame += 1
		creature.set_frame(creature.current_frame)
	return animate_index >= animate_list.size()
