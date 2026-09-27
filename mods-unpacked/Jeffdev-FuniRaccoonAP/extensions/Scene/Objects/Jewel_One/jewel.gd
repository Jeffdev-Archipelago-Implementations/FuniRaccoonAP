extends "res://Scene/Objects/Jewel_One/jewel.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready() -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	var location_id: int = ap_client.Ids.JEWEL_LOCATIONS.get(jewel_flag, 0)
	var player_collected: bool = Globals.save_file.get_meta("ap_checked_jewels", []).has(location_id)
	var ap_received: bool = Globals.save_file.states_occurred.has(jewel_flag)

	# Hidden from the vanilla _ready, which deletes the pickup for eaten jewels.
	if ap_received and not player_collected:
		Globals.save_file.states_occurred.erase(jewel_flag)
	super()
	if ap_received and not player_collected and not Globals.save_file.states_occurred.has(jewel_flag):
		Globals.save_file.states_occurred.append(jewel_flag)

	if player_collected and is_instance_valid(jewel):
		jewel.queue_free()

func eaten(_player) -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	ap_client.jewel_collected(jewel_flag)
