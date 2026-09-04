extends Node

const MOD_NAME = "Jeffdev-FuniRaccoonAP"
const MOD_VERSION = "1.7.0"
const LOG_NAME = MOD_NAME + "/mod_main"
const CONFIG_PATH = "user://ap_connect.json"

# Held-item HUD icons for these items are blacked out until their AP check has been sent.
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

# Scenes the mod has to reach for by uid, because the game never names them.
const GACHA_MACHINE_SCENE_PATH := "res://Scene/Objects/GachaMachine/gacha_machine.tscn"
const GACHA_MACHINE_SCENE_UID := "uid://bevwwjw1owksw"
const TROLLEY_VEHICLE_SCENE_UID := "uid://b4skd2o7aix7d"

# Ids the game has no enum entry for: item_tracker.item_id stops at ROBIN = 184 and
# SaveGame.vehicles stops at HORSE = 4, so the mod assigns these itself.
const GACHA_MACHINE_ITEM_ID := 185
const TROLLEY_VEHICLE_ID := 5
const TROLLEY_LOGO_UID := "uid://cads36fss47rk"
const TROLLEY_MENU_SCALE := 0.75
const TROLLEY_MENU_LIFT := 0.50

var ap_websocket_connection
var ap_client
var connect_panel
var _color_randomized_this_transition: bool = false

# Replacement title textures (base game's title_text.png / title_text_no_bg.png).
var _title_text_tex: Texture2D
var _title_text_no_bg_tex: Texture2D

func _load_item_scene(item_id) -> PackedScene:
	if not ItemTacker.item_list_data.has(item_id):
		return null
	var entry = ItemTacker.item_list_data[item_id]
	if entry is PackedScene:
		return entry
	if entry is String:
		if entry.is_empty():
			return null
		var res = load(entry)
		if res is PackedScene:
			return res
	return null

func _instantiate_item(item_id) -> InteractData:
	var packed: PackedScene = _load_item_scene(item_id)
	if packed == null:
		return null
	var inst = packed.instantiate()
	if inst is InteractData:
		return inst
	if inst != null:
		inst.queue_free()
	return null

func _register_gacha_machine_item() -> void:
	var item_id: int = GACHA_MACHINE_ITEM_ID
	if ItemTacker.item_list_data.has(item_id):
		return
	# item_list_data is typed Dictionary[item_id, String], so this must be the uid
	ItemTacker.item_list_data[item_id] = GACHA_MACHINE_SCENE_UID
	ModLoaderLog.info("Registered gacha machine with ItemTacker as id %d." % item_id, LOG_NAME)

func _hide_vehicles(vehicles: Array) -> Array:
	var owned: Array = []
	for vehicle in vehicles:
		if Globals.save_file.unlocked_vehicles.has(vehicle):
			owned.append(vehicle)
			Globals.save_file.unlocked_vehicles.erase(vehicle)
	return owned

func _restore_vehicles(owned: Array) -> void:
	for vehicle in owned:
		if not Globals.save_file.unlocked_vehicles.has(vehicle):
			Globals.save_file.unlocked_vehicles.append(vehicle)

# =============================================================================
# Startup things
# =============================================================================

func _init() -> void:
	ModLoaderLog.info("Init", LOG_NAME)

func _ready() -> void:
	var config_data = {"ap_server": "", "ap_player": "", "ap_password": ""}

	if FileAccess.file_exists(CONFIG_PATH):
		var f = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed and typeof(parsed) == TYPE_DICTIONARY:
				config_data = parsed
				ModLoaderLog.info("Loaded config from %s" % CONFIG_PATH, LOG_NAME)
			else:
				ModLoaderLog.warning("Failed to parse config at %s" % CONFIG_PATH, LOG_NAME)
		else:
			ModLoaderLog.warning("Could not open config file at %s" % CONFIG_PATH, LOG_NAME)
	else:
		ModLoaderLog.info("No config file found at %s, skipping auto-connect." % CONFIG_PATH, LOG_NAME)

	var ApWebSocketConnectionScript = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/ap_websocket_connection.gd")
	var FuniRaccoonApClientScript = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

	ap_websocket_connection = ApWebSocketConnectionScript.new()
	add_child(ap_websocket_connection)
	var client_config = {
		"ap_server": config_data.get("ap_server", ""),
		"ap_player": config_data.get("ap_player", ""),
		"ap_password": config_data.get("ap_password", ""),
	}
	ap_client = FuniRaccoonApClientScript.new(ap_websocket_connection, client_config)
	add_child(ap_client)

	_register_gacha_machine_item()

	ModLoaderLog.success("AP client ready v%s" % MOD_VERSION, LOG_NAME)
	var ApChatPopupScript = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
	ApChatPopupScript.set_ap_client(ap_client)
	load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd").set_client(ap_client)

	var ApConnectPanelScript = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_connect_panel.tscn")
	connect_panel = ApConnectPanelScript.instantiate()
	connect_panel.ap_client = ap_client
	add_child(connect_panel)

	_title_text_tex = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/title_text.png")
	_title_text_no_bg_tex = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/title_text_no_bg.png")
	if _title_text_tex == null or _title_text_no_bg_tex == null:
		ModLoaderLog.warning("Title replacement texture(s) failed to load.", LOG_NAME)

	get_tree().node_added.connect(_on_node_added)
	call_deferred("_scan_existing_save_select")
	call_deferred("_scan_existing_title")

	LevelChanger.changing_level.connect(func():
		_color_randomized_this_transition = false
	)

	LevelChanger.level_Changed.connect(func(level_id: level_changer.LEVEL_ID):
		ap_client.clear_police_warning()
		ap_client.update_map_location(level_id)
		if ap_client.slot_data.get("options", {}).get("color_rando", false):
			if not _color_randomized_this_transition and Globals.player_inst != null and Globals.player_inst.player != null:
				Globals.player_inst.player.set_colour(Color(randf(), randf(), randf(), 1))
				_color_randomized_this_transition = true
		match level_id:
			level_changer.LEVEL_ID.ORB_ENDING:
				ap_client.check_goal("orb")
			level_changer.LEVEL_ID.BEENIE_BRANCH:
				ap_client.check_goal("fellowship")
			level_changer.LEVEL_ID.HYPERCUBE_TREE_ENDING:
				ap_client.check_goal("lugh")
	)

# =============================================================================
# Node interception
# =============================================================================

