extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "speedDown"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	if _assert_status(target, Constants.Status.SPEED_DOWN, true, "should apply speed down to target"):
		_pass("speedDown applied SPEED_DOWN to target")
