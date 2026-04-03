extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "revivifier"

func is_ally_skill() -> bool:
	return true

func verify() -> void:
	_pass("revivifier cast succeeded")
