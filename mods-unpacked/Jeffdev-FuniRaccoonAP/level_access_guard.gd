extends Node

var _orb: Node

# Minimum AP items received (ap_received_item_index) required per cluster.
const CLUSTER_REQUIREMENTS: Dictionary = {
	level_info.level_cluster_id.act2: 25,
	level_info.level_cluster_id.act3: 30,
	level_info.level_cluster_id.act4: 50,
}

# Per-level overrides that take precedence over the cluster requirement.
const LEVEL_REQUIREMENTS: Dictionary = {
	level_changer.LEVEL_ID.MUSEUM:             15,
	level_changer.LEVEL_ID.BLIMBO_CITY:        35,
	level_changer.LEVEL_ID.GULLY:             100,
	level_changer.LEVEL_ID.SALMON_OF_KNOWLEDGE: 100,
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
		var have: int = Globals.save_file.get_meta("ap_received_item_index", 0)

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
