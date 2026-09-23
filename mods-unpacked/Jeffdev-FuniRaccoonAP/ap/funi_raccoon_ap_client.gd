## Funi Raccoon Game Archipelago Client
##
## Extends GodotApClient with game-specific integration: granting received items,
## sending location checks, goals, traps and the tracker map location.
extends "res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/godot_ap_client.gd"

const ApTypes = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/ap_types.gd")
const Ids = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ids.gd")
const ApChatPopup = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
const ApItemPopup = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_item_popup.gd")

const _LOG = "Jeffdev-FuniRaccoonAP/FuniRaccoonApClient"

## slot_data["goal"] is an Archipelago OptionSet of these; every selected goal must be completed.
const VALID_GOALS: Array = ["orb", "museum", "fellowship", "lugh"]

const ACT_CLUSTER_NAMES: Dictionary = {
	1: "ACT_1_CLUSTER",
	2: "ACT_2_CLUSTER",
	5: "ACT_3_CLUSTER",
}

# Vanilla dumpster gate values, in the order of ItemTacker.thresholds.
const DEFAULT_GATE_THRESHOLDS := [15, 25, 35, 50]

# Save meta keys holding the location ids already checked, per location type.
const CHECKED_META_KEYS: Array = [
	"ap_checked_truck_scores",
	"ap_checked_shop_upgrades",
	"ap_checked_cats",
	"ap_checked_hats",
	"ap_checked_jewels",
	"ap_checked_euros",
	"ap_checked_vehicles",
	"ap_checked_speedway",
]

const POLICE_CLUSTER_SCENE = preload("res://Scene/characters/police/police_cluster.tscn")
const POLICE_WARNING_SCENE = preload("res://Scene/characters/police/police_warning.tscn")
const POLICE_TRAP_WARNING_DURATION: float = 20.0
const POLICE_TRAP_CAR_DURATION: float = 25.0
const MAX_CONCURRENT_POLICE_CLUSTERS: int = 1

# Matches the "Phone" option in Scene/Menus/settings/resolution_settings.gd.
const PHONE_SCREEN_SIZE = Vector2i(240, 480)
const PHONE_RATIO_TRAP_DURATION: float = 30.0
const PHONE_TRAP_META := "ap_phone_trap_original_size"
var _phone_trap_generation: int = 0

# Item index at connect time
var _baseline_item_index: int = -1
# ItemTacker.thresholds in vanilla, restored on disconnect.
var _vanilla_thresholds: Array = []
var _was_connected: bool = false

var _active_police_clusters: Array = []
var _active_police_warning: Node2D = null

func _ready() -> void:
	super._ready()
	connection_state_changed.connect(_on_connection_state_changed)
	websocket_client.on_print_json.connect(func(command: Dictionary): ApChatPopup.show_print_json(command, self))

func get_player_name(player_slot: int) -> String:
	for p in players:
		if int(p.get("slot", -1)) == player_slot:
			return str(p.get("alias", p.get("name", "Unknown")))
	return "Unknown"

func get_player_game(player_slot: int) -> String:
	var info = slot_info.get(str(player_slot), slot_info.get(player_slot, null))
	if info is Dictionary:
		return str(info.get("game", ""))
	return ""

# =============================================================================
# Receiving items
# =============================================================================

func _on_received_items(command: Dictionary) -> void:
	var first_index: int = int(command.get("index", 0))
	var items: Array = command.get("items", [])
	var next_index: int = Globals.save_file.get_meta("ap_received_item_index", 0)
	var changed := false

	for i in range(items.size()):
		var index := first_index + i
		if index < next_index:
			continue
		var item: Dictionary = items[i]
		var ap_item_id: int = int(item["item"])
		var item_name := _item_name(ap_item_id)
		ModLoaderLog.info("AP received item [%d] id=%d '%s'" % [index, ap_item_id, item_name], _LOG)

		var granted := _grant_item(ap_item_id)
		if granted != "":
			changed = true
			if _baseline_item_index >= 0 and index >= _baseline_item_index:
				ApItemPopup.show_popup(
					item_name if item_name != "" else granted,
					get_player_name(int(item.get("player", 0))),
					get_tree().get_root()
				)

		item_received.emit(item_name, item)
		next_index = index + 1
		Globals.save_file.set_meta("ap_received_item_index", next_index)

	if changed:
		Globals.save_game()

