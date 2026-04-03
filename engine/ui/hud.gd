class_name HUD
extends Control
## Player HUD - replaces oHud from GMS2
## Uses original GMS2 sprite artwork scaled from 1281x720 GUI to 427x240 viewport.
## Draw order: back → ring gauge → HP/MP bars → face → front overlay → text

# Scale factor: GMS2 GUI resolution (1281x720) → Godot viewport (427x240)
const SCALE: float = 1.0 / 3.0

# GMS2 anchor coordinates (at 1281x720 resolution)
const HUD_X: float = 15.0
const HUD_Y: float = 30.0

# Element offsets relative to anchor (GMS2 space)
const FACE_OX: float = 56.0
const FACE_OY: float = -26.0
const FRONT_OX: float = 48.0
const FRONT_OY: float = 12.0
const HP_BAR_OX: float = 144.0
const HP_BAR_OY: float = 18.0
const HP_BAR_W: float = 196.0
const HP_BAR_H: float = 8.0
const MP_BAR_OX: float = 151.0
const MP_BAR_OY: float = 32.0
const MP_BAR_W: float = 87.0
const MP_BAR_H: float = 4.0
const HP_TEXT_OX: float = 300.0
const HP_TEXT_OY: float = 10.0
const MP_TEXT_OX: float = 350.0
const MP_TEXT_OY: float = 30.0
const RING_OX: float = 94.0
const RING_OY: float = 39.0
const RING_RADIUS: float = 39.0
const RING_START_DEG: float = -36.0
const RING_ARC_DEG: float = 124.0
const WPN_LV_OX: float = 15.0
const WPN_LV_OY: float = 38.0
const OH_TEXT_OX: float = 20.0
const OH_TEXT_OY: float = 40.0
const CTRL_TEXT_OX: float = 147.0
const CTRL_TEXT_OY: float = 39.0

# Colors (GMS2 defineConstants)
const COLOR_YELLOW := Color(1.0, 1.0, 0.0)       # Weapon gauge ring
const COLOR_TURQUOISE := Color(0.0, 0.847, 1.0)   # Overheat ring RGB(0,216,255)

# Native bitmap font size (font_sitka.fnt: size=12, lineHeight=22)
const FONT_SIZE: int = 12

# Preloaded HUD sprites
var tex_back: Texture2D = preload("res://assets/sprites/spr_artBattleHud_back/hud_back.png")
var tex_front: Texture2D = preload("res://assets/sprites/spr_artBattleHud_front/hud_front.png")
var tex_face_randi: Texture2D = preload("res://assets/sprites/spr_artBattleHud_face/face_randi.png")
var tex_face_purim: Texture2D = preload("res://assets/sprites/spr_artBattleHud_face/face_purim.png")
var tex_face_popoie: Texture2D = preload("res://assets/sprites/spr_artBattleHud_face/face_popoie.png")
var hud_font: Font = preload("res://assets/fonts/font_sitka.fnt")

var face_map: Dictionary = {}
var hud_alpha: float = 1.0
var visible_hud: bool = true
## GMS2: imageAlpha fade speed = 0.1 per frame (60fps)
var _hud_fading: int = 0  # 0=none, 1=fading in, -1=fading out
const _HUD_FADE_SPEED: float = 0.1

