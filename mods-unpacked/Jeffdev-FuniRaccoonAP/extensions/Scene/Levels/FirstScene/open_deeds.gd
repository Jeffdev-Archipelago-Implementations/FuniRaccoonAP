extends "res://Scene/Levels/FirstScene/open_deeds.gd"

func _ready() -> void :
    var tutorial_played: bool = Globals.save_file.get_meta("ap_tutorial_played", false)
    if not tutorial_played:
        Globals.save_file.set_meta("ap_tutorial_played", true)
        Globals.save_game()
        super()
        return
