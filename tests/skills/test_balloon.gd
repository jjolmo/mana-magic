extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "balloon"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	if _assert_status(target, Constants.Status.BALLOON, true, "should apply balloon"):
		_pass("balloon applied BALLOON to target")
