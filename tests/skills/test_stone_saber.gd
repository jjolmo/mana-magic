extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "stoneSaber"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	if _assert_status(ally_target, Constants.Status.BUFF_WEAPON_GNOME, true, "should apply Gnome saber"):
		_pass("stoneSaber applied BUFF_WEAPON_GNOME to ally")
