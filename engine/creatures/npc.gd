class_name NPC
extends Creature
## NPC class - non-hostile creature that can trigger events

@export var npc_name: String = ""
@export var dialog_id: String = ""
@export var fire_event: bool = false
@export var sprite_id: String = ""  # e.g. "darkLich", "dyluck", "neko"

# Shop NPC properties (GMS2: oNpc_neko)
@export var is_shop_keeper: bool = false
@export var shop_seller_id: String = ""

## GMS2: pushable property - NPCs can be pushed by the player walking into them.
## Shop NPCs (neko) have pushable=false (they block movement).
@export var is_pushable: bool = true

# NPC sprite configurations (GMS2 oCreature default animation ranges)
# Standard layout: 25 frames in 5-column grid
# Stand: 0=up, 1=right, 2=down, 3=left
# Walk: 5-8=up, 10-13=right, 15-18=down, 20-23=left
const NPC_SPRITE_CONFIG: Dictionary = {
	"darkLich": {
		"texture": "res://assets/sprites/sheets/spr_npc_darkLich.png",
		"columns": 5, "fw": 42, "fh": 42, "origin": Vector2(20, 35),
		"stand": [0, 1, 2, 3],
		"walk_up": [5, 8], "walk_right": [10, 13],
		"walk_down": [15, 18], "walk_left": [20, 23],
	},
	"dyluck": {
		"texture": "res://assets/sprites/sheets/spr_npc_dyluck.png",
		"columns": 5, "fw": 42, "fh": 42, "origin": Vector2(20, 35),
		"stand": [0, 1, 2, 3],
		"walk_up": [5, 8], "walk_right": [10, 13],
		"walk_down": [15, 18], "walk_left": [20, 23],
	},
	"neko": {
		"texture": "res://assets/sprites/sheets/spr_npc_neko.png",
		"columns": 5, "fw": 32, "fh": 44, "origin": Vector2(16, 33),
		"stand": [0, 1, 2, 3],
		"walk_up": [5, 8], "walk_right": [10, 13],
		"walk_down": [15, 17], "walk_left": [15, 17],
	},
}

var creature_is_npc: bool = true
var _shop_waiting_response: bool = false
var _shop_player: Actor = null
var _scene_prepared: bool = false

func _ready() -> void:
	super._ready()
	creature_is_npc = true
	is_npc = true
	# GMS2: shop NPCs (neko) are not pushable
	if is_shop_keeper:
		is_pushable = false
	_init_npc_sprite()
	# GMS2: image_speed = 0 (NPCs don't animate by default)
	image_speed = 0.0
	# Default facing: down
	facing = Constants.Facing.DOWN
	set_default_facing_index()

func _init_npc_sprite() -> void:
	if sprite_id == "":
		return
	var config: Dictionary = NPC_SPRITE_CONFIG.get(sprite_id, {})
	if config.is_empty():
		push_warning("NPC sprite config not found for: " + sprite_id)
		return

	# Try loading AnimatedSprite2D from .tres (new system)
	var anim_lib_path: String = "res://assets/animations/npcs/%s/%s.tres" % [sprite_id, sprite_id]
	if ResourceLoader.exists(anim_lib_path):
		var sf: SpriteFrames = load(anim_lib_path)
		if sf:
			var origin: Vector2 = config.get("origin", Vector2(20, 35))
			setup_animated_sprite(sf, origin)
			# Set frame ranges for bridge
			var stand: Array = config.get("stand", [0, 1, 2, 3])
			spr_stand_up = stand[0]; spr_stand_right = stand[1]
			spr_stand_down = stand[2]; spr_stand_left = stand[3]
			var wu: Array = config.get("walk_up", [5, 8])
			spr_up_ini = wu[0]; spr_up_end = wu[1]
			# Build bridge map
			_frame_to_anim_map[stand[0]] = "stand"
			_frame_to_anim_map[wu[0]] = "walk"
			return

	# Fallback: legacy Sprite2D system
	var tex: Texture2D = load(config.get("texture", ""))
	if not tex:
		push_warning("NPC sprite texture not found: " + config.get("texture", ""))
		return
	set_sprite_sheet(
		tex,
		config.get("columns", 5),
		config.get("fw", 42),
		config.get("fh", 42),
		config.get("origin", Vector2(20, 35))
	)
	# Set stand frames
	var stand: Array = config.get("stand", [0, 1, 2, 3])
	spr_stand_up = stand[0]
	spr_stand_right = stand[1]
	spr_stand_down = stand[2]
	spr_stand_left = stand[3]
	# Set walk animation ranges
	var wu: Array = config.get("walk_up", [5, 8])
	var wr: Array = config.get("walk_right", [10, 13])
	var wd: Array = config.get("walk_down", [15, 18])
	var wl: Array = config.get("walk_left", [20, 23])
	spr_up_ini = wu[0]; spr_up_end = wu[1]
	spr_right_ini = wr[0]; spr_right_end = wr[1]
	spr_down_ini = wd[0]; spr_down_end = wd[1]
	spr_left_ini = wl[0]; spr_left_end = wl[1]
	# Show the stand-down frame
	set_frame(spr_stand_down)

