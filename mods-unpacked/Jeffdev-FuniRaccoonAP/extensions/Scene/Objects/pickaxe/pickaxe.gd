extends "res://Scene/Objects/pickaxe/pickaxe.gd"

func pick_axe(_player) -> void:
	if not Globals.save_file.items_stored.has(item_tracker.item_id.PICKAXE):
		return
	super(_player)