func _on_node_added(node: Node) -> void:
	_replace_title_on(node)

	# --- Main menu / save select ---

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Menus/setup/load_game.gd":
		node.ready.connect(func():
			if ap_client.connect_state != ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
				connect_panel.show_overlay()
		, CONNECT_ONE_SHOT)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/MainMenu/save_file_select_logic.gd":
		node.ready.connect(func():
			_setup_save_file_select(node)
		, CONNECT_ONE_SHOT)

	# --- Pause menu ---

	if node.name == "Quit" and node.get_script() != null:
		if node.get_script().resource_path == "res://Scene/Menus/quit_menu.gd":
			ModLoaderLog.info("Found quit button, connecting pressed signal.", LOG_NAME)
			node.pressed.connect(_on_quit_pressed)
			# Add a "To Rackheath" entry beside Quit
			call_deferred("_add_rackheath_pause_option", node)

	# --- Player menu UI ---

	# Item list checkmarks: use ap_stored_items (sent checks) instead of items_stored (received).
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Player Stuff/menu/objectives_list.gd":
		node.ready.connect(func():
			_ap_rebuild_objectives_list(node)
		, CONNECT_ONE_SHOT)

	# Paper counter: show checks sent rather than items received.
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Player Stuff/menu/items_left_new.gd":
		node.ready.connect(func():
			_ap_fix_items_left_counter(node)
		, CONNECT_ONE_SHOT)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Player Stuff/ui/object_icon_meta.gd":
		_update_object_icon_blackout(node)
		# Re-evaluate while the icon is alive: checks sent and items received from the
		# multiworld can both change the blackout state after the icon was created.
		var refresh: Callable = _update_object_icon_blackout.bind(node)
		var refresh_on_item: Callable = refresh.unbind(2)
		Globals.dumpster_added_item.connect(refresh)
		ap_client.item_received.connect(refresh_on_item)
		node.tree_exiting.connect(func():
			Globals.dumpster_added_item.disconnect(refresh)
			ap_client.item_received.disconnect(refresh_on_item)
		)

	# --- Hub world ---

	# Hub dumpster gates/displays hardcode vanilla thresholds (15/25/35/50) per instance.
	# Remap them to this slot's thresholds. Runs before their _ready reads the value.
	if node.get_script() != null:
		match node.get_script().resource_path:
			"res://Scene/Levels/hub_world/number_reached.gd":
				node.stored_size = ap_client.slot_threshold_for(node.stored_size)
			"res://Scene/Levels/hub_world/item_meter.gd":
				node.item_count_max = ap_client.slot_threshold_for(node.item_count_max)
			"res://Scene/Levels/hub_world/portal_connection.gd":
				node.item_count_needed = ap_client.slot_threshold_for(node.item_count_needed)
			"res://Scene/Levels/hub_world/state_handler.gd":
				if ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
					node.second_floor_threshold = ap_client.slot_threshold_for(25)
					node.third_floor_threshold = ap_client.slot_threshold_for(35)

	# Hub item spawner: in the future spawn nothing; before the future spawn only player-thrown items
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/hub_world/item_spawner.gd":
		node.set_script(null)
		if not Globals.save_file.is_the_future:
			node.ready.connect(func():
				var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
				var items: Array = []
				if ap_stored.size() < 15:
					items = ap_stored.duplicate()
				else:
					var attempts: int = 0
					while items.size() < 15 and attempts < ap_stored.size() * 3:
						var ran_item = ap_stored.pick_random()
						if not items.has(ran_item):
							items.append(ran_item)
						attempts += 1
				for item_id in items:
					if item_id == item_tracker.item_id.KEI_TRUCK:
						continue
					if not ItemTacker.item_list_data.has(item_id):
						continue
					var item_inst: InteractData = _instantiate_item(item_id)
					if item_inst == null:
						continue
					item_inst.global_position = node.global_position
					item_inst.freeze = false
					node.add_child(item_inst)
					item_inst.apply_central_impulse(Vector3.UP * 10)
					await node.get_tree().create_timer(0.1).timeout
			)

	# --- Level access gating ---

	if node.get_script() != null and node.get_script().resource_path == "res://Scripts/levels/player_level_change.gd":
		node.ready.connect(func():
			node.body_entered.disconnect(node._on_body_entered)
			node.body_entered.connect(func(body):
				if not node.random:
					var level_id = node.level_id
					var LevelAccessGuard = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd")
					var required: int = LevelAccessGuard.get_required_for_level(level_id)
					var have: int = Globals.save_file.items_stored.size()
					if ap_client.connect_state != ap_client.ConnectState.CONNECTED_TO_MULTIWORLD \
							or have < required or not LevelAccessGuard.item_requirement_met(level_id):
						ModLoaderLog.info(
							"Transition to %s blocked: need %d items, have %d, connected=%s." % [
								level_changer.LEVEL_ID.keys()[level_id], required, have,
								str(ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD)
							],
							LOG_NAME
						)
						var connected: bool = ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD
						var popup_script = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
						popup_script.show_message(LevelAccessGuard.locked_message(level_id, connected, have), get_tree().get_root())
						return
				node._on_body_entered(body)
			)
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/LevelSelectOrb/level_select_orb.gd":
		_log_cluster_levels(node.get("level_cluster_id"))
		node.ready.connect(func():
			ModLoaderLog.info("Level select orb ready (cluster_id=%s)" % str(node.get("level_cluster_id")), LOG_NAME)
			var player = Globals.get_player()
			if is_instance_valid(player):
				var pickup = player.get_node_or_null("pivotCotainer/PickupPivot")
				if pickup != null:
					var removed := false
					for obj in pickup.get_children():
						if obj is InteractData and obj.obj_id == item_tracker.item_id.KEI_TRUCK:
							obj.queue_free()
							removed = true
					if removed:
						player.holding = false
						player.carrying_weight = 0
						if pickup.menu_updater != null:
							pickup.menu_updater.remove_object_icons()

			node.set_process_input(false)
			ap_client.update_map_location_for_cluster(node.level_cluster_id)
			var guard = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd").new()
			guard._orb = node
			guard.ap_client = ap_client
			node.add_child(guard)
		)

	# Goo Office exit to Blimbo City
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/LongOffice/escape_to_blimbo_city.gd":
		node.ready.connect(func():
			var LevelAccessGuard = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd")
			node.pressy_button.button_pressed.disconnect(node.button_pressed)
			node.pressy_button.button_pressed.connect(func():
				var have: int = Globals.save_file.get_meta("ap_received_item_index", 0)
				var required: int = LevelAccessGuard.get_required_for_level(level_changer.LEVEL_ID.BLIMBO_CITY)
				if have < required:
					ModLoaderLog.info("Goo Office exit blocked: need %d items, have %d." % [required, have], LOG_NAME)
					return
				node.button_pressed()
			)
		)

	# Brazil train: Gate based on Brazil Train Ticket item, so remove the existing script
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/raccoon_central_station/brazil_deleter.gd":
		node.set_script(null)

	# --- Location checks ---

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/funbells/levelup_strength.gd":
		node.ready.connect(func():
			node.dumbells.eaten_signal.disconnect(node._on_dumbell_levelup_pickup)
			node.dumbells.eaten_signal.connect(func(_player):
				if Globals.save_file.collect_upgrades.has(node.collectable_id):
					return
				Globals.save_file.collect_upgrades.append(node.collectable_id)
				Globals.save_game()
				ap_client.dumbbell_eaten(node.collectable_id)
			)
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Dumpster/Dumpster.gd":
		node.ready.connect(func():
			node.object_area_detect.body_entered.disconnect(node._on_object_area_detect_body_entered)
			node.object_area_detect.body_entered.connect(func(body: InteractData):
				if body is not InteractData:
					return
				if body.obj_id == item_tracker.item_id.KEI_TRUCK:
					return
				if LevelChanger.current_level.level_id == level_changer.LEVEL_ID.MAIN_MENU:
					return
				var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
				var is_new: bool = not ap_stored.has(body.obj_id)
				var weight_blocking: bool = ap_client.slot_data.get("options", {}).get("dumpster_weight_blocking", false)
				if not is_new:
					body.item_in_dumpster.emit()
					node.process_item(body, false)
					return
				if weight_blocking and float(body.weight) > float(Globals.save_file.strength):
					ModLoaderLog.info("Dumpster rejected %s: weight %s > strength %s" % [body.obj_id, body.weight, Globals.save_file.strength], LOG_NAME)
					body.freeze = true
					body.set_collision_layer_value(3, false)
					body.set_collision_mask_value(1, false)
					body.set_collision_mask_value(3, false)
					body.set_collision_mask_value(4, false)
					body.set_collision_mask_value(5, false)
					var t1 = node.create_tween()
					t1.tween_property(body, "global_position", node.start_point.global_position, 0.1)
					await t1.finished
					if not is_instance_valid(body) or not is_instance_valid(node):
						return
					var t2 = node.create_tween()
					t2.tween_property(body, "global_position", node.end_point.global_position, 0.1)
					await t2.finished
					if not is_instance_valid(body) or not is_instance_valid(node):
						return
					node.animation_player.play("stuff_added")
					node.play_random_sounds()
					body.hide()
					await node.animation_player.animation_finished
					if not is_instance_valid(body) or not is_instance_valid(node):
						return
					body.freeze = false
					body.show()
					body.global_position = node.end_point.global_position
					body.apply_central_impulse((node.get_transform().basis.z * -node.dupes_forward_force) + node.dupes_directions)
					EffectsSpawner.spawn_explosion(node.global_position + Vector3.UP * 4)
					node.TEXT_SPAWN_DUPE(Vector3(0, 6, 0), "TOO HEAVY!")
					await node.get_tree().create_timer(1).timeout
					if not is_instance_valid(body) or not is_instance_valid(node):
						return
					body.set_collision_layer_value(3, true)
					body.set_collision_mask_value(1, true)
					body.set_collision_mask_value(3, true)
					body.set_collision_mask_value(4, true)
					body.set_collision_mask_value(5, true)
					return
				body.item_in_dumpster.emit()
				ap_client.item_stored(body.obj_id)
				node.process_item(body, true)
			)
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/keiTruck/stunt_tracker.gd":
		node.ready.connect(func():
			node.hit_ground.connect(func():
				ap_client.truck_score_achieved(node.score)
			)
		)

	if node.has_method("add_money"):
		node.ready.connect(func():
			var money_id: String = node.get("money_id") if node.get("money_id") != null else ""
			if not ap_client.EURO_LOCATION_IDS.has(money_id):
				return
			node.get_parent().connect("eaten_signal", func(_player):
				ap_client.euro_collected(money_id)
			)
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/cat/find_cat_quest.gd":
		node.ready.connect(func():
			node.cat.pick_signal.connect(func(_player):
				ap_client.cat_found(node.cat.obj_id)
			)
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/hats/hat_collect.gd":
		var hat_id = node.hat_id
		var location_id: int = ap_client.HAT_LOCATION_IDS.get(hat_id, 0)
		var player_collected: bool = Globals.save_file.get_meta("ap_checked_hats", []).has(location_id)
		var ap_received: bool = Globals.save_file.unlocked_hats.has(hat_id)
		if ap_received and not player_collected:
			Globals.save_file.unlocked_hats.erase(hat_id)
		node.ready.connect(func():
			if player_collected:
				if is_instance_valid(node.item_hat_data):
					node.item_hat_data.queue_free()
				return
			if ap_received and not player_collected:
				if not Globals.save_file.unlocked_hats.has(hat_id):
					Globals.save_file.unlocked_hats.append(hat_id)
			if is_instance_valid(node.item_hat_data):
				node.item_hat_data.eaten_signal.disconnect(node.found_hat)
				node.item_hat_data.eaten_signal.connect(func(_player):
					ap_client.hat_collected(hat_id)
				)
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/Jewel_One/jewel.gd":
		var jewel_flag = node.jewel_flag
		var location_id: int = ap_client.JEWEL_LOCATION_IDS.get(jewel_flag, 0)
		var player_collected: bool = Globals.save_file.get_meta("ap_checked_jewels", []).has(location_id)
		var ap_received: bool = Globals.save_file.states_occurred.has(jewel_flag)
		if ap_received and not player_collected:
			Globals.save_file.states_occurred.erase(jewel_flag)
		node.ready.connect(func():
			if player_collected:
				if is_instance_valid(node.jewel):
					node.jewel.queue_free()
				return
			if ap_received and not player_collected:
				if not Globals.save_file.states_occurred.has(jewel_flag):
					Globals.save_file.states_occurred.append(jewel_flag)
			if is_instance_valid(node.jewel):
				for conn in node.jewel.eaten_signal.get_connections():
					node.jewel.eaten_signal.disconnect(conn["callable"])
				node.jewel.eaten_signal.connect(func(_player):
					ap_client.jewel_collected(jewel_flag)
				)
		)

	# --- Shops / vehicles / Behrman Speedway ---

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/raccoon_central_station/deluxe_store.gd":
		node.ready.connect(func():
			node.dialogue_interaction_orb_seller.dialogue_closed.connect(func():
				if ap_client.connect_state != ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
					return
				var deluxe_location_id: int = ap_client.ITEM_ID_TO_AP_LOCATION[item_tracker.item_id.FUNI_RACCOON_GAME_CD]
				var hint_sent: bool = Globals.save_file.get_meta("ap_deluxe_store_hint_sent", false)
				ap_client.send_location_scouts([deluxe_location_id], 0 if hint_sent else 1)
				if not hint_sent:
					Globals.save_file.set_meta("ap_deluxe_store_hint_sent", true)
			)
		)

	# Deluxe purchase menu: replace "YOU WANT TO BUY THE DELUXE EDITION" with the
	# scouted AP item and the player it belongs to.
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Menus/funi_raccoon_delux.gd":
		if ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
			var deluxe_location_id: int = ap_client.ITEM_ID_TO_AP_LOCATION[item_tracker.item_id.FUNI_RACCOON_GAME_CD]
			var on_deluxe_info := func(location_id: int, _item_id: int, item_name: String, _game_name: String, _player_slot: int, player_name: String) -> void:
				if location_id != deluxe_location_id or not is_instance_valid(node):
					return
				var label: RichTextLabel = node.get_node_or_null("Control/Control/RichTextLabel")
				if label != null:
					var target: String = item_name
					if player_name != "":
						target = "%s FOR %s" % [item_name, player_name]
					label.text = " [wave]YOU WANT TO BUY %s" % target
			ap_client.location_info_received.connect(on_deluxe_info)
			node.tree_exiting.connect(func():
				ap_client.location_info_received.disconnect(on_deluxe_info)
			)
			ap_client.send_location_scouts([deluxe_location_id], 0)

	if node.get_script() != null:
		var path: String = node.get_script().resource_path
		if path == "res://Models/siopa_riz/siopa_riz_ui.gd":
			node.ready.connect(func():
				var shop_upgrade_labels = {
					4001: node.radio_sign,
					4002: node.jump_sign,
					4003: node.boost_sign,
				}
				var ap_sign_tex: Texture2D = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/siopa_ris_ap.png")
				for sign in shop_upgrade_labels.values():
					_apply_ap_sign_texture(sign, ap_sign_tex)
					if sign.title_rect and sign.title_rect.get_child_count() > 0:
						var title_label = sign.title_rect.get_child(0)
						if title_label.has_method("add_theme_font_size_override"):
							title_label.add_theme_font_size_override("normal_font_size", 14)
						if title_label.has_method("set_bbcode_enabled"):
							title_label.set_bbcode_enabled(true)
						if title_label.has_method("set_autowrap"):
							title_label.set_autowrap(true)
						title_label.fit_content = false
				ap_client.location_info_received.connect(func(location_id: int, item_id: int, item_name: String, game_name: String, player_slot: int, player_name: String) -> void:
					var sign = shop_upgrade_labels.get(location_id, null)
					if sign != null and is_instance_valid(sign):
						var label_text = item_name
						if player_name != "":
							label_text = "%s\nfor %s" % [item_name, player_name]
						sign.title_rect.get_child(0).text = label_text
				)
				node.animation_player.animation_finished.connect(func(anim_name: String):
					if anim_name != "enter_shop" or not node.shop_showing:
						return
					var shop_hint_sent: bool = Globals.save_file.get_meta("ap_shop_upgrade_hint_sent", false)
					if not shop_hint_sent:
						ap_client.send_location_scouts([4001, 4002, 4003], 1)
						Globals.save_file.set_meta("ap_shop_upgrade_hint_sent", true)
					else:
						ap_client.send_location_scouts([4001, 4002, 4003], 0)
					var shop_items = [
						[node.radio_sign, truck_flags.radio_purchased],
						[node.boost_sign, truck_flags.boost_purchased],
						[node.jump_sign,  truck_flags.jump_purchased],
					]
					for entry in shop_items:
						var upgrade_sign = entry[0]
						var flag: String = entry[1]
						for conn in upgrade_sign.button.pressed.get_connections():
							upgrade_sign.button.pressed.disconnect(conn["callable"])
						var check_location_id: int = ap_client.SHOP_UPGRADE_LOCATION_IDS.get(flag, 0)
						var already_checked: bool = Globals.save_file.get_meta("ap_checked_shop_upgrades", []).has(check_location_id)
						if already_checked:
							upgrade_sign.cur_state = truck_upgrade_sign.sign_states.PURCHASED
							upgrade_sign.updated_state()
						else:
							upgrade_sign.cur_state = truck_upgrade_sign.sign_states.UNLOCKED
							upgrade_sign.updated_state()
							upgrade_sign.button.disabled = false
							upgrade_sign.check.hide()
							upgrade_sign.button.pressed.connect(func():
								if Globals.save_file.get_meta("ap_checked_shop_upgrades", []).has(check_location_id):
									return
								if not Globals.remove_euro(upgrade_sign.true_price):
									upgrade_sign.poor()
									return
								node.cash_sound.play()
								node.hide_shop(Globals.get_player())
								ap_client.shop_upgrade_purchased(flag)
							)
				)
			)
		elif path == "res://Scene/Levels/kei_truck_logic.gd":
			node.ready.connect(func():
				node.interact_area_get_in.interacted.disconnect(node.turn_car_on)
				node.interact_area_get_in.interacted.connect(func(player: PlayerScript):
					if Globals.save_file.items_stored.has(item_tracker.item_id.KEI_TRUCK):
						node.turn_car_on(player)
					else:
						ModLoaderLog.info("Kei truck blocked: KEI_TRUCK not received from AP.", LOG_NAME)
				)
				if not Globals.save_file.items_stored.has(item_tracker.item_id.KEI_TRUCK):
					node.animation_player_truck.play("close")
					node.truck_lid_closed = true
					node.object_area_detect.set_collision_mask_value(3, false)
				node.truck_lid_open.connect(func():
					if Globals.save_file.items_stored.has(item_tracker.item_id.KEI_TRUCK):
						return
					if not node.truck_lid_closed:
						node.truck_lid_closed = true
				)
			)
		elif path == "res://Scene/Levels/Gully/orb_store.gd":
			node.ready.connect(func():
				node.dialogue_interaction_orb_seller.dialogue_closed.disconnect(node.show_orb_store)
				node.dialogue_interaction_orb_seller.dialogue_closed.connect(func():
					if Globals.save_file.items_stored.has(item_tracker.item_id.ORB):
						node.show_orb_store()
					else:
						ModLoaderLog.info("Orb store blocked: ORB not received from AP.", LOG_NAME)
				)
			)
		elif path == "res://Scene/Levels/BehrmanRacetrack/time_track.gd":
			node.ready.connect(func():
				node.finish.race_done.connect(func():
					if node.time <= 60.0:
						ap_client.speedway_completed()
				)
			)

	# --- Repeatable quests ---
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/hatstore/toastie_safety_zone.gd":
		Globals.save_file.states_occurred.erase(flag_names.toastie_saved_hat)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/OldBuilding/path_3d.gd":
		var owned_dilemma: Array = _hide_vehicles([SaveGame.vehicles.TONY, SaveGame.vehicles.FORKLIFT])
		node.ready.connect(func():
			_restore_vehicles(owned_dilemma)
			if is_instance_valid(node.mikk_dialogue):
				node.mikk_dialogue.dialogue_closed.disconnect(node.unlock_vehicle)
				node.mikk_dialogue.dialogue_closed.connect(func():
					if node.robin_dead:
						ap_client.vehicle_unlocked(SaveGame.vehicles.FORKLIFT)
				)
			if is_instance_valid(node.robin_dialogue):
				node.robin_dialogue.dialogue_closed.disconnect(node.unlock_tony)
				node.robin_dialogue.dialogue_closed.connect(func():
					if node.mikk_dead:
						ap_client.vehicle_unlocked(SaveGame.vehicles.TONY)
				)
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/petrol_station/area_3d_horse.gd":
		var owned_horse: Array = _hide_vehicles([node.current])
		node.ready.connect(func():
			_restore_vehicles(owned_horse)
			node.body_entered.disconnect(node.unlock_vehicle)
			node.body_entered.connect(func(_player):
				ap_client.vehicle_unlocked(node.current)
				node.queue_free()
			)
		)

	# Prevent credits from giving Tony
	if node.get_script() != null:
		var credits_path: String = node.get_script().resource_path
		if credits_path == "res://Scene/Levels/Credits/credits_spawner.gd" or credits_path == "res://Scene/Levels/ending_hypercube/end_credits.gd":
			var had_tony: bool = Globals.save_file.unlocked_vehicles.has(SaveGame.vehicles.TONY)
			node.tree_exiting.connect(func():
				if had_tony or not Globals.save_file.unlocked_vehicles.has(SaveGame.vehicles.TONY):
					return
				# The credits already saved with TONY in it, so rewrite the save too.
				Globals.save_file.unlocked_vehicles.erase(SaveGame.vehicles.TONY)
				Globals.save_game()
			)

	# --- Gacha and Trolly handling ---

	if node.scene_file_path == GACHA_MACHINE_SCENE_PATH:
		if node is InteractData:
			node.obj_id = GACHA_MACHINE_ITEM_ID
		else:
			ModLoaderLog.warning("Gacha machine root is %s, not InteractData; its check will never send." % node.get_class(), LOG_NAME)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/petrol_station/change_vehicle.gd":
		if not node.vehicles.has(TROLLEY_VEHICLE_ID):
			node.vehicles[TROLLEY_VEHICLE_ID] = load(TROLLEY_VEHICLE_SCENE_UID)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Menus/car_menu.gd":
		node.ready.connect(func():
			_add_trolley_to_car_menu(node)
		, CONNECT_ONE_SHOT)

	# --- Goals ---

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/museum/ending_controller.gd":
		node.ready.connect(func():
			node.dialogue_interact.dialogue_closed.connect(func():
				ap_client.check_goal("museum")
			)
		)

	# --- Museum display ---

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/museum/the_museum.gd":
		node.ready.connect(func():
			var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
			for child in node.get_children():
				if child.get_script() == null or child.get_script().resource_path != "res://Scene/Levels/museum/item_museum.gd":
					continue
				if child.item == null:
					continue
				var obj_id = child.item.obj_id
				if Globals.save_file.items_stored.has(obj_id) and not ap_stored.has(obj_id):
					# AP-received but not player-thrown: hide from museum
					for spawn_child in child.get_node("spawn").get_children():
						spawn_child.queue_free()
					if is_instance_valid(child.interact_area):
						child.interact_area.queue_free()
				elif ap_stored.has(obj_id) and not Globals.save_file.items_stored.has(obj_id):
					child.get_node("spawn").add_child(child.item)
					child.item.position.y = child.item.height / 2
		)

	# --- Block items/actions until received from AP ---

	if node.get_script() != null and node.get_script().resource_path == "res://Globals/item_tracker/player_stopper_office.gd":
		node.ready.connect(func():
			var blockers = node.get_node_or_null("PlayerBlockers")
			if is_instance_valid(blockers):
				blockers.queue_free()
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/Gully/gully_cooling_rod_collect.gd":
		node.ready.connect(func():
			node.body_entered.disconnect(node.cooling_rod_logic)
			node.body_entered.connect(func(body: Node3D):
				if body is InteractData:
					var stored: Array = Globals.save_file.items_stored
					if body.obj_id == item_tracker.item_id.COOLING_ROD_FRIDGE_KING and not stored.has(item_tracker.item_id.COOLING_ROD_FRIDGE_KING):
						return
					if body.obj_id == item_tracker.item_id.COOLING_ROD_PLIMBO and not stored.has(item_tracker.item_id.COOLING_ROD_PLIMBO):
						return
				node.cooling_rod_logic(body)
			)
		)

	# Mines door (requires MINES_KEY)
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/BlimboVillage/open_door.gd":
		node.ready.connect(func():
			if Globals.save_file.states_occurred.has(flag_names.mines_door_open):
				return
			node.body_entered.disconnect(node.open_door)
			node.body_entered.connect(func(obj):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.MINES_KEY):
					ModLoaderLog.info("Mines door blocked: need MINES_KEY from AP.", LOG_NAME)
					return
				node.open_door(obj)
			)
		)

	# Fridge save (requires FRIDGE_KEY)
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/fridge/fridge_logic.gd":
		node.ready.connect(func():
			node.interact_area.body_entered.disconnect(node.key_collected)
			node.interact_area.body_entered.connect(func(obj):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.FRIDGE_KEY):
					ModLoaderLog.info("Fridge blocked: need FRIDGE_KEY from AP.", LOG_NAME)
					return
				node.key_collected(obj)
			)
		)

	# ATM: only show items the player has thrown into the dumpster for checks; blocked entirely in the future
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/atm/ATMLogic.gd":
		node.ready.connect(func():
			node.interact_area.interacted.disconnect(node.show_atm_interface)
			node.interact_area.interacted.connect(func(player: PlayerScript):
				var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
				var original: Array = Globals.save_file.items_stored.duplicate()
				Globals.save_file.items_stored.clear()
				for id in ap_stored:
					if original.has(id):
						Globals.save_file.items_stored.append(id)
				await node.show_atm_interface(player)
				Globals.save_file.items_stored.clear()
				for id in original:
					Globals.save_file.items_stored.append(id)
			)
		)

	# Lugh Quests
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/SunGod/sun_god_cliff.gd":
		node.ready.connect(func():
			node.player_entered.body_entered.disconnect(node.check_what_is_in_hand)
			node.player_entered.body_entered.connect(func(body):
				var lugh_quest_locking: bool = ap_client.slot_data.get("options", {}).get("lugh_quest_locking", false)
				if lugh_quest_locking and not Globals.save_file.items_stored.has(node.item_id):
					ModLoaderLog.info("Sun god quest blocked: need %s from AP." % item_tracker.item_id.keys()[node.item_id], LOG_NAME)
					# Only speak up if the player is actually offering the quest item itself
					var offering_quest_item: bool = false
					if body is InteractData:
						offering_quest_item = (body.obj_id == node.item_id)
					elif body is PlayerScript:
						offering_quest_item = body.pickup_pivot.get_objects_in_hand_id().has(node.item_id)
					if offering_quest_item:
						DialogueManager.Dialogue_Start(
							node.sun_gawd_dialogue.profile,
							node.sun_gawd_dialogue.char_name,
							"[color=#FF0000]NO!!!!![/color] This item does not contain any power!! Its power must be found in a [rainbow][wave]mysterious Archipelago location.....[/wave][/rainbow]",
							node.sun_gawd_dialogue.voice_sound,
							node.sun_gawd_dialogue.id
						)
					return
				node.check_what_is_in_hand(body)
			)
		)

	# Pickaxe
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/pickaxe/pickaxe.gd":
		node.ready.connect(func():
			node.pickaxe.use_signal.disconnect(node.pick_axe)
			node.pickaxe.use_signal.connect(func(player):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.PICKAXE):
					ModLoaderLog.info("Pickaxe swing blocked: need PICKAXE item from AP.", LOG_NAME)
					return
				node.pick_axe(player)
			)
		)

	# Brob Energy
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/brob_energy/energy.gd":
		node.ready.connect(func():
			node.brob_energy.pick_signal.disconnect(node._on_picked_up)
			node.brob_energy.throw_signal.disconnect(node._on_throw_object)
			node.brob_energy.pick_signal.connect(func(_player):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.BROB_ENERGY):
					ModLoaderLog.info("Brob Energy blocked: BROB_ENERGY not received from AP.", LOG_NAME)
					return
				node._on_picked_up(_player)
			)
			node.brob_energy.throw_signal.connect(func(_player):
				node._on_throw_object(_player)
			)
		)

	# Goo
	if node.get_script() != null and node.get_script().resource_path == "res://Models/goo/goo_logic.gd":
		node.ready.connect(func():
			node.parent_interact.pick_signal.disconnect(node.picked_up)
			node.parent_interact.pick_signal.connect(func(player):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.GOO):
					ModLoaderLog.info("Goo bounce blocked: need GOO item from AP.", LOG_NAME)
					return
				node.picked_up(player)
			)
		)

	# Chicken
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/chicken/chicken_logic.gd":
		node.ready.connect(func():
			var chicken = node.get_parent()
			chicken.pick_signal.disconnect(node._on_chicken_pick_signal)
			chicken.pick_signal.connect(func(player):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.CHICKEN):
					ModLoaderLog.info("Chicken float blocked: need CHICKEN item from AP.", LOG_NAME)
					return
				node._on_chicken_pick_signal(player)
			)
		)

	# Butterfly
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/cliffs_of_nowher/butterFLY.gd":
		node.ready.connect(func():
			node.butterfly_mesh.pick_signal.disconnect(node.change_player_gravity)
			node.butterfly_mesh.pick_signal.connect(func(player):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.BUTTERFLY):
					ModLoaderLog.info("Butterfly float blocked: need BUTTERFLY item from AP.", LOG_NAME)
					return
				node.change_player_gravity(player)
			)
		)

# =============================================================================
# Title screen replacement
# =============================================================================

# Swaps any Texture2D property on a node for our replacement if it's a base title image.
func _replace_title_on(node: Node) -> void:
	for p in node.get_property_list():
		if int(p.get("type", TYPE_NIL)) != TYPE_OBJECT:
			continue
		var pname: String = p.get("name", "")
		if pname == "" or pname == "script" or pname == "owner":
			continue
		var val = node.get(pname)
		if not (val is Texture2D):
			continue
		# The base title images are embedded CompressedTexture2D sub-resources, so the
		# source is only visible via load_path (resource_path doesn't carry the filename).
		var id: String = val.resource_path
		var lp = val.get("load_path")
		if lp is String:
			id += " " + lp
		# Check no_bg first; "title_text_no_bg" does not contain "title_text.png".
		if id.contains("title_text_no_bg") and _title_text_no_bg_tex != null:
			node.set(pname, _title_text_no_bg_tex)
		elif id.contains("title_text.png") and _title_text_tex != null:
			node.set(pname, _title_text_tex)

func _scan_existing_title() -> void:
	for n in get_tree().root.find_children("*", "", true, false):
		_replace_title_on(n)

# =============================================================================
# Save file select screen
# =============================================================================

func _scan_existing_save_select() -> void:
	for n in get_tree().root.find_children("*", "", true, false):
		if n.get_script() != null and n.get_script().resource_path == "res://Scene/MainMenu/save_file_select_logic.gd":
			_setup_save_file_select(n)

func _setup_save_file_select(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if is_instance_valid(node.get_node_or_null("APInfoLabel")):
		return
	var ap_label := RichTextLabel.new()
	ap_label.name = "APInfoLabel"
	ap_label.bbcode_enabled = true
	ap_label.fit_content = true
	ap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_label.add_theme_color_override("default_color", Color(1, 1, 0, 1))
	ap_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	ap_label.add_theme_constant_override("shadow_offset_x", 3)
	ap_label.add_theme_constant_override("shadow_offset_y", 3)
	ap_label.add_theme_font_override("normal_font", load("res://Fonts/IBM_EGA_8x8.ttf"))
	ap_label.add_theme_font_size_override("normal_font_size", 18)
	var container := node.get_node_or_null("Centerer/Container")
	if container != null:
		ap_label.set_position(Vector2(0, 436))
		ap_label.set_size(Vector2(620, 40))
		container.add_child(ap_label)
	else:
		node.add_child(ap_label)
	for icon in node.find_children("*", "", true, false):
		if icon.get_script() == null:
			continue
		if icon.get_script().resource_path != "res://Scene/MainMenu/save_file_icon.gd":
			continue
		if not icon.has_signal("raccoon_button_focus"):
			continue
		icon.raccoon_button_focus.connect(func(icon_node):
			var raccoon_id: String = str(icon_node.get("id") if icon_node.get("id") != null else "")
			if not raccoon_id.is_empty():
				_show_ap_info(ap_label, raccoon_id)
		)

func _show_ap_info(ap_label: RichTextLabel, raccoon_name: String) -> void:
	var save_path := "user://raccoon_saves/%s_game_save.tres" % raccoon_name
	if not FileAccess.file_exists(save_path):
		save_path = "user://raccoon_saves/%s_game_saves.res" % raccoon_name
	var logo: Texture2D = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/ap_logo_80.png")
	ap_label.clear()
	if not FileAccess.file_exists(save_path):
		if logo:
			ap_label.add_image(logo, 24, 24, Color(0.5, 0.5, 0.5, 1))
			ap_label.add_text(" ")
		ap_label.push_color(Color(0.6, 0.6, 0.6, 1))
		ap_label.add_text("No Archipelago Data")
		ap_label.pop()
		return
	var save_game = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if save_game == null or not save_game.has_meta("ap_slot_name"):
		if logo:
			ap_label.add_image(logo, 24, 24, Color(0.5, 0.5, 0.5, 1))
			ap_label.add_text(" ")
		ap_label.push_color(Color(0.6, 0.6, 0.6, 1))
		ap_label.add_text("No Archipelago Data")
		ap_label.pop()
		return
	var slot_name: String = save_game.get_meta("ap_slot_name")
	var server_host: String = save_game.get_meta("ap_server_host", "")
	if logo:
		ap_label.add_image(logo, 24, 24)
		ap_label.add_text(" ")
	ap_label.push_color(Color(1, 1, 0, 1))
	ap_label.add_text("%s" % slot_name)
	ap_label.pop()
	if server_host != "":
		ap_label.add_text("\n")
		ap_label.push_color(Color(0.7, 0.7, 0.7, 1))
		ap_label.add_text(server_host)
		ap_label.pop()

# =============================================================================
# Pause menu
# =============================================================================

func _on_quit_pressed() -> void:
	ModLoaderLog.info("Quit pressed, disconnecting from AP.", LOG_NAME)
	if ap_client:
		ap_client.disconnect_from_multiworld()

func _add_rackheath_pause_option(quit_button: Node) -> void:
	if not is_instance_valid(quit_button):
		return
	# Don't offer "To Rackheath" while already in Rackheath.
	if LevelChanger.current_level != null and LevelChanger.current_level.level_id == level_changer.LEVEL_ID.DEFAULT:
		return
	var parent = quit_button.get_parent()
	if parent == null or parent.has_node("RackheathOption"):
		return

	# Clone the Quit button so we inherit its styling; drop signals/script so its
	# quit behaviour isn't copied.
	var btn = quit_button.duplicate(DUPLICATE_GROUPS)
	btn.name = "RackheathOption"
	btn.set_script(null)
	if "text" in btn:
		btn.text = "To Rackheath"
	for lbl in btn.find_children("*", "Label", true, false):
		lbl.text = "To Rackheath"
	for lbl in btn.find_children("*", "RichTextLabel", true, false):
		lbl.text = "To Rackheath"
	parent.add_child(btn)
	parent.move_child(btn, quit_button.get_index())

	if not (parent is Container) and quit_button is Control and btn is Control:
		btn.position = quit_button.position - Vector2(0, quit_button.size.y + 8)

	if not btn.has_signal("pressed"):
		ModLoaderLog.warning("Rackheath pause option: cloned button has no 'pressed' signal.", LOG_NAME)
		return
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])
	btn.pressed.connect(func():
		if Globals.save_file == null:
			return
		if LevelChanger.current_level != null and LevelChanger.current_level.level_id == level_changer.LEVEL_ID.DEFAULT:
			return
		ModLoaderLog.info("Pause menu: loading Rackheath (DEFAULT).", LOG_NAME)
		# Close the pause menu and unpause so the level transition plays normally.
		var menu := _find_pause_menu_root(btn)
		if is_instance_valid(menu):
			menu.queue_free()
		MenuController.menus_transiting = false
		get_tree().paused = false
		LevelChanger.LOAD_FROM_LEVEL_WITH_SHORT_ID(level_changer.LEVEL_ID.DEFAULT, Globals.player_inst, "START_SPAWN")
	)
	ModLoaderLog.success("Rackheath pause option added under '%s'." % parent.name, LOG_NAME)

