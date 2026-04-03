@tool
extends VBoxContainer

## Miscellaneous editor - shows read-only reference info about game constants,
## enemy classes, attribute list, and editable dialog settings.

const DIALOG_SETTINGS_FILE := "dialog_settings.json"
const DIALOG_SPEED_NAMES := ["Slow", "Normal", "Fast"]

var _tab: TabContainer

# Dialog settings fields
var _f_dialog_speed: OptionButton
var _f_dialog_bg: SpinBox
var _f_dialog_border: SpinBox
var _f_dialog_color: ColorPickerButton

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_tab = TabContainer.new()
	_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tab)

	_build_dialog_settings_tab()
	_build_enemy_classes_tab()
	_build_attribute_list_tab()
	_build_constants_tab()

func _build_enemy_classes_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Enemy Classes"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var data := ManaJsonHelper.load_json("enemy_classes.json")
	var header := Label.new()
	header.text = "Enemy Class Definitions (%d classes)" % data.size()
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	for entry in data:
		var lbl := Label.new()
		lbl.text = "[%s] %s — STR:%s CON:%s AGI:%s LCK:%s INT:%s WIS:%s | EXP:%s Money:%s" % [
			entry.get("id", "?"), entry.get("name", "?"),
			entry.get("base_strength", "?"), entry.get("base_constitution", "?"),
			entry.get("base_agility", "?"), entry.get("base_luck", "?"),
			entry.get("base_intelligence", "?"), entry.get("base_wisdom", "?"),
			entry.get("base_experience", "?"), entry.get("base_money", "?"),
		]
		vbox.add_child(lbl)

func _build_attribute_list_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Attributes"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var data := ManaJsonHelper.load_json("attributeList.json")
	var header := Label.new()
	header.text = "Attribute List (%d attributes)" % data.size()
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	for entry in data:
		var lbl := Label.new()
		lbl.text = "[%s] %s" % [entry.get("id", "?"), entry.get("description", entry.get("name", "?"))]
		vbox.add_child(lbl)

func _build_constants_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Game Constants"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var header := Label.new()
	header.text = "Game Constants Reference"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	var constants := [
		"--- Status Effects ---",
		"1=FROZEN, 2=PETRIFIED, 3=CONFUSED, 4=POISONED, 5=BALLOON",
		"6=ENGULFED, 7=FAINT, 8=SILENCED, 9=ASLEEP, 10=SNARED",
		"11=PYGMIZED, 12=TRANSFORMED, 13=BARREL",
		"14=SPEED_UP, 15=SPEED_DOWN, 16=ATTACK_UP, 17=ATTACK_DOWN",
		"18=DEFENSE_UP, 19=DEFENSE_DOWN, 20=MAGIC_UP, 21=MAGIC_DOWN",
		"22=HIT_UP, 23=HIT_DOWN, 24=EVADE_UP, 25=EVADE_DOWN",
		"26=WALL, 27=LUCID_BARRIER",
		"28-35=BUFF_WEAPON_* (per deity), 36=BUFF_MANA_MAGIC",
		"",
		"--- Elements/Deities ---",
		"0=Undine, 1=Gnome, 2=Sylphid, 3=Salamando",
		"4=Shade, 5=Luna, 6=Lumina, 7=Dryad",
		"",
		"--- Weapon Types ---",
		"SWORD, AXE, SPEAR, JAVELIN, BOW, BOOMERANG, WHIP, KNUCKLES, NONE",
		"",
		"--- Equipment Kinds ---",
		"0=Weapon, 1=Head, 2=Accessories, 3=Body",
		"",
		"--- Skill Types ---",
		"DAMAGE, STATUS_BUFF, STATUS_DEBUFF, HEAL, DRAIN, SUMMON",
		"",
		"--- Target Types ---",
		"ALLY, ENEMY, ALL_ALLIES, ALL_ENEMIES, SELF",
		"",
		"--- Characters ---",
		"RANDI=0, PURIM=1, POPOIE=2",
		"",
		"--- Game Limits ---",
		"MAX_LEVEL=99, MAX_EQUIPMENT_LEVEL=100",
		"DAMAGE_LIMIT=999, ITEM_MAX_QUANTITY=99",
		"WEAPON_GAUGE_MAX=110, MAX_COMBO=3",
	]
	for line in constants:
		var lbl := Label.new()
		lbl.text = line
		if line.begins_with("---"):
			lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		vbox.add_child(lbl)

