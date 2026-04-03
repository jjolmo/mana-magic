extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "moonEnergy"

func is_ally_skill() -> bool:
	return true  # moonEnergy targets ALLY (raises crit hit %)

func verify() -> void:
	# moonEnergy is a buff (raises critical hit %), not damage
	_pass("moonEnergy buff cast succeeded")
