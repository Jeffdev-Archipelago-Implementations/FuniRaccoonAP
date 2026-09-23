extends "res://Scene/Objects/cat/find_cat_quest.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func checkCat(_player) -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	super(_player)
	ap_client.cat_found(cat.obj_id)
