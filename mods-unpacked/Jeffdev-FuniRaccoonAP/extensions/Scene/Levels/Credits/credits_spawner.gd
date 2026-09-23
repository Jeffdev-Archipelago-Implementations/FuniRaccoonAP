extends "res://Scene/Levels/Credits/credits_spawner.gd"

# The credits unlock Tony, which AP hands out itself.

var _ap_had_tony: bool

func _enter_tree() -> void:
	_ap_had_tony = Globals.save_file.unlocked_vehicles.has(SaveGame.vehicles.TONY)

func _exit_tree() -> void:
	if _ap_had_tony or not Globals.save_file.unlocked_vehicles.has(SaveGame.vehicles.TONY):
		return
	# The credits already saved with TONY in it, so rewrite the save too.
	Globals.save_file.unlocked_vehicles.erase(SaveGame.vehicles.TONY)
	Globals.save_game()
