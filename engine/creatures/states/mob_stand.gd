class_name MobStand
extends State
## Mob STAND state - replaces fsm_mob_stand from GMS2

var random_timer_limit: float = 100.0 / 60.0
var attack_cooldown_max: float = 50.0 / 60.0

func enter() -> void:
	var mob := creature as Mob
	if not mob:
		return

	if mob.is_dead:
		switch_to("Dead")
		return

	creature.set_facing_frame(
		creature.spr_stand_up,
		creature.spr_stand_right,
		creature.spr_stand_down,
		creature.spr_stand_left
	)
	creature.image_speed = mob.img_speed_stand
	attack_cooldown_max = randf_range(20 / 60.0, 100 / 60.0)
	# GMS2: resetTimer = state_var[0] — if true, use short 30-frame timer for faster re-engagement
	var reset_timer: bool = state_machine.get_state_var(0, false) == true
	if reset_timer:
		random_timer_limit = 30.0 / 60.0
	else:
		random_timer_limit = randf_range(mob.steps_stand_min / 60.0, mob.steps_stand_max / 60.0)

	# Check damage stack
	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# Set walk animations
	creature.set_default_facing_animations(
		mob.spr_walk_up_ini, mob.spr_walk_right_ini,
		mob.spr_walk_down_ini, mob.spr_walk_left_ini,
		mob.spr_walk_up_end, mob.spr_walk_right_end,
		mob.spr_walk_down_end, mob.spr_walk_left_end
	)
	creature.set_default_facing_index()

	# GMS2: fsm_mob_stand immediately transitions to WANDER (line 21: state_switch(state_WANDER))
	# Skip the immediate wander if we just got hit or have special conditions
	if not mob.passive and not mob.is_action_blocked():
		if mob.is_rabite:
			# Rabbigte has its own wander/chase with bounce angle + castRandomSkill
			if mob.creature_is_boss and mob.skill_list.size() > 0:
				switch_to("RabbigteStand")
			else:
				switch_to("RabiteWander")
		else:
			switch_to("Wander")
		return

func execute(_delta: float) -> void:
	var mob := creature as Mob
	if not mob or mob.is_dead:
		return

	creature.animate_sprite()

	# Check damage stack BEFORE movement block — ballooned/frozen mobs can still be hit
	# GMS2: damage_stack is processed regardless of CC status
	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# Status effects block all mob actions (movement, AI, casting)
	if mob.is_movement_blocked():
		return

	# Check for player in sight - transition to chase
	if mob.is_player_in_sight() and not mob.passive:
		mob.current_target = mob.find_nearest_player()
		if mob.current_target:
			if mob.is_rabite:
				if mob.creature_is_boss and mob.skill_list.size() > 0:
					switch_to("RabbigteChase")
				else:
					switch_to("RabiteChase")
			else:
				switch_to("Chase")
			return

	if get_timer() > random_timer_limit:
		# Try to cast an idle skill
		# GMS2: random_range(1,8) >= 7 = 12.5% chance, iterates from index 1
		if mob.idle_skills.size() > 1 and not mob.is_action_blocked() and randf() < 0.125:
			_try_cast_skill(mob)
		else:
			if mob.is_rabite:
				if mob.creature_is_boss and mob.skill_list.size() > 0:
					switch_to("RabbigteWander")
				else:
					switch_to("RabiteWander")
			else:
				switch_to("Wander")


func _try_cast_skill(mob: Mob) -> void:
	# GMS2: iterates from index 1 onward and executes ALL skills in sequence
	# for (var i = 1; i < idleSkillsarrLength; i++) { script_execute(idle_skills[i]); }
	# In Godot, we can only enter ONE summon state at a time, so we iterate to find
	# the first castable skill (GMS2 executed all but only one summon plays at once anyway)
	var target: Node = mob.find_nearest_player()
	if not is_instance_valid(target):
		switch_to("Wander")
		return

	# Check range - must be within sight radius to cast
	if mob.global_position.distance_to(target.global_position) > mob.sight_radius:
		switch_to("Wander")
		return

	# GMS2: iterate all skills from index 1 onward
	for skill_idx in range(1, mob.idle_skills.size()):
		var skill_entry = mob.idle_skills[skill_idx]

		var skill_name: String = ""
		var magic_level: int = 1

		# idle_skills can be: String (skill name), Array [name, level], or Callable
		if skill_entry is String:
			skill_name = skill_entry
		elif skill_entry is Array and skill_entry.size() >= 1:
			skill_name = str(skill_entry[0])
			if skill_entry.size() >= 2:
				magic_level = int(skill_entry[1])
		elif skill_entry is Callable:
			skill_entry.call()
			continue
		else:
			continue

		if skill_name.is_empty():
			continue

		# Look at target before casting
		mob.look_at_target(target)

		# Switch to Summon state with the first valid skill found
		switch_to("Summon", [skill_name, magic_level, target, mob])
		return

	# No valid skill found
	switch_to("Wander")
