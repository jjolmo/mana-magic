class_name SceneRabite1
extends SceneEvent
## Rabite quest start cutscene (rom_01) - replaces oSce_rabite1 from GMS2
## The party rests, a rabite appears, steals the Mana Seeds, and runs away.
## Full choreography matching GMS2: camera, blend, movement, animations, rabite phases.

var dialog_done: bool = false
var _step_inited: bool = false

# Rabite NPC reference
var rabite: Creature = null

# Step 1: track player movement completion
var _players_reached: Array[bool] = [false, false, false]

# Step 5: rabite movement state
var _rabite_moving: bool = false
var _rabite_reached: bool = false
var _rabite_move_time: float = 0.0  # Independent time counter (not paused by dialog)

# Step 6: complex attack choreography sub-phases
var _attack_phase: int = 0
var _actors_hit: bool = false
var _finished_hit_anim: bool = false
var _step6_time: float = 0.0  # Independent time counter for step 6 (like GMS2 timer)
# Step 6: rabite seed collection waypoints
var _seed_waypoints_x: Array[float] = [594.0, 671.0, 643.0]
var _seed_waypoints_y: Array[float] = [400.0, 452.0, 400.0]
var _seed_waypoint_idx: int = 0

# Step 3: dialog line tracking for animation triggers
var _affirmate_started: bool = false
var _fall_up_started: bool = false

# Step 6: rabite bounce helper
var _rabite_bounce_value: float = 2.5
# Step 6: one-shot flags for time-based triggers
var _s6_flag_1: bool = false
var _s6_flag_28: bool = false
var _s6_flag_30: bool = false
var _s6_flag_150: bool = false
var _s6_flag_300: bool = false
var _s6_flag_500: bool = false
var _s6_flag_520: bool = false
var _s6_flag_540: bool = false
var _s6_flag_600: bool = false

# Seeds spawned for collection tracking
var _spawned_seeds: Array = []

# Rabite animation setup flag
var _rabite_anim_setup: bool = false
var _rabite_bouncing: bool = false  # Whether rabite should bounce (only during movement)


func _ready() -> void:
	auto_start = true
	scene_persistence_id = "oSce_rabite1"
	super._ready()
	DialogManager.dialog_finished.connect(_on_dialog_finished)

	# GMS2 Create_0: go_blendScreenOn(c_black, 1) - start with black screen
	go_blend_screen_on(Color.BLACK, 1.0)


func _on_dialog_finished(_id: String) -> void:
	dialog_done = true


