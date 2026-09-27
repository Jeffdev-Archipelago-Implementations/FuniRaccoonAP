extends "res://Scene/Levels/OldBuilding/path_3d.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready() -> void:
	var mod_main: Node = ModLoader.get_node("Jeffdev-FuniRaccoonAP")
	var owned: Array = mod_main.hide_vehicles([SaveGame.vehicles.TONY, SaveGame.vehicles.FORKLIFT])
	super()
	mod_main.restore_vehicles(owned)

func unlock_vehicle() -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	if robin_dead:
		ap_client.vehicle_unlocked(SaveGame.vehicles.FORKLIFT)

func unlock_tony() -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	if mikk_dead:
		ap_client.vehicle_unlocked(SaveGame.vehicles.TONY)
