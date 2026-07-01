extends Node

var _orb: Node
var ap_client: Node
var _last_shown_level_id: int = -1

# Minimum dumpsterable AP items received (items_stored.size()) required per cluster.
const CLUSTER_REQUIREMENTS: Dictionary = {
	level_info.level_cluster_id.act2: 25,
	level_info.level_cluster_id.act3: 35,
	level_info.level_cluster_id.act4: 50,
}

# Per-level overrides that take precedence over the cluster requirement.
const LEVEL_REQUIREMENTS: Dictionary = {
	level_changer.LEVEL_ID.MUSEUM:             15,
	level_changer.LEVEL_ID.RBMK:              50,
}

static func item_requirement_met(level_id: level_changer.LEVEL_ID) -> bool:
	if level_id == level_changer.LEVEL_ID.RBMK:
		var stored: Array = Globals.save_file.items_stored
		return (stored.has(item_tracker.item_id.COOLING_ROD)
			or stored.has(item_tracker.item_id.COOLING_ROD_PLIMBO)
			or stored.has(item_tracker.item_id.COOLING_ROD_FRIDGE_KING))
	if level_id == level_changer.LEVEL_ID.INSIDE_BRAZIL_TRAIN:
		return Globals.save_file.get_meta("ap_brazil_train_ticket", false)
	return true

static func get_required_for_level(level_id: level_changer.LEVEL_ID) -> int:
	if LEVEL_REQUIREMENTS.has(level_id):
		return LEVEL_REQUIREMENTS[level_id]
	if not LevelChanger.all_levels.has(level_id):
		return 0
	var cluster = LevelChanger.all_levels[level_id].level_cluster
	return CLUSTER_REQUIREMENTS.get(cluster, 0)

func _get_required(level_id: level_changer.LEVEL_ID) -> int:
	return get_required_for_level(level_id)

# Human-readable name of the specific item a level needs (beyond the item count).
static func _missing_item_text(level_id: level_changer.LEVEL_ID) -> String:
	if level_id == level_changer.LEVEL_ID.RBMK:
		return "a Cooling Rod"
	if level_id == level_changer.LEVEL_ID.INSIDE_BRAZIL_TRAIN:
		return "the Brazil Train Ticket"
	return ""

# Builds the "area locked" chat message describing why the level can't be entered yet.
static func locked_message(level_id: level_changer.LEVEL_ID, connected: bool, have: int) -> String:
	var header := "[color=#EE0000]This area is currently locked![/color]"
	if not connected:
		return header + " Connect to Archipelago first."
	var needs: Array = []
	var required: int = get_required_for_level(level_id)
	if have < required:
		var diff: int = required - have
		needs.append("%d more dumpstered item%s (%d/%d)" % [diff, ("s" if diff != 1 else ""), have, required])
	if not item_requirement_met(level_id):
		var item_txt: String = _missing_item_text(level_id)
		if item_txt != "":
			needs.append(item_txt)
	if needs.is_empty():
		return header
	return header + " You need: " + ", ".join(needs) + "."

func _process(_delta: float) -> void:
	if not is_instance_valid(_orb):
		return
	var icon = _orb.current_selected_world
	if icon == null or not is_instance_valid(icon):
		return
	var current_id: int = int(icon.level_id)
	if current_id == _last_shown_level_id:
		return
	_last_shown_level_id = current_id
	var items = icon.get("items")
	if items == null or not (items is Array):
		ModLoaderLog.warning(
			"Selected level icon (level_id=%d) has no valid 'items' array; skipping counter." % current_id,
			"Jeffdev-FuniRaccoonAP/LevelAccessGuard"
		)
		return
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	var count: int = 0
	for item_id in items:
		if ap_stored.has(item_id):
			count += 1
	if is_instance_valid(_orb.get("items_got_text")):
		_orb.items_got_text.text = "[shake]Checks Sent: " + str(count) + "/" + str(items.size())

func _input(event: InputEvent) -> void:
	if not is_instance_valid(_orb):
		return
	if _orb.transition_to_level_started:
		return

	if Input.is_action_just_pressed("JUMP") or Input.is_action_just_released("THROW"):
		if not _orb.current_selected_world.discovered:
			_orb.animation_player_camera.play("no_entery")
			return

		var level_id: level_changer.LEVEL_ID = _orb.current_selected_world.level_id
		var required: int = _get_required(level_id)
		var have: int = Globals.save_file.items_stored.size()

		_orb.transition_to_level_started = true
		_orb.animation_player_camera.play("camera_tween")
		await _orb.animation_player_camera.animation_finished

		var connected: bool = is_instance_valid(ap_client) and ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD
		if not connected or have < required or not item_requirement_met(level_id):
			ModLoaderLog.info(
				"Level %s blocked: need %d items, have %d. Redirecting to dumpster." % [
					level_changer.LEVEL_ID.keys()[level_id], required, have
				],
				"Jeffdev-FuniRaccoonAP/LevelAccessGuard"
			)
			var popup_script = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
			popup_script.show_message(locked_message(level_id, connected, have), get_tree().get_root())
			LevelChanger.LOAD_FROM_LEVEL_SELECT_WITH_ID(level_changer.LEVEL_ID.MAIN_MENU)
		else:
			if is_instance_valid(ap_client):
				ap_client.update_map_location(level_id)
			LevelChanger.LOAD_FROM_LEVEL_SELECT_WITH_ID(level_id)

		MenuController.menus_transiting = false
		_orb.queue_free()

	elif Input.is_action_just_pressed("QUIT"):
		_orb.transition_to_level_started = true
		_orb.animation_player_camera.play("camera_tween")
		await _orb.animation_player_camera.animation_finished
		LevelChanger.LOAD_FROM_LEVEL_SELECT_WITH_ID(level_changer.LEVEL_ID.MAIN_MENU)
		MenuController.menus_transiting = false
		_orb.queue_free()
