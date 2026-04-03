extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "defender"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.DEFENSE_UP, true, "should apply defense up"):
		_pass("defender applied DEFENSE_UP to ally")
