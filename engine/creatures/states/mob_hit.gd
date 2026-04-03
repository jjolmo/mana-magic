class_name MobHit
extends State
## Mob HIT state - replaces fsm_mob_hit from GMS2
## GMS2: 120-frame hit stagger, no knockback (commented out), faces attacker,
## multi-damage cycling (processes next damage after 120 frames).

var hit_duration: float = 2.0  ## GMS2: 120 frames / 60 = 2.0 seconds

func enter() -> void:
	var mob := creature as Mob
	creature.attacked = true
	creature.velocity = Vector2.ZERO
	# Reset sprite rotation/scale from bounce angle (rabbigte)
	if creature.sprite:
		creature.sprite.rotation = 0
		creature.sprite.scale.y = 1.0

	_process_damage(mob)

func _process_damage(mob: Mob) -> void:
	## Process one damage entry from the stack and set up hit visuals.
	if creature.damage_stack.size() > 0:
		# GMS2: damageCreature() plays sound_hurt (defaults to snd_hit1 for mobs)
		MusicManager.play_sfx("snd_hit1")
		var dmg := creature.damage_stack[0] as Dictionary
		var push_dir: Vector2 = dmg.get("push_dir", Vector2.DOWN) as Vector2
		if push_dir.length() < 0.1:
			push_dir = Vector2.DOWN

		# Aggro on the attacker
		if mob and dmg.has("source") and is_instance_valid(dmg.source):
			mob.current_target = dmg.source

		# GMS2: newFacing = getReverseMovingDir(stateDir) - face toward attacker
		var reverse_dir: Vector2 = -push_dir
		if reverse_dir.length() > 0.1:
			creature.facing = creature.get_facing_from_direction(reverse_dir)

		creature.damage_stack.pop_front()

	# GMS2: setFacingImageIndex(state_sprHurtUpIni, ...) - use HURT frames
	# BUT skip if a status sprite is active (frozen/petrified) — GMS2's manageStatusAilments()
	# forces the frozen frame every step, overriding hurt frames. In Godot we simply don't
	# change the frame when _status_sprite_swapped is active.
	if mob and not creature._status_sprite_swapped:
		creature.set_facing_frame(
			mob.spr_hit_up, mob.spr_hit_right,
			mob.spr_hit_down, mob.spr_hit_left
		)
		creature.image_speed = 0.2  # GMS2: image_speed = state_imgSpeedHit (default 0.2)

func execute(_delta: float) -> void:
	var timer := get_timer()

	# GMS2: immediate death check after damage processing (fsm_mob_hit lines 33-44)
	# In Godot, damage is applied before entering Hit state via take_damage()/apply_damage(),
	# so is_dead is already set. GMS2 checks isCreatureDead() right after damageCreature()
	# and switches to state_DEAD immediately — no 120-frame wait.
	if creature.is_dead:
		creature.attacked = false
		switch_to("Dead")
		return

	# GMS2: mob knockback is COMMENTED OUT (moveKnock = false, never set to true)
	# No knockback movement - mob stays in place when hit
	creature.velocity = Vector2.ZERO

	if timer >= hit_duration:
		# GMS2: Check for more damage in stack - if so, reset and cycle
		if creature.damage_stack.size() > 0:
			var mob := creature as Mob
			# GMS2: soundPlay(sound_hurt) on re-cycle — _process_damage also plays it
			reset_timer()
			_process_damage(mob)
			return

		creature.attacked = false
		# Re-pause if creature still has a hard CC status (e.g., returning from Hit while ballooned)
		# GMS2: hit state completes normally, then creature goes back to paused/frozen
		if creature.has_status(Constants.Status.PETRIFIED) or \
				creature.has_status(Constants.Status.FROZEN) or \
				creature.has_status(Constants.Status.ENGULFED) or \
				creature.has_status(Constants.Status.BALLOON):
			creature.pause_creature()
		# GMS2: changeStateStandDead() with resetTimer=true (fast restart 30 frames)
		switch_to("Stand", [true])

func exit() -> void:
	creature.velocity = Vector2.ZERO
