extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "speedUp"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.SPEED_UP, true, "should apply speed up"):
		_pass("speedUp applied SPEED_UP to ally")
