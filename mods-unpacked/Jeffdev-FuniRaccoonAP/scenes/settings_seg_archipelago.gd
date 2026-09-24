extends Control

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

const GOAL_NAMES: Dictionary = {
	"orb": "Orb Ending",
	"museum": "Museum Ending",
	"fellowship": "Fellowship Ending",
	"lugh": "Lugh Ending",
}
const TRACKER_MISSING := Color(1, 1, 1, 0.25)
const TRACKER_OBTAINED := Color(1, 1, 1, 1)
# Progressive Trackers
const COUNTED_TRACKERS: Array[String] = ["JewelTracker", "RodTracker", "StrengthTracker"]
# Goal icon -> slot_data goal name.
const GOAL_ICONS: Dictionary = {
	"Orb": "orb",
	"Waffle": "museum",
	"Priest": "fellowship",
	"Lugh": "lugh",
}

@onready var status_label: Label = %StatusLabelEntry
@onready var slot_name: Label = %SlotNameLabelEntry
@onready var checks: Label = %ChecksLabelEntry
@onready var dumpster: Label = %DumpsterLabelEntry
@onready var tracker_grid: GridContainer = $VBoxContainer2/GridContainer
@onready var goal_grid: GridContainer = $VBoxContainer2/GridContainer2

var ap_client: ApClient
var _count_labels: Dictionary = {}

func _ready() -> void:
	ap_client = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	var vp := get_viewport()
	if vp is SubViewport:
		vp.gui_embed_subwindows = true
	for icon_name in COUNTED_TRACKERS:
		var icon: Control = tracker_grid.get_node_or_null(icon_name)
		if icon != null:
			_count_labels[icon_name] = _add_corner_label(icon, Color.WHITE, Control.PRESET_BOTTOM_RIGHT)

	ap_client.connection_state_changed.connect(_on_connection_state_changed)
	ap_client.room_updated.connect(_on_room_update)
	ap_client.item_received.connect(_on_item_received)
	Globals.dumpster_added_item.connect(_update_status)
	visibility_changed.connect(_update_status)
	_update_status()

func _exit_tree() -> void:
	if ap_client != null:
		if ap_client.connection_state_changed.is_connected(_on_connection_state_changed):
			ap_client.connection_state_changed.disconnect(_on_connection_state_changed)
		if ap_client.room_updated.is_connected(_on_room_update):
			ap_client.room_updated.disconnect(_on_room_update)
		if ap_client.item_received.is_connected(_on_item_received):
			ap_client.item_received.disconnect(_on_item_received)
	if Globals.dumpster_added_item.is_connected(_update_status):
		Globals.dumpster_added_item.disconnect(_update_status)

func _on_connection_state_changed(_state, _error = 0) -> void:
	_update_status()

func _on_room_update(_state, _error = 0) -> void:
	_update_status()

func _on_item_received(_item_name, _item) -> void:
	_update_status()

func _update_status() -> void:
	var connected: bool = ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD
	status_label.text = "CONNECTED" if connected else "DISCONNECTED"
	status_label.add_theme_color_override("font_color", Color(0, 0.6, 0, 1) if connected else Color(1, 0, 0, 1))

	if connected:
		slot_name.text = ap_client.player
		var done: int = ap_client.checked_locations.size()
		checks.text = "%d/%d" % [done, done + ap_client.missing_locations.size()]
		dumpster.text = str(Globals.save_file.items_stored.size())
	else:
		slot_name.text = "NOT CONNECTED"
		checks.text = "N/A"
		#goal.text = "N/A"
		dumpster.text = "N/A"

	for icon in tracker_grid.get_children():
		var icon_name := String(icon.name)
		var count: int = _tracker_count(icon_name) if connected else 0
		icon.modulate = TRACKER_OBTAINED if count > 0 else TRACKER_MISSING
		if _count_labels.has(icon_name):
			var label: Label = _count_labels[icon_name]
			label.text = str(count)
			label.visible = count > 0

	# Goals stay dim until they are both required for this slot and won.
	var required: Array = ap_client.get_required_goals() if connected else []
	for icon in goal_grid.get_children():
		var goal_id: String = GOAL_ICONS.get(String(icon.name), "")
		if not required.has(goal_id):
			icon.hide()
		var won: bool = required.has(goal_id) and ap_client.is_goal_completed(goal_id)
		icon.self_modulate = TRACKER_OBTAINED if won else TRACKER_MISSING

func _tracker_count(icon_name: String) -> int:
	var save: SaveGame = Globals.save_file
	match icon_name:
		"OrbTracker":
			return _stored(item_tracker.item_id.ORB)
		"WaffleTracker":
			return _stored(item_tracker.item_id.WAFFLE)
		"GreenTracker":
			return _stored(item_tracker.item_id.GREENIE)
		"PriestTracker":
			return _stored(item_tracker.item_id.PRIESTESS)
		"JewelTracker":
			return save.get_meta("ap_received_jewels", []).size()
		"RodTracker":
			return ap_client.Ids.COOLING_ROD_ORDER.filter(func(rod): return save.items_stored.has(rod)).size()
		"StrengthTracker":
			# Strength starts at 1 and each Progressive Mystical Dumbbell adds 1.
			return maxi(int(save.strength) - 1, 0)
		"TruckTracker":
			return _stored(item_tracker.item_id.KEI_TRUCK)
		"BoostTracker":
			return 1 if save.truck_upgrades.has(truck_flags.boost_purchased) else 0
		"ToastTracker":
			return 1 if save.truck_upgrades.has(truck_flags.jump_purchased) else 0
		"RadioTracker":
			return 1 if save.truck_upgrades.has(truck_flags.radio_purchased) else 0
		"GooTracker":
			return _stored(item_tracker.item_id.GOO)
		"ChickenTracker":
			return _stored(item_tracker.item_id.CHICKEN)
		"BrobTracker":
			return _stored(item_tracker.item_id.BROB_ENERGY)
		"PickaxeTracker":
			return _stored(item_tracker.item_id.PICKAXE)
		"ButterflyTracker":
			return _stored(item_tracker.item_id.BUTTERFLY)
		"MineKeyTracker":
			return _stored(item_tracker.item_id.MINES_KEY)
		"FridgeKeyTracker":
			return _stored(item_tracker.item_id.FRIDGE_KEY)
		"GunTracker":
			return _stored(item_tracker.item_id.GUN)
		"PlushTracker":
			return _stored(item_tracker.item_id.FUNI_MARKETABLE_PLUSHIE)
		"FlowianTracker":
			return _stored(item_tracker.item_id.FLOWIAN)
		"AntisadTracker":
			return _stored(item_tracker.item_id.ANTI_SADS)
		"BrazilTracker":
			return 1 if save.get_meta("ap_brazil_train_ticket", false) else 0
	return 0

func _stored(id: int) -> int:
	return 1 if Globals.save_file.items_stored.has(id) else 0

func _add_corner_label(icon: Control, color: Color, corner: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.theme = status_label.theme
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	icon.add_child(label)
	label.set_anchors_and_offsets_preset(corner)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN if corner == Control.PRESET_BOTTOM_RIGHT else Control.GROW_DIRECTION_END
	return label
