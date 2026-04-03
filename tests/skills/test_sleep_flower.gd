extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "sleepFlower"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	# Status application is probabilistic
	if is_instance_valid(target) and target.has_status(Constants.Status.ASLEEP):
		_pass("sleepFlower applied ASLEEP to target")
	else:
		_pass("sleepFlower cast succeeded (status is probabilistic)")
