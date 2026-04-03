class_name LineUpAnimator
extends Node
## GMS2: oAnimator ACTION_LINE_UP — multi-phase lineup animation controller.
## Phase 0: Set all players to walk-charge stand, find middle player.
## Phase 1: Non-middle players converge to middle player's position (running).
## Phase 2: After 30 frames, non-middle players spread left/right 18px.
## Phase 3: (Optional) All players step backward 16px with charge animation.

static var _active: LineUpAnimator = null

var line_direction: int = Constants.Facing.UP
var placement: Array = []
var step_back_on_finish: bool = false
var middle_idx: int = -1

var phase: int = 0
var phase_timer: float = 0.0
var pixels_moved: Array[float] = []
const SPREAD_PIXELS: float = 18.0
const STEP_BACK_PIXELS: float = 16.0


static func start(p_direction: int, p_placement: Array, p_step_back: bool) -> void:
	## Create and start a new lineup animation. Replaces any existing one.
	if _active and is_instance_valid(_active):
		_active.queue_free()
		_active = null

	var total: int = GameManager.players.size()
	if total < 1:
		return

	# Default placement (GMS2 default: [1, 0, 2])
	if p_placement.is_empty():
		if total == 1:
			p_placement = [1]
		elif total == 2:
			p_placement = [1, 0]
		else:
			p_placement = [1, 0, 2]

	var animator := LineUpAnimator.new()
	animator.line_direction = p_direction
	animator.placement = p_placement
	animator.step_back_on_finish = p_step_back
	_active = animator

	# Stop any active MoveToPosition on all players first
	for i in range(total):
		var p: Node2D = GameManager.players[i] as Node2D
		if is_instance_valid(p) and p is Creature:
			MoveToPosition.stop(p as Creature)
			(p as Creature).velocity = Vector2.ZERO

	# Add to scene tree so _process runs
	var tree: SceneTree = GameManager.get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(animator)


func _process(delta: float) -> void:
	# GMS2: oAnimator checks game.runWorld — pauses during dialogs
	if DialogManager.is_showing():
		return

	phase_timer += delta
	_execute_phase()


func _execute_phase() -> void:
	match phase:
		0: _phase_stand_ready()
		1: _phase_converge()
		2: _phase_spread()
		3: _phase_step_back()


func _phase_stand_ready() -> void:
	## Phase 0: GMS2 oAnimator Create — set all players to walk-charge animation
	## and find the middle player (placement == 1).
	var total: int = GameManager.players.size()

	for i in range(total):
		var p: Creature = GameManager.players[i] as Creature
		if not is_instance_valid(p) or not (p is Actor):
			continue
		var a := p as Actor
		# GMS2: sets walk-charge animation with imgSpeedWalkCharging
		p.facing = line_direction
		p.new_facing = line_direction
		p.set_default_facing_animations(
			a.spr_walk_charge_up_ini, a.spr_walk_charge_right_ini,
			a.spr_walk_charge_down_ini, a.spr_walk_charge_left_ini,
			a.spr_walk_charge_up_end, a.spr_walk_charge_right_end,
			a.spr_walk_charge_down_end, a.spr_walk_charge_left_end
		)
		p.set_default_facing_index()
		p.image_speed = a.img_speed_walk_charging

	# GMS2: middlePlayerIndex = findIndex(placement, 1)
	middle_idx = placement.find(1)
	if middle_idx < 0:
		middle_idx = 0  # Fallback

	# GMS2 phase 0 → 1: immediately set stand ready and advance
	for i in range(total):
		var p: Creature = GameManager.players[i] as Creature
		if is_instance_valid(p) and p is Actor:
			_anim_stand_ready(p as Actor)

	phase = 1
	phase_timer = 0.0


func _phase_converge() -> void:
	## Phase 1: GMS2 — Non-middle players run to middle player's position
	## using go_moveToPosition(player, middlePlayer.x, middlePlayer.y, running=true, collisions=false).
	var total: int = GameManager.players.size()
	if middle_idx < 0 or middle_idx >= total:
		_finish()
		return

	var middle_player: Node2D = GameManager.players[middle_idx] as Node2D
	if not is_instance_valid(middle_player):
		_finish()
		return

	var all_reached: bool = true
	for i in range(total):
		if i == middle_idx:
			continue
		var p: Creature = GameManager.players[i] as Creature
		if not is_instance_valid(p):
			continue
		# GMS2: go_moveToPosition(player, middlePlayer.x, middlePlayer.y, true, false)
		# running=true, collisions=false
		if not MoveToPosition.go(p, middle_player.global_position.x, middle_player.global_position.y, true, false, false):
			all_reached = false

	if all_reached:
		# All converged → prepare for spread phase
		phase = 2
		phase_timer = 0.0
		pixels_moved.clear()
		for i in range(total):
			pixels_moved.append(0.0)

		# GMS2: Set run animation + walkSpeed = runMax for non-middle players
		for i in range(total):
			if i == middle_idx:
				continue
			var p: Creature = GameManager.players[i] as Creature
			if not is_instance_valid(p) or not (p is Actor):
				continue
			var a := p as Actor
			p.set_default_facing_animations(
				a.spr_run_up_ini, a.spr_run_right_ini,
				a.spr_run_down_ini, a.spr_run_left_ini,
				a.spr_run_up_end, a.spr_run_right_end,
				a.spr_run_down_end, a.spr_run_left_end
			)
			p.set_default_facing_index()
			p.image_speed = a.img_speed_run


