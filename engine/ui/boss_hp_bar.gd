class_name BossHPBar
extends CanvasLayer
## Boss HP bar UI - displays a large health bar for boss creatures at top of screen
## GMS2: No explicit boss HP bar, but standard for SoM-style games

var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _bar_border: ColorRect
var _name_label: Label
var _boss: Node = null
var _target_fill: float = 1.0
var _current_fill: float = 1.0
var _visible_timer: float = 0.0
var _fade_alpha: float = 0.0

const BAR_WIDTH: int = 200
const BAR_HEIGHT: int = 8
const BAR_Y: int = 220  # Bottom of 240px viewport (240 - BAR_HEIGHT - margin)
const BAR_BORDER: int = 1
const FADE_IN_SPEED: float = 0.05
const FADE_OUT_SPEED: float = 0.02
const FILL_LERP_SPEED: float = 0.03

func _ready() -> void:
	layer = 90  # Above most UI, below fade

	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	# Boss name label (positioned above the bar)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2((get_viewport().get_visible_rect().size.x - BAR_WIDTH) / 2.0, BAR_Y - 14)
	_name_label.size = Vector2(BAR_WIDTH, 14)
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_name_label)

	# Bar border (dark outline)
	_bar_border = ColorRect.new()
	_bar_border.color = Color(0.1, 0.1, 0.1, 1.0)
	_bar_border.size = Vector2(BAR_WIDTH + BAR_BORDER * 2, BAR_HEIGHT + BAR_BORDER * 2)
	_bar_border.position = Vector2(
		(get_viewport().get_visible_rect().size.x - BAR_WIDTH) / 2.0 - BAR_BORDER,
		BAR_Y - BAR_BORDER
	)
	_bar_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_bar_border)

	# Bar background (dark red)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.2, 0.05, 0.05, 1.0)
	_bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_bg.position = Vector2(
		(get_viewport().get_visible_rect().size.x - BAR_WIDTH) / 2.0,
		BAR_Y
	)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_bar_bg)

	# Bar fill (red -> yellow gradient feel)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.8, 0.15, 0.1, 1.0)
	_bar_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_fill.position = _bar_bg.position
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_bar_fill)

	# Start hidden
	_set_bar_alpha(0.0)

func _process(_delta: float) -> void:
	_update_boss_tracking()
	_update_fill()
	_update_visibility()

func _update_boss_tracking() -> void:
	## Find and track the current boss
	if not is_instance_valid(_boss) or _boss.is_dead:
		_boss = null
		# Search for a boss in the scene
		var bosses := get_tree().get_nodes_in_group("bosses")
		for b in bosses:
			if is_instance_valid(b) and b is Creature and not b.is_dead:
				_boss = b
				if b.has_method("get") and b.get("display_name"):
					_name_label.text = b.display_name
				elif b.has_method("get") and b.get("mob_name"):
					_name_label.text = b.mob_name
				else:
					_name_label.text = "Boss"
				break

func _update_fill() -> void:
	## Update the HP bar fill amount
	if is_instance_valid(_boss):
		var hp: float = float(_boss.attribute.hp)
		var max_hp: float = float(_boss.attribute.maxHP)
		if max_hp > 0:
			_target_fill = clampf(hp / max_hp, 0.0, 1.0)
		else:
			_target_fill = 0.0
	else:
		_target_fill = 0.0

	# Smoothly lerp toward target
	_current_fill = lerpf(_current_fill, _target_fill, FILL_LERP_SPEED)

	# Update bar width
	_bar_fill.size.x = BAR_WIDTH * _current_fill

	# Color shift: green -> yellow -> red based on HP percentage
	if _current_fill > 0.5:
		_bar_fill.color = Color(0.8 * (1.0 - _current_fill) * 2, 0.8, 0.1, 1.0)
	else:
		_bar_fill.color = Color(0.8, 0.8 * _current_fill * 2, 0.1, 1.0)

func _update_visibility() -> void:
	## Fade in when boss is alive, fade out when dead/absent
	if is_instance_valid(_boss) and not _boss.is_dead:
		_fade_alpha = minf(_fade_alpha + FADE_IN_SPEED, 1.0)
	else:
		_fade_alpha = maxf(_fade_alpha - FADE_OUT_SPEED, 0.0)

	_set_bar_alpha(_fade_alpha)

func _set_bar_alpha(alpha: float) -> void:
	_bar_border.modulate.a = alpha
	_bar_bg.modulate.a = alpha
	_bar_fill.modulate.a = alpha
	_name_label.modulate.a = alpha
