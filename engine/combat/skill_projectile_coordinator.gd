class_name SkillProjectileCoordinator
extends Node
## Coordinates multiple projectiles for a single skill cast.
## Waits for all projectiles to hit, then applies the skill effect once.

var source: Creature
var target: Creature
var skill_data: Dictionary
var level: int = 0
var total_projectiles: int = 0
var hits_received: int = 0


func setup(p_source: Creature, p_target: Creature, p_skill_data: Dictionary, p_level: int, p_count: int) -> void:
	source = p_source
	target = p_target
	skill_data = p_skill_data
	level = p_level
	total_projectiles = p_count


func _on_projectile_hit() -> void:
	hits_received += 1
	if hits_received >= total_projectiles:
		_apply_combined_effect()
		queue_free()


func _apply_combined_effect() -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return

	# Get element index
	var element_idx: int = -1
	var deity: String = skill_data.get("deity", "")
	match deity:
		"Undine": element_idx = Constants.Element.UNDINE
		"Gnome": element_idx = Constants.Element.GNOME
		"Sylphid": element_idx = Constants.Element.SYLPHID
		"Salamando": element_idx = Constants.Element.SALAMANDO
		"Shade": element_idx = Constants.Element.SHADE
		"Luna": element_idx = Constants.Element.LUNA
		"Lumina": element_idx = Constants.Element.LUMINA
		"Dryad": element_idx = Constants.Element.DRYAD

	# Apply magic damage
	DamageCalculator.perform_attack(target, source, Constants.AttackType.MAGIC, element_idx, level)

	# Apply any status effects from the skill
	var types_raw = skill_data.get("type", [])
	var types: Array = types_raw if types_raw is Array else ([types_raw] if types_raw is String else [])

	var status_map: Dictionary = {
		"STATUS_FROZEN": Constants.Status.FROZEN,
		"STATUS_POISONED": Constants.Status.POISONED,
		"STATUS_SILENCED": Constants.Status.SILENCED,
		"STATUS_CONFUSED": Constants.Status.CONFUSED,
		"STATUS_PETRIFIED": Constants.Status.PETRIFIED,
	}

	var duration: float = float(skill_data.get("duration", 300)) / 60.0  # Convert frame duration to seconds
	var probability: float = skill_data.get("value1", 100.0)

	for type_str in types:
		if type_str is String and type_str in status_map:
			if probability >= 100.0 or randf() * 100.0 <= probability:
				target.set_status(status_map[type_str], duration)

	# Unfreeze target after effect
	if is_instance_valid(target) and target.state_machine_node:
		if target.is_dead:
			if target.state_machine_node.has_state("Dead"):
				target.state_machine_node.switch_state("Dead")
		elif target.state_machine_node.has_state("Hit"):
			target.state_machine_node.switch_state("Hit")
		elif target.state_machine_node.has_state("Stand"):
			target.state_machine_node.switch_state("Stand")
