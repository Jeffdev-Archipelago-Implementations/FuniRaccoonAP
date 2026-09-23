extends "res://Scene/MainMenu/save_file_select_logic.gd"

const AP_LOGO := preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/ap_logo_80.png")

var _ap_label: RichTextLabel

func _ready() -> void:
	super()
	_ap_label = RichTextLabel.new()
	_ap_label.name = "APInfoLabel"
	_ap_label.bbcode_enabled = true
	_ap_label.fit_content = true
	_ap_label.clip_contents = false
	_ap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ap_label.add_theme_color_override("default_color", Color(1, 1, 0, 1))
	_ap_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_ap_label.add_theme_constant_override("shadow_offset_x", 3)
	_ap_label.add_theme_constant_override("shadow_offset_y", 3)
	_ap_label.add_theme_font_override("normal_font", load("res://Fonts/IBM_EGA_8x8.ttf"))
	_ap_label.add_theme_font_size_override("normal_font_size", 18)
	_ap_label.set_position(Vector2(0, 425))
	_ap_label.set_size(Vector2(620, 40))
	$Centerer/Container.add_child(_ap_label)

func item_in_focus(val: saveFileIcon) -> void:
	super(val)
	if not val.id.is_empty():
		_ap_show_info(val.id)

func _ap_show_info(raccoon_name: String) -> void:
	_ap_label.clear()
	var save_path := "user://raccoon_saves/%s_game_save.tres" % raccoon_name
	if not FileAccess.file_exists(save_path):
		save_path = "user://raccoon_saves/%s_game_saves.res" % raccoon_name
	var save_game = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) if FileAccess.file_exists(save_path) else null
	if save_game == null or not save_game.has_meta("ap_slot_name"):
		_ap_label.add_image(AP_LOGO, 24, 24, Color(0.5, 0.5, 0.5, 1))
		_ap_label.append_text(" [color=#999999][wave]No Archipelago Data[/wave][/color]")
		return

	_ap_label.add_image(AP_LOGO, 24, 24)
	_ap_label.append_text(" [color=#ffff00][wave]%s[/wave][/color]" % _ap_escape(save_game.get_meta("ap_slot_name")))
	var server_host: String = save_game.get_meta("ap_server_host", "")
	if server_host != "":
		_ap_label.append_text("\n[color=#b3b3b3][wave]%s[/wave][/color]" % _ap_escape(server_host))

func _ap_escape(text: String) -> String:
	return text.replace("[", "[lb]")
