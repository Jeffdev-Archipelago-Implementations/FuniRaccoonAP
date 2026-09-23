extends "res://Audio/SoundEffects/dumpster/check_players_hands.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready() -> void:
	if Globals.player_inst == null or Globals.player_inst.pickup_pivot == null:
		return
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	for item in Globals.player_inst.pickup_pivot.get_objects_in_hand():
		if item is not InteractData:
			continue
		if item.obj_id == item_tracker.item_id.KEI_TRUCK:
			continue
		ap_client.item_stored(item.obj_id)
