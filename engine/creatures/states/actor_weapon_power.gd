class_name ActorWeaponPower
extends State
## Actor WEAPON POWER state - replaces fsm_actor_weaponPower from GMS2
## Executes weapon power script based on equipped weapon and reached level

func enter() -> void:
	var actor := creature as Actor
	if not actor:
		switch_to("Stand")
		return

	var weapon_name := actor.get_weapon_name()
	var weapon_id: int = actor.equipped_weapon_id
	var weapon_level: int = actor.equipment_current_level.get(weapon_name, 0)

	# Try to find and execute weapon power animation state
	var power_state_name := "WeaponPower_%s_LV%d" % [weapon_name, weapon_level]

	if state_machine.has_state(power_state_name):
		switch_to(power_state_name)
	else:
		# Fallback: just do a stronger attack
		actor.equipment_current_level[weapon_name] = 0
		actor.weapon_gauge = 0.0
		actor.show_weapon_level = false
		switch_to("Attack")

func execute(_delta: float) -> void:
	# Should not stay here - enter() always switches
	switch_to("Stand")
