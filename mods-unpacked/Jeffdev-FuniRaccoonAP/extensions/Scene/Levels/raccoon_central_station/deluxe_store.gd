extends "res://Scene/Levels/raccoon_central_station/deluxe_store.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func show_deluxe_store() -> void:
	super()
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	if ap_client.connect_state != ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	var deluxe_location_id: int = ap_client.Ids.store_location(item_tracker.item_id.FUNI_RACCOON_GAME_CD)
	var hint_sent: bool = Globals.save_file.get_meta("ap_deluxe_store_hint_sent", false)
	ap_client.send_location_scouts([deluxe_location_id], 0 if hint_sent else 1)
	if not hint_sent:
		Globals.save_file.set_meta("ap_deluxe_store_hint_sent", true)