func _find_pause_menu_root(from: Node) -> Node:
	var n: Node = from
	while n != null:
		var s = n.get_script()
		if s != null and "pause_menu" in s.resource_path:
			return n
		n = n.get_parent()
	return null

# =============================================================================
# Player menu UI (objectives list / items-left counter)
# =============================================================================

func _ap_rebuild_objectives_list(node: Node) -> void:
	# The captured node can be freed before this deferred ready callback runs (e.g.
	# opening/closing the menu quickly), arriving here as null.
	if not is_instance_valid(node):
		return
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	var ITEM_LIST_ITEM = load("res://Scene/Menus/item_list_item.tscn")
	var v_box_container: VBoxContainer = node.get_node("Control/VBoxContainer")

	for child in v_box_container.get_children():
		child.queue_free()

	var current_world = Globals.get_current_world()
	if current_world == null:
		return
	var level_items = current_world.get("items_in_levels")
	if level_items == null or not (level_items is Array):
		return

	var items_in_level: Dictionary = {}
	for item_id in level_items as Array[item_tracker.item_id]:
		if not ItemTacker.item_list_data.has(item_id):
			continue
		# Only list items that are actual AP checks; skip non-randomized level items.
		if not ap_client.ITEM_ID_TO_AP_LOCATION.has(item_id):
			continue
		var item_inst: InteractData = _instantiate_item(item_id)
		if item_inst == null:
			continue
		if item_inst.item_list_ignore:
			item_inst.queue_free()
			continue
		items_in_level[item_id] = [item_inst.obj_name, item_inst.hud_icon]
		item_inst.queue_free()

	if items_in_level.is_empty():
		return

	var items_listed: Array = []
	var total_sent: int = 0

	for key in items_in_level.keys():
		if items_listed.has(key):
			continue
		var item_sent: bool = ap_stored.has(key)
		if item_sent:
			total_sent += 1
		items_listed.append(key)
		var item_menu = ITEM_LIST_ITEM.instantiate()
		v_box_container.add_child(item_menu)
		if not Globals.save_file.items_found.has(key) and not Globals.save_file.items_stored.has(key):
			item_menu.populate("???????", items_in_level[key][1])
		else:
			item_menu.populate(items_in_level[key][0], items_in_level[key][1], item_sent)
		var scribble = item_menu.get_node_or_null("Label/Scribble")
		if scribble != null:
			scribble.visible = item_sent

	var complete = node.get_node_or_null("../../position/complete")
	if complete != null:
		if total_sent == items_in_level.keys().size():
			complete.show()
			var ap = complete.get_node_or_null("AnimationPlayer")
			if ap:
				ap.play("show")
		else:
			complete.hide()