func _item_name(ap_item_id: int) -> String:
	if not data_package:
		return ""
	var name_val = data_package.item_id_to_name.get(ap_item_id, data_package.item_id_to_name.get(float(ap_item_id), null))
	return str(name_val) if name_val != null else ""

# Item granting handler system, the returned string is displayed in an item popup if not ""
func _grant_item(id: int) -> String:
	var save := Globals.save_file
	if id == Ids.PROGRESSIVE_DUMBBELL:
		LevelUpSystem.level_up_system()
		LevelUpSystem.Level_Up.emit()
		return "Progressive Mystical Dumbbell"
	if id == Ids.PROGRESSIVE_COOLING_ROD:
		return _grant_cooling_rod()
	if id == Ids.EURO_10:
		Globals.add_euro(10.0)
		return "10 Euro"
	if id == Ids.EURO_100:
		Globals.add_euro(100.0)
		return "100 Euro"
	if id == Ids.POLICE_TRAP:
		_trigger_police_trap()
		return ""
	if id == Ids.PHONE_RATIO_TRAP:
		_trigger_phone_ratio_trap()
		return "Phone Ratio Trap"
	if id == Ids.BRAZIL_TRAIN_TICKET:
		if save.get_meta("ap_brazil_train_ticket", false):
			return ""
		save.set_meta("ap_brazil_train_ticket", true)
		return "Brazil Train Ticket"
	if Ids.KEI_TRUCK_UPGRADES.has(id):
		return _grant_unique(save.truck_upgrades, Ids.KEI_TRUCK_UPGRADES[id], Ids.KEI_TRUCK_UPGRADES[id])
	if Ids.HATS.has(id):
		return _grant_unique(save.unlocked_hats, Ids.HATS[id], "Hat")
	if Ids.JEWELS.has(id):
		_remember("ap_received_jewels", id)
		return _grant_unique(save.states_occurred, Ids.JEWELS[id], "Mystical Jewel")
	if Ids.VEHICLES.has(id):
		_remember("ap_received_vehicles", Ids.VEHICLES[id])
		return _grant_unique(save.unlocked_vehicles, Ids.VEHICLES[id], "Vehicle")
	if id == item_tracker.item_id.KEI_TRUCK:
		return _grant_stored_item(id, "Kei Truck")
	if Ids.STORE_ITEMS.has(id):
		return _grant_stored_item(id, str(id))
	ModLoaderLog.warning("AP item id=%d has no handler, skipping." % id, _LOG)
	return ""

func _grant_unique(list: Array, value, popup_name: String) -> String:
	if list.has(value):
		return ""
	list.append(value)
	return popup_name

func _grant_stored_item(id: int, popup_name: String) -> String:
	if Globals.save_file.items_stored.has(id):
		return ""
	Globals.save_file.items_stored.append(id)
	Globals.dumpster_added_item.emit()
	return popup_name

func _grant_cooling_rod() -> String:
	for rod_id in Ids.COOLING_ROD_ORDER:
		if Globals.save_file.items_stored.has(rod_id):
			continue
		_grant_stored_item(rod_id, "")
		var rods: Array = Globals.save_file.cooling_rods
		if rod_id == item_tracker.item_id.COOLING_ROD_PLIMBO and not rods.has("plimbo"):
			rods.append("plimbo")
		elif rod_id == item_tracker.item_id.COOLING_ROD_FRIDGE_KING and not rods.has("fridge_king"):
			rods.append("fridge_king")
		return "Progressive Cooling Rod"
	ModLoaderLog.warning("AP granted Progressive Cooling Rod but all three are already collected.", _LOG)
	return ""

func _remember(meta_key: String, value) -> void:
	var list: Array = Globals.save_file.get_meta(meta_key, [])
	if not list.has(value):
		list.append(value)
		Globals.save_file.set_meta(meta_key, list)

# =============================================================================
# Sending checks
# =============================================================================

# Records a check in the save (so it can be resent on the next connect) and sends it if connected.
func _send_check(meta_key: String, location_id: int) -> void:
	var checked: Array = Globals.save_file.get_meta(meta_key, [])
	if checked.has(location_id):
		return
	checked.append(location_id)
	Globals.save_file.set_meta(meta_key, checked)
	Globals.save_game()
	if connect_state == ConnectState.CONNECTED_TO_MULTIWORLD:
		check_location(location_id)

