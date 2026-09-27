extends "res://Scene/Levels/cliffs_of_nowher/butterFLY.gd"

func change_player_gravity(player: PlayerScript) -> void:
	if not Globals.save_file.items_stored.has(item_tracker.item_id.BUTTERFLY):
		return
	super(player)
