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
	level_changer.LEVEL_ID.BLIMBO_CITY:        35,
	level_changer.LEVEL_ID.RBMK:              50,
}

static func item_requirement_met(level_id: level_changer.LEVEL_ID) -> bool:
	if level_id == level_changer.LEVEL_ID.RBMK:
		var stored: Array = Globals.save_file.items_stored
		return (stored.has(item_tracker.item_id.COOLING_ROD)
			or stored.has(item_tracker.item_id.COOLING_ROD_PLIMBO)
			or stored.has(item_tracker.item_id.COOLING_ROD_FRIDGE_KING))
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
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	var count: int = 0
	for item_id in icon.items:
		if ap_stored.has(item_id):
			count += 1
	_orb.items_got_text.text = "[shake]Items Got: " + str(count) + "/" + str(icon.items.size())

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

		if have < required or not item_requirement_met(level_id):
			ModLoaderLog.info(
				"Level %s blocked: need %d items, have %d. Redirecting to dumpster." % [
					level_changer.LEVEL_ID.keys()[level_id], required, have
				],
				"Jeffdev-FuniRaccoonAP/LevelAccessGuard"
			)
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
