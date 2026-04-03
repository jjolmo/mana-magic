extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "moonSaber"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.BUFF_WEAPON_LUNA, true, "should apply Luna saber"):
		_pass("moonSaber applied BUFF_WEAPON_LUNA to ally")
