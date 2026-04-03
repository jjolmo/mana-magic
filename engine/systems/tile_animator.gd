class_name TileAnimator
extends Node
## Runtime tile animation system - replaces GMS2 tileAnimationFrames/tileAnimationSpeed.
## Auto-attaches to TileMapLayers that use animated tilesets.
## Call TileAnimator.setup_scene(root) after any room load to activate.
## GMS2: tileAnimationSpeed = 8 (advance every 8 game ticks at 60fps → 7.5 tile fps)

var animation_fps: float = 7.5
var _animations: Array = []  # Array of Array[Vector2i] (4 frames each)
var _animated_cells: Dictionary = {}  # Vector2i(cell_pos) → int(animation_index)
var _tilemap: TileMapLayer = null
var _source_id: int = 0
var _current_frame: int = 0
var _frame_count: int = 4
var _frame_timer: float = 0.0

func setup(tilemap: TileMapLayer, animations: Array, source_id: int) -> void:
	_tilemap = tilemap
	_animations = animations
	_source_id = source_id
	_scan_cells()

func _scan_cells() -> void:
	if not _tilemap or _animations.is_empty():
		return
	# Build lookup: base frame (frame 0) → animation index
	var base_lookup: Dictionary = {}
	for i in range(_animations.size()):
		var frames: Array = _animations[i]
		if frames.size() > 0:
			base_lookup[frames[0]] = i
	# Scan all placed tiles for animated base frames
	for cell in _tilemap.get_used_cells():
		var src_id: int = _tilemap.get_cell_source_id(cell)
		if src_id != _source_id:
			continue
		var atlas_coords: Vector2i = _tilemap.get_cell_atlas_coords(cell)
		if base_lookup.has(atlas_coords):
			_animated_cells[cell] = base_lookup[atlas_coords]

func _process(delta: float) -> void:
	if _animated_cells.is_empty():
		return
	_frame_timer += delta
	var frame_dur: float = 1.0 / animation_fps
	if _frame_timer >= frame_dur:
		_frame_timer -= frame_dur
		_current_frame = (_current_frame + 1) % _frame_count
		for cell: Vector2i in _animated_cells:
			var anim_idx: int = _animated_cells[cell]
			var frames: Array = _animations[anim_idx]
			if _current_frame < frames.size():
				_tilemap.set_cell(cell, _source_id, frames[_current_frame])

# ==========================================================================
# Static setup: call from StartingPoint or MapTransition after room load.
# Scans all TileMapLayers in the scene and attaches animators as needed.
# ==========================================================================
static func setup_scene(scene_root: Node) -> void:
	if not scene_root:
		return
	var tilemaps: Array = scene_root.find_children("*", "TileMapLayer", true, false)
	for node in tilemaps:
		var tm: TileMapLayer = node as TileMapLayer
		if not tm or not tm.tile_set:
			continue
		# Skip if already has an animator
		if tm.has_node("TileAnimator"):
			continue
		# Check each source for animated tileset textures
		for src_idx in range(tm.tile_set.get_source_count()):
			var src_id: int = tm.tile_set.get_source_id(src_idx)
			var source: TileSetSource = tm.tile_set.get_source(src_id)
			if source is TileSetAtlasSource:
				var atlas: TileSetAtlasSource = source as TileSetAtlasSource
				if atlas.texture and atlas.texture.resource_path:
					var path: String = atlas.texture.resource_path
					var anims: Array = []
					if "spr_til_mana." in path:
						anims = ANIM_TIL_MANA
					elif "spr_til_manaFortressOutsideFade" in path:
						anims = ANIM_TIL_MANA_FORTRESS_FADE
					if anims.size() > 0:
						var animator := TileAnimator.new()
						animator.name = "TileAnimator"
						tm.add_child(animator)
						animator.setup(tm, anims, src_id)

