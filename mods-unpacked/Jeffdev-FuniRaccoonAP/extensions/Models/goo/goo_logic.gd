extends "res://Models/goo/goo_logic.gd"

func picked_up(player: PlayerScript) -> void:
	if not Globals.save_file.items_stored.has(item_tracker.item_id.GOO):
		return
	super(player)
