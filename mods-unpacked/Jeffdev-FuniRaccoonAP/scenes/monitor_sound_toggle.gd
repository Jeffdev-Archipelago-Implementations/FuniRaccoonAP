extends CheckBox

const ModMain = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/mod_main.gd")

func _ready() -> void:
	set_pressed_no_signal(not Globals.save_file.get_meta(ModMain.META_MONITOR_SOUND_MUTED, false))
	toggled.connect(_on_toggled)

func _on_toggled(on: bool) -> void:
	Globals.save_file.set_meta(ModMain.META_MONITOR_SOUND_MUTED, not on)
	Globals.save_game()
	if not on:
		for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
			if ModMain.is_monitor_sound(player):
				player.stop()
