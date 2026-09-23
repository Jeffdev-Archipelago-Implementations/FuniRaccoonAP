extends "res://Scripts/levels/player_level_change.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")
const LevelAccessGuard = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd")
const ApChatPopup = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")

# Only the body_entered signal is gated. Sun gods, the salmon, the bees exit etc. call
# _on_body_entered directly for scripted teleports, and those must stay ungated.
func _ready() -> void:
	super()
	body_entered.disconnect(_on_body_entered)
	body_entered.connect(_ap_on_body_entered)

func _ap_on_body_entered(body) -> void:
	if not random:
		var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
		var required: int = LevelAccessGuard.get_required_for_level(level_id)
		var have: int = Globals.save_file.items_stored.size()
		var connected: bool = ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD
		if not connected or have < required or not LevelAccessGuard.item_requirement_met(level_id):
			ApChatPopup.show_message(LevelAccessGuard.locked_message(level_id, connected, have), get_tree().get_root())
			return
	_on_body_entered(body)
