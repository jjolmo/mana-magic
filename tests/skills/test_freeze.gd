extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "freeze"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	if _assert_lt(target.attribute.hp, _pre_target_hp, "should deal damage"):
		_pass("freeze dealt damage to target")
