extends "res://Scene/Levels/Gully/orb_store.gd"

func show_orb_store() -> void:
	if not Globals.save_file.items_stored.has(item_tracker.item_id.ORB):
		return
	super()
