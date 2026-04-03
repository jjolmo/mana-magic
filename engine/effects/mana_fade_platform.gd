class_name ManaFadePlatform
extends Sprite2D
## Mana Fortress outside fade platform - replaces oManaFadePlatform from GMS2
## Starts invisible, fades in during Mana Beast boss explosion.
## Controlled externally by BossExplosion._process_mana_beast()

var _fading_in: bool = false
var _fade_speed: float = 0.005  # GMS2: image_alpha += 0.005 per tick (at 60fps)


func _ready() -> void:
	# Load fade platform texture (253x154, origin 0,0)
	var tex: Texture2D = load("res://assets/sprites/spr_manaFortressOutsideFade/fade_platform.png") as Texture2D
	if tex:
		texture = tex
	visible = false
	# Depth 300 in GMS2 → high z_index behind other things but above background
	z_index = -50


func start_fade_in() -> void:
	## Called by BossExplosion at tick 10 of Mana Beast explosion
	modulate.a = 0.0
	visible = true
	_fading_in = true


func _process(delta: float) -> void:
	if _fading_in:
		if modulate.a < 1.0:
			modulate.a += _fade_speed * delta * 60.0
		else:
			modulate.a = 1.0
			_fading_in = false
