extends "res://Scene/Objects/atm/ATMLogic.gd"

func all_items() -> void:
	item_list.clear()

	for i in range(10):
		item_list.add_item("", EMPTY_ICON, false)

	for item_id in Globals.save_file.get_meta("ap_stored_items", []):
		var item: InteractData = ModLoader.get_node("Jeffdev-FuniRaccoonAP").instantiate_item(item_id)
		if item == null:
			continue
		item_list.add_item(item.obj_name, item.hud_icon)
		item.queue_free()

	item_list.sort_items_by_text()

	await get_tree().create_timer(0.1).timeout

	item_list.get_v_scroll_bar().ratio = 0.5

	for i in range(10):
		item_list.add_item("", EMPTY_ICON, false)
