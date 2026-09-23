extends "res://Scene/Objects/hats/hat_collect.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready() -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	var location_id: int = ap_client.Ids.HAT_LOCATIONS.get(hat_id, 0)
	var player_collected: bool = Globals.save_file.get_meta("ap_checked_hats", []).has(location_id)
	var ap_received: bool = Globals.save_file.unlocked_hats.has(hat_id)

	# Hidden from the vanilla _ready, which deletes the pickup for owned hats.
	if ap_received and not player_collected:
		Globals.save_file.unlocked_hats.erase(hat_id)
	super()
	if ap_received and not player_collected and not Globals.save_file.unlocked_hats.has(hat_id):
		Globals.save_file.unlocked_hats.append(hat_id)

	if player_collected and is_instance_valid(item_hat_data):
		item_hat_data.queue_free()

func found_hat(_player: PlayerScript) -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	ap_client.hat_collected(hat_id)
