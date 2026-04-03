extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "flameSaber"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.BUFF_WEAPON_SALAMANDO, true, "should apply BUFF_WEAPON_SALAMANDO"):
		_pass("Skill applied BUFF_WEAPON_SALAMANDO status")
