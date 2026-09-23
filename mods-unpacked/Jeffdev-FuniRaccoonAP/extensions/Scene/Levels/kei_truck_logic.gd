extends "res://Scene/Levels/kei_truck_logic.gd"

func _ready() -> void:
	super()
	if not _ap_has_truck() and not kei_truck.hide_dumpster:
		animation_player_lid.play("close")
		truck_lid_closed = true
		object_area_detect.set_collision_mask_value(3, false)

func turn_car_on(_player: PlayerScript) -> void:
	if not _ap_has_truck():
		return
	super(_player)

func truck_lid_controller() -> void:
	if truck_lid_closed and not _ap_has_truck():
		return
	super()

func _ap_has_truck() -> bool:
	return Globals.save_file.items_stored.has(item_tracker.item_id.KEI_TRUCK)
