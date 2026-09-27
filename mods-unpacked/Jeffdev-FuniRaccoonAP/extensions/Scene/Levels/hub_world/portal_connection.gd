extends "res://Scene/Levels/hub_world/portal_connection.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready() -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	item_count_needed = ap_client.slot_threshold_for(item_count_needed)
	super()
