extends "res://Globals/item_tracker/player_stopper_office.gd"

func _ready() -> void:
	super()
	_free_blockers()

func _on_item_counter_disappear_started() -> void:
	_free_blockers()

func _free_blockers() -> void:
	if is_instance_valid(player_blockers) and not player_blockers.is_queued_for_deletion():
		player_blockers.queue_free()