func interact(player: Actor) -> void:
	# GMS2: fireNPCEvent() calls prepareScene() first
	_prepare_scene()

	if is_shop_keeper and shop_seller_id != "":
		_start_shop_interaction(player)
		return
	if dialog_id != "":
		DialogManager.show_dialog(dialog_id, {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		# End scene when dialog finishes (non-shop NPCs)
		DialogManager.dialog_finished.connect(_on_dialog_finished_end_scene, CONNECT_ONE_SHOT)
	else:
		# No dialog - just fire event, scene will end when event completes
		pass
	fire_event = true

## GMS2: prepareScene() - locks all players and sets scene state
func _prepare_scene() -> void:
	if _scene_prepared:
		return
	_scene_prepared = true
	GameManager.scene_running = true

	# GMS2: stopPlayers() + with(oActor) { state_switch(state_ANIMATION); lockMovementInput(); }
	for player in GameManager.players:
		if is_instance_valid(player) and player is Actor:
			var actor: Actor = player as Actor
			actor.velocity = Vector2.ZERO
			MoveToPosition.stop(actor)
			actor.lock_movement_input()
			actor.lock_input()
			if actor.state_machine_node and actor.state_machine_node.has_state("Animation"):
				actor.state_machine_node.switch_state("Animation")

## GMS2: endScene equivalent - restores all players
func _end_npc_scene() -> void:
	if not _scene_prepared:
		return
	_scene_prepared = false
	GameManager.scene_running = false
	fire_event = false

	# Restore all players to stand/dead state
	for player in GameManager.players:
		if is_instance_valid(player) and player is Actor:
			var actor: Actor = player as Actor
			actor.unlock_movement_input()
			actor.unlock_input()
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

	# GMS2: endAnimationScene() rebinds camera to party leader
	var leader: Node = GameManager.get_party_leader()
	if leader:
		var cam: Node = get_tree().current_scene.find_child("CameraController", true, false)
		if cam is CameraController:
			cam.camera_bind(leader)

func _on_dialog_finished_end_scene(_dialog_id: String) -> void:
	## Non-shop NPC: end scene when dialog finishes
	_end_npc_scene()

func _start_shop_interaction(player: Actor) -> void:
	## GMS2 oNpc_neko: line up party, show dialog, then ask Buy/Sell
	_shop_player = player
	# GMS2: step 0 calls go_lineUp(FACING_UP, placement, true) before dialog
	_line_up_party_for_shop()
	if dialog_id != "":
		DialogManager.show_dialog(dialog_id, {
			"anchor": Constants.DialogAnchor.TOP,
			"block_controls": true,
		})
		# Wait for dialog to finish then show question
		_shop_waiting_response = true
		DialogManager.dialog_finished.connect(_on_shop_dialog_finished, CONNECT_ONE_SHOT)
	else:
		_show_buy_sell_question()

func _line_up_party_for_shop() -> void:
	## GMS2: go_lineUp(FACING_UP, [1, 0, 2]) before shop dialog
	var total: int = GameManager.players.size()
	if total < 2:
		return
	var leader: Node2D = GameManager.players[0] as Node2D
	if not is_instance_valid(leader):
		return
	# GMS2 default placement [1, 0, 2]: leader center, P1 left, P2 right
	var placement: Array = [1, 0, 2]
	var perp := Vector2(16, 0)
	var base_pos: Vector2 = leader.global_position
	for i in range(mini(total, placement.size())):
		var p: Node2D = GameManager.players[i] as Node2D
		if is_instance_valid(p):
			p.global_position = base_pos + perp * (placement[i] - 1)
			if p is Creature:
				(p as Creature).facing = Constants.Facing.UP
				(p as Creature).new_facing = Constants.Facing.UP

func _on_shop_dialog_finished(_dialog_id: String) -> void:
	if _shop_waiting_response:
		_shop_waiting_response = false
		_show_buy_sell_question()

func _show_buy_sell_question() -> void:
	## Ask player to Buy or Sell (GMS2: dialogQuestion)
	DialogManager.show_dialog("Buy or Sell?", {
		"anchor": Constants.DialogAnchor.TOP,
		"block_controls": true,
		"questions": ["Buy", "Sell"],
	})
	DialogManager.dialog_question_answered.connect(_on_shop_question_answered, CONNECT_ONE_SHOT)

func _on_shop_question_answered(_dialog_id: String, answer_idx: int) -> void:
	## Open shop based on player's choice
	var buying: bool = (answer_idx == 0)  # 0 = Buy, 1 = Sell
	# Find the ring menu instance
	var ring_menu: RingMenu = _find_ring_menu()
	if ring_menu:
		ring_menu.open_shop(shop_seller_id, buying, _shop_player)
		# GMS2: scene ends when ring menu (shop) closes - connect to close signal
		if ring_menu.has_signal("menu_closed"):
			ring_menu.menu_closed.connect(_on_shop_closed, CONNECT_ONE_SHOT)
		else:
			# Fallback: end scene immediately if no close signal
			_end_npc_scene()
	else:
		_end_npc_scene()
	_shop_player = null

func _on_shop_closed() -> void:
	## GMS2: neko sets fireEvent=false when ring menu opens (shop takes over)
	_end_npc_scene()

func _find_ring_menu() -> RingMenu:
	## Find the RingMenu node (child of GameManager UI layer)
	for child in GameManager.get_children():
		if child is CanvasLayer:
			for ui_child in child.get_children():
				if ui_child is RingMenu:
					return ui_child
		if child is RingMenu:
			return child
	# Also check deeper (ring_menu.tscn root is a CanvasLayer with RingMenu child)
	var ring_menus := GameManager.get_tree().get_nodes_in_group("ring_menu")
	if ring_menus.size() > 0 and ring_menus[0] is RingMenu:
		return ring_menus[0]
	# Brute force search
	for node in GameManager.get_tree().root.find_children("*", "RingMenu", true, false):
		if node is RingMenu:
			return node as RingMenu
	return null

func get_npc_ahead(creature: Creature) -> NPC:
	var dir := creature.facing
	var check_offset := Vector2.ZERO
	match dir:
		Constants.Facing.UP: check_offset = Vector2(0, -1)
		Constants.Facing.RIGHT: check_offset = Vector2(1, 0)
		Constants.Facing.DOWN: check_offset = Vector2(0, 1)
		Constants.Facing.LEFT: check_offset = Vector2(-1, 0)

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		creature.global_position,
		creature.global_position + check_offset * 16,
		creature.collision_mask
	)
	var result := space.intersect_ray(query)
	if result and result.collider is NPC:
		return result.collider as NPC
	return null
