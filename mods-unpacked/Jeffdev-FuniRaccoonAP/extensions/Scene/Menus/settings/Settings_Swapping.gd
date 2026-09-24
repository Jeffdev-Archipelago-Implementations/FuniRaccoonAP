extends "res://Scene/Menus/settings/Settings_Swapping.gd"

# One past the last settings_menu_controller.menu_item (CONTROLLER = 3).
const AP_MENU := 4
const AP_PAGE_SCENE := "res://mods-unpacked/Jeffdev-FuniRaccoonAP/scenes/settings_seg_archipelago.tscn"

static var open_ap_tab_next := false

var ap_settings: Control
var ap_button: Button
var color_rect_ap: ColorRect

func _ready() -> void:
	_add_ap_tab()
	super()

func _add_ap_tab() -> void:
	var tabs: HBoxContainer = $Container/HBoxContainer
	var controls_tab: Control = $Container/HBoxContainer/Controls

	# No signals: the copied button connects its own pressed signal in _ready.
	var no_signals := Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION
	var separator: Node = $Container/HBoxContainer/frame5.duplicate(no_signals)
	var ap_tab: Control = controls_tab.duplicate(no_signals)
	ap_tab.name = "Archipelago"
	tabs.add_child(separator)
	tabs.move_child(separator, controls_tab.get_index() + 1)
	tabs.add_child(ap_tab)
	tabs.move_child(ap_tab, separator.get_index() + 1)

	color_rect_ap = ap_tab.get_child(0)
	ap_button = ap_tab.get_child(1)
	ap_button.text = "AP"
	ap_button.menu_item = AP_MENU
	ap_button.focus_neighbor_left = ap_button.get_path_to(controls_button)
	ap_button.focus_neighbor_right = ap_button.get_path_to(audio_button)
	controls_button.focus_neighbor_right = controls_button.get_path_to(ap_button)
	audio_button.focus_neighbor_left = audio_button.get_path_to(ap_button)
	ap_button.button_press_settings.connect(change_menu)

	ap_settings = load(AP_PAGE_SCENE).instantiate()
	parent_setting_node.add_child(ap_settings)
	ap_settings.hide()

func change_menu(item: menu_item):
	if open_ap_tab_next:
		open_ap_tab_next = false
		item = AP_MENU as menu_item
	if item == AP_MENU:
		currentmenu = item
		audio_settings.hide()
		game_settings.hide()
		res_settings.hide()
		controller_settings.hide()
		ap_settings.show()

		color_rect_audio.color = second_colour
		color_rect_video.color = second_colour
		color_rect_game.color = second_colour
		color_rect_controls.color = second_colour
		color_rect_ap.color = main_colour

		focus_controller_button = null
		return

	ap_settings.hide()
	color_rect_ap.color = second_colour
	super(item)

func _process(delta: float) -> void:
	var left := Input.is_action_just_pressed("next_menu_set_left")
	var right := Input.is_action_just_pressed("next_menu_set_right")
	if currentmenu == AP_MENU:
		if left:
			change_menu(menu_item.CONTROLLER)
		elif right:
			change_menu(menu_item.AUDIO)
		return
	if currentmenu == menu_item.CONTROLLER and right:
		change_menu(AP_MENU as menu_item)
		return
	if currentmenu == menu_item.AUDIO and left:
		change_menu(AP_MENU as menu_item)
		return
	super(delta)
