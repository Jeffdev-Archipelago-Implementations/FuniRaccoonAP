extends "res://Scene/Objects/fridge/fridge_logic.gd"

func key_collected(object: InteractData) -> void:
	if object.obj_id == item_tracker.item_id.FRIDGE_KEY and not Globals.save_file.items_stored.has(item_tracker.item_id.FRIDGE_KEY):
		return
	super(object)
