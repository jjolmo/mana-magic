extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "balloonRing"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	if _assert_status(target, Constants.Status.BALLOON, true, "should balloon target"):
		_pass("balloonRing applied BALLOON to target")
