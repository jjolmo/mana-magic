extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "wall"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.WALL, true, "should apply wall"):
		_pass("wall applied WALL to ally")
