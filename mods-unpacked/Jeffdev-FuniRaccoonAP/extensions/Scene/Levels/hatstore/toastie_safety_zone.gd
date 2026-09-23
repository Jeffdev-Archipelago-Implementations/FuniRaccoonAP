extends "res://Scene/Levels/hatstore/toastie_safety_zone.gd"

# Repeatable, so the check can be sent on any visit.

func _ready() -> void:
	Globals.save_file.states_occurred.erase(flag_names.toastie_saved_hat)
	super()
