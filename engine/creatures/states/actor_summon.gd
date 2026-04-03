class_name ActorSummon
extends State
## Actor SUMMON state - replaces fsm_actor_summon from GMS2
## Magic summoning/casting animation with deity summon visual (spark → deity sprite)

static var _summon_effect_scene: PackedScene = null

var summoned: bool = false
var animate_list: Array[float] = []
var animate_index: int = 0
var animate_frame_counter: float = 0.0

func enter() -> void:
	var actor := creature as Actor
	creature.velocity = Vector2.ZERO
	creature.disable_shader()
	creature.state_protect = true
	summoned = false
	animate_index = 0
	animate_frame_counter = 0.0

	# Set summon animation
	creature.set_default_facing_animations(
		actor.spr_summon_up_ini, actor.spr_summon_right_ini,
		actor.spr_summon_down_ini, actor.spr_summon_left_ini,
		actor.spr_summon_up_end, actor.spr_summon_right_end,
		actor.spr_summon_down_end, actor.spr_summon_left_end
	)
	creature.set_default_facing_index()
	creature.image_speed = 0

	# Check if already summoned (resuming from pushed state)
	# GMS2: if summoned, startFrame = 4 (skip first 4 frames of casting anim)
	# state_var[0] may contain a leftover Object from a previous state (e.g. IAGuardTarget target)
	var sv0: Variant = state_machine.get_state_var(0, false)
	var already_summoned: bool = sv0 is bool and sv0
	if already_summoned:
		summoned = true
		animate_list = [1.333, 0.5]
		# GMS2: offset sprite indices by startFrame=4 when resuming
		creature.current_frame += 4
		creature.set_frame(creature.current_frame)
	else:
		animate_list = [0.5, 0.5, 0.083, 1.5, 0.667, 0.333]

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# get_timer() now returns seconds
	var timer: float = get_timer()

	# Create deity summon visual at 0.5 seconds (was frame 30)
	if timer > 0.5 and not summoned:
		summoned = true
		MusicManager.play_sfx("snd_summon")

		# Calculate summon anchor point based on facing (26px offset from caster)
		var summon_pos: Vector2 = creature.global_position
		var summon_distance: float = 26.0
		match creature.facing:
			Constants.Facing.UP:
				summon_pos.y -= summon_distance
			Constants.Facing.RIGHT:
				summon_pos.x += summon_distance
				summon_pos.y -= 10
			Constants.Facing.DOWN:
				summon_pos.y += summon_distance
			Constants.Facing.LEFT:
				summon_pos.x -= summon_distance
				summon_pos.y -= 10

		# GMS2: addBattleDialog("LV X SkillName") - show spell name with level
		var magic_level: int = 0
		if actor.summon_magic_deity >= 0 and actor.summon_magic_deity < actor.deity_levels.size():
			magic_level = actor.deity_levels[actor.summon_magic_deity]
		var skill_data: Dictionary = Database.get_skill(actor.summon_magic)
		var skill_display_name: String = skill_data.get("nameText", actor.summon_magic)
		GameManager.add_battle_dialog("LV %d %s" % [magic_level, skill_display_name])

		# Spawn the deity summon visual (spark → deity animation → triggers cast_skill)
		if actor.summon_magic != "" and is_instance_valid(actor.summon_target):
			if _summon_effect_scene == null:
				_summon_effect_scene = load("res://scenes/effects/summon_effect.tscn") as PackedScene
			var summon_effect: Node2D = _summon_effect_scene.instantiate() as Node2D
			summon_effect.call("setup", actor, actor.summon_target, actor.summon_magic, actor.summon_magic_deity, magic_level, actor.summon_target_all)
			summon_effect.global_position = summon_pos
			var world: Node = creature.get_parent()
			if world:
				world.add_child(summon_effect)
			else:
				creature.get_tree().current_scene.add_child(summon_effect)

	# Animate step-by-step
	if _animate_step(delta):
		creature.state_protect = false
		switch_to("Stand")

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
