extends "res://Scene/Levels/hub_world/floors/number_reached.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready() -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	stored_size = ap_client.slot_threshold_for(stored_size)
	super()
