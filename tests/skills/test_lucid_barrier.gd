extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "lucidBarrier"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.LUCID_BARRIER, true, "should apply lucid barrier"):
		_pass("lucidBarrier applied LUCID_BARRIER to ally")
