extends "res://Scene/Objects/keiTruck/stunt_tracker.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready():
	super()
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	hit_ground.connect(func():
		ap_client.truck_score_achieved(score)
	)
