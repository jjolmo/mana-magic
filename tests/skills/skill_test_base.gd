class_name SkillTestBase
extends Node
## Base class for automated skill tests.
## Provides arena setup (caster + target), skill casting, assertion helpers, and cleanup.
## Run headless: godot --headless --path . tests/skills/skill_test_runner.tscn

signal test_completed(test_name: String, passed: bool, message: String)

const ACTOR_SCENE: PackedScene = preload("res://scenes/creatures/actor.tscn")
const MOB_SCENE: PackedScene = preload("res://scenes/creatures/mob.tscn")

var test_name: String = "unnamed_test"
var skill_name: String = ""

var caster: Actor = null
var target: Creature = null
var ally_target: Actor = null  # For ALLY-targeted skills

var _active_effects: Array = []
var _timeout: float = 15.0
var _elapsed: float = 0.0
var _phase: String = "idle"  # idle, casting, waiting, verifying, done
var _pre_target_hp: float = 0.0
var _pre_target_mp: float = 0.0
var _pre_caster_hp: float = 0.0
var _pre_caster_mp: float = 0.0
var _cast_result: Dictionary = {}
var _passed: bool = false
var _message: String = ""
var _pre_cast_delay: float = 0.5  # Wait before casting so you can see the arena
var _post_effect_delay: float = 2.0  # Wait after effect completes so you can see the result
var _delay_timer: float = 0.0

## Override in subclass: return the skill name to test
func get_skill_name() -> String:
	return ""

## Override in subclass: return the deity level for casting (0-8)
func get_deity_level() -> int:
	return 7

## Override in subclass: return true if this skill targets allies (heals, buffs)
func is_ally_skill() -> bool:
	return false

## Override in subclass: verify the skill effect after it completes
func verify() -> void:
	_pass("Skill cast completed (no specific verification)")

## Called by the runner to start the test
func run_test() -> void:
	skill_name = get_skill_name()
	test_name = "test_%s" % skill_name
	_phase = "setup"
	_elapsed = 0.0

func _process(delta: float) -> void:
	if _phase == "idle" or _phase == "done":
		return

	_elapsed += delta

	match _phase:
		"setup":
			_do_setup()
		"pre_cast_delay":
			_delay_timer += delta
			if _delay_timer >= _pre_cast_delay:
				_delay_timer = 0.0
				_phase = "casting"
		"casting":
			_do_cast()
		"waiting":
			_do_wait(delta)
		"post_delay":
			_delay_timer += delta
			if _delay_timer >= _post_effect_delay:
				_delay_timer = 0.0
				_phase = "verifying"
		"verifying":
			_do_verify()

	# Timeout
	if _phase != "done" and _elapsed > _timeout:
		_fail("Test timed out after %.1fs" % _timeout)

func _do_setup() -> void:
	_setup_arena()
	_delay_timer = 0.0
	_phase = "pre_cast_delay"

func _do_cast() -> void:
	# Save pre-cast state
	if is_instance_valid(target):
		_pre_target_hp = target.attribute.hp
		_pre_target_mp = target.attribute.mp
	_pre_caster_hp = caster.attribute.hp
	_pre_caster_mp = caster.attribute.mp

	# Cast the skill
	var actual_target: Creature = ally_target if is_ally_skill() else target
	_cast_result = SkillSystem.cast_skill(skill_name, caster, actual_target, get_deity_level())

	if not _cast_result.get("success", false):
		var reason: String = _cast_result.get("reason", "unknown")
		if reason == "disabled":
			_pass("Skill is disabled in database (expected)")
		else:
			_fail("Cast failed: %s" % reason)
		return

	# Collect active skill effects in the scene
	_active_effects.clear()
	await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("skill_effects"):
		_active_effects.append(node)
	# Also find by class if not in group
	if _active_effects.is_empty():
		_find_skill_effects(get_tree().root)

	_phase = "waiting"

func _find_skill_effects(node: Node) -> void:
	if node is SkillEffect:
		_active_effects.append(node)
	for child in node.get_children():
		_find_skill_effects(child)

func _do_wait(_delta: float) -> void:
	# Wait for all skill effects to complete
	var all_done := true
	for effect in _active_effects:
		if is_instance_valid(effect) and effect is SkillEffect:
			if not effect.animation_finished:
				all_done = false
				break

	# Also check if effects were freed (animation complete + queue_free)
	var any_alive := false
	for effect in _active_effects:
		if is_instance_valid(effect):
			any_alive = true
			break

	if all_done or not any_alive or _elapsed > 8.0:
		# Wait a bit after effect so you can see the result visually
		_delay_timer = 0.0
		_phase = "post_delay"

func _do_verify() -> void:
	verify()
	if _phase != "done":
		# verify() didn't explicitly pass or fail — auto-pass
		_pass("Skill completed without errors")

## --- Arena Setup ---

## Where to add creatures — defaults to root, visual runner overrides via parent
func _get_world_parent() -> Node:
	# If our parent is a Node2D (visual runner), add there so creatures are visible
	if get_parent() is Node2D:
		return get_parent()
	return get_tree().root

