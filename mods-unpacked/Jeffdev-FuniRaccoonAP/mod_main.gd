extends Node

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")
const ApChatPopup = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
const MOD_NAME = "Jeffdev-FuniRaccoonAP"
const CONFIG_PATH = "user://ap_connect.json"

# Scenes the mod has to reach for by uid, because the game never names them.
const GACHA_MACHINE_SCENE_PATH := "res://Scene/Objects/GachaMachine/gacha_machine.tscn"
const MONITOR_SOUND_SCENES: Array[String] = [
	"res://Scene/Menus/settings/settins_menu.tscn",
	"res://Scene/Menus/setup/setup_menu.tscn",
]
const GACHA_MACHINE_SCENE_UID := "uid://bevwwjw1owksw"
const TROLLEY_VEHICLE_SCENE_UID := "uid://b4skd2o7aix7d"

# Ids the game has no enum entry for: item_tracker.item_id stops at ROBIN = 184 and
# SaveGame.vehicles stops at HORSE = 4, so the mod assigns these itself.
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

func _register_gacha_machine_item() -> void:
	var item_id: int = GACHA_MACHINE_ITEM_ID
	if ItemTacker.item_list_data.has(item_id):
		return
	# item_list_data is typed Dictionary[item_id, String], so this must be the uid
	ItemTacker.item_list_data[item_id] = GACHA_MACHINE_SCENE_UID
	ModLoaderLog.info("Registered gacha machine with ItemTacker as id %d." % item_id, MOD_NAME)

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

func _init() -> void:
	# Every script under extensions/ extends the game script at the same relative path,
	# so installing them all is just a matter of finding them.
	for extension_path in _find_scripts(ModLoaderMod.get_unpacked_dir().path_join(MOD_NAME).path_join("extensions")):
		ModLoaderMod.install_script_extension(extension_path)
	# The game's autoloads preload these scenes before ModLoader runs, so they still
	# hold the vanilla scripts. Refresh each scene that directly uses an extended script.
	for scene_path in [
		"res://Scene/MainMenu/SaveFileSelect.tscn",
		"res://Scene/Menus/setup/store_page.tscn",
		"res://Scene/Menus/pause_menu.tscn",
		"res://Scene/Menus/settings/loading_page.tscn",
		"res://Scene/Player Stuff/menu/items_left_new.tscn",
		"res://Scene/Player Stuff/ui/object_icon.tscn",
		"res://Scene/Menus/car_menu.tscn",
		"res://Scene/Objects/brob_energy/brob_energy.tscn",
	]:
		ModLoaderMod.refresh_scene(scene_path)

func _find_scripts(dir_path: String) -> Array[String]:
	var scripts: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "gd":
			scripts.append(dir_path.path_join(file))
	for sub_dir in DirAccess.get_directories_at(dir_path):
		scripts.append_array(_find_scripts(dir_path.path_join(sub_dir)))
	return scripts

func _ready() -> void:
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

	_register_gacha_machine_item()

	ModLoaderLog.success("AP client ready v%s" % ModLoaderMod.get_mod_data(MOD_NAME).manifest.version_number, MOD_NAME)

	var ApConnectPanelScript = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_connect_panel.tscn")
	connect_panel = ApConnectPanelScript.instantiate()
	connect_panel.ap_client = ap_client
	add_child(connect_panel)

	_title_text_tex = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/title_text.png")
	_title_text_no_bg_tex = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/title_text_no_bg.png")
	if _title_text_tex == null or _title_text_no_bg_tex == null:
		ModLoaderLog.warning("Title replacement texture(s) failed to load.", MOD_NAME)

	get_tree().node_added.connect(_on_node_added)
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

	# The settings screens' monitor noise is a plain autoplaying player; F7 mutes it
	# (see ap_chat_popup.gd). Autoplay has only just started when the node is added.
	var in_settings_menu: bool = node.owner != null and MONITOR_SOUND_SCENES.has(node.owner.scene_file_path)
	if in_settings_menu and ApChatPopup.is_monitor_sound(node) and Globals.save_file.get_meta(ApChatPopup.META_MONITOR_SOUND_MUTED, false):
		node.stop()

	# The gacha machine's root uses the generic InteractData script every item shares,
	# so its obj_id can't be set from a script extension.
	if node.scene_file_path == GACHA_MACHINE_SCENE_PATH:
		if node is InteractData:
			node.obj_id = GACHA_MACHINE_ITEM_ID
		else:
			ModLoaderLog.warning("Gacha machine root is %s, not InteractData; its check will never send." % node.get_class(), MOD_NAME)

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
# Title screen replacement
# =============================================================================

func _replace_title_on(node: Node) -> void:
	if not (node is TextureRect or node is Sprite2D or node is Sprite3D):
		return
	var tex: Texture2D = node.texture
	if tex == null:
		return
	# Some scenes embed the title image, so only load_path carries its file name.
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
