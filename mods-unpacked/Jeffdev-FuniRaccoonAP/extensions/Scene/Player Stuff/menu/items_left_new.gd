extends "res://Scene/Player Stuff/menu/items_left_new.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

# [LEVEL_CHECKS key, label, save meta key of checks sent, slot_data option that enables it ("" = always on)]
const CHECK_CATEGORIES: Array = [
	["euros", "Euros", "ap_checked_euros", "eurosanity"],
	["cats", "Cats", "ap_checked_cats", ""],
	["hats", "Hats", "ap_checked_hats", "hatsanity"],
]
const FLIP_KEYBOARD_ACTION := "CHANGE_TO_MAP"
const FLIP_CONTROLLER_ACTION := "CHANGE_PAGE"
const FLIP_HINT_SIZE := 22.0
const FLIP_HINT_MARGIN := 6.0

var _flip_hints: Array[TextureRect] = []
var _checks_viewport: SubViewport
var _on_checks_page: bool = false
var _flipping: bool = false
var _closing: bool = false

func _ready() -> void:
	_build_checks_page()
	super()

func _build_checks_page() -> void:
	var items_viewport: SubViewport = item_info.get_parent()
	_checks_viewport = SubViewport.new()
	_checks_viewport.transparent_bg = items_viewport.transparent_bg
	_checks_viewport.canvas_item_default_texture_filter = items_viewport.canvas_item_default_texture_filter
	_checks_viewport.size = items_viewport.size
	items_viewport.add_sibling(_checks_viewport)

	var checks_page: level_item_info = load(item_info.scene_file_path).instantiate()
	_checks_viewport.add_child(checks_page)
	checks_page.title.text = "[u]" + LevelChanger.all_levels[Globals.get_current_world().level_id].level_name + "\n\n"
	checks_page.info.text = _checks_text()
	checks_page.money.hide()
	_add_flip_hint(checks_page)
	_add_flip_hint(item_info)
	_update_flip_hints(ControllerIcons._last_input_type)
	ControllerIcons.input_type_changed.connect(_on_input_type_changed)

func _add_flip_hint(page: level_item_info) -> void:
	var hint := TextureRect.new()
	# The page renders with nearest filtering, which turns a shrunk-down key icon into mush
	hint.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hint.size = Vector2i(32, 32)
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -FLIP_HINT_SIZE - FLIP_HINT_MARGIN
	hint.offset_top = FLIP_HINT_MARGIN
	hint.offset_right = -FLIP_HINT_MARGIN
	hint.offset_bottom = FLIP_HINT_SIZE + FLIP_HINT_MARGIN
	page.get_node("Control").add_child(hint)
	_flip_hints.append(hint)

func _on_input_type_changed(input_type: ControllerIcons.InputType, _controller: int) -> void:
	_update_flip_hints(input_type)

func _update_flip_hints(input_type: ControllerIcons.InputType) -> void:
	var action: String = FLIP_CONTROLLER_ACTION if input_type == ControllerIcons.InputType.CONTROLLER else FLIP_KEYBOARD_ACTION
	var icon: Texture2D = ControllerIcons.parse_path(action, input_type)
	for hint in _flip_hints:
		hint.texture = icon

func _checks_text() -> String:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	var level_checks: Dictionary = ap_client.Ids.LEVEL_CHECKS.get(Globals.get_current_world().level_id, {})
	var lines: PackedStringArray = []
	for category in CHECK_CATEGORIES:
		if category[3] != "" and not ap_client.slot_data.get(category[3], false):
			continue
		var sent_here: Array = Globals.save_file.get_meta(category[2], [])
		var total: int = 0
		var count: int = 0
		for location_id in level_checks.get(category[0], []):
			total += 1
			if sent_here.has(location_id) or ap_client.is_location_checked(location_id):
				count += 1
		if total > 0:
			lines.append("%s %d/%d" % [category[1], count, total])
	if lines.is_empty():
		return "No extra checks here!"
	return "\n".join(lines)

func _input(event: InputEvent) -> void:
	if not (event.is_action_pressed("CHANGE_TO_MAP") or event.is_action_pressed("CHANGE_PAGE")):
		return
	if _flipping or _closing:
		return
	_flipping = true
	animation_player.play("change_page")
	var finished: StringName = await animation_player.animation_finished
	if finished == &"change_page" and not _closing:
		animation_player.play("loop_idle")
	_flipping = false

func change_to_map() -> void:
	_on_checks_page = not _on_checks_page
	var page: SubViewport = _checks_viewport if _on_checks_page else item_info.get_parent()
	polygon_2d.material.set("shader_parameter/screen", page.get_texture())

func remove_menu() -> void:
	_closing = true
	super()

func populate_list() -> void:
	var mod_main: Node = ModLoader.get_node("Jeffdev-FuniRaccoonAP")
	var ap_client: ApClient = mod_main.ap_client
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	var level_items: Array = Globals.get_current_world().items_in_levels
	var level_name: String = LevelChanger.all_levels[Globals.get_current_world().level_id].level_name

	var checks: Array = []
	for item_id in level_items:
		if ItemTacker.item_list_data.has(item_id) and ap_client.Ids.STORE_ITEMS.has(item_id):
			checks.append(item_id)
	var total: int = checks.size()
	var count: int = 0
	_ap_show_count(count, total, level_name)

	for item_id in checks:
		await get_tree().create_timer(0.1, true, false, true).timeout

		var item_inst: InteractData = mod_main.instantiate_item(item_id)
		if item_inst == null:
			continue
		var sent: bool = ap_stored.has(item_id)
		if sent:
			count += 1
			_ap_show_count(count, total, level_name)

		var new_item = NEW_ITEM.instantiate()
		grid.add_child(new_item)
		new_item.set_val(item_inst.hud_icon, true, sent)
		item_inst.queue_free()

func _ap_show_count(count: int, total: int, level_name: String) -> void:
	item_info.items_left(count, total, level_name)
	var info_label = item_info.get_node_or_null("Control/VBoxContainer/info")
	if info_label != null:
		info_label.text = str(count) + "/" + str(total) + " dumpster\nitems sent"
