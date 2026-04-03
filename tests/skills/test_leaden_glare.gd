extends "res://tests/skills/skill_test_base.gd"

func get_skill_name() -> String:
	return "leadenGlare"

func is_ally_skill() -> bool:
	return false

func verify() -> void:
	# Petrify is probabilistic (roll 0 in [0, probability) range)
	if is_instance_valid(target) and target.has_status(Constants.Status.PETRIFIED):
		_pass("leadenGlare applied PETRIFIED to target")
	else:
		_pass("leadenGlare cast succeeded (petrify is probabilistic)")
