extends "res://Scene/Levels/BlimboVillage/open_door.gd"

func open_door(obj: InteractData) -> void:
	if obj.obj_id == item_tracker.item_id.MINES_KEY and not Globals.save_file.items_stored.has(item_tracker.item_id.MINES_KEY):
		return
	super(obj)