func _send_mapped_check(meta_key: String, locations: Dictionary, key) -> void:
	if not locations.has(key):
		ModLoaderLog.warning("No AP location for %s (%s)." % [str(key), meta_key], _LOG)
		return
	_send_check(meta_key, locations[key])

func item_stored(id: item_tracker.item_id) -> void:
	if not Ids.STORE_ITEMS.has(id):
		ModLoaderLog.warning("item_stored: no AP location for item_id %d (%s)" % [id, item_tracker.item_id.keys()[id]], _LOG)
		return
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	if not ap_stored.has(id):
		ap_stored.append(id)
		Globals.save_file.set_meta("ap_stored_items", ap_stored)
	if not Globals.save_file.items_found.has(id):
		Globals.save_file.items_found.append(id)
	Globals.save_game()
	if connect_state == ConnectState.CONNECTED_TO_MULTIWORLD:
		check_location(Ids.store_location(id))

func dumbbell_eaten(collectable_id: String) -> void:
	if not Ids.DUMBBELL_LOCATIONS.has(collectable_id):
		ModLoaderLog.warning("dumbbell_eaten: no AP location for '%s'" % collectable_id, _LOG)
		return
	_remember("ap_eaten_dumbbells", collectable_id)
	Globals.save_game()
	if connect_state == ConnectState.CONNECTED_TO_MULTIWORLD:
		check_location(Ids.DUMBBELL_LOCATIONS[collectable_id])

func truck_score_achieved(score: int) -> void:
	for entry in Ids.TRUCK_SCORE_LOCATIONS:
		if score >= entry[0]:
			_send_check("ap_checked_truck_scores", entry[1])

func shop_upgrade_purchased(flag: String) -> void:
	_send_mapped_check("ap_checked_shop_upgrades", Ids.SHOP_UPGRADE_LOCATIONS, flag)

func cat_found(cat_id: item_tracker.item_id) -> void:
	_send_mapped_check("ap_checked_cats", Ids.CAT_LOCATIONS, cat_id)

func hat_collected(hat_id: int) -> void:
	_send_mapped_check("ap_checked_hats", Ids.HAT_LOCATIONS, hat_id)

func jewel_collected(jewel_flag: String) -> void:
	_send_mapped_check("ap_checked_jewels", Ids.JEWEL_LOCATIONS, jewel_flag)

func vehicle_unlocked(vehicle: int) -> void:
	_send_mapped_check("ap_checked_vehicles", Ids.VEHICLE_LOCATIONS, vehicle)

func euro_collected(money_id: String) -> void:
	_send_mapped_check("ap_checked_euros", Ids.EURO_LOCATIONS, money_id)

func speedway_completed() -> void:
	_send_check("ap_checked_speedway", Ids.SPEEDWAY_LOCATION)

func _resend_saved_checks() -> void:
	for id in Globals.save_file.get_meta("ap_stored_items", []):
		if Ids.STORE_ITEMS.has(id):
			check_location(Ids.store_location(id))
		if not Globals.save_file.items_found.has(id):
			Globals.save_file.items_found.append(id)

	Globals.save_game()
	for collectable_id in Globals.save_file.get_meta("ap_eaten_dumbbells", []):
		if Ids.DUMBBELL_LOCATIONS.has(collectable_id):
			check_location(Ids.DUMBBELL_LOCATIONS[collectable_id])
	for meta_key in CHECKED_META_KEYS:
		for location_id in Globals.save_file.get_meta(meta_key, []):
			check_location(location_id)

# =============================================================================
# Connection
# =============================================================================

func _validate_room_info(room_info_to_validate: Dictionary) -> int:
	var stored_seed: String = str(Globals.save_file.get_meta("ap_seed", ""))
	var room_seed: String = str(room_info_to_validate.get("seed_name", ""))
	if stored_seed != "" and room_seed != "" and stored_seed != room_seed:
		ModLoaderLog.warning("Seed mismatch: save is seed '%s' but the room is seed '%s'. Refusing to connect." % [stored_seed, room_seed], _LOG)
		return ConnectResult.SEED_MISMATCH
	return ConnectResult.SUCCESS

func _on_connection_state_changed(new_state: int, _error: int = 0) -> void:
	if new_state == ConnectState.CONNECTING:
		_baseline_item_index = -1
	elif new_state == ConnectState.CONNECTED_TO_MULTIWORLD:
		_on_joined_multiworld()
	elif new_state == ConnectState.DISCONNECTED:
		_on_disconnected()

