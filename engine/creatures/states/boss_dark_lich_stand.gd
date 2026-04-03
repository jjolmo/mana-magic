class_name BossDarkLichStand
extends State
## Dark Lich STAND state - replaces fsm_mob_darkLich_stand from GMS2
## Complex idle state with two phases (FULLBODY/HANDS), casting, and movement.

var cast_times: int = 0
var cast_times_limit: int = 3
var keyframe: int = 1
var will_move: bool = false
var random_time: float = 5.0  # 300 / 60.0
var changing: bool = false
var hands_head_appear_timer: float = 200 / 60.0
var show_head: bool = false
var hands_head_shown: bool = false
var timer_cast: float = 0.0
var timer_limit_skill: float = 250.0 / 60.0
var insta_cast: bool = false
var attacked_times: int = 0  ## GMS2: attackedTimes - attacks per HANDS phase
var max_attack_times: int = 3  ## GMS2: maxAttackTimes
var hands_move_dir: int = -1  ## Movement direction for HANDS: -1=up, 1=down
var target_player: Node = null  ## GMS2: targetPlayer - persists for movement during keyframe 2

func enter() -> void:
	var boss := creature as BossDarkLich
	if not boss:
		return

	creature.is_invulnerable = false
	creature.velocity = Vector2.ZERO
	changing = false
	creature.modulate.a = 1.0

	# GMS2: state_var[0] controls entry mode:
	# true = insta-cast from HANDS→FULLBODY, 2 = returning from Cast (keyframe=2), else normal
	var entry_var: Variant = state_machine.get_state_var(0, null)
	var returning_from_cast: bool = (entry_var is int and entry_var == 2)

	if returning_from_cast:
		# GMS2: state_payload(2) from Cast — resume at keyframe 2, keep cast_times
		insta_cast = false
		keyframe = 2
		# Reset timer for wait phase but preserve cast_times
		random_time = randf_range(720 / 60.0, 960 / 60.0)
		if will_move:
			random_time += 240 / 60.0
	else:
		# Fresh entry
		cast_times = 0
		keyframe = 1
		attacked_times = 0
		hands_head_shown = false
		insta_cast = (entry_var == true)

		if boss.current_phase == BossDarkLich.Phase.FULLBODY:
			random_time = randf_range(720 / 60.0, 960 / 60.0)
			_look_at_random_player()
			target_player = _get_random_player()  # GMS2: persist for movement
		else:
			# HANDS phase
			hands_head_appear_timer = randf_range(180 / 60.0, 300 / 60.0)
			show_head = randi() % 2 == 0
			random_time = randf_range(60 / 60.0, 180 / 60.0)
			# GMS2: setDefaultFacingAnimations(handsMove1Ini+1, handsMove1End) on STAND entry
			var config: Dictionary = boss.phase_sprite_config.get(BossDarkLich.Phase.HANDS, {})
			var stand_ini: int = config.get("stand_ini", 51) + 1  # skip first frame
			var stand_end: int = config.get("stand_end", 53)
			creature.set_default_facing_animations(
				stand_ini, stand_ini, stand_ini, stand_ini,
				stand_end, stand_end, stand_end, stand_end
			)
			creature.set_default_facing_index()

		cast_times_limit = randi_range(2, 3)
		will_move = randi() % 2 == 0
		if will_move:
			random_time += 240 / 60.0

	# GMS2: image_speed = state_imgSpeedStand = 0.1 (always set on state entry)
	creature.image_speed = 0.1
	timer_limit_skill = randf_range(250 / 60.0, 300 / 60.0)
	timer_cast = 0.0