# ==========================================================================
# til_mana animations (1000x1000 PNG, 62 columns, 43 sequences × 4 frames)
# GMS2 tile ID → Godot atlas_coords: Vector2i(id % 62, id / 62)
# ==========================================================================
const ANIM_TIL_MANA: Array = [
	[Vector2i(0, 2), Vector2i(2, 2), Vector2i(4, 2), Vector2i(6, 2)], # floor1_ul
	[Vector2i(1, 2), Vector2i(3, 2), Vector2i(5, 2), Vector2i(7, 2)], # floor1_ur
	[Vector2i(0, 3), Vector2i(2, 3), Vector2i(4, 3), Vector2i(6, 3)], # floor1_dl
	[Vector2i(1, 3), Vector2i(3, 3), Vector2i(5, 3), Vector2i(7, 3)], # floor1_dr
	[Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)], # floor2_ud
	[Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)], # floor2_lr
	[Vector2i(0, 8), Vector2i(2, 8), Vector2i(4, 8), Vector2i(6, 8)], # floor3_ul
	[Vector2i(1, 8), Vector2i(3, 8), Vector2i(5, 8), Vector2i(7, 8)], # floor3_ur
	[Vector2i(0, 9), Vector2i(2, 9), Vector2i(4, 9), Vector2i(6, 9)], # floor3_dl
	[Vector2i(1, 9), Vector2i(3, 9), Vector2i(5, 9), Vector2i(7, 9)], # floor3_dr
	[Vector2i(4, 13), Vector2i(5, 13), Vector2i(6, 13), Vector2i(7, 13)], # floor4_u
	[Vector2i(4, 14), Vector2i(5, 14), Vector2i(6, 14), Vector2i(7, 14)], # floor4_d
	[Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)], # floor5_u
	[Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)], # floor5_d
	[Vector2i(0, 10), Vector2i(2, 10), Vector2i(4, 10), Vector2i(6, 10)], # base1_l
	[Vector2i(1, 10), Vector2i(3, 10), Vector2i(5, 10), Vector2i(7, 10)], # base1_r
	[Vector2i(0, 11), Vector2i(3, 11), Vector2i(6, 11), Vector2i(9, 11)], # core_ul
	[Vector2i(1, 11), Vector2i(4, 11), Vector2i(7, 11), Vector2i(10, 11)], # core_um
	[Vector2i(11, 11), Vector2i(8, 11), Vector2i(5, 11), Vector2i(2, 11)], # core_ur (reverse)
	[Vector2i(0, 12), Vector2i(3, 12), Vector2i(6, 12), Vector2i(9, 12)], # core_dl
	[Vector2i(1, 12), Vector2i(4, 12), Vector2i(7, 12), Vector2i(10, 12)], # core_dm
	[Vector2i(2, 12), Vector2i(5, 12), Vector2i(8, 12), Vector2i(11, 12)], # core_dr
	[Vector2i(0, 13), Vector2i(1, 13), Vector2i(2, 13), Vector2i(3, 13)], # gear1
	[Vector2i(1, 15), Vector2i(1, 15), Vector2i(2, 15), Vector2i(3, 15)], # gear2 (holds frame 0)
	[Vector2i(0, 16), Vector2i(1, 16), Vector2i(2, 16), Vector2i(3, 16)], # gear3
	[Vector2i(0, 14), Vector2i(1, 14), Vector2i(2, 14), Vector2i(3, 14)], # wall1
	[Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6)], # tele1_off
	[Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7)], # tele1_on
	[Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6)], # tele2_off
	[Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7)], # tele2_on
	[Vector2i(0, 17), Vector2i(3, 17), Vector2i(6, 17), Vector2i(9, 17)], # platform1_l
	[Vector2i(1, 17), Vector2i(4, 17), Vector2i(7, 17), Vector2i(10, 17)], # platform1_m
	[Vector2i(2, 17), Vector2i(5, 17), Vector2i(8, 17), Vector2i(11, 17)], # platform1_r
	[Vector2i(0, 18), Vector2i(2, 18), Vector2i(4, 18), Vector2i(6, 18)], # platform2_ul
	[Vector2i(1, 18), Vector2i(3, 18), Vector2i(5, 18), Vector2i(7, 18)], # platform2_ur
	[Vector2i(0, 19), Vector2i(2, 19), Vector2i(4, 19), Vector2i(6, 19)], # platform2_dl
	[Vector2i(1, 19), Vector2i(3, 19), Vector2i(5, 19), Vector2i(7, 19)], # platform2_dr
	[Vector2i(1, 20), Vector2i(3, 20), Vector2i(5, 20), Vector2i(7, 20)], # platform2_base
	[Vector2i(0, 21), Vector2i(2, 21), Vector2i(4, 21), Vector2i(6, 21)], # platform3_ul
	[Vector2i(1, 21), Vector2i(3, 21), Vector2i(5, 21), Vector2i(7, 21)], # platform3_ur
	[Vector2i(0, 22), Vector2i(2, 22), Vector2i(4, 22), Vector2i(6, 22)], # platform3_dl
	[Vector2i(1, 22), Vector2i(3, 22), Vector2i(5, 22), Vector2i(7, 22)], # platform3_dr
	[Vector2i(0, 23), Vector2i(2, 23), Vector2i(4, 23), Vector2i(6, 23)], # platform3_base
]

