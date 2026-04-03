extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "cureWater"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	# cureWater heals allies — ally_target starts at half HP
	# After casting, ally HP should be >= what it was (heal applied)
	var pre_hp: float = ally_target.attribute.maxHP / 2.0  # We set it to half in setup
	if _assert_gt(ally_target.attribute.hp, pre_hp, "should heal ally HP"):
		_pass("cureWater healed ally successfully")