func _ap_fix_items_left_counter(node: Node) -> void:
	# The captured node can be freed before this deferred ready callback runs.
	if not is_instance_valid(node):
		return
	var current_world = Globals.get_current_world()
	if current_world == null:
		return
	var level_items = current_world.get("items_in_levels")
	if level_items == null or not (level_items is Array):
		return
	if not LevelChanger.all_levels.has(current_world.level_id):
		return
	var item_info = node.get_node_or_null("Container/SubViewport/CanvasLayer")
	if item_info == null or not item_info.has_method("items_left"):
		return
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	# Count only items that are actual AP checks, to match the filtered list.
	var total: int = 0
	for item_id in level_items:
		if ItemTacker.item_list_data.has(item_id) and ap_client.ITEM_ID_TO_AP_LOCATION.has(item_id):
			total += 1
	var level_name: String = LevelChanger.all_levels[current_world.level_id].level_name
	var grid = node.get_node_or_null("Control/Grid")
	var grid_idx: int = 0
	var count: int = 0
	var info_label = item_info.get_node_or_null("Control/VBoxContainer/info")
	for item_id in level_items:
		if not ItemTacker.item_list_data.has(item_id):
			continue
		await node.get_tree().create_timer(0.1, true, false, true).timeout
		if not is_instance_valid(node):
			return
		var is_check: bool = ap_client.ITEM_ID_TO_AP_LOCATION.has(item_id)
		if is_check and ap_stored.has(item_id):
			count += 1
		item_info.items_left(count, total, level_name)
		if info_label != null:
			info_label.text = str(count) + "/" + str(total) + " checks\nsent"
		if grid != null:
			var grid_children: Array = grid.get_children()
			if grid_idx < grid_children.size():
				var icon = grid_children[grid_idx]
				if not is_check:
					# Non-check item: hide its icon so the grid only shows checks.
					icon.visible = false
				elif icon.has_method("set_val"):
					var item_inst: InteractData = _instantiate_item(item_id)
					if item_inst != null:
						icon.set_val(item_inst.hud_icon, Globals.save_file.items_found.has(item_id), ap_stored.has(item_id))
						item_inst.queue_free()
		grid_idx += 1