## Status effect display names for debug overlay
const STATUS_NAMES: Dictionary = {
	Constants.Status.FROZEN: "FROZEN",
	Constants.Status.PETRIFIED: "PETRIFY",
	Constants.Status.CONFUSED: "CONFUSE",
	Constants.Status.POISONED: "POISON",
	Constants.Status.BALLOON: "BALLOON",
	Constants.Status.ENGULFED: "ENGULF",
	Constants.Status.FAINT: "FAINT",
	Constants.Status.SILENCED: "SILENCE",
	Constants.Status.ASLEEP: "SLEEP",
	Constants.Status.SNARED: "SNARE",
	Constants.Status.PYGMIZED: "PYGMIZE",
	Constants.Status.TRANSFORMED: "TRANSFRM",
	Constants.Status.BARREL: "BARREL",
	Constants.Status.SPEED_UP: "SPD+",
	Constants.Status.SPEED_DOWN: "SPD-",
	Constants.Status.ATTACK_UP: "ATK+",
	Constants.Status.ATTACK_DOWN: "ATK-",
	Constants.Status.DEFENSE_UP: "DEF+",
	Constants.Status.DEFENSE_DOWN: "DEF-",
	Constants.Status.MAGIC_UP: "MAG+",
	Constants.Status.MAGIC_DOWN: "MAG-",
	Constants.Status.HIT_UP: "HIT+",
	Constants.Status.HIT_DOWN: "HIT-",
	Constants.Status.EVADE_UP: "EVA+",
	Constants.Status.EVADE_DOWN: "EVA-",
	Constants.Status.WALL: "WALL",
	Constants.Status.LUCID_BARRIER: "BARRIER",
	Constants.Status.BUFF_WEAPON_UNDINE: "S:UNDINE",
	Constants.Status.BUFF_WEAPON_GNOME: "S:GNOME",
	Constants.Status.BUFF_WEAPON_SYLPHID: "S:SYLPH",
	Constants.Status.BUFF_WEAPON_SALAMANDO: "S:SALA",
	Constants.Status.BUFF_WEAPON_SHADE: "S:SHADE",
	Constants.Status.BUFF_WEAPON_LUNA: "S:LUNA",
	Constants.Status.BUFF_WEAPON_LUMINA: "S:LUMINA",
	Constants.Status.BUFF_WEAPON_DRYAD: "S:DRYAD",
	Constants.Status.BUFF_MANA_MAGIC: "MANA",
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Use linear filtering for HD HUD art (not pixel-art)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Map character_id → face portrait texture
	face_map[Constants.CharacterId.RANDI] = tex_face_randi
	face_map[Constants.CharacterId.PURIM] = tex_face_purim
	face_map[Constants.CharacterId.POPOIE] = tex_face_popoie

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			GameManager.show_debug = not GameManager.show_debug

func _process(_delta: float) -> void:
	# GMS2: oHud Step_0 - gradual alpha fade in/out (0.1 per frame at 60fps)
	if _hud_fading == -1:
		hud_alpha -= _HUD_FADE_SPEED * _delta * 60.0
		if hud_alpha <= 0.0:
			hud_alpha = 0.0
			_hud_fading = 0
			visible_hud = false
	elif _hud_fading == 1:
		hud_alpha += _HUD_FADE_SPEED * _delta * 60.0
		if hud_alpha >= 1.0:
			hud_alpha = 1.0
			_hud_fading = 0
	queue_redraw()

func _draw() -> void:
	if not visible_hud:
		return
	var total: int = GameManager.total_players
	if total == 0:
		return
	for i in range(total):
		var player: Node = GameManager.get_player(i)
		if is_instance_valid(player) and player is Actor:
			var offset_x: float = (size.x / float(total)) * float(i)
			_draw_player_hud(player as Actor, offset_x)

	# Debug status overlay: show active statuses above each player's head
	if GameManager.show_debug:
		_draw_debug_status_overlay()

func _draw_player_hud(player: Actor, offset_x: float) -> void:
	# Transform: per-player horizontal offset + scale GMS2→viewport
	# draw_set_transform places origin at (offset_x, 0) then scales all
	# subsequent draw coordinates by SCALE (1/3).
	draw_set_transform(Vector2(offset_x, 0.0), 0.0, Vector2(SCALE, SCALE))
	var ac := Color(1, 1, 1, hud_alpha)

	# 1. Background sprite
	draw_texture(tex_back, Vector2(HUD_X, HUD_Y), ac)

	# 2. Weapon gauge ring OR overheat ring (drawn behind face/front)
	var rcx: float = HUD_X + RING_OX
	var rcy: float = HUD_Y + RING_OY
	if player.weapon_gauge > 0 and not player.overheating:
		# Weapon gauge ring (yellow) - thickness scales with weapon level
		var wlv: int = player.equipment_current_level.get(
			player.get_weapon_name(), 1)
		var thickness: float = float(wlv * 2 + 10)
		_draw_ring(rcx, rcy, RING_RADIUS, thickness,
			int(player.weapon_gauge_max_base), int(player.weapon_gauge),
			RING_START_DEG, RING_ARC_DEG, -1, Color(COLOR_YELLOW, hud_alpha))
		# Weapon level text (GMS2: fa_top alignment)
		if player.show_weapon_level:
			_draw_text_top("Lv " + str(wlv),
				HUD_X + WPN_LV_OX, HUD_Y + WPN_LV_OY)
	elif player.overheating:
		# Overheat ring (turquoise) - fixed thickness 10
		# Ring fills from 0→100 as cooldown progresses
		var fill: int = int(player.attribute.overheat)
		_draw_ring(rcx, rcy, RING_RADIUS, 10.0, 100, fill,
			RING_START_DEG, RING_ARC_DEG, -1, Color(COLOR_TURQUOISE, hud_alpha))
		# Overheat % text
		var pct: int = ceili(player.attribute.overheat)
		_draw_text_top(str(pct) + " %",
			HUD_X + OH_TEXT_OX, HUD_Y + OH_TEXT_OY)

	# 3. HP bar (red fill on black background)
	_draw_bar(HUD_X + HP_BAR_OX, HUD_Y + HP_BAR_OY, HP_BAR_W, HP_BAR_H,
		player.attribute.hpPercent / 100.0, Color.RED)

	# 4. MP bar (blue fill on black background)
	_draw_bar(HUD_X + MP_BAR_OX, HUD_Y + MP_BAR_OY, MP_BAR_W, MP_BAR_H,
		player.attribute.mpPercent / 100.0, Color.BLUE)

	# 5. Face portrait (subimage selected by character_id)
	var ftex: Texture2D = face_map.get(player.character_id, tex_face_randi)
	draw_texture(ftex, Vector2(HUD_X + FACE_OX, HUD_Y + FACE_OY), ac)

	# 6. Front overlay (frame border drawn over bars and face)
	draw_texture(tex_front, Vector2(HUD_X + FRONT_OX, HUD_Y + FRONT_OY), ac)

	# 7. HP/MP text (GMS2: fa_middle vertical alignment)
	var hp_text: String = str(player.attribute.hp) + "/" + str(player.attribute.maxHP)
	var mp_text: String = str(player.attribute.mp) + "/" + str(player.attribute.maxMP)
	_draw_text_mid(hp_text, HUD_X + HP_TEXT_OX, HUD_Y + HP_TEXT_OY)
	_draw_text_mid(mp_text, HUD_X + MP_TEXT_OX, HUD_Y + MP_TEXT_OY)

	# 8. Control type indicator (GMS2: drawPlayerHud - shows "KB" for keyboard player)
	if player.player_controlled:
		_draw_text_top("KB", HUD_X + CTRL_TEXT_OX, HUD_Y + CTRL_TEXT_OY)

	# Reset transform for next player / other draw calls
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- Drawing helpers ---

## Draw text with GMS2 fa_top alignment (y = top of text)
func _draw_text_top(text: String, x: float, y: float,
		color: Color = Color.WHITE) -> void:
	var font: Font = hud_font if hud_font else ThemeDB.fallback_font
	var ascent: float = font.get_ascent(FONT_SIZE)
	draw_string(font, Vector2(x, y + ascent), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(color, hud_alpha))

## Draw text with GMS2 fa_middle alignment (y = vertical center of text)
func _draw_text_mid(text: String, x: float, y: float,
		color: Color = Color.WHITE) -> void:
	var font: Font = hud_font if hud_font else ThemeDB.fallback_font
	var ascent: float = font.get_ascent(FONT_SIZE)
	var height: float = font.get_height(FONT_SIZE)
	# fa_middle: text center at y → baseline = y + ascent - height/2
	draw_string(font, Vector2(x, y + ascent - height * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(color, hud_alpha))

## Draw a health/mana bar (black background + colored fill)
func _draw_bar(x: float, y: float, w: float, h: float,
		pct: float, fill_color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, hud_alpha))
	if pct > 0.0:
		draw_rect(Rect2(x, y, w * clampf(pct, 0.0, 1.0), h),
			Color(fill_color, hud_alpha))

## Draw a ring arc gauge - port of GMS2 scr_health_ring
## Builds a ring-sector polygon from outer arc + inner arc (reversed)
func _draw_ring(cx: float, cy: float, radius: float, thickness: float,
		max_seg: int, segments: int, start_deg: float, arc_deg: float,
		direction: int, color: Color) -> void:
	if segments <= 0 or max_seg <= 0:
		return
	segments = mini(segments, max_seg)
	var step: float = arc_deg / float(max_seg) * PI / 180.0
	var start: float = start_deg * PI / 180.0
	var outer: float = radius + thickness
	# Build ring polygon: outer arc forward, then inner arc backward
	var pts := PackedVector2Array()
	for s in range(segments + 1):
		var a: float = start + float(s * direction) * step
		pts.append(Vector2(cx + cos(a) * outer, cy - sin(a) * outer))
	for s in range(segments, -1, -1):
		var a: float = start + float(s * direction) * step
		pts.append(Vector2(cx + cos(a) * radius, cy - sin(a) * radius))
	if pts.size() >= 3:
		draw_colored_polygon(pts, color)

# --- Public API ---

func show_hud() -> void:
	## GMS2: showHud() - gradual fade in (imageAlpha += 0.1/frame)
	visible_hud = true
	_hud_fading = 1

func hide_hud() -> void:
	## GMS2: hideHud() - gradual fade out (imageAlpha -= 0.1/frame)
	_hud_fading = -1


# --- Debug Status Overlay ---

func _draw_debug_status_overlay() -> void:
	## GMS2: drawAllPlayerStatus - shows state name + active statuses above each player's head
	var vp := get_viewport()
	if not vp:
		return
	var ct: Transform2D = vp.get_canvas_transform()
	var font: Font = hud_font if hud_font else ThemeDB.fallback_font
	var font_size: int = 8

	for i in range(GameManager.total_players):
		var player: Node = GameManager.get_player(i)
		if not is_instance_valid(player) or not (player is Actor):
			continue
		var actor: Actor = player as Actor

		# Convert world position to screen position
		var world_pos: Vector2 = actor.global_position + Vector2(0, -30)
		var screen_pos: Vector2 = ct * world_pos

		# Build status text: state name + active statuses
		var lines: PackedStringArray = PackedStringArray()
		# Line 1: current state name
		if actor.state_machine_node:
			lines.append(actor.state_machine_node.current_state_name)
		# Line 2+: active status effects with remaining time
		for s in range(1, Constants.STATUS_COUNT):
			if s < actor.status_effects.size() and actor.status_effects[s]:
				var sname: String = STATUS_NAMES.get(s, "?%d" % s)
				var timer: float = actor.status_timers[s] if s < actor.status_timers.size() else 0.0
				var secs: String = "%.1fs" % timer if timer > 0.0 else ""
				lines.append("%s %s" % [sname, secs])

		if lines.is_empty():
			continue

		# Measure text for background box
		var line_h: float = font.get_height(font_size) + 1
		var max_w: float = 0.0
		for line in lines:
			max_w = maxf(max_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		var box_h: float = line_h * lines.size() + 4
		var box_w: float = max_w + 6
		var box_x: float = screen_pos.x - box_w * 0.5
		var box_y: float = screen_pos.y - box_h

		# Draw background
		draw_rect(Rect2(box_x, box_y, box_w, box_h), Color(0, 0, 0, 0.7))

		# Draw text lines
		var ascent: float = font.get_ascent(font_size)
		for j in range(lines.size()):
			var tx: float = box_x + 3
			var ty: float = box_y + 2 + ascent + line_h * float(j)
			var col: Color = Color.YELLOW if j == 0 else Color.WHITE
			draw_string(font, Vector2(tx, ty), lines[j],
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
