class_name ActorHit
extends State
## Actor HIT state - replaces fsm_actor_hit from GMS2
## Full implementation: directional hit sprites, z-bounce, multi-hit stack, knockback with collision

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

func enter() -> void:
	var actor := creature as Actor
	creature.velocity = Vector2.ZERO
	creature.disable_shader()
	creature.state_protect = true
	creature.attacked = true
	anim_phase = 1
	performing_damage = false
	has_finished_anim = false
	animate_index = 0
	animate_frame_counter = 0.0

	MusicManager.play_sfx("snd_hurt")

	# Get push direction from damage stack (GMS2: pushDir = state_var[0])
	# push_dir is cached at take_damage() time, safe even if source died since
	if creature.damage_stack.size() > 0:
		var dmg := creature.damage_stack[0] as Dictionary
		knockback_dir = dmg.get("push_dir", Vector2.DOWN) as Vector2
		if knockback_dir.length() < 0.1:
			knockback_dir = Vector2.DOWN

	# Set hit animation frames (directional)
	creature.set_default_facing_animations(
		actor.spr_hit_up_ini, actor.spr_hit_right_ini,
		actor.spr_hit_down_ini, actor.spr_hit_left_ini,
		actor.spr_hit_up_end, actor.spr_hit_right_end,
		actor.spr_hit_down_end, actor.spr_hit_left_end
	)

	# Face direction the hit came from
	creature.facing = creature.get_facing_from_direction(-knockback_dir)
	creature.image_speed = 0
	creature.set_default_facing_index()

	old_pos = creature.global_position
	move_vec = knockback_dir * actor.battle_knockback_speed
	# GMS2: moveKnock = rollCoin() — 50% chance of knockback
	move_knock = randf() >= 0.5

	# Z-bounce (pseudo-3D jump, positive = going up)
	creature.z_velocity = 2.0

	# Animation timing list (frames to spend on each animation frame)
	if actor.has_status(Constants.Status.FAINT):
		animate_list = [0.167, 0.167, 0.167, 0.083]
	else:
		animate_list = [0.167, 0.167, 0.167, 0.083, 1.333, 0.167]

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# Process damage from stack (damage already applied by DamageCalculator)
	if not performing_damage:
		if creature.damage_stack.size() > 0:
			performing_damage = true
			creature.damage_stack.pop_front()
			# GMS2: moveKnock = rollCoin() — 50% chance
			move_knock = randf() >= 0.5
		else:
			# No more damage to process
			creature.state_protect = false
			actor.change_state_stand_dead()
			return

	# Phase 1: Knockback + animate
	if anim_phase == 1:
		# Knockback movement with per-axis collision (GMS2: place_free checks)
		# GMS2: if either axis hits a wall, ALL knockback stops (moveKnock = false).
		# No sliding along walls.
		var distance_moved: float = creature.global_position.distance_to(old_pos)
		if distance_moved >= max_knockback_distance:
			move_knock = false
		elif move_knock:
			var body := creature as CharacterBody2D
			# Y-axis first (GMS2 order): place_free(x, y + move_y)
			body.velocity = Vector2(0, move_vec.y) * 60.0
			body.move_and_slide()
			if body.get_slide_collision_count() > 0:
				move_knock = false
			# X-axis second: place_free(x + move_x, y) — still runs this frame
			body.velocity = Vector2(move_vec.x, 0) * 60.0
			body.move_and_slide()
			if body.get_slide_collision_count() > 0:
				move_knock = false

		# Animate step-by-step using animate_list
		if _animate_step(delta):
			has_finished_anim = true

		if has_finished_anim:
			anim_phase = 2

	elif anim_phase == 2:
		creature.velocity = Vector2.ZERO
		if not actor.is_actor_dead():
			if creature.damage_stack.size() > 0:
				# More damage in stack - loop back
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
	# Restore walk animations
	var actor := creature as Actor
	if actor:
		creature.set_default_facing_animations(
			actor.spr_walk_up_ini, actor.spr_walk_right_ini,
			actor.spr_walk_down_ini, actor.spr_walk_left_ini,
			actor.spr_walk_up_end, actor.spr_walk_right_end,
			actor.spr_walk_down_end, actor.spr_walk_left_end
		)

## Advance animation using animate_list timing. Returns true when finished.
func _animate_step(delta: float) -> bool:
	if animate_index >= animate_list.size():
		return true
	animate_frame_counter += delta
	if animate_frame_counter >= animate_list[animate_index]:
		animate_frame_counter = 0.0
		animate_index += 1
		# Advance sprite frame
		creature.current_frame += 1
		creature.set_frame(creature.current_frame)
	return animate_index >= animate_list.size()
