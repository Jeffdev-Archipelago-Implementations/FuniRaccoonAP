extends "res://Scene/Player Stuff/menu/objectives_list.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func show_objective():
	var mod_main: Node = ModLoader.get_node("Jeffdev-FuniRaccoonAP")
	var ap_client: ApClient = mod_main.ap_client
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])

	for child in v_box_container.get_children():
		child.queue_free()

	items_in_level = {}
	for item_id in Globals.get_current_world().items_in_levels as Array[item_tracker.item_id]:
		if not ap_client.Ids.STORE_ITEMS.has(item_id):
			continue
		var item_inst: InteractData = mod_main.instantiate_item(item_id)
		if item_inst == null:
			continue
		if not item_inst.item_list_ignore:
			items_in_level[item_id] = [item_inst.obj_name, item_inst.hud_icon]
		item_inst.queue_free()

	if items_in_level.is_empty():
		return

	var total_sent: int = 0
	for key in items_in_level.keys():
		var item_sent: bool = ap_stored.has(key)
		if item_sent:
			total_sent += 1
		var item_menu = ITEM_LIST_ITEM.instantiate()
		v_box_container.add_child(item_menu)
		if not item_sent and not Globals.save_file.items_stored.has(key):
			item_menu.populate("???????", items_in_level[key][1])
		else:
			item_menu.populate(items_in_level[key][0], items_in_level[key][1], item_sent)
		var scribble = item_menu.get_node_or_null("Label/Scribble")
		if scribble != null:
			scribble.visible = item_sent

	if total_sent == items_in_level.size():
		complete.show()
		animation_player.play("show")
	else:
		complete.hide()
