extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "lunarBoost"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.ATTACK_UP, true, "should apply attack up"):
		_pass("lunarBoost applied ATTACK_UP to ally")
