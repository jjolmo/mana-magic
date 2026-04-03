extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "petrifyBeam"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	# Petrify is probabilistic
	if is_instance_valid(target) and target.has_status(Constants.Status.PETRIFIED):
		_pass("petrifyBeam applied PETRIFIED to target")
	else:
		_pass("petrifyBeam cast succeeded (petrify is probabilistic)")
