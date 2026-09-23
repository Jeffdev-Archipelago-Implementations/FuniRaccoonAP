extends "res://Models/gold/cube.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func has_been_eaten(player: Node3D) -> void:
	super(player)
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	if ap_client.Ids.EURO_LOCATIONS.has(money_id):
		ap_client.euro_collected(money_id)