func _setup_arena() -> void:
	var world_parent := _get_world_parent()

	# Create caster (Actor) with high stats and lots of MP
	caster = ACTOR_SCENE.instantiate() as Actor
	caster.character_id = Constants.CharacterId.PURIM  # Purim has white magic
	caster.character_name = "TestCaster"
	caster.enable_magic = Constants.MAGIC_ALL  # Can cast all magic
	caster.global_position = Vector2(270, 100)
	caster.facing = Constants.Facing.DOWN
	caster.add_to_group("players")

	# Set high stats so skills work
	caster.attribute.classId = 3  # Priest
	caster.attribute.level = 99
	caster.attribute.HPMultiplier = 3.8
	caster.attribute.MPMultiplier = 4.0
	caster.attribute.MPMultiplier2 = 2.0
	caster.attribute.MPDivisor = 4.0
	caster.attribute.intelligence = 99
	caster.attribute.wisdom = 99

	# Set deity levels to max
	for i in range(caster.deity_levels.size()):
		caster.deity_levels[i] = get_deity_level()

	world_parent.add_child(caster)
	GameManager.add_player(caster)

	caster.recalculate_stats()
	caster.attribute.hp = caster.attribute.maxHP
	caster.attribute.mp = 999  # Effectively infinite MP
	caster.is_party_leader = false
	caster.player_controlled = false
	# Lock movement so they stay still
	caster.input_locked = true
	caster.movement_input_locked = true
	caster.velocity = Vector2.ZERO

	# Create ally target (another Actor for ALLY skills)
	ally_target = ACTOR_SCENE.instantiate() as Actor
	ally_target.character_id = Constants.CharacterId.RANDI
	ally_target.character_name = "TestAlly"
	ally_target.global_position = Vector2(300, 100)
	ally_target.facing = Constants.Facing.DOWN
	ally_target.add_to_group("players")
	ally_target.attribute.classId = 1
	ally_target.attribute.level = 60
	ally_target.attribute.HPMultiplier = 3.8

	world_parent.add_child(ally_target)
	GameManager.add_player(ally_target)
	ally_target.recalculate_stats()
	ally_target.attribute.hp = ally_target.attribute.maxHP / 2  # Half HP so heals are testable
	ally_target.attribute.mp = 100
	ally_target.player_controlled = false
	ally_target.is_party_leader = false
	ally_target.input_locked = true
	ally_target.movement_input_locked = true
	ally_target.velocity = Vector2.ZERO

	# Create target (Mob) — Rabite (ID 2)
	target = MOB_SCENE.instantiate() as Mob
	target.global_position = Vector2(340, 150)
	target.facing = Constants.Facing.UP
	target.add_to_group("mobs")
	world_parent.add_child(target)
	(target as Mob).load_from_database(2)  # Rabite
	# Mob doesn't have recalculate_stats() — load_from_database sets stats directly
	target.attribute.hp = target.attribute.maxHP
	# Keep mob still
	target.input_locked = true
	target.movement_input_locked = true
	target.velocity = Vector2.ZERO

## --- Assertion Helpers ---

func _pass(msg: String = "") -> void:
	_passed = true
	_message = msg
	_phase = "done"
	_cleanup()
	test_completed.emit(test_name, true, msg)

func _fail(msg: String = "") -> void:
	_passed = false
	_message = msg
	_phase = "done"
	_cleanup()
	test_completed.emit(test_name, false, msg)

func _assert_true(condition: bool, msg: String = "") -> bool:
	if not condition:
		_fail("ASSERT_TRUE failed: %s" % msg)
		return false
	return true

func _assert_eq(a: Variant, b: Variant, msg: String = "") -> bool:
	if a != b:
		_fail("ASSERT_EQ failed: %s != %s — %s" % [a, b, msg])
		return false
	return true

func _assert_gt(a: float, b: float, msg: String = "") -> bool:
	if a <= b:
		_fail("ASSERT_GT failed: %s <= %s — %s" % [a, b, msg])
		return false
	return true

func _assert_lt(a: float, b: float, msg: String = "") -> bool:
	if a >= b:
		_fail("ASSERT_LT failed: %s >= %s — %s" % [a, b, msg])
		return false
	return true

func _assert_status(creature: Creature, status: int, expected: bool, msg: String = "") -> bool:
	if not is_instance_valid(creature):
		_fail("Creature invalid for status check — %s" % msg)
		return false
	var has: bool = creature.has_status(status)
	if has != expected:
		var sname: String = "status_%d" % status
		_fail("ASSERT_STATUS: %s has_status(%s) = %s, expected %s — %s" % [creature.name, sname, has, expected, msg])
		return false
	return true

## --- Cleanup ---

func _cleanup() -> void:
	# Remove skill effects
	for effect in _active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	_active_effects.clear()

	# Remove creatures
	if is_instance_valid(caster):
		GameManager.players.erase(caster)
		caster.queue_free()
	if is_instance_valid(ally_target):
		GameManager.players.erase(ally_target)
		ally_target.queue_free()
	if is_instance_valid(target):
		target.queue_free()
