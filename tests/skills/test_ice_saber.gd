extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "iceSaber"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.BUFF_WEAPON_UNDINE, true, "should apply Undine saber"):
		_pass("iceSaber applied BUFF_WEAPON_UNDINE to ally")
