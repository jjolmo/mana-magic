class_name SceneIntro
extends Node2D
## rom_intro auto-transition: waits briefly on black screen then goes to rom_start
## GMS2: rom_intro was a black splash screen before the main start room

var _timer: float = 0.0

func _process(delta: float) -> void:
	_timer += delta
	# Brief black screen (1 second), then transition to rom_start
	if _timer > 1.0:
		set_process(false)
		GameManager.change_map("rom_start")
