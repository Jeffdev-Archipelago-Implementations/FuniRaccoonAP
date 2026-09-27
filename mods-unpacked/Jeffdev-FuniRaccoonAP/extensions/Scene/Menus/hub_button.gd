extends "res://Scene/Menus/hub_button.gd"

func _ready() -> void:
	disabled = Globals.get_current_world().level_id == LevelChanger.LEVEL_ID.HYPERCUBE_TREE_ENDING