# ==========================================================================
# til_manaFortressOutsideFade animations (17 columns, 29 sequences × 4 frames)
# GMS2 tile ID → Godot atlas_coords: Vector2i(id % 17, id / 17)
# Extracted from GMS2: tileAnimationSpeed = 8 (7.5 fps)
# ==========================================================================
const ANIM_TIL_MANA_FORTRESS_FADE: Array = [
	[Vector2i(0, 9), Vector2i(4, 9), Vector2i(8, 9), Vector2i(12, 9)],
	[Vector2i(1, 9), Vector2i(5, 9), Vector2i(9, 9), Vector2i(13, 9)],
	[Vector2i(2, 9), Vector2i(6, 9), Vector2i(10, 9), Vector2i(14, 9)],
	[Vector2i(3, 9), Vector2i(7, 9), Vector2i(11, 9), Vector2i(15, 9)],
	[Vector2i(1, 10), Vector2i(5, 10), Vector2i(9, 10), Vector2i(13, 10)],
	[Vector2i(2, 10), Vector2i(6, 10), Vector2i(10, 10), Vector2i(14, 10)],
	[Vector2i(0, 11), Vector2i(4, 11), Vector2i(8, 11), Vector2i(12, 11)],
	[Vector2i(1, 11), Vector2i(5, 11), Vector2i(9, 11), Vector2i(13, 11)],
	[Vector2i(2, 11), Vector2i(6, 11), Vector2i(10, 11), Vector2i(14, 11)],
	[Vector2i(3, 11), Vector2i(7, 11), Vector2i(11, 11), Vector2i(15, 11)],
	[Vector2i(0, 12), Vector2i(4, 12), Vector2i(8, 12), Vector2i(12, 12)],
	[Vector2i(1, 12), Vector2i(5, 12), Vector2i(9, 12), Vector2i(13, 12)],
	[Vector2i(2, 12), Vector2i(6, 12), Vector2i(10, 12), Vector2i(14, 12)],
	[Vector2i(3, 12), Vector2i(7, 12), Vector2i(11, 12), Vector2i(15, 12)],
	[Vector2i(0, 13), Vector2i(4, 13), Vector2i(8, 13), Vector2i(12, 13)],
	[Vector2i(1, 13), Vector2i(5, 13), Vector2i(9, 13), Vector2i(13, 13)],
	[Vector2i(2, 13), Vector2i(6, 13), Vector2i(10, 13), Vector2i(14, 13)],
	[Vector2i(3, 13), Vector2i(7, 13), Vector2i(11, 13), Vector2i(15, 13)],
	[Vector2i(0, 14), Vector2i(1, 14), Vector2i(2, 14), Vector2i(3, 14)],
	[Vector2i(0, 15), Vector2i(1, 15), Vector2i(2, 15), Vector2i(3, 15)],
	[Vector2i(0, 16), Vector2i(1, 16), Vector2i(2, 16), Vector2i(3, 16)],
	[Vector2i(0, 17), Vector2i(2, 17), Vector2i(4, 17), Vector2i(6, 17)],
	[Vector2i(1, 17), Vector2i(3, 17), Vector2i(5, 17), Vector2i(7, 17)],
	[Vector2i(0, 18), Vector2i(2, 18), Vector2i(4, 18), Vector2i(6, 18)],
	[Vector2i(1, 18), Vector2i(3, 18), Vector2i(5, 18), Vector2i(7, 18)],
	[Vector2i(0, 19), Vector2i(2, 19), Vector2i(4, 19), Vector2i(6, 19)],
	[Vector2i(1, 19), Vector2i(3, 19), Vector2i(5, 19), Vector2i(7, 19)],
	[Vector2i(0, 20), Vector2i(2, 20), Vector2i(4, 20), Vector2i(6, 20)],
	[Vector2i(1, 20), Vector2i(3, 20), Vector2i(5, 20), Vector2i(7, 20)],
]
