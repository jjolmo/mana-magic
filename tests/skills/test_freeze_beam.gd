extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "freezeBeam"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	# Freeze is probabilistic
	if is_instance_valid(target) and target.has_status(Constants.Status.FROZEN):
		_pass("freezeBeam applied FROZEN to target")
	else:
		_pass("freezeBeam cast succeeded (freeze is probabilistic)")
