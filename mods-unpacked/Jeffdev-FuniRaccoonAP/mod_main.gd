extends Node

const MOD_NAME = "Jeffdev-FuniRaccoonAP"
const MOD_VERSION = "0.1.0"
const LOG_NAME = MOD_NAME + "/mod_main"
const CONFIG_PATH = "user://ap_connect.json"

var ap_websocket_connection
var ap_client

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

	ModLoaderLog.success("AP client ready v%s" % MOD_VERSION, LOG_NAME)
		
	var ApConnectPanelScript = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_connect_panel.tscn")
	var connect_panel = ApConnectPanelScript.instantiate()
	connect_panel.ap_client = ap_client
	add_child(connect_panel)
	
	get_tree().node_added.connect(_on_node_added)

	LevelChanger.level_Changed.connect(func(level_id: level_changer.LEVEL_ID):
		if level_id == level_changer.LEVEL_ID.CREDITS_LEVEL:
			ap_client.check_goal()
	)

func _on_node_added(node: Node) -> void:
	if node.name == "Quit" and node.get_script() != null:
		if node.get_script().resource_path == "res://Scene/Menus/quit_menu.gd":
			ModLoaderLog.info("Found quit button, connecting pressed signal.", LOG_NAME)
			node.pressed.connect(_on_quit_pressed)

	if node.get_script() != null and node.get_script().resource_path == "res://Scripts/levels/player_level_change.gd":
		node.ready.connect(func():
			node.body_entered.disconnect(node._on_body_entered)
			node.body_entered.connect(func(body):
				if body is PlayerScript and not node.random:
					var level_id = node.level_id
					var LevelAccessGuard = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd")
					var required: int = LevelAccessGuard.get_required_for_level(level_id)
					var have: int = Globals.save_file.get_meta("ap_received_item_index", 0)
					if have < required or not LevelAccessGuard.item_requirement_met(level_id):
						ModLoaderLog.info(
							"Transition to %s blocked: need %d items, have %d." % [
								level_changer.LEVEL_ID.keys()[level_id], required, have
							],
							LOG_NAME
						)
						return
				node._on_body_entered(body)
			)
		)

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

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/keiTruck/stunt_tracker.gd":
		node.ready.connect(func():
			node.hit_ground.connect(func():
				ap_client.truck_score_achieved(node.score)
			)
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Globals/item_tracker/player_stopper_office.gd":
		node.ready.connect(func():
			var blockers = node.get_node_or_null("PlayerBlockers")
			if is_instance_valid(blockers):
				blockers.queue_free()
		)

	if node.get_script() != null and node.get_script().resource_path == "res://Scene/LevelSelectOrb/level_select_orb.gd":
		node.ready.connect(func():
			var player = Globals.get_player()
			if is_instance_valid(player):
				var pickup = player.get_node_or_null("pivotCotainer/PickupPivot")
				if pickup != null:
					for obj in pickup.get_children():
						obj.queue_free()
					player.holding = false
					player.carrying_weight = 0
					if pickup.menu_updater != null:
						pickup.menu_updater.remove_object_icons()

			node.set_process_input(false)
			var guard = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd").new()
			guard._orb = node
			node.add_child(guard)
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
				body.item_in_dumpster.emit()
				var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
				var is_new: bool = not ap_stored.has(body.obj_id)
				if is_new:
					ap_client.item_stored(body.obj_id)
				node.process_item(body, is_new)
			)
			node.player_area_detect.body_exited.connect(func(body: Node3D):
				if body is PlayerScript:
					var pickup = body.get_node_or_null("pivotCotainer/PickupPivot")
					if pickup is pickup_logic:
						pickup.Delete_Items_In_Hand()
			)
		)

	if node.get_script() != null:
		var path: String = node.get_script().resource_path
		if path == "res://Models/siopa_riz/siopa_riz_ui.gd":
			node.ready.connect(func():
				node.animation_player.animation_finished.connect(func(anim_name: String):
					if anim_name != "enter_shop" or not node.shop_showing:
						return
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

	# Turn off the dumpster item spawner in the future
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Levels/hub_world/item_spawner.gd" and Globals.save_file.is_the_future:
		node.set_script(null)

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
			if ap_received and not player_collected:
				if not Globals.save_file.unlocked_hats.has(hat_id):
					Globals.save_file.unlocked_hats.append(hat_id)
			if is_instance_valid(node.item_hat_data):
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
			if ap_received and not player_collected:
				if not Globals.save_file.states_occurred.has(jewel_flag):
					Globals.save_file.states_occurred.append(jewel_flag)
			if is_instance_valid(node.jewel):
				node.jewel.eaten_signal.connect(func(_player):
					ap_client.jewel_collected(jewel_flag)
				)
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

	# Crisp undying love sideplot
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/crisp/CrispLogic.gd":
		node.ready.connect(func():
			var crisp_script = node.get_script()
			node.windmill_detector.area_entered.disconnect(node.real_windmill_detected)
			node.windmill_detector.area_entered.connect(func(area):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.CRISP):
					ModLoaderLog.info("Crisp sideplot blocked: need CRISP item from AP.", LOG_NAME)
					return
				crisp_script.real_windmill_detected(area)
			)
		)

	# Lugh Sun Quests
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/SunGod/sun_god_cliff.gd":
		node.ready.connect(func():
			node.player_entered.body_entered.disconnect(node.check_what_is_in_hand)
			node.player_entered.body_entered.connect(func(body):
				if not Globals.save_file.items_stored.has(node.item_id):
					ModLoaderLog.info("Sun god quest blocked: need %s from AP." % item_tracker.item_id.keys()[node.item_id], LOG_NAME)
					return
				node.check_what_is_in_hand(body)
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

	# ATM (blocked in act 4 dumpster)
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/atm/ATMLogic.gd":
		node.ready.connect(func():
			node.interact_area.interacted.disconnect(node.show_atm_interface)
			node.interact_area.interacted.connect(func(player: PlayerScript):
				if Globals.save_file.is_the_future:
					ModLoaderLog.info("ATM blocked: cannot use ATM in dumpster level.", LOG_NAME)
					return
				node.show_atm_interface(player)
			)
		)

	# Block Items until they are received

	# Priestess church construction
	if node.get_script() != null and node.get_script().resource_path == "res://Models/priest/preist_logic.gd":
		node.ready.connect(func():
			var priestess_script = node.get_script()
			node.interact_area.interacted.disconnect(node.play_talk)
			node.interact_area.interacted.connect(func(player):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.PRIESTESS):
					ModLoaderLog.info("Priestess church blocked: need PRIESTESS item from AP.", LOG_NAME)
					return
				priestess_script.play_talk(player)
			)
		)

	# Vending Machine
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/vending_machine/VendingMachine.gd":
		node.ready.connect(func():
			var root = node.get_parent()
			var area = root.get_node_or_null("Area3D")
			if is_instance_valid(area):
				area.body_entered.disconnect(node._on_area_3d_body_entered)
				var _item_tracker = item_tracker
				area.body_entered.connect(func(body: Node3D):
					if not Globals.save_file.items_stored.has(_item_tracker.item_id.VENDING_MACHINE):
						ModLoaderLog.info("Vending machine (coin slot) blocked: VENDING_MACHINE not received from AP.", LOG_NAME)
						return
					node._on_area_3d_body_entered(body)
				)
		)

	# Gun
	if node.get_script() != null and node.get_script().resource_path == "res://Scene/Objects/gun/gun_logic.gd":
		node.ready.connect(func():
			var gun_script = node.get_script()
			node.a_gun.use_signal.disconnect(node._on_a_gun_use_signal)
			node.a_gun.use_signal.connect(func(player):
				if not Globals.save_file.items_stored.has(item_tracker.item_id.GUN):
					ModLoaderLog.info("Gun blocked: need GUN item from AP.", LOG_NAME)
					return
				gun_script._on_a_gun_use_signal(player)
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


func _on_quit_pressed() -> void:
	ModLoaderLog.info("Quit pressed, disconnecting from AP.", LOG_NAME)
	if ap_client:
		ap_client.disconnect_from_multiworld()
