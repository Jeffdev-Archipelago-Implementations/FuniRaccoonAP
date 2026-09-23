extends "res://Scene/Levels/hub_world/item_spawner.gd"

func _ready() -> void:
	if not Globals.save_file.is_the_future:
		_ap_spawn_items()

func _ap_spawn_items() -> void:
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	var items: Array = []
	if ap_stored.size() < max_item_spawn:
		items = ap_stored.duplicate()
	else:
		var attempts: int = 0
		while items.size() < max_item_spawn and attempts < ap_stored.size() * 3:
			var ran_item = ap_stored.pick_random()
			if not items.has(ran_item):
				items.append(ran_item)
			attempts += 1
	for item_id in items:
		if item_id == item_tracker.item_id.KEI_TRUCK:
			continue
		var item_inst: InteractData = ModLoader.get_node("Jeffdev-FuniRaccoonAP").instantiate_item(item_id)
		if item_inst == null:
			continue
		item_inst.global_position = global_position
		item_inst.freeze = false
		add_child(item_inst)
		item_inst.apply_central_impulse(Vector3.UP * 10)
		await get_tree().create_timer(0.1).timeout
