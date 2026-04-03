extends Node
## Converted from defineConstants.gml - All game constants

# Colors
const COLOR_TURQUOISE := Color(0.0, 0.8, 0.8)
const COLOR_GOLD := Color(1.0, 0.84, 0.0)
const COLOR_SHADOW := Color(0.16, 0.16, 0.16)
const COLOR_YELLOW := Color(1.0, 1.0, 0.0)

# Input Types
enum InputType { KEYBOARD, GAMEPAD, AI, MULTI }

# Attributes
enum Attribute {
	STRENGTH, CONSTITUTION, AGILITY, LUCK, INTELLIGENCE, WISDOM,
	MAX_HP, MAX_MP, HP, MP, CRITICAL_RATE,
	HP_MULTIPLIER_1, HP_MULTIPLIER_2, HP_MULTIPLIER_EXP,
	MP_MULTIPLIER_1, MP_MULTIPLIER_2, MP_DIVISOR,
	IDENTIFIER,
	MAGIC_WEAKNESS, MAGIC_PROTECTION, MAGIC_ATUNEMENT
}

# Attack Types
enum AttackType { WEAPON, MAGIC, ELEMENTAL, ULTIMATE, FAINT, DRAIN, ETEREAL, DRAIN_MAGIC, DRAIN_HEALTH }

# Weapon Attack Types
enum WeaponAttackType { PIERCE, SLASH, SWING, BOW, THROW }

# Character IDs (order matches party array: Randi=0, Purim=1, Popoie=2)
enum CharacterId { RANDI, PURIM, POPOIE }

# Status Effects
enum Status {
	NONE,
	FROZEN, PETRIFIED, CONFUSED, POISONED, BALLOON, ENGULFED, FAINT,
	SILENCED, ASLEEP, SNARED, PYGMIZED, TRANSFORMED, BARREL,
	SPEED_UP, SPEED_DOWN,
	ATTACK_UP, ATTACK_DOWN,
	DEFENSE_UP, DEFENSE_DOWN,
	MAGIC_UP, MAGIC_DOWN,
	HIT_UP, HIT_DOWN,
	EVADE_UP, EVADE_DOWN,
	WALL, LUCID_BARRIER,
	BUFF_WEAPON_UNDINE, BUFF_WEAPON_GNOME, BUFF_WEAPON_SYLPHID, BUFF_WEAPON_SALAMANDO,
	BUFF_WEAPON_SHADE, BUFF_WEAPON_LUNA, BUFF_WEAPON_LUMINA, BUFF_WEAPON_DRYAD,
	BUFF_MANA_MAGIC,
}

const STATUS_BUFF_START := Status.SPEED_UP
const STATUS_COUNT := 37

# Magic Types (GMS2: MAGIC_NONE=0, MAGIC_BLACK=1, MAGIC_WHITE=2)
const MAGIC_NONE := 0
const MAGIC_BLACK := 1
const MAGIC_WHITE := 2
const MAGIC_ALL := 3  # Son of Mana: access to all magic (black + white)

# Elements / Deities
enum Element { UNDINE, GNOME, SYLPHID, SALAMANDO, SHADE, LUNA, LUMINA, DRYAD }
const ELEMENT_COUNT := 8

# Weapons
enum Weapon { SWORD, AXE, SPEAR, JAVELIN, BOW, BOOMERANG, WHIP, KNUCKLES, NONE }
const WEAPON_COUNT := 9

# Equipment Types
enum EquipmentType { WEAPON, HEAD, ACCESSORIES, BODY }

# Menu Sections
enum MenuSection { ITEM, MAGIC, WEAPON, STATUS, ETC }
enum MenuSubsection {
	ITEMS, SKILLS, WEAPONS,
	GEAR_HEAD, GEAR_ACCESSORIES, GEAR_BODY,
	STATUS_VIEW, ACTION_GRID, CONTROLLER_EDIT, WINDOW_EDIT
}

# Skill Types
enum SkillType { DAMAGE, STATUS_BUFF, STATUS_DEBUFF, HEAL, DRAIN, SUMMON }

# Target Types
enum TargetType { ALLY, ENEMY, ALL_ALLIES, ALL_ENEMIES, SELF }

# Camera Actions
enum CameraAction { NONE, WALK, MOVE_MOTION, SHAKE }

# Camera Shake Modes
enum ShakeMode { UP_DOWN, LEFT_RIGHT, BOTH }

# Dialog Anchors
enum DialogAnchor { TOP, MIDDLE, BOTTOM }

# Game Actions
enum GameAction { NONE, FADE_IN, FADE_OUT, FLASH, BLEND_ON, BLEND_OFF }

# Facing Directions
enum Facing { UP = 0, RIGHT = 1, DOWN = 2, LEFT = 3 }

# Depths (converted to z_index ranges)
const DEPTH_ANIMATIONS := -100
const DEPTH_CREATURES := -50
const DEPTH_TEXTURES := 0
const DEPTH_GUI := -200

# Battle Config
const MAX_HITS_STACKABLE := 5
const DAMAGE_LIMIT := 999
const POISON_TIMER := 120
const SPEED_DIVISOR_WALK := 2
const SPEED_DIVISOR_RUN := 1.5

# Party/Level Config
const MAX_ACTORS_ON_SCREEN := 6
const GUI_SCALE := 3
const SHOP_SELL_DIVISOR := 2
const EXP_MULTIPLIER := 50
const MAX_LEVEL := 99
const MAX_EQUIPMENT_LEVEL := 100

# Camera Speeds
const CAMERA_SPEED_NORMAL := 3.0
const CAMERA_SPEED_RUN := 6.0

# Dialog Config
const DIALOG_SPEED_SLOW := 0.5
const DIALOG_SPEED_NORMAL := 1.0
const DIALOG_SPEED_FAST := 2.0
const DIALOG_MAX_LINES := 3

# Markers
const DIALOG_STOP := "¬"
const DIALOG_WAIT := "~"
