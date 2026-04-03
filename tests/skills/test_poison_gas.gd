extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "poisonGas"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	if _assert_status(target, Constants.Status.POISONED, true, "should poison target"):
		_pass("poisonGas applied POISONED to target")
