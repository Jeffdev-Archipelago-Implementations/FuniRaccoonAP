extends "res://Scene/Menus/pause_menu_logic.gd"

func _ready() -> void:
	super()
	if LevelChanger.current_level != null and LevelChanger.current_level.level_id == level_changer.LEVEL_ID.DEFAULT:
		return
	var quit: Button = $"CanvasLayer/SpriteContainer/Notebook-sheet/menu_point/Menu_Item_Main/VBoxContainer/Quit"
	var rackheath: Button = quit.duplicate(0)
	rackheath.name = "Rackheath"
	rackheath.text = "To Rackheath"
	quit.add_sibling(rackheath)
	quit.get_parent().move_child(rackheath, quit.get_index())
	rackheath.pressed.connect(_ap_go_to_rackheath)

func _ap_go_to_rackheath() -> void:
	LevelChanger.LOAD_FROM_LEVEL_WITH_SHORT_ID(level_changer.LEVEL_ID.DEFAULT, Globals.player_inst, "START_SPAWN")
	MenuController.hide_pause()