func execute(_delta: float) -> void:
	var boss := creature as BossDarkLich
	if not boss:
		return

	# Process damage
	if creature.damage_stack.size() > 0:
		switch_to("DLHit")
		return

	creature.animate_sprite()
	var timer := get_timer()
	# Note: phase_time is already incremented in boss_dark_lich._process()

	if boss.current_phase == BossDarkLich.Phase.FULLBODY:
		if keyframe == 1:
			cast_times += 1
			# GMS2: castMagic() — always transition to Cast state on keyframe 1
			var skill_name: String = boss.get_random_skill()
			var random_player: Node = _get_random_player()
			if random_player and skill_name != "":
				# GMS2: changeState(state_SUMMON) with skill info
				# Cast state vars: [0]=skillName, [1]=magicLevel, [2]=target, [3]=source
				switch_to("DLCast", [skill_name, 8, random_player, creature])
				return
			# No valid target — skip to keyframe 2
			keyframe = 2

		elif keyframe == 2:
			if timer > random_time:
				if cast_times < cast_times_limit:
					keyframe = 1
					state_machine.state_timer = 0.0
				else:
					# Transition to fade
					changing = true
					switch_to("DLFade")
					return
			elif will_move and timer > 240 / 60.0:
				# GMS2: move toward persisted targetPlayer (chosen once per stand cycle)
				if is_instance_valid(target_player):
					var dir: Vector2 = (target_player.global_position - creature.global_position).normalized()
					creature.velocity = dir * 0.25 * 60.0  # GMS2: walkSpeed/4 = 1/4 = 0.25 px/frame
					(creature as CharacterBody2D).move_and_slide()

	elif boss.current_phase == BossDarkLich.Phase.HANDS:
		# GMS2: Head appearance timer — after N frames, switch to head animation (handsMove2)
		if show_head and not hands_head_shown and timer > hands_head_appear_timer:
			hands_head_shown = true
			# GMS2: if image_index < handsMove2Ini+2 (< 69), use full range 67-70
			#        else use narrower range 69-70 (head already mid-animation)
			var config: Dictionary = boss.phase_sprite_config.get(boss.current_phase, {})
			var head_ini: int = config.get("stand_head_ini", 67)
			var head_end: int = config.get("stand_head_end", 70)
			if creature.current_frame < head_ini + 2:
				# Full head appearance range
				creature.set_default_facing_animations(
					head_ini, head_ini, head_ini, head_ini,
					head_end, head_end, head_end, head_end
				)
			else:
				# Narrow loop (head already visible)
				creature.set_default_facing_animations(
					head_ini + 2, head_ini + 2, head_ini + 2, head_ini + 2,
					head_end, head_end, head_end, head_end
				)
			creature.set_default_facing_index()

		if keyframe == 1:
			if timer > random_time:
				random_time = randf_range(120 / 60.0, 240 / 60.0)
				state_machine.state_timer = 0.0
				# GMS2: 50% move, 50% attack
				keyframe = 2 if randi() % 2 == 0 else 3

				if keyframe == 2:
					# GMS2: Check player direction — only move if player is UP or DOWN
					var random_player: Node = _get_random_player()
					if not random_player:
						keyframe = 4
					else:
						var dir_to_player: Vector2 = (random_player.global_position - creature.global_position)
						var player_facing: int = creature.get_facing_from_direction(dir_to_player)
						if player_facing == Constants.Facing.UP:
							hands_move_dir = -1  # Move up toward player
						elif player_facing == Constants.Facing.DOWN:
							hands_move_dir = 1  # Move down toward player
						else:
							# Player is LEFT or RIGHT — can't reach by vertical movement
							if attacked_times < max_attack_times:
								keyframe = 3  # Attack instead
							else:
								keyframe = 4  # Phase change

				if keyframe == 3:
					if attacked_times >= max_attack_times:
						keyframe = 4  # Phase change instead

		elif keyframe == 2:
			# GMS2: Move vertically at walkMax (1 px/frame) speed
			var body := creature as CharacterBody2D
			creature.velocity = Vector2(0, hands_move_dir) * 1.0 * 60.0  # GMS2: walkMax = 1
			body.move_and_slide()

			# GMS2: Wall collision pivot
			if body.get_slide_collision_count() > 0:
				hands_move_dir = -hands_move_dir  # Reverse direction

			# GMS2: getTargetsInRange(lichHandsRange=70) — attack if player in range
			var lich_hands_range: float = 70.0
			for player in GameManager.get_alive_players():
				if is_instance_valid(player) and player is Creature:
					if creature.global_position.distance_to(player.global_position) < lich_hands_range:
						keyframe = 3  # Switch to attack
						break

			if keyframe != 3 and timer > random_time:
				keyframe = 4

		elif keyframe == 3:
			# Attack
			attacked_times += 1
			switch_to("DLAttack")
			return

		elif keyframe == 4:
			if timer > random_time:
				changing = true
				switch_to("DLFade")
				return

	# Phase timeout
	if boss.phase_time > boss.max_time_between_phases and not changing:
		boss.phase_time = 0
		switch_to("DLFade")

func _get_random_player() -> Node:
	var alive_players: Array = GameManager.get_alive_players()
	if alive_players.size() > 0:
		return alive_players[randi() % alive_players.size()]
	return null

func _look_at_random_player() -> void:
	var player: Node = _get_random_player()
	if player and is_instance_valid(player):
		var dir: Vector2 = (player.global_position - creature.global_position)
		if dir.length() > 1.0:
			creature.facing = creature.get_facing_from_direction(dir)

func exit() -> void:
	creature.velocity = Vector2.ZERO
