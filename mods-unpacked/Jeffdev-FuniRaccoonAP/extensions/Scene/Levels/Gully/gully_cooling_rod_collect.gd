extends "res://Scene/Levels/Gully/gully_cooling_rod_collect.gd"

func cooling_rod_logic(body: Node3D) -> void:
	if body is InteractData:
		var stored: Array = Globals.save_file.items_stored
		if body.obj_id == item_tracker.item_id.COOLING_ROD_FRIDGE_KING and not stored.has(item_tracker.item_id.COOLING_ROD_FRIDGE_KING):
			return
		if body.obj_id == item_tracker.item_id.COOLING_ROD_PLIMBO and not stored.has(item_tracker.item_id.COOLING_ROD_PLIMBO):
			return
	super(body)