func _on_joined_multiworld() -> void:
	_was_connected = true
	_end_phone_ratio_trap()
	_baseline_item_index = Globals.save_file.get_meta("ap_received_item_index", 0)
	_apply_slot_thresholds()
	_resend_saved_checks()
	Globals.save_file.streamer_mode = true # All this does is make Hintblo spawn, nothing else
	_return_to_hub()
	ApChatPopup.show_message(ApChatPopup.HELP_MESSAGE, get_tree().get_root())
	if LevelChanger.current_level != null:
		update_map_location(LevelChanger.current_level.level_id)

func _on_disconnected() -> void:
	if not _vanilla_thresholds.is_empty():
		ItemTacker.thresholds.assign(_vanilla_thresholds)
	if not _was_connected:
		return
	_was_connected = false
	ApChatPopup.clear_all()
	ApItemPopup.clear_all()
	ApChatPopup.show_message("[color=#EE0000]Disconnected from Archipelago[/color]", get_tree().get_root())
	Globals.QUIT_TO_MEUN()

func _apply_slot_thresholds() -> void:
	if _vanilla_thresholds.is_empty():
		_vanilla_thresholds = ItemTacker.thresholds.duplicate()
	var options: Dictionary = slot_data.get("options", {})
	ItemTacker.thresholds = [
		int(options.get("museum_threshold", 15)),
		int(options.get("act2_threshold", 25)),
		int(options.get("act3_threshold", 35)),
		int(options.get("act4_threshold", 50)),
	]

func _return_to_hub() -> void:
	if LevelChanger.current_level != null and LevelChanger.current_level.level_id == level_changer.LEVEL_ID.DEFAULT:
		return
	if Globals.save_file.is_the_future:
		LevelChanger.LOAD_FROM_LEVEL_WITH_SHORT_ID(level_changer.LEVEL_ID.CANYON, Globals.player_inst, "THE_DUMPSTER")
	else:
		LevelChanger.LOAD_FROM_LEVEL_WITH_SHORT_ID(level_changer.LEVEL_ID.MAIN_MENU, Globals.player_inst, "START_SPAWN")

# Checks slot threshold against the vanilla value for each act and swaps it
func slot_threshold_for(vanilla_value: int) -> int:
	if _vanilla_thresholds.is_empty():
		return vanilla_value
	var idx: int = DEFAULT_GATE_THRESHOLDS.find(vanilla_value)
	if idx == -1 or idx >= ItemTacker.thresholds.size():
		return vanilla_value
	return int(ItemTacker.thresholds[idx])

# =============================================================================
# Tracker map storage
# =============================================================================

func _map_location_key() -> String:
	return "map_location_%s" % player

func update_map_location(level_id: int) -> void:
	if connect_state != ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	set_value(_map_location_key(), "replace", level_changer.LEVEL_ID.keys()[level_id])

func update_map_location_for_cluster(cluster_id: int) -> void:
	if connect_state != ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	var act_name: String = ACT_CLUSTER_NAMES.get(cluster_id, "")
	if act_name != "":
		set_value(_map_location_key(), "replace", act_name)

# =============================================================================
# Goals
# =============================================================================

func get_required_goals() -> Array:
	var goal_raw = slot_data.get("goal", [])
	var goals: Array = []
	if goal_raw is Array:
		goals = goal_raw
	elif goal_raw is Dictionary:
		goals = goal_raw.keys()
	elif goal_raw != null and str(goal_raw) != "":
		goals = [str(goal_raw)]
	var valid: Array = []
	for goal in goals:
		if VALID_GOALS.has(str(goal)):
			valid.append(str(goal))
		else:
			ModLoaderLog.warning("Ignoring unrecognized goal '%s' in slot_data." % str(goal), _LOG)
	return valid

func is_goal_completed(goal: String) -> bool:
	return Globals.save_file.get_meta("ap_goals_completed", []).has(goal)

func _goal_requirements_met(goal: String) -> bool:
	var stored: Array = Globals.save_file.items_stored
	var enough_for_act4: bool = stored.size() >= slot_threshold_for(50)
	var all_rods: bool = Ids.COOLING_ROD_ORDER.all(func(rod): return stored.has(rod))
	match goal:
		"orb":
			return enough_for_act4 and all_rods and stored.has(item_tracker.item_id.ORB)
		"museum":
			return stored.size() >= 100 and all_rods and stored.has(item_tracker.item_id.WAFFLE)
		"fellowship":
			return (enough_for_act4 and all_rods
				and stored.has(item_tracker.item_id.PRIESTESS)
				and stored.has(item_tracker.item_id.GREENIE))
		"lugh":
			return enough_for_act4
	ModLoaderLog.warning("check_goal: unknown goal '%s'." % goal, _LOG)
	return false

