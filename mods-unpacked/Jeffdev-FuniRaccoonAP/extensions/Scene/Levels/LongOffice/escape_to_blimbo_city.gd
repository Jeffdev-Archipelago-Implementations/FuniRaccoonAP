extends "res://Scene/Levels/LongOffice/escape_to_blimbo_city.gd"

const LevelAccessGuard = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/level_access_guard.gd")

func button_pressed() -> void:
	var have: int = Globals.save_file.get_meta("ap_received_item_index", 0)
	var required: int = LevelAccessGuard.get_required_for_level(level_changer.LEVEL_ID.BLIMBO_CITY)
	if have < required:
		return
	super()
