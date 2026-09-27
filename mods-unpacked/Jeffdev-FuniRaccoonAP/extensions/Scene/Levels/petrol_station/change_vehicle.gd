extends "res://Scene/Levels/petrol_station/change_vehicle.gd"

func _ready() -> void:
	var mod_main: Node = ModLoader.get_node("Jeffdev-FuniRaccoonAP")
	if not vehicles.has(mod_main.TROLLEY_VEHICLE_ID):
		vehicles[mod_main.TROLLEY_VEHICLE_ID] = load(mod_main.TROLLEY_VEHICLE_SCENE_UID)
	super()
