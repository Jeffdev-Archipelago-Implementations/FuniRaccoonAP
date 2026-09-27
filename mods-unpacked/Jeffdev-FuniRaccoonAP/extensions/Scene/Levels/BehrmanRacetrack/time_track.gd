extends "res://Scene/Levels/BehrmanRacetrack/time_track.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func stop_timer() -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	super()
	if time <= 60.0:
		ap_client.speedway_completed()
