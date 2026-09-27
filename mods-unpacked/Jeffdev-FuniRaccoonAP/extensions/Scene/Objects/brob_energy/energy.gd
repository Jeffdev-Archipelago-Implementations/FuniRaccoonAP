extends "res://Scene/Objects/brob_energy/energy.gd"

func _on_picked_up(_player) -> void:
	if not Globals.save_file.items_stored.has(item_tracker.item_id.BROB_ENERGY):
		return
	super(_player)
