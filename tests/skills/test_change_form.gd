extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "changeForm"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	if _assert_status(target, Constants.Status.TRANSFORMED, true, "should apply TRANSFORMED"):
		_pass("Skill applied TRANSFORMED status")
