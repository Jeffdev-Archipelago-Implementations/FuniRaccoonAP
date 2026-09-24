extends "res://Scene/Levels/hatstore/toastie_safety_zone.gd"

func _ready() -> void:
	# This simply just makes it repeatable
	Globals.save_file.states_occurred.erase(flag_names.toastie_saved_hat)
	super()
