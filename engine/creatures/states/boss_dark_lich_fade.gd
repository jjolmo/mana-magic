class_name BossDarkLichFade
extends State
## Dark Lich FADE state - replaces fsm_mob_darkLich_fade from GMS2
## Phase transition via alpha fade out/in. Swaps FULLBODY <-> HANDS.

var is_fade_out: bool = true
var alpha_speed: float = 0.005
var _damage_check_acc: float = 0.0

## GMS2: game.checkDamageStackFrequency — how often to check death during fade
const DAMAGE_CHECK_FREQUENCY: float = 6.0 / 60.0  # 0.1 seconds

func enter() -> void:
	var boss := creature as BossDarkLich
	if not boss:
		return

	boss.phase_time = 0
	creature.is_invulnerable = false
	creature.velocity = Vector2.ZERO
	creature.image_speed = 0
	creature.state_protect = true
	alpha_speed = 0.005
	_damage_check_acc = 0.0

	# Check state var for fade direction (true = fade out, false = fade in)
	is_fade_out = state_machine.get_state_var(0, true)

	if is_fade_out:
		creature.modulate.a = 1.0
	else:
		creature.modulate.a = 0.0

	# GMS2: Set phase-appropriate animation during fade
	if boss.current_phase == BossDarkLich.Phase.HANDS:
		# GMS2: setDefaultFacingAnimations(handsMove1Ini+1, handsMove1End)
		var config: Dictionary = boss.phase_sprite_config.get(BossDarkLich.Phase.HANDS, {})
		var stand_ini: int = config.get("stand_ini", 51) + 1  # skip first frame
		var stand_end: int = config.get("stand_end", 53)
		creature.set_default_facing_animations(
			stand_ini, stand_ini, stand_ini, stand_ini,
			stand_end, stand_end, stand_end, stand_end
		)
		creature.set_default_facing_index()
	else:
		# GMS2: bossLookAtPlayer() during FULLBODY fade
		boss.look_at_player()

	# GMS2: attackedTimes = 0 on fade entry
	boss.attacked_times = 0

func execute(delta: float) -> void:
	var boss := creature as BossDarkLich
	if not boss:
		return

	# GMS2: check death every checkDamageStackFrequency seconds during state_protect
	_damage_check_acc += delta
	if _damage_check_acc >= DAMAGE_CHECK_FREQUENCY:
		_damage_check_acc -= DAMAGE_CHECK_FREQUENCY
		if creature.is_dead:
			creature.modulate.a = 1.0
			creature.state_protect = false
			switch_to("Dead")
			return

	# GMS2: checkDamageStack() — process damage normally during fade
	if creature.damage_stack.size() > 0:
		var dmg_data: Variant = creature.damage_stack.pop_front()
		if dmg_data is Dictionary:
			var damage: int = dmg_data.get("damage", 0)
			creature.apply_damage(damage)
			# Show floating number during fade (GMS2 does this via checkDamageStack)
			var scene_root: Node = creature.get_tree().current_scene if creature.get_tree() else null
			if scene_root and damage > 0:
				FloatingNumber.spawn(scene_root, creature, damage, FloatingNumber.CounterType.HP_LOSS)

	if is_fade_out:
		creature.modulate.a -= alpha_speed
		if creature.modulate.a <= 0 and get_timer() > 300 / 60.0:
			# Switch phase
			if boss.current_phase == BossDarkLich.Phase.FULLBODY:
				boss.current_phase = BossDarkLich.Phase.HANDS
			else:
				boss.current_phase = BossDarkLich.Phase.FULLBODY
			boss._apply_phase_sprites()
			creature.set_default_facing_index()  # GMS2: set frame to new phase's initial frame

			# Reset to fade in
			is_fade_out = false
			# Optional position reset
			if randi() % 2 == 0:
				creature.global_position = Vector2(335, 287)
			state_machine.state_timer = 0.0
	else:
		creature.modulate.a += alpha_speed
		if creature.modulate.a >= 1.0:
			creature.modulate.a = 1.0
			creature.state_protect = false
			creature.is_invulnerable = false
			# Set insta-cast flag for stand
			state_machine.set_state_var(0, true)
			switch_to("DLStand")

func exit() -> void:
	creature.state_protect = false
