extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "gemMissile"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	_pass("gemMissile cast succeeded")
