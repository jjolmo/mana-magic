class_name MapChangeDeny
extends Area2D
## Blocks map progression - replaces oSce_mapChangeDeny from GMS2
## GMS2: oSce_mapChangeDeny Step event:
##   Step 0: Gather party (companions move to leader, then separate by facing)
##   Step 1: Show dialog
##   Step 2: Walk all actors backward (2 tiles in direction_to_move)
##   Step 3: Wait 60 frames, end scene

@export var dialog_id: String = ""
@export var direction_to_move: int = Constants.Facing.UP

var running: bool = false
var scene_step: int = 0
var timer: float = 0.0

# Step 0: party gather tracking
var _companions_reached: Array[bool] = []

# Step 2: walk-back tracking
var _walk_targets: Array[Vector2] = []
var _walk_started: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Actor and not running and not GameManager.scene_running:
		running = true
		scene_step = 0
		timer = 0.0
		_companions_reached.clear()
		_walk_targets.clear()
		_walk_started = false
		GameManager.scene_running = true
		# Lock all players immediately (GMS2: scene running blocks input)
		for player in GameManager.players:
			if is_instance_valid(player) and player.has_method("lock_movement_input"):
				player.lock_movement_input()
				player.velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if not running:
		return
	timer += delta

	if scene_step == 0:
		# GMS2: Gather all companions to leader position
		_process_gather_party()
	elif scene_step == 1 and timer >= 1.0 / 60.0:
		if dialog_id != "":
			DialogManager.show_dialog(dialog_id, {
				"id": dialog_id,
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
		scene_step = 2
		timer = 0.0
	elif scene_step == 2:
		if not DialogManager.is_showing():
			scene_step = 3
			timer = 0.0
			_walk_started = false
	elif scene_step == 3:
		# GMS2: Walk all actors 2 tiles in direction_to_move
		_process_walk_back()
	elif scene_step == 4 and timer >= 60.0 / 60.0:
		# GMS2: endAnimationScene() — cleanup
		running = false
		GameManager.scene_running = false
		# Unlock all players and restore stand/dead state
		for player in GameManager.players:
			if is_instance_valid(player) and player is Actor:
				var actor: Actor = player as Actor
				actor.unlock_movement_input()
				actor.unlock_input()
				actor.velocity = Vector2.ZERO
				if actor.state_machine_node:
					if actor.is_dead:
						if actor.state_machine_node.has_state("Dead"):
							actor.state_machine_node.switch_state("Dead")
					elif actor.player_controlled:
						if actor.state_machine_node.has_state("Stand"):
							actor.state_machine_node.switch_state("Stand")
					else:
						if actor.state_machine_node.has_state("IAStand"):
							actor.state_machine_node.switch_state("IAStand")


func _process_gather_party() -> void:
	## GMS2: Step 0 — move all non-leader actors to leader position, then separate
	var leader: Node2D = GameManager.get_party_leader() as Node2D
	if not is_instance_valid(leader):
		# No leader — skip gather
		scene_step = 1
		timer = 0.0
		return

	var total: int = GameManager.players.size()
	if total <= 1:
		# Solo player — skip gather
		scene_step = 1
		timer = 0.0
		return

	# Initialize tracking array
	if _companions_reached.size() != total:
		_companions_reached.resize(total)
		_companions_reached[0] = true  # Leader is already at their own position
		for i in range(1, total):
			_companions_reached[i] = false

	# Move each companion to leader
	var all_reached: bool = true
	for i in range(1, total):
		if _companions_reached[i]:
			continue
		var player: Node2D = GameManager.players[i] as Node2D
		if not is_instance_valid(player):
			_companions_reached[i] = true
			continue
		if player is Creature:
			_companions_reached[i] = MoveToPosition.go(
				player as Creature, leader.global_position.x, leader.global_position.y,
				false, true, false
			)
		if not _companions_reached[i]:
			all_reached = false

	if all_reached:
		# GMS2: go_separatePlayersByFacing(directionToMove) — offset to prevent sprite flickering
		_separate_players_by_facing(direction_to_move)
		# Make all players face the deny direction
		for player in GameManager.players:
			if is_instance_valid(player) and player is Creature:
				(player as Creature).facing = direction_to_move
				(player as Creature).new_facing = direction_to_move
		scene_step = 1
		timer = 0.0


func _process_walk_back() -> void:
	## GMS2: Step 2 — walk all actors 2 tiles in direction_to_move (away from the deny area)
	## GMS2: with(oActor) { go_walk(self, other.directionToMove, 2); }
	var total: int = GameManager.players.size()
	if total < 1:
		scene_step = 4
		timer = 0.0
		return

	if not _walk_started:
		_walk_started = true
		# Calculate walk-back targets: 2 tiles (32 px) in direction_to_move
		_walk_targets.clear()
		var offset := Vector2.ZERO
		match direction_to_move:
			Constants.Facing.UP: offset = Vector2(0, -32)
			Constants.Facing.RIGHT: offset = Vector2(32, 0)
			Constants.Facing.DOWN: offset = Vector2(0, 32)
			Constants.Facing.LEFT: offset = Vector2(-32, 0)
		for i in range(total):
			var player: Node2D = GameManager.players[i] as Node2D
			if is_instance_valid(player):
				_walk_targets.append(player.global_position + offset)
			else:
				_walk_targets.append(Vector2.ZERO)

	# Move each actor toward their walk-back target
	var all_done: bool = true
	for i in range(total):
		var player: Node = GameManager.players[i]
		if not is_instance_valid(player) or not (player is Creature):
			continue
		var creature: Creature = player as Creature
		if _walk_targets.size() <= i:
			continue
		var reached: bool = MoveToPosition.go(
			creature, _walk_targets[i].x, _walk_targets[i].y,
			false, true, false
		)
		if not reached:
			all_done = false

	if all_done:
		# Stop all movement
		for player in GameManager.players:
			if is_instance_valid(player):
				MoveToPosition.stop(player as Creature)
		scene_step = 4
		timer = 0.0


func _separate_players_by_facing(direction: int) -> void:
	## GMS2: go_separatePlayersByFacing — offset players by 1px to prevent depth flickering
	var counted: int = 0
	for i in range(GameManager.players.size()):
		var player: Node2D = GameManager.players[i] as Node2D
		if not is_instance_valid(player):
			counted += 1
			continue
		match direction:
			Constants.Facing.UP: player.global_position.y -= counted
			Constants.Facing.RIGHT: player.global_position.x += counted
			Constants.Facing.DOWN: player.global_position.y += counted
			Constants.Facing.LEFT: player.global_position.x -= counted
		counted += 1