func _process(delta: float) -> void:
	super._process(delta)
	if not scene_running:
		return

	# GMS2: rabite movement runs EVERY frame, even during dialog display.
	# The GMS2 child oSce_rabite1 has its own timer++ that runs when game.runWorld
	# is true (not affected by dialog_paused). In Godot, we handle rabite physics
	# before the _dialog_paused check to match this behavior.
	_update_rabite_physics()

	if _dialog_paused:
		return

	# === STEP 0: Setup - camera, player positions ===
	if is_scene_step(0):
		if timer >= 1.0 / 60.0:
			lock_all_players()

			# Get rabite reference and disable its AI/physics during cutscene
			rabite = get_parent().get_node_or_null("mob_rabite_npc") as Creature
			if is_instance_valid(rabite):
				rabite.velocity = Vector2.ZERO
				# GMS2: rabite starts facing LEFT (state_facing = state_facingLeft)
				rabite.facing = Constants.Facing.LEFT
				rabite.new_facing = Constants.Facing.LEFT
				# Disable mob state machine so it doesn't interfere with scripted movement
				if rabite.state_machine_node:
					rabite.state_machine_node.process_mode = Node.PROCESS_MODE_DISABLED

			# GMS2: cameraSetCoord(700, 370)
			camera_set_coord(Vector2(700, 370))

			# Position players spread out (GMS2: players[1].x -= 40, players[2].x -= 80)
			if GameManager.players.size() >= 3:
				var leader: Node2D = GameManager.players[0]
				GameManager.players[1].global_position = leader.global_position + Vector2(-40, 0)
				GameManager.players[2].global_position = leader.global_position + Vector2(-80, 0)

			add_step()

	# === STEP 1: Blend off + move players into position (GMS2: min_timer=200) ===
	elif is_scene_step(1):
		if not _step_inited:
			_step_inited = true
			_players_reached = [false, false, false]
			# GMS2: go_blendScreenOff(60) - fade from black
			go_blend_screen_off(60)

		# Move players to their cutscene positions every frame
		if GameManager.players.size() >= 3:
			if not _players_reached[0]:
				_players_reached[0] = go_move_to_position(
					GameManager.players[0] as Creature, 620, 443)
			if not _players_reached[1]:
				_players_reached[1] = go_move_to_position(
					GameManager.players[1] as Creature, 572, 440)
			if not _players_reached[2]:
				_players_reached[2] = go_move_to_position(
					GameManager.players[2] as Creature, 595, 410)

			# Advance when all arrived AND enough time passed (GMS2: min 200 frames)
			if _players_reached[0] and _players_reached[1] and _players_reached[2] and timer >= 200.0 / 60.0:
				_step_inited = false
				add_step()

	# === STEP 2: Popoie complains about being hungry (GMS2: min_timer=120) ===
	elif is_scene_step(2, 120.0 / 60.0):
		if not _step_inited:
			_step_inited = true
			dialog_done = false
			DialogManager.show_dialog("rom_02-evt_rabiteQuestStart_0", {
				"id": "rom_02-evt_rabiteQuestStart_0",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
		elif dialog_done:
			dialog_done = false
			_step_inited = false
			_affirmate_started = false
			_fall_up_started = false
			add_step()

	# === STEP 3: Purim teases Popoie + animations ===
	elif is_scene_step(3):
		if not _step_inited:
			_step_inited = true
			dialog_done = false
			DialogManager.show_dialog("rom_02-evt_rabiteQuestStart_1", {
				"id": "rom_02-evt_rabiteQuestStart_1",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})

		# GMS2: timer == 30 → player[0] look LEFT
		if timer >= 30.0 / 60.0 and GameManager.players.size() > 0:
			go_look(GameManager.players[0] as Creature, Constants.Facing.LEFT)

		# GMS2: isDialogLine(3, true) → player[2] AFFIRMATE animation
		# Approximate with dialog page index check
		if not _affirmate_started and GameManager.players.size() >= 3:
			var page_idx: int = DialogManager.get_dialog_index()
			if page_idx >= 2:  # 3rd page (0-indexed)
				_affirmate_started = true
				go_animation(GameManager.players[2] as Creature, 2, Constants.Facing.DOWN)

		# GMS2: timer == 280 → player[2] FALL_UP (sad pose)
		if timer >= 280.0 / 60.0 and not _fall_up_started and GameManager.players.size() >= 3:
			_fall_up_started = true
			stop_animation(GameManager.players[2] as Creature)
			go_animation(GameManager.players[2] as Creature, 1, Constants.Facing.UP)

		if dialog_done:
			dialog_done = false
			_step_inited = false
			# Clear animation on Popoie
			if GameManager.players.size() >= 3:
				stop_animation(GameManager.players[2] as Creature)
			add_step()

	# === STEP 4: Randi reminds about the seeds ===
	elif is_scene_step(4):
		if not _step_inited:
			_step_inited = true
			dialog_done = false
			DialogManager.show_dialog("rom_02-evt_rabiteQuestStart_2", {
				"id": "rom_02-evt_rabiteQuestStart_2",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
		elif dialog_done:
			dialog_done = false
			_step_inited = false
			add_step()

	# === STEP 5: Purim spots the rabite + rabite moves ===
	elif is_scene_step(5):
		if not _step_inited:
			_step_inited = true
			dialog_done = false
			_rabite_moving = false
			_rabite_reached = false
			_rabite_move_time = 0.0

			# GMS2: go_look(player[2], DOWN)
			if GameManager.players.size() >= 3:
				go_look(GameManager.players[2] as Creature, Constants.Facing.DOWN)

			DialogManager.show_dialog("rom_02-evt_rabiteQuestStart_3", {
				"id": "rom_02-evt_rabiteQuestStart_3",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})

		# GMS2: timer == 40 → player[0] look RIGHT (timer-based, only when unpaused)
		if timer >= 40.0 / 60.0 and GameManager.players.size() > 0:
			go_look(GameManager.players[0] as Creature, Constants.Facing.RIGHT)

		if dialog_done:
			dialog_done = false
			_step_inited = false
			add_step()

	# === STEP 6: Rabite attacks — 600-frame choreography ===
	# All timing handled in _update_rabite_physics() with independent frame counter.
	# Only step init and final step advance handled here.
	elif is_scene_step(6):
		if not _step_inited:
			_step_inited = true
			_attack_phase = 0
			_actors_hit = false
			_finished_hit_anim = false
			_seed_waypoint_idx = 0
			_step6_time = 0.0
			_s6_flag_1 = false; _s6_flag_28 = false; _s6_flag_30 = false
			_s6_flag_150 = false; _s6_flag_300 = false; _s6_flag_500 = false
			_s6_flag_520 = false; _s6_flag_540 = false; _s6_flag_600 = false
			dialog_done = false

	# === STEP 7: Party is angry ===
	elif is_scene_step(7):
		if not _step_inited:
			_step_inited = true
			dialog_done = false
			for p in GameManager.players:
				if is_instance_valid(p) and p is Creature:
					go_look(p as Creature, Constants.Facing.UP)
			DialogManager.show_dialog("rom_02-evt_rabiteQuestStart_5", {
				"id": "rom_02-evt_rabiteQuestStart_5",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})
		elif dialog_done:
			dialog_done = false
			_step_inited = false
			add_step()

	# === STEP 8: Popoie wants to chase ===
	elif is_scene_step(8):
		if not _step_inited:
			_step_inited = true
			dialog_done = false
			DialogManager.show_dialog("rom_02-evt_rabiteQuestStart_6", {
				"id": "rom_02-evt_rabiteQuestStart_6",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})

		# GMS2: timer > 30 → player[2] runs to exit
		if timer > 30.0 / 60.0 and GameManager.players.size() >= 3:
			go_move_to_position(GameManager.players[2] as Creature, 745, 220, true, false)

		if dialog_done:
			dialog_done = false
			_step_inited = false
			add_step()

	# === STEP 9: Randi says wait (GMS2: min_timer=30) ===
	elif is_scene_step(9, 30.0 / 60.0):
		if not _step_inited:
			_step_inited = true
			dialog_done = false
			DialogManager.show_dialog("rom_02-evt_rabiteQuestStart_7", {
				"id": "rom_02-evt_rabiteQuestStart_7",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})

		# GMS2: ALL players run to exit point (Popoie started in step 8, continues here)
		if GameManager.players.size() >= 3:
			go_move_to_position(GameManager.players[0] as Creature, 745, 220, true, false)
			go_move_to_position(GameManager.players[1] as Creature, 745, 220, true, false)
			go_move_to_position(GameManager.players[2] as Creature, 745, 220, true, false)

		if dialog_done:
			dialog_done = false
			_step_inited = false
			add_step()

	# === STEP 10: Change map to rom_02 (GMS2: min_timer=120) ===
	elif is_scene_step(10, 120.0 / 60.0):
		unlock_all_players()
		GameManager.change_map("rom_02")
		end_scene()


## Rabite physics that runs EVERY frame, even during dialog display.
## GMS2: the child oSce_rabite1 has timer++/timer2++ inside game.runWorld guard,
## which runs independently of the dialog system. The rabite moves, bounces, and
## collects seeds while the dialog text is paused/locked.
func _update_rabite_physics() -> void:
	if not is_instance_valid(rabite):
		return

	# Setup rabite with standing idle animation initially (GMS2: PHASE_STAND)
	if not _rabite_anim_setup and rabite is Mob:
		_rabite_anim_setup = true
		_set_rabite_stand_anim()

	# State machine is disabled during cutscene, so we must manually
	# process z-axis, animation, and sprite using delta time.
	# Z-axis physics (gravity + bounce)
	rabite._update_z_axis()
	# Re-trigger bounce when landing (GMS2: if z==0 then zsp = -2.5)
	if _rabite_bouncing and rabite.z_height <= 0 and rabite.z_velocity == 0:
		rabite.z_velocity = _rabite_bounce_value
	# Advance animation frames
	rabite.animate_sprite(rabite.image_speed)
	# Visual update every render frame for smooth display
	rabite._update_sprite_position()

	# Step 5: Rabite approaches players during dialog.
	# Uses its own frame counter (_rabite_move_frames) because the scene timer
	# pauses during dialog in Godot, but GMS2's oSce_rabite1 has independent timer++.
	if scene_step == 5:
		_rabite_move_time += get_process_delta_time()
		# GMS2: at frame 60 (1 sec), rabite starts moving + dialog locks
		if _rabite_move_time >= 1.0 and not _rabite_moving and not _rabite_reached:
			_rabite_moving = true
			_set_rabite_hop_anim()  # Switch to hop animation + enable bounce
			DialogManager.dialog_lock()
		if _rabite_moving:
			# GMS2: rabite keeps facing LEFT during PHASE_MOVE (no direction update)
			var reached: bool = move_toward_position(rabite, Vector2(637, 392), 0.7)
			if reached:
				_rabite_moving = false
				_rabite_reached = true
				DialogManager.dialog_unlock()

	# Step 6: Full choreography with independent frame counter (matches GMS2 timer)
	# GMS2 timer runs independently of dialog, so all phase transitions use _step6_frames.
	elif scene_step == 6:
		_step6_time += get_process_delta_time()
		var t: float = _step6_time

		# Frame 1 (~0.017s): Rabite jump attack
		if t >= 1.0 / 60.0 and not _s6_flag_1:
			_s6_flag_1 = true
			_rabite_bouncing = false  # Disable auto-bounce during controlled jump
			rabite.z_velocity = 3.0
			MusicManager.play_sfx("snd_rabiteJump")

		# Frames 1-28: Rabite arcs toward players
		if t >= 1.0 / 60.0 and t < 28.0 / 60.0:
			move_toward_position(rabite, Vector2(575, 451), 1.5)

		# Frame 28: Rabite lands
		if t >= 28.0 / 60.0 and not _s6_flag_28:
			_s6_flag_28 = true
			rabite.z_height = 0
			rabite.z_velocity = 0

		# Frame 30: Hit actors + seed burst + dialog
		if t >= 30.0 / 60.0 and not _s6_flag_30 and not _actors_hit:
			_s6_flag_30 = true
			_actors_hit = true
			for p in GameManager.players:
				if is_instance_valid(p) and p is Actor:
					var a := p as Actor
					a.set_meta("hit2_push_dir", 90.0)
					a.set_meta("hit2_is_anim", true)
					if a.state_machine_node and a.state_machine_node.has_state("Hit2"):
						a.state_machine_node.switch_state("Hit2")
			if GameManager.players.size() > 0:
				var leader: Node2D = GameManager.players[0]
				_spawned_seeds = AssetSeed.spawn_seed_burst(leader.global_position, get_parent(), rabite)
			_rabite_bouncing = true  # Re-enable bounce after attack landing
			DialogManager.show_dialog("rom_02-evt_rabiteQuestStart_4", {
				"id": "rom_02-evt_rabiteQuestStart_4",
				"anchor": Constants.DialogAnchor.TOP,
				"block_controls": true,
			})

		# Frames 30+: Bounce and animation handled by _update_rabite_physics() via _rabite_bouncing flag

		# Frame 150: Rabite starts collecting seeds
		if t >= 150.0 / 60.0 and not _s6_flag_150:
			_s6_flag_150 = true
			MusicManager.play_sfx("snd_menuError")
			_seed_waypoint_idx = 0

		# Frames 150-300: Move between seed waypoints collecting seeds
		if t >= 150.0 / 60.0 and t < 300.0 / 60.0 and _seed_waypoint_idx < 3:
			var tx: float = _seed_waypoints_x[_seed_waypoint_idx]
			var ty: float = _seed_waypoints_y[_seed_waypoint_idx]
			_update_rabite_facing(Vector2(tx, ty))
			# Collect seeds continuously while near them (not just at waypoints)
			_collect_nearby_seeds()
			if move_toward_position(rabite, Vector2(tx, ty), 1.5):
				_seed_waypoint_idx += 1

		# Frame 300: Force-destroy any remaining seeds before escaping
		if t >= 300.0 / 60.0 and not _s6_flag_300:
			_s6_flag_300 = true
			_destroy_all_seeds()

		# Frames 300-500: Rabite escapes to exit
		if t >= 300.0 / 60.0 and t < 500.0 / 60.0:
			_update_rabite_facing(Vector2(745, 220))
			move_toward_position(rabite, Vector2(745, 220), 1.5)

		# Frame 500: Actors stand ready
		if t >= 500.0 / 60.0 and not _s6_flag_500:
			_s6_flag_500 = true
			for p in GameManager.players:
				if is_instance_valid(p) and p is Actor:
					var a := p as Actor
					if a.state_machine_node and a.state_machine_node.has_state("Stand"):
						a.state_machine_node.switch_state("Stand")

		# Frame 520: Look directions
		if t >= 520.0 / 60.0 and not _s6_flag_520 and GameManager.players.size() >= 3:
			_s6_flag_520 = true
			go_look(GameManager.players[0] as Creature, Constants.Facing.LEFT)
			go_look(GameManager.players[2] as Creature, Constants.Facing.UP)

		# Frame 540: More look directions
		if t >= 540.0 / 60.0 and not _s6_flag_540 and GameManager.players.size() >= 2:
			_s6_flag_540 = true
			go_look(GameManager.players[1] as Creature, Constants.Facing.RIGHT)

		# Frame 600: Final looks + advance step
		if t >= 600.0 / 60.0 and not _s6_flag_600:
			_s6_flag_600 = true
			if GameManager.players.size() >= 2:
				go_look(GameManager.players[0] as Creature, Constants.Facing.UP)
				go_look(GameManager.players[1] as Creature, Constants.Facing.UP)

		# Frame 600+: Wait for dialog to finish, then advance
		if t > 600.0 / 60.0 and not DialogManager.is_showing():
			_step_inited = false
			add_step()


## Set rabite to standing idle animation (GMS2: PHASE_STAND, frames 0-1, no bounce)
func _set_rabite_stand_anim() -> void:
	if not is_instance_valid(rabite) or not (rabite is Mob):
		return
	var mob := rabite as Mob
	rabite.set_default_facing_animations(
		mob.spr_stand_up, mob.spr_stand_up,
		mob.spr_stand_up, mob.spr_stand_up,
		mob.spr_stand_right, mob.spr_stand_right,
		mob.spr_stand_right, mob.spr_stand_right
	)
	rabite.image_speed = mob.img_speed_stand
	rabite.set_default_facing_index()
	_rabite_bouncing = false


## Set rabite to walk-jump animation (GMS2: PHASE_MOVE/STAND_BOUNCE, frames 2-4, with bounce)
func _set_rabite_hop_anim() -> void:
	if not is_instance_valid(rabite) or not (rabite is Mob):
		return
	var mob := rabite as Mob
	rabite.set_default_facing_animations(
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_ini, mob.spr_walk_jump_ini,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end,
		mob.spr_walk_jump_end, mob.spr_walk_jump_end
	)
	rabite.image_speed = mob.img_speed_walk
	rabite.set_default_facing_index()
	_rabite_bouncing = true
	rabite.z_velocity = _rabite_bounce_value


## Update rabite facing direction based on movement target
func _update_rabite_facing(target: Vector2) -> void:
	if not is_instance_valid(rabite):
		return
	var diff: Vector2 = target - rabite.global_position
	# Choose primary direction based on largest axis
	if abs(diff.x) > abs(diff.y):
		rabite.facing = Constants.Facing.RIGHT if diff.x > 0 else Constants.Facing.LEFT
	else:
		rabite.facing = Constants.Facing.UP if diff.y < 0 else Constants.Facing.DOWN
	rabite.new_facing = rabite.facing


## Destroy seeds near the rabite's current position
func _collect_nearby_seeds() -> void:
	if not is_instance_valid(rabite):
		return
	for seed_node in _spawned_seeds:
		if is_instance_valid(seed_node):
			if rabite.global_position.distance_to(seed_node.global_position) < 60.0:
				seed_node.queue_free()


## Force-destroy all remaining seeds (rabite collected everything)
func _destroy_all_seeds() -> void:
	for seed_node in _spawned_seeds:
		if is_instance_valid(seed_node):
			seed_node.queue_free()
	_spawned_seeds.clear()


## Step 6 choreography is now entirely handled inside _update_rabite_physics()
## using _step6_frames independent counter (runs even during dialog, matching GMS2).
