extends "res://Scene/Objects/chicken/chicken_logic.gd"

func _on_chicken_pick_signal(player: PlayerScript) -> void:
	if not Globals.save_file.items_stored.has(item_tracker.item_id.CHICKEN):
		return
	super(player)
