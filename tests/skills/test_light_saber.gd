extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "lightSaber"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.BUFF_WEAPON_LUMINA, true, "should apply Lumina saber"):
		_pass("lightSaber applied BUFF_WEAPON_LUMINA to ally")
