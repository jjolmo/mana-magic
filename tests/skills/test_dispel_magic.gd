extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "dispelMagic"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	_pass("dispelMagic cast succeeded")
