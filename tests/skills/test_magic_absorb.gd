extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "magicAbsorb"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	if _assert_true(_cast_result.get("success", false), "should cast successfully"):
		_pass("Skill cast succeeded")