# Shop signs idle on frame 0 of their spin sheet; show the AP sign image while a
# sign is unfocused and restore the vanilla spin sheet while it is focused. The AP
# image (262x450) is scaled so its height matches the sheet's 250px frames.
func _apply_ap_sign_texture(upgrade_sign, ap_tex: Texture2D) -> void:
	if ap_tex == null or not is_instance_valid(upgrade_sign) or not is_instance_valid(upgrade_sign.item_sprite):
		return
	var sprite: AnimatedSprite2D = upgrade_sign.item_sprite
	var spin_frames: SpriteFrames = sprite.sprite_frames
	var spin_scale: Vector2 = sprite.scale
	# Fixed reference height because the signs are different sizes
	var ap_frames := SpriteFrames.new()
	ap_frames.add_frame("default", ap_tex)
	var ap_scale: Vector2 = spin_scale * (250.0 / float(ap_tex.get_height()))
	sprite.sprite_frames = ap_frames
	sprite.scale = ap_scale
	# Runs after the sign's own toggle_spin (connected in its _ready), so the
	# play/stop it did on the wrong SpriteFrames is redone on the right one here.
	upgrade_sign.button.focus_entered.connect(func():
		sprite.sprite_frames = spin_frames
		sprite.scale = spin_scale
		sprite.play("default")
	)
	upgrade_sign.button.focus_exited.connect(func():
		sprite.stop()
		sprite.sprite_frames = ap_frames
		sprite.scale = ap_scale
	)

