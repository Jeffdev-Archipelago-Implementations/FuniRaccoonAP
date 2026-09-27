extends "res://Scene/Levels/museum/the_museum.gd"

const MUSEUM_PIECE_SCRIPT := "res://Scene/Levels/museum/item_museum.gd"

func _ready() -> void:
	super()
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	for piece in get_children():
		if piece.get_script() == null or piece.get_script().resource_path != MUSEUM_PIECE_SCRIPT:
			continue
		if not is_instance_valid(piece.item) or not is_instance_valid(piece.interact_area):
			continue
		var displayed: bool = piece.item.get_parent() != null
		if displayed == ap_stored.has(piece.item.obj_id):
			continue
		if displayed:
			piece.item.queue_free()
			piece.interact_area.queue_free()
		else:
			_ap_display_piece(piece)

func _ap_display_piece(piece: Node) -> void:
	var area: InteractArea = piece.interact_area.duplicate()
	piece.add_child(area)
	piece.interact_area = area
	area.interacted.connect(piece.dialogue_interact.dialogue_activate)
	area.exited.connect(piece.dialogue_interact.dialogue_remove)

	piece.item = load(piece.item_uid).instantiate()
	piece.stop_evil_items()
	piece.spawn.add_child(piece.item)
	piece.item.position.y = piece.item.height / 2
