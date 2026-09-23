extends "res://Scene/Objects/funbells/levelup_strength.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _on_dumbell_levelup_pickup(_player: PlayerScript) -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	if Globals.save_file.collect_upgrades.has(collectable_id):
		return
	Globals.save_file.collect_upgrades.append(collectable_id)
	Globals.save_game()
	ap_client.dumbbell_eaten(collectable_id)