# Blacks out a held-item icon until the real item arrives from the multiworld
# (items_stored) or our own check for it has been sent (ap_stored_items).
# Safe to call from signals that outlive the icon.
func _update_object_icon_blackout(icon: Node) -> void:
	if not is_instance_valid(icon):
		return
	if ap_client.connect_state != ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	if not ap_client.ITEM_ID_TO_AP_LOCATION.has(icon.icon_id) or not BLACKOUT_ITEMS.has(icon.icon_id):
		return
	var items_stored: Array = Globals.save_file.items_stored
	icon.modulate = Color.WHITE if items_stored.has(icon.icon_id) else Color.BLACK

# =============================================================================
# Debug helpers
# =============================================================================

# dump every level the cluster orb is about to draw, with its icon and found state for debugging
func _log_cluster_levels(cluster_id) -> void:
	if cluster_id == null:
		ModLoaderLog.warning("Cluster orb added but level_cluster_id is null.", LOG_NAME)
		return
	ModLoaderLog.info("=== Cluster %s orb building. Levels in cluster: ===" % str(cluster_id), LOG_NAME)
	for level_id in LevelChanger.all_levels:
		var info = LevelChanger.all_levels[level_id]
		if info == null or info.level_cluster != cluster_id:
			continue
		if not info.level_found:
			continue
		var icon = info.level_icon
		var icon_kind: String = "null"
		if icon != null:
			icon_kind = "PackedScene" if icon is PackedScene else ("Texture" if icon is Texture2D else icon.get_class())
		ModLoaderLog.info(
			"  level=%s found=%s icon=%s [%s]" % [
				str(level_id), str(info.level_found), str(icon), icon_kind
			],
			LOG_NAME
		)
	ModLoaderLog.info("=== end cluster %s level list ===" % str(cluster_id), LOG_NAME)

