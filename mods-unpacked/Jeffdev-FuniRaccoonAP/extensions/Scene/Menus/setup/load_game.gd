extends "res://Scene/Menus/setup/load_game.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func _ready() -> void:
	var mod_main: Node = ModLoader.get_node("Jeffdev-FuniRaccoonAP")
	var ap_client: ApClient = mod_main.ap_client
	if ap_client.connect_state != ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
		mod_main.connect_panel.show_overlay()
	super()
