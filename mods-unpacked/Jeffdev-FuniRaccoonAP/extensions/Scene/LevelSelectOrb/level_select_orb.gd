extends "res://Scene/LevelSelectOrb/level_select_orb.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")
const LevelAccessGuard = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd")
const ApChatPopup = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")

var _ap_client: ApClient

func _ready() -> void:
	_ap_client = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	super()
	_ap_remove_vehicle()
	_ap_drop_held_kei_truck()
	_ap_client.update_map_location_for_cluster(level_cluster_id)

func update_text(icon: level_select_icon) -> void:
	super(icon)
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	var sent: int = 0
	for item_id in icon.items:
		if ap_stored.has(item_id):
			sent += 1
	items_got_text.text = "[shake]Dumpster Items Sent: %d/%d" % [sent, icon.items.size()]

func _input(event: InputEvent) -> void:
	if transition_to_level_started:
		return
	if not (Input.is_action_just_pressed("JUMP") or Input.is_action_just_released("THROW")):
		super(event)
		return
	if not current_selected_world.discovered:
		animation_player_camera.play("no_entery")
		return

	transition_to_level_started = true
	animation_player_camera.play("camera_tween")
	await animation_player_camera.animation_finished
	LevelChanger.LOAD_FROM_LEVEL_SELECT_WITH_ID(_ap_destination(current_selected_world.level_id))
	MenuController.menus_transiting = false
	queue_free()

func _ap_destination(level_id: level_changer.LEVEL_ID) -> level_changer.LEVEL_ID:
	var required: int = LevelAccessGuard.get_required_for_level(level_id)
	var have: int = Globals.save_file.items_stored.size()
	var connected: bool = _ap_client.connect_state == _ap_client.ConnectState.CONNECTED_TO_MULTIWORLD
	if connected and have >= required and LevelAccessGuard.item_requirement_met(level_id):
		_ap_client.update_map_location(level_id)
		return level_id
	ApChatPopup.show_message(LevelAccessGuard.locked_message(level_id, connected, have), get_tree().get_root())
	return level_changer.LEVEL_ID.MAIN_MENU

func _ap_remove_vehicle() -> void:
	var player = Globals.get_player()
	if not is_instance_valid(player) or player.truck == null:
		return
	var vehicle: Node = player.truck
	player.truck = null
	player.player_in_truck = false
	Globals.player_inst.main_player_camera.set_cull_mask_value(3, false)
	Globals.got_in_car.emit(false)
	vehicle.queue_free()

# The kei truck can't go through the orb, so take it out of the player's hands.
func _ap_drop_held_kei_truck() -> void:
	var player = Globals.get_player()
	if not is_instance_valid(player):
		return
	var pickup = player.get_node_or_null("pivotCotainer/PickupPivot")
	if pickup == null:
		return
	var removed := false
	for obj in pickup.get_children():
		if obj is InteractData and obj.obj_id == item_tracker.item_id.KEI_TRUCK:
			if is_instance_valid(obj.twin_collider):
				player.collider_dupes.erase(obj.twin_collider)
				obj.twin_collider.queue_free()
			obj.queue_free()
			removed = true
	if removed:
		_ap_refresh_hand_state(player, pickup)

func _ap_refresh_hand_state(player, pickup) -> void:
	var still_held: Array = []
	for obj in pickup.get_children():
		if obj is InteractData and not obj.is_queued_for_deletion():
			still_held.append(obj)

	var weight := 0.0
	for obj in still_held:
		weight += float(obj.weight)
	player.holding = not still_held.is_empty()
	player.carrying_weight = weight

	if pickup.sprite_3d != null and pickup.sprite_3d.sprites != null:
		pickup.sprite_3d.sprites.set_holding(player.holding)

	if pickup.menu_updater != null:
		pickup.menu_updater.remove_object_icons()
		for obj in still_held:
			pickup.menu_updater.add_picked_up_icons(obj)
