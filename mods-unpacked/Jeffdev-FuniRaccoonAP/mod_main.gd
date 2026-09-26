extends Node

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")
const ApChatPopup = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
const LevelAccessGuard = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd")
const MOD_NAME = "Jeffdev-FuniRaccoonAP"
const CONFIG_PATH = "user://ap_connect.json"

# Scenes the mod has to reach for by uid, because the game never names them.
const GACHA_MACHINE_SCENE_PATH := "res://Scene/Objects/GachaMachine/gacha_machine.tscn"
const MONITOR_SOUND_SCENES: Array[String] = [
	"res://Scene/Menus/settings/settins_menu.tscn",
	"res://Scene/Menus/setup/setup_menu.tscn",
]
const MAIN_MENU_SCENE_PATH := "res://Scene/MainMenu/MainMenu.tscn"
const MAIN_MENU_TITLE_NODES: Array[String] = ["Title", "Title/Title2"]
const TRASCO_TRAIN_SCENE_PATH := "res://Scene/Levels/inside_train/inside_train_TRASCO.tscn"
const GACHA_MACHINE_SCENE_UID := "uid://bevwwjw1owksw"
const TROLLEY_VEHICLE_SCENE_UID := "uid://b4skd2o7aix7d"

const TRACKER_KEY = KEY_F1
const SETTINGS_SWAPPING_SCRIPT = "res://Scene/Menus/settings/Settings_Swapping.gd"
const MONITOR_SOUND = "res://Audio/SoundEffects/computer/facuarmo__286-startup.ogg"
const META_MONITOR_SOUND_MUTED = "ap_monitor_sound_muted"

const EXTRA_LEVEL_ITEMS := {
	"res://Scene/Levels/petrol_station/petrol_station.tscn": [item_tracker.item_id.LIGHTNING_ROD, 185], # Gacha Machine
	"res://Scene/Levels/inside_the_machine/inside_the_machine.tscn": [item_tracker.item_id.GOO],
	"res://Scene/Levels/cave/caves.tscn": [item_tracker.item_id.MICHI_CAT],
	"res://Scene/Levels/BlimboCity/BlimboCity.tscn": [item_tracker.item_id.PATRICK_OHARA, item_tracker.item_id.APPLE],
	"res://Scene/Levels/Norwich/norwich.tscn": [item_tracker.item_id.HINTBLO],
	"res://Scene/Levels/museum/the_museum.tscn": [item_tracker.item_id.HINTBLO],
	"res://Scene/Levels/TheFactory/TheFactory.tscn": [item_tracker.item_id.HINTBLO]
}

# Unused/unnamed content ids we have to manually name here
const GACHA_MACHINE_ITEM_ID := 185
const TROLLEY_VEHICLE_ID := 5

var ap_websocket_connection
var ap_client: ApClient
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

# Also called by the ATM and gacha machine extensions.
func instantiate_item(item_id) -> InteractData:
	var packed: PackedScene = _load_item_scene(item_id)
	if packed == null:
		return null
	var inst = packed.instantiate()
	if inst is InteractData:
		return inst
	if inst != null:
		inst.queue_free()
	return null

# Called by the path_3d.gd and area_3d_horse.gd extensions.
func hide_vehicles(vehicles: Array) -> Array:
	var owned: Array = []
	for vehicle in vehicles:
		if Globals.save_file.unlocked_vehicles.has(vehicle):
			owned.append(vehicle)
			Globals.save_file.unlocked_vehicles.erase(vehicle)
	return owned

func restore_vehicles(owned: Array) -> void:
	for vehicle in owned:
		if not Globals.save_file.unlocked_vehicles.has(vehicle):
			Globals.save_file.unlocked_vehicles.append(vehicle)

# =============================================================================
# Startup things
# =============================================================================

var _paths_taken_over: Array[Resource] = []

func _take_over_path(vanilla_path: String, mod_path: String) -> void:
	var res: Resource = load(mod_path)
	res.take_over_path(vanilla_path)
	_paths_taken_over.append(res)

