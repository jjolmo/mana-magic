class_name MobSummon
extends State
## Mob SUMMON state - replaces fsm_mob_summon from GMS2
## Enemy casting/summon animation. Plays summon animation, then casts skill.
## state_vars: [0]=skillName, [1]=magicLevel, [2]=target, [3]=source

var skill_name: String = ""
var magic_level: int = 0
var target: Node = null
var source: Node = null
var casted: bool = false

func enter() -> void:
	var mob := creature as Mob
	creature.velocity = Vector2.ZERO
	casted = false

	# Read state vars
	skill_name = state_machine.get_state_var(0, "")
	magic_level = state_machine.get_state_var(1, 1)
	target = state_machine.get_state_var(2, null)
	source = state_machine.get_state_var(3, creature)

	# Set summon animation
	creature.set_default_facing_animations(
		mob.spr_summon_up_ini, mob.spr_summon_right_ini,
		mob.spr_summon_down_ini, mob.spr_summon_left_ini,
		mob.spr_summon_up_end, mob.spr_summon_right_end,
		mob.spr_summon_down_end, mob.spr_summon_left_end
	)
	creature.set_default_facing_index()
	creature.image_speed = mob.img_speed_walk

func execute(_delta: float) -> void:
	# Check damage stack
	if creature.damage_stack.size() > 0:
		switch_to("Hit")
		return

	# Animate and cast when animation ends
	if creature.animate_sprite(creature.image_speed, true):
		if not casted:
			casted = true
			if skill_name != "" and is_instance_valid(target):
				SkillSystem.cast_skill(skill_name, source, target, magic_level)
			# Return to Stand after casting
			switch_to("Stand")
			return

func exit() -> void:
	creature.velocity = Vector2.ZERO
