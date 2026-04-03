class_name WeaponSystem
extends RefCounted
## Weapon type definitions and attack data - replaces drawWeaponAttack from GMS2

# Weapon configuration data
static func get_weapon_config(weapon_id: int) -> Dictionary:
	match weapon_id:
		Constants.Weapon.SWORD:
			return {
				"name": "sword",
				"sprite": "spr_weapon_sword",
				"attack_speed": 0.4,
				"timeout": 20.0 / 60.0,
				"hitbox_size": Vector2(24, 16),
				"combo_count": 3,
			}
		Constants.Weapon.AXE:
			return {
				"name": "axe",
				"sprite": "spr_weapon_axe",
				"attack_speed": 0.35,
				"timeout": 25.0 / 60.0,
				"hitbox_size": Vector2(28, 20),
				"combo_count": 3,
			}
		Constants.Weapon.SPEAR:
			return {
				"name": "spear",
				"sprite": "spr_weapon_spear",
				"attack_speed": 0.4,
				"timeout": 20.0 / 60.0,
				"hitbox_size": Vector2(12, 32),
				"combo_count": 3,
			}
		Constants.Weapon.JAVELIN:
			return {
				"name": "javelin",
				"sprite": "spr_weapon_javelin",
				"attack_speed": 0.5,
				"timeout": 25.0 / 60.0,
				"hitbox_size": Vector2(8, 40),
				"combo_count": 2,
				"projectile": true,
			}
		Constants.Weapon.BOW:
			return {
				"name": "bow",
				"sprite": "spr_weapon_bow",
				"attack_speed": 0.3,
				"timeout": 30.0 / 60.0,
				"hitbox_size": Vector2(8, 8),
				"combo_count": 1,
				"projectile": true,
			}
		Constants.Weapon.BOOMERANG:
			return {
				"name": "boomerang",
				"sprite": "spr_weapon_boomerang",
				"attack_speed": 0.4,
				"timeout": 20.0 / 60.0,
				"hitbox_size": Vector2(16, 16),
				"combo_count": 2,
				"projectile": true,
			}
		Constants.Weapon.WHIP:
			return {
				"name": "whip",
				"sprite": "spr_weapon_whip",
				"attack_speed": 0.35,
				"timeout": 25.0 / 60.0,
				"hitbox_size": Vector2(32, 8),
				"combo_count": 2,
			}
		Constants.Weapon.KNUCKLES:
			return {
				"name": "knucles",
				"sprite": "spr_weapon_knucles",
				"attack_speed": 0.4,
				"timeout": 20.0 / 60.0,
				"hitbox_size": Vector2(16, 16),
				"combo_count": 3,
			}
		_:
			return {
				"name": "none",
				"sprite": "spr_weapon_none",
				"attack_speed": 0.4,
				"timeout": 20.0 / 60.0,
				"hitbox_size": Vector2(16, 16),
				"combo_count": 1,
			}

static func get_weapon_sound(weapon_id: int) -> String:
	match weapon_id:
		Constants.Weapon.SWORD: return "snd_sword"
		Constants.Weapon.AXE: return "snd_axe"
		Constants.Weapon.SPEAR: return "snd_spear"
		Constants.Weapon.JAVELIN: return "snd_javelin"
		Constants.Weapon.BOW: return "snd_bow"
		Constants.Weapon.BOOMERANG: return "snd_boomerang"
		Constants.Weapon.WHIP: return "snd_whip"
		Constants.Weapon.KNUCKLES: return "snd_glove"
		_: return ""