func _init() -> void:
	# Install extensions
	for extension_path in _find_scripts(ModLoaderMod.get_unpacked_dir().path_join(MOD_NAME).path_join("extensions")):
		ModLoaderMod.install_script_extension(extension_path)
	# A few things have to be refreshed due to loading early
	for scene_path in [
		"res://Scene/Player Stuff/ui/object_icon.tscn",
		"res://Scene/Objects/money/money.tscn",
		"res://Scene/Objects/brob_energy/brob_energy.tscn",
		"res://Scene/Menus/setup/store_page.tscn",
		"res://Scene/Menus/funiRaccoonDelux.tscn",
		"res://Scene/Player Stuff/menu/items_left_new.tscn",
		"res://Scene/Menus/pause_menu.tscn",
	]:
		ModLoaderMod.refresh_scene(scene_path)

	_take_over_path("res://Sprites/title_text.png", "res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/title_text.png")
	_take_over_path("res://Sprites/title_text_no_bg.png", "res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/title_text_no_bg.png")
	_take_over_path("res://Scene/Menus/settings/settings_seg_audio.tscn", "res://mods-unpacked/Jeffdev-FuniRaccoonAP/scenes/settings_seg_audio.tscn")

	# The gacha machine is an item the game never gives an id or registers.
	ModLoaderMod.extend_scene(GACHA_MACHINE_SCENE_PATH, func(root: Node) -> Node:
		root.obj_id = GACHA_MACHINE_ITEM_ID
		return root)

	ModLoaderMod.extend_scene(MAIN_MENU_SCENE_PATH, func(root: Node) -> Node:
		var title_tex: Texture2D = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/title_text_no_bg.png")
		for node_path in MAIN_MENU_TITLE_NODES:
			root.get_node(node_path).texture = title_tex
		return root)

	ModLoaderMod.extend_scene("res://Scene/Levels/BlimboVillage/BlimboVillage.tscn", func(root: Node) -> Node:
		root.items_in_levels.erase(item_tracker.item_id.BUISNESS_MAN)
		return root)

	for scene_path in EXTRA_LEVEL_ITEMS:
		var extra: Array = EXTRA_LEVEL_ITEMS[scene_path]
		ModLoaderMod.extend_scene(scene_path, func(root: Node) -> Node:
			for id in extra:
				if not root.items_in_levels.has(id):
					root.items_in_levels.append(id)
			return root)


func _find_scripts(dir_path: String) -> Array[String]:
	var scripts: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "gd":
			scripts.append(dir_path.path_join(file))
	for sub_dir in DirAccess.get_directories_at(dir_path):
		scripts.append_array(_find_scripts(dir_path.path_join(sub_dir)))
	return scripts

func _ready() -> void:
	# Has to load after some of the other ones, this loads it after _init
	_take_over_path("res://Scene/photobooth/photobooth.tscn", "res://mods-unpacked/Jeffdev-FuniRaccoonAP/scenes/photobooth.tscn")
	# Defer setup until all the autoloads are ready
	_setup.call_deferred()

func _setup() -> void:
	var config_data = {"ap_server": "", "ap_player": "", "ap_password": ""}

	if FileAccess.file_exists(CONFIG_PATH):
		var f = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed and typeof(parsed) == TYPE_DICTIONARY:
				config_data = parsed
				ModLoaderLog.info("Loaded config from %s" % CONFIG_PATH, MOD_NAME)
			else:
				ModLoaderLog.warning("Failed to parse config at %s" % CONFIG_PATH, MOD_NAME)
		else:
			ModLoaderLog.warning("Could not open config file at %s" % CONFIG_PATH, MOD_NAME)
	else:
		ModLoaderLog.info("No config file found at %s, skipping auto-connect." % CONFIG_PATH, MOD_NAME)

	var ApWebSocketConnectionScript = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/ap_websocket_connection.gd")

	ap_websocket_connection = ApWebSocketConnectionScript.new()
	add_child(ap_websocket_connection)
	var client_config = {
		"ap_server": config_data.get("ap_server", ""),
		"ap_player": config_data.get("ap_player", ""),
		"ap_password": config_data.get("ap_password", ""),
	}
	ap_client = ApClient.new(ap_websocket_connection, client_config)
	add_child(ap_client)

	ItemTacker.item_list_data[GACHA_MACHINE_ITEM_ID] = GACHA_MACHINE_SCENE_UID

	ModLoaderLog.success("AP client ready v%s" % ModLoaderMod.get_mod_data(MOD_NAME).manifest.version_number, MOD_NAME)

	var ApConnectPanelScript = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_connect_panel.tscn")
	connect_panel = ApConnectPanelScript.instantiate()
	connect_panel.ap_client = ap_client
	add_child(connect_panel)
	get_tree().node_added.connect(_on_node_added)

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
	# I have to do this here otherwise things get loaded too quickly in the autoloads and it freaks out
	if node is level_teleporter:
		node.ready.connect(func():
			node.body_entered.disconnect(node._on_body_entered)
			node.body_entered.connect(_ap_on_body_entered.bind(node)), CONNECT_ONE_SHOT)

	var in_settings_menu: bool = node.owner != null and MONITOR_SOUND_SCENES.has(node.owner.scene_file_path)
	if in_settings_menu and is_monitor_sound(node) and Globals.save_file.get_meta(META_MONITOR_SOUND_MUTED, false):
		node.stop()

	if node is InteractData and node.obj_name == "CHEESE" and node.obj_id == item_tracker.item_id.DEFAULT:
		node.obj_id = item_tracker.item_id.CHEESE