func check_goal(triggered_goal: String = "") -> void:
	if connect_state != ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	var required_goals: Array = get_required_goals()
	if required_goals.is_empty():
		ModLoaderLog.warning("check_goal: slot_data has no goals configured.", _LOG)
		return
	if triggered_goal != "":
		if not required_goals.has(triggered_goal):
			return
		if not is_goal_completed(triggered_goal):
			if not _goal_requirements_met(triggered_goal):
				return
			var completed: Array = Globals.save_file.get_meta("ap_goals_completed", [])
			completed.append(triggered_goal)
			Globals.save_file.set_meta("ap_goals_completed", completed)
			Globals.save_game()
			ModLoaderLog.info("Goal '%s' complete (%d/%d)." % [triggered_goal, completed.size(), required_goals.size()], _LOG)

	if Globals.save_file.get_meta("ap_goal_complete", false):
		return
	for goal in required_goals:
		if not is_goal_completed(goal):
			return
	ModLoaderLog.info("All selected goals complete - sending CLIENT_GOAL.", _LOG)
	Globals.save_file.set_meta("ap_goal_complete", true)
	Globals.save_game()
	set_status(ApTypes.ClientStatus.CLIENT_GOAL)

# =============================================================================
# Traps
# =============================================================================

func clear_police_warning() -> void:
	if is_instance_valid(_active_police_warning):
		_active_police_warning.queue_free()
	_active_police_warning = null

func _trigger_police_trap() -> void:
	var raccoon_player := Globals.get_player()
	if not is_instance_valid(raccoon_player) or not is_instance_valid(LevelChanger.current_level):
		return
	_active_police_clusters = _active_police_clusters.filter(func(c): return is_instance_valid(c))
	if _active_police_clusters.size() >= MAX_CONCURRENT_POLICE_CLUSTERS:
		return

	var police_inst: Node3D = POLICE_CLUSTER_SCENE.instantiate()
	LevelChanger.current_level.add_child(police_inst)
	police_inst.global_position = raccoon_player.global_position + Vector3(2.0, 0.0, 2.0)
	_active_police_clusters.append(police_inst)
	get_tree().create_timer(POLICE_TRAP_CAR_DURATION).timeout.connect(func():
		if is_instance_valid(police_inst):
			police_inst.queue_free()
	)

	clear_police_warning()
	var warning_inst: Node2D = POLICE_WARNING_SCENE.instantiate()
	_active_police_warning = warning_inst
	warning_inst.tree_exited.connect(func():
		if _active_police_warning == warning_inst:
			_active_police_warning = null
	)
	var message_label: RichTextLabel = warning_inst.get_node("CanvasLayer/CenterContainer/RichTextLabel")
	if is_instance_valid(message_label):
		message_label.text = "[center]THEY GOT A POLICE TRAP LMAOOOO[/center]\n\n\n[center][shake][color=#FF0000]GET THEY/THEM ASS[/color][/shake][/center]"
	var warning_timer: Timer = warning_inst.get_node("Timer")
	if is_instance_valid(warning_timer):
		warning_timer.wait_time = POLICE_TRAP_WARNING_DURATION
	get_tree().get_root().add_child(warning_inst)

func _trigger_phone_ratio_trap() -> void:
	var save := Globals.save_file
	if not save.has_meta(PHONE_TRAP_META):
		save.set_meta(PHONE_TRAP_META, save.screen_size)
	_phone_trap_generation += 1
	var this_generation: int = _phone_trap_generation
	save.screen_size = PHONE_SCREEN_SIZE
	Globals.updated_res.emit()
	get_tree().create_timer(PHONE_RATIO_TRAP_DURATION).timeout.connect(func():
		if this_generation == _phone_trap_generation:
			_end_phone_ratio_trap()
	)

func _end_phone_ratio_trap() -> void:
	var save := Globals.save_file
	if not save.has_meta(PHONE_TRAP_META):
		return
	save.screen_size = save.get_meta(PHONE_TRAP_META)
	save.remove_meta(PHONE_TRAP_META)
	Globals.updated_res.emit()
	Globals.save_game()
