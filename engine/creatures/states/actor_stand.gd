class_name ActorStand
extends State
## Actor STAND state - replaces fsm_actor_stand from GMS2

var check_stand_anim_interval: float = 20.0 / 60.0
var _stand_anim_timer: float = 0.0

func enter() -> void:
	creature.attacked = false
	creature.change_state = false
	creature.image_speed = 0  # GMS2: standing actors do not animate
	creature.set_facing_frame(
		creature.spr_stand_up,
		creature.spr_stand_right,
		creature.spr_stand_down,
		creature.spr_stand_left
	)
	# Check damage stack
	_check_damage_stack()

func execute(delta: float) -> void:
	var actor := creature as Actor
	if not actor:
		return

	# GMS2: During cutscenes, actors should not interact with NPCs or process
	# any gameplay input. Without this, brief windows between cutscene dialogs
	# allow the player to trigger NPC interactions (e.g. Dyluck during Dark Lich).
	if GameManager.scene_running:
		return

	_stand_anim_timer += delta
	if _stand_anim_timer >= check_stand_anim_interval:
		_stand_anim_timer = 0.0
		creature.set_facing_frame(
			creature.spr_stand_up,
			creature.spr_stand_right,
			creature.spr_stand_down,
			creature.spr_stand_left
		)

	if not actor.change_state and not actor.is_movement_input_locked():
		# Update facing from input
		if actor.control_left_held:
			actor.new_facing = Constants.Facing.LEFT
		if actor.control_right_held:
			actor.new_facing = Constants.Facing.RIGHT
		if actor.control_up_held:
			actor.new_facing = Constants.Facing.UP
		if actor.control_down_held:
			actor.new_facing = Constants.Facing.DOWN

		actor.facing = actor.new_facing

		if GameManager.ring_menu_opened:
			return

		# GMS2: weapon gauge only charges in ChargingWeapon/Pushing states
		actor.overheat_controller(false)

		if not actor.is_movement_blocked():
			# Check for movement
			if actor.control_is_moving or (actor.control_run_held and not actor.overheating):
				# GMS2: lockRunningDirection(newFacing) when pressing RUN from Stand
				if actor.control_run_held and not actor.overheating and not actor.has_status(Constants.Status.CONFUSED):
					actor.lock_running_direction(actor.new_facing)
				switch_to("Walk")
				return

		if not actor.is_action_blocked():
			# Check for NPC ahead before attacking (GMS2: getNPCAhead + fireNPCEvent)
			if actor.control_attack_pressed and not actor.is_actor_dead():
				var npc_ahead: NPC = _check_npc_ahead(actor)
				if npc_ahead:
					npc_ahead.interact(actor)
					return
				# GMS2: No overheat check — player can always attack, just does less damage
				# (damage is proportional to gauge via DamageCalculator)
				switch_to("Attack")
				return

		# GMS2: Stand state does NOT have charging logic — charging only from Attack/ChargingWeapon

		# Check for menu (A key) - open ring menu (GMS2: blocked when action is blocked)
		if InputManager.is_menu_pressed() and not actor.is_action_blocked():
			_open_ring_menu(actor)

		# Check for misc (W key / Y gamepad) - open ALLY ring menu (GMS2: control_miscPressed)
		if InputManager.is_misc_pressed() and not actor.is_action_blocked():
			_open_ally_ring_menu(actor)

		# Actor swap (Shift key) handled in actor._physics_process()

func _check_damage_stack() -> void:
	if creature.damage_stack.size() > 0:
		# Process pending damage
		var dmg_data: Variant = creature.damage_stack.pop_front()
		if dmg_data:
			switch_to("Hit")

static func _open_ring_menu(actor: Actor) -> void:
	# Find the ring menu in GameManager's tree (RingMenu is inside a CanvasLayer)
	var ring_menu: RingMenu = _find_ring_menu(GameManager)
	if ring_menu:
		ring_menu.toggle(actor, actor)

static func _open_ally_ring_menu(actor: Actor) -> void:
	## GMS2: control_miscPressed — open ring menu for next alive ally (not self)
	if actor.is_actor_dead():
		return
	var total: int = GameManager.players.size()
	if total <= 1:
		return
	# Find actor's index
	var actor_idx: int = -1
	for i in range(total):
		if GameManager.players[i] == actor:
			actor_idx = i
			break
	if actor_idx == -1:
		return
	# Find next alive player that is NOT the caller
	var next_idx: int = (actor_idx + 1) % total
	for _i in range(total):
		var candidate: Actor = GameManager.players[next_idx] as Actor
		if candidate and candidate != actor:
			if not (candidate is Creature and (candidate as Creature).is_dead):
				var ring_menu: RingMenu = _find_ring_menu(GameManager)
				if ring_menu:
					ring_menu.toggle(candidate, actor)
				return
		next_idx = (next_idx + 1) % total

static func _find_ring_menu(node: Node) -> RingMenu:
	for child in node.get_children():
		if child is RingMenu:
			return child
		var found: RingMenu = _find_ring_menu(child)
		if found:
			return found
	return null

func _check_npc_ahead(actor: Actor) -> NPC:
	## Raycast check for NPC in front of the actor (GMS2: getNPCAhead)
	var check_offset := actor.get_facing_direction()
	var space := actor.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		actor.global_position,
		actor.global_position + check_offset * 10.0,
		actor.collision_mask
	)
	query.exclude = [actor.get_rid()]
	var result := space.intersect_ray(query)
	if result and result.collider is NPC:
		return result.collider as NPC
	return null