# --- Dialog Settings Tab (editable) ---

func _build_dialog_settings_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Dialog Settings"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var header := Label.new()
	header.text = "Default Dialog Configuration"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	vbox.add_child(margin)

	var form := GridContainer.new()
	form.columns = 2
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 8)
	margin.add_child(form)

	# Dialog Speed
	form.add_child(_make_label("Text Speed:"))
	_f_dialog_speed = OptionButton.new()
	for name in DIALOG_SPEED_NAMES:
		_f_dialog_speed.add_item(name)
	_f_dialog_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_f_dialog_speed.item_selected.connect(_on_dialog_setting_changed)
	form.add_child(_f_dialog_speed)

	# Background index
	form.add_child(_make_label("Background Style:"))
	_f_dialog_bg = SpinBox.new()
	_f_dialog_bg.min_value = 0
	_f_dialog_bg.max_value = 10
	_f_dialog_bg.step = 1
	_f_dialog_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_f_dialog_bg.value_changed.connect(_on_dialog_setting_changed_val)
	form.add_child(_f_dialog_bg)

	# Border index
	form.add_child(_make_label("Border Style:"))
	_f_dialog_border = SpinBox.new()
	_f_dialog_border.min_value = 0
	_f_dialog_border.max_value = 10
	_f_dialog_border.step = 1
	_f_dialog_border.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_f_dialog_border.value_changed.connect(_on_dialog_setting_changed_val)
	form.add_child(_f_dialog_border)

	# Color
	form.add_child(_make_label("Background Color:"))
	_f_dialog_color = ColorPickerButton.new()
	_f_dialog_color.custom_minimum_size = Vector2(60, 30)
	_f_dialog_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_f_dialog_color.edit_alpha = false
	_f_dialog_color.color_changed.connect(_on_dialog_color_changed)
	form.add_child(_f_dialog_color)

	# Load current values
	_load_dialog_settings()

func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = 140
	return lbl

func _load_dialog_settings() -> void:
	var data := ManaJsonHelper.load_json_dict(DIALOG_SETTINGS_FILE)
	_f_dialog_speed.selected = clampi(int(data.get("dialog_speed_index", 0)), 0, DIALOG_SPEED_NAMES.size() - 1)
	_f_dialog_bg.value = int(data.get("dialog_background_index", 0))
	_f_dialog_border.value = int(data.get("dialog_border_index", 0))
	_f_dialog_color.color = Color(
		float(data.get("dialog_color_r", 0.0)),
		float(data.get("dialog_color_g", 0.0)),
		float(data.get("dialog_color_b", 0.5)),
	)

func _save_dialog_settings() -> void:
	var data := {
		"dialog_speed_index": _f_dialog_speed.selected,
		"dialog_background_index": int(_f_dialog_bg.value),
		"dialog_border_index": int(_f_dialog_border.value),
		"dialog_color_r": _f_dialog_color.color.r,
		"dialog_color_g": _f_dialog_color.color.g,
		"dialog_color_b": _f_dialog_color.color.b,
	}
	ManaJsonHelper.save_json_dict(DIALOG_SETTINGS_FILE, data)

func _on_dialog_setting_changed(_index: int) -> void:
	_save_dialog_settings()

func _on_dialog_setting_changed_val(_value: float) -> void:
	_save_dialog_settings()

func _on_dialog_color_changed(_color: Color) -> void:
	_save_dialog_settings()