func _ap_on_body_entered(body, teleporter: level_teleporter) -> void:
	if teleporter.random and body is PlayerScript:
		_random_teleport(body, teleporter)
		return
	if not teleporter.random:
		var level_id = teleporter.level_id
		var required: int = LevelAccessGuard.get_required_for_level(level_id)
		var have: int = Globals.save_file.items_stored.size()
		var connected: bool = ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD
		if not connected or have < required or not LevelAccessGuard.item_requirement_met(level_id):
			ApChatPopup.show_message(LevelAccessGuard.locked_message(level_id, connected, have), get_tree().get_root())
			return
	teleporter._on_body_entered(body)

# Modified version of random teleport that removes the 1% chance for cricket
func _random_teleport(body, teleporter: level_teleporter) -> void:
	var pool: Array
	if Globals.save_file.is_the_future:
		pool = teleporter.future_level_id.duplicate()
	else:
		pool = Globals.save_file.found_levels
	if pool.is_empty():
		pool = [LevelChanger.LEVEL_ID.MAIN_MENU]
	LevelChanger.CHANGE_LEVEL(LevelChanger.get_level_resource(pool.pick_random()).level_container, body, teleporter.level_spawn_name, teleporter.level_transition_effect)

# Called by the Dumpster.gd and dumpster_special_ending.gd extensions.
func dumpster_handling(node: Node, body: InteractData) -> void:
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
		ModLoaderLog.info("Dumpster rejected %s: weight %s > strength %s" % [body.obj_id, body.weight, Globals.save_file.strength], MOD_NAME)
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
		if node.has_method("TEXT_SPAWN_DUPE"):
			node.TEXT_SPAWN_DUPE(Vector3(0, 6, 0), "TOO HEAVY!")
		else:
			node.TEXT_SPAWN(Vector3(0, 3.5, 0), "TOO HEAVY!")
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

# =============================================================================
# AP Settings
# =============================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TRACKER_KEY:
		open_tracker()

func open_tracker() -> void:
	if MenuController.game_paused or MenuController.menus_transiting or not MenuController.menus_enabled:
		return
	load(SETTINGS_SWAPPING_SCRIPT).open_ap_tab_next = true
	MenuController.game_paused = true
	MenuController.set_pause_state(true)
	MenuController.show_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

static func is_monitor_sound(node: Node) -> bool:
	return node is AudioStreamPlayer and node.stream != null and node.stream.resource_path == MONITOR_SOUND

# =============================================================================
# Title screen replacement
# =============================================================================

func _replace_title_on(node: Node) -> void:
	if not (node is TextureRect or node is Sprite2D or node is Sprite3D):
		return
	var tex: Texture2D = node.texture
	if tex == null:
		return
	var id: String = tex.resource_path
	var load_path = tex.get("load_path")
	if load_path is String:
		id += " " + load_path
	if id.contains("title_text_no_bg") and _title_text_no_bg_tex != null:
		node.texture = _title_text_no_bg_tex
	elif id.contains("title_text.png") and _title_text_tex != null:
		node.texture = _title_text_tex

func _scan_existing_title() -> void:
	for n in get_tree().root.find_children("*", "", true, false):
		_replace_title_on(n)
