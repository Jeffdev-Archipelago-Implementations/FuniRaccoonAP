extends "res://Scene/Levels/petrol_station/area_3d_horse.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready() -> void:
	var mod_main: Node = ModLoader.get_node("Jeffdev-FuniRaccoonAP")
	var owned: Array = mod_main.hide_vehicles([current])
	super()
	mod_main.restore_vehicles(owned)

func unlock_vehicle(_player: PlayerScript) -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	ap_client.vehicle_unlocked(current)
	queue_free()