# Build the trolley's entry in the vehicle selector
func _add_trolley_to_car_menu(menu: Node) -> void:
	var trolley_id: int = TROLLEY_VEHICLE_ID
	if menu.vehicles.has(trolley_id):
		return
	var spin: Node3D = menu.get_node_or_null("vehicleContainer/Spin")
	if spin == null:
		ModLoaderLog.warning("Car menu has no vehicleContainer/Spin; skipping trolley.", LOG_NAME)
		return

	var source: Node = (load(TROLLEY_VEHICLE_SCENE_UID) as PackedScene).instantiate()
	var model: Node3D = source.get_node_or_null("Vehicle/kei_truck_new/body/trolly")
	if model == null:
		ModLoaderLog.warning("Trolley scene has no body/trolly mesh; skipping trolley.", LOG_NAME)
		source.free()
		return

	var rider: Node = model.get_node_or_null("RaccoonMesh")
	if rider != null:
		model.remove_child(rider)
		rider.free()

	model.get_parent().remove_child(model)
	source.free()

	model.name = "trolly"
	model.transform = Transform3D.IDENTITY
	spin.add_child(model)

	var reference: Node3D = menu.vehicles.get(SaveGame.vehicles.KEI_TRUCK)
	var layers: int = 0
	for vis in _visual_instances(reference):
		layers = vis.layers
		break
	if layers != 0:
		for vis in _visual_instances(model):
			vis.layers = layers
	else:
		ModLoaderLog.warning("Could not read the car menu's render layer; trolley may be invisible.", LOG_NAME)

	if reference != null:
		var want: AABB = _visual_bounds(reference, spin)
		var got: AABB = _visual_bounds(model, spin)
		var want_span: float = maxf(want.size.x, maxf(want.size.y, want.size.z))
		var got_span: float = maxf(got.size.x, maxf(got.size.y, got.size.z))
		if got_span > 0.0 and want_span > 0.0:
			var k: float = (want_span / got_span) * TROLLEY_MENU_SCALE
			var origin: Vector3 = want.get_center() - got.get_center() * k
			origin.y += got.size.y * k * TROLLEY_MENU_LIFT
			model.transform = Transform3D(Basis().scaled(Vector3.ONE * k), origin)

	model.hide()
	menu.vehicles[trolley_id] = model

	var data := car_resource.new()
	data.car_dialogue = "[shake]THE VEHICLE NOT AVAILABLE IN THE BASE GAME\nA FULL BLOWN ARCHIPELAGO EXCLUSIVE!!!![/shake]"
	data.car_logo = load(TROLLEY_LOGO_UID)
	menu.vehicle_data[trolley_id] = data
	ModLoaderLog.info("Added the trolley to the vehicle selector as id %d." % trolley_id, LOG_NAME)

func _visual_instances(root: Node) -> Array:
	var found: Array = []
	if root == null:
		return found
	var stack: Array = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.push_back(child)
		if current is VisualInstance3D:
			found.append(current)
	return found

# Combined bounds of every mesh under `node`, in `space`'s local frame.
func _visual_bounds(node: Node3D, space: Node3D) -> AABB:
	var to_space: Transform3D = space.global_transform.affine_inverse()
	var bounds: AABB = AABB()
	var found: bool = false
	for vis in _visual_instances(node):
		var box: AABB = (to_space * vis.global_transform) * vis.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	return bounds
