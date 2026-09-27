extends "res://Scene/Levels/Factory_part_2/change_item_spawn_on_flag.gd"

const THE_PROCESS_SCENE_PATH := "res://Scene/Levels/Factory_part_2/factorty_part_two.tscn"
const BEENIE_CHANCE := 0.25

var _original_item: PackedScene

# 1/4 chance to spawn beenie the birthday boy
func change_item() -> void:
	_original_item = item_spawner_to_change.item
	super()
	if owner == null or owner.scene_file_path != THE_PROCESS_SCENE_PATH:
		return
	_roll_item()
	item_spawner_to_change.get_node("Timer").timeout.connect(_roll_item)

func _roll_item() -> void:
	item_spawner_to_change.item = _original_item if randf() < BEENIE_CHANCE else item_to_change_to
