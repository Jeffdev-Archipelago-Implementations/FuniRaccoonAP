extends "res://Scene/Menus/funi_raccoon_delux.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

var _ap_client: ApClient
var _ap_deluxe_location_id: int

func _ready() -> void:
	super()
	_ap_client = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	if _ap_client.connect_state != _ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	_ap_deluxe_location_id = _ap_client.Ids.store_location(item_tracker.item_id.FUNI_RACCOON_GAME_CD)
	_ap_client.location_info_received.connect(_ap_on_location_info)
	_ap_client.send_location_scouts([_ap_deluxe_location_id], 0)

func _exit_tree() -> void:
	if _ap_client != null and _ap_client.location_info_received.is_connected(_ap_on_location_info):
		_ap_client.location_info_received.disconnect(_ap_on_location_info)

func _ap_on_location_info(location_id: int, _item_id: int, item_name: String, _game_name: String, _player_slot: int, player_name: String) -> void:
	if location_id != _ap_deluxe_location_id:
		return
	var label: RichTextLabel = get_node_or_null("Control/Control/RichTextLabel")
	if label == null:
		return
	var target: String = item_name
	if player_name != "":
		target = "%s FOR %s" % [item_name, player_name]
	label.text = " [wave]YOU WANT TO BUY %s" % target
