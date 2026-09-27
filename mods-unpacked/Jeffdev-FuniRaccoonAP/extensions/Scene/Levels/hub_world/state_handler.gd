extends "res://Scene/Levels/hub_world/state_handler.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready() -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	if ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
		second_floor_threshold = ap_client.slot_threshold_for(25)
		third_floor_threshold = ap_client.slot_threshold_for(35)
	super()