func _phase_spread() -> void:
	## Phase 2: GMS2 — After 30-frame delay, non-middle players spread left/right
	## 18px at attribute.runMax speed with run animation.
	if phase_timer <= 30.0 / 60.0:
		return  # GMS2: 30-frame delay before spreading

	var total: int = GameManager.players.size()
	var reached_count: int = 0
	var movers_count: int = 0

	for i in range(total):
		var slot: int = placement[i]
		if slot == 1:  # Center player stays
			continue
		movers_count += 1

		var p: Creature = GameManager.players[i] as Creature
		if not is_instance_valid(p):
			reached_count += 1
			continue

		if pixels_moved[i] >= SPREAD_PIXELS:
			reached_count += 1
			continue

		var speed: float = p.attribute.runMax  # GMS2: walkSpeed set to runMax

		# GMS2: slot 0 = left, slot 2 = right (perpendicular to line direction)
		if slot == 0:  # Move left (relative to line direction)
			match line_direction:
				Constants.Facing.UP, Constants.Facing.DOWN:
					p.global_position.x -= speed
					p.facing = Constants.Facing.LEFT
					p.new_facing = Constants.Facing.LEFT
				Constants.Facing.LEFT, Constants.Facing.RIGHT:
					p.global_position.y -= speed
					p.facing = Constants.Facing.UP
					p.new_facing = Constants.Facing.UP
		elif slot == 2:  # Move right (relative to line direction)
			match line_direction:
				Constants.Facing.UP, Constants.Facing.DOWN:
					p.global_position.x += speed
					p.facing = Constants.Facing.RIGHT
					p.new_facing = Constants.Facing.RIGHT
				Constants.Facing.LEFT, Constants.Facing.RIGHT:
					p.global_position.y += speed
					p.facing = Constants.Facing.DOWN
					p.new_facing = Constants.Facing.DOWN

		pixels_moved[i] += speed
		p.animate_sprite()

	# GMS2: check if reached == 2 (or totalPlayers-1 non-center)
	if reached_count >= movers_count or GameManager.players.size() == 1:
		# All reached — face line direction and stand ready
		for i in range(total):
			var p: Creature = GameManager.players[i] as Creature
			if is_instance_valid(p) and p is Actor:
				p.facing = line_direction
				p.new_facing = line_direction
				_anim_stand_ready(p as Actor)

		if step_back_on_finish:
			# GMS2: prepare phase 3 — step-back
			phase = 3
			phase_timer = 0.0
			pixels_moved.clear()
			for i in range(total):
				pixels_moved.append(0.0)
			# Set walk-charge animation for step-back
			for i in range(total):
				var p: Creature = GameManager.players[i] as Creature
				if not is_instance_valid(p) or not (p is Actor):
					continue
				var a := p as Actor
				p.facing = Constants.Facing.UP
				p.new_facing = Constants.Facing.UP
				p.set_default_facing_animations(
					a.spr_walk_charge_up_ini, a.spr_walk_charge_right_ini,
					a.spr_walk_charge_down_ini, a.spr_walk_charge_left_ini,
					a.spr_walk_charge_up_end, a.spr_walk_charge_right_end,
					a.spr_walk_charge_down_end, a.spr_walk_charge_left_end
				)
				p.set_default_facing_index()
				p.image_speed = a.img_speed_walk_charging
		else:
			_finish()


func _phase_step_back() -> void:
	## Phase 3: GMS2 — All players step backward (DOWN) 16px at walkPushing speed.
	var total: int = GameManager.players.size()
	var reached_count: int = 0

	for i in range(total):
		var p: Creature = GameManager.players[i] as Creature
		if not is_instance_valid(p):
			reached_count += 1
			continue

		if pixels_moved[i] >= STEP_BACK_PIXELS:
			reached_count += 1
			continue

		# GMS2: walkSpeed = walkPushing; move DOWN (backward from UP direction)
		var speed: float = 1.0  # GMS2: walkPushing = 1
		if p is Actor:
			speed = (p as Actor).walk_pushing_speed
		p.global_position.y += speed
		pixels_moved[i] += speed
		p.animate_sprite()

	if reached_count >= total:
		# GMS2: all reached, stand ready and destroy
		for i in range(total):
			var p: Creature = GameManager.players[i] as Creature
			if is_instance_valid(p) and p is Actor:
				_anim_stand_ready(p as Actor)
		_finish()


func _anim_stand_ready(actor: Actor) -> void:
	## GMS2: anim_wpnStandReady() — set stand frame for current facing
	actor.set_default_facing_animations(
		actor.spr_walk_up_ini, actor.spr_walk_right_ini,
		actor.spr_walk_down_ini, actor.spr_walk_left_ini,
		actor.spr_walk_up_end, actor.spr_walk_right_end,
		actor.spr_walk_down_end, actor.spr_walk_left_end
	)
	actor.set_facing_frame(
		actor.spr_stand_up, actor.spr_stand_right,
		actor.spr_stand_down, actor.spr_stand_left
	)
	actor.image_speed = 0


func _finish() -> void:
	## Cleanup: remove active reference and destroy
	if _active == self:
		_active = null
	queue_free()
