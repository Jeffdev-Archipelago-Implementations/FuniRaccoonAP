extends "res://Scene/Player Stuff/ui/object_icon_meta.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")
const AP_LOGO := preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/ap_logo_80.png")

const BLACKOUT_ITEMS: Array = [
	item_tracker.item_id.CHICKEN,
	item_tracker.item_id.BROB_ENERGY,
	item_tracker.item_id.KEI_TRUCK,
	item_tracker.item_id.GOO,
	item_tracker.item_id.PICKAXE,
	item_tracker.item_id.BUTTERFLY,
	item_tracker.item_id.ORB,
	item_tracker.item_id.PRIESTESS,
	item_tracker.item_id.GREENIE,
	item_tracker.item_id.MINES_KEY,
	item_tracker.item_id.FRIDGE_KEY,
]

const BADGE_SIZE := Vector2(14, 14)

var _ap_client: ApClient
var _ap_badge: TextureRect

func _enter_tree() -> void:
	_ap_client = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	Globals.dumpster_added_item.connect(_ap_refresh)
	_ap_client.item_received.connect(_ap_on_item_received)
	_ap_client.location_sent.connect(_ap_on_location_sent)
	_ap_refresh()

func _ready() -> void:
	_ap_badge = TextureRect.new()
	_ap_badge.name = "APBadge"
	_ap_badge.texture = AP_LOGO
	_ap_badge.custom_minimum_size = BADGE_SIZE
	_ap_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ap_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ap_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ap_badge.visible = false
	add_child(_ap_badge)
	_ap_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_ap_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ap_update_badge()

func _exit_tree() -> void:
	Globals.dumpster_added_item.disconnect(_ap_refresh)
	_ap_client.item_received.disconnect(_ap_on_item_received)
	_ap_client.location_sent.disconnect(_ap_on_location_sent)

func _ap_on_item_received(_a = null, _b = null) -> void:
	_ap_refresh()

func _ap_on_location_sent(_location_id = null) -> void:
	_ap_refresh()

func _ap_refresh() -> void:
	_ap_update_blackout()
	_ap_update_badge()

func _ap_update_blackout() -> void:
	if _ap_client.connect_state != _ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	if not _ap_client.Ids.STORE_ITEMS.has(icon_id) or not BLACKOUT_ITEMS.has(icon_id):
		return
	self_modulate = Color.WHITE if Globals.save_file.items_stored.has(icon_id) else Color.BLACK

func _ap_update_badge() -> void:
	if _ap_badge == null:
		return
	var connected: bool = _ap_client.connect_state == _ap_client.ConnectState.CONNECTED_TO_MULTIWORLD
	var is_check: bool = _ap_client.Ids.STORE_ITEMS.has(icon_id)
	var sent: bool = Globals.save_file.get_meta("ap_stored_items", []).has(icon_id)
	_ap_badge.visible = connected and is_check and not sent
