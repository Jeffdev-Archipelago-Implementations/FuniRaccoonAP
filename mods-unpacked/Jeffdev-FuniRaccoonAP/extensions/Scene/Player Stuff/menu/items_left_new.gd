extends "res://Scene/Player Stuff/menu/items_left_new.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func populate_list() -> void:
	var mod_main: Node = ModLoader.get_node("Jeffdev-FuniRaccoonAP")
	var ap_client: ApClient = mod_main.ap_client
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	var level_items: Array = Globals.get_current_world().items_in_levels
	var level_name: String = LevelChanger.all_levels[Globals.get_current_world().level_id].level_name

	var checks: Array = []
	for item_id in level_items:
		if ItemTacker.item_list_data.has(item_id) and ap_client.Ids.STORE_ITEMS.has(item_id):
			checks.append(item_id)
	var total: int = checks.size()
	var count: int = 0
	_ap_show_count(count, total, level_name)

	for item_id in checks:
		await get_tree().create_timer(0.1, true, false, true).timeout

		var item_inst: InteractData = mod_main.instantiate_item(item_id)
		if item_inst == null:
			continue
		var sent: bool = ap_stored.has(item_id)
		if sent:
			count += 1
			_ap_show_count(count, total, level_name)

		var new_item = NEW_ITEM.instantiate()
		grid.add_child(new_item)
		new_item.set_val(item_inst.hud_icon, true, sent)
		item_inst.queue_free()

func _ap_show_count(count: int, total: int, level_name: String) -> void:
	item_info.items_left(count, total, level_name)
	var info_label = item_info.get_node_or_null("Control/VBoxContainer/info")
	if info_label != null:
		info_label.text = str(count) + "/" + str(total) + " checks\nsent"
