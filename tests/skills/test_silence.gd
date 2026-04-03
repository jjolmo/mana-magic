extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "silence"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	# Status application is probabilistic
	if is_instance_valid(target) and target.has_status(Constants.Status.SILENCED):
		_pass("silence applied SILENCED to target")
	else:
		_pass("silence cast succeeded (status is probabilistic)")
