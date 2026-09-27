## Chat popup manager for AP PrintJSON messages.
extends CanvasLayer

const MAX_MESSAGES = 4
const MESSAGE_DURATION = 7.5

const HELP_MESSAGE = "Press [color=#FAFAD2]F1[/color] to open the Archipelago tracker and settings."

const META_CHAT_VISIBLE = "ap_chat_visible"
const META_CHAT_RELEVANT_ONLY = "ap_chat_relevant_only"

static var _manager: CanvasLayer = null
static var _vbox: VBoxContainer = null
static var _messages: Array = []  # Active RichTextLabel nodes
static var _chat_visible: bool = true
static var _relevant_only: bool = false

static func set_chat_visible(value: bool) -> void:
	_chat_visible = value
	Globals.save_file.set_meta(META_CHAT_VISIBLE, value)
	Globals.save_game()
	if is_instance_valid(_vbox):
		_vbox.visible = value

static func set_relevant_only(value: bool) -> void:
	_relevant_only = value
	Globals.save_file.set_meta(META_CHAT_RELEVANT_ONLY, value)
	Globals.save_game()
	# Re-apply visibility to messages already on screen.
	for m in _messages:
		if is_instance_valid(m):
			m.visible = _chat_visible and (m.get_meta("ap_relevant", true) or not _relevant_only)

static func _clear_messages() -> void:
	for msg in _messages:
		if is_instance_valid(msg):
			msg.queue_free()
	_messages.clear()

# Clear every queued/visible popup (e.g. on AP disconnect).
static func clear_all() -> void:
	_clear_messages()

static func show_message(bbcode_text: String, root: Node, relevant := true) -> void:
	# When the "your messages only" filter is on, drop irrelevant AP messages.
	# Mod-generated messages default to relevant := true so they always show.
	if _relevant_only and not relevant:
		return
	if not is_instance_valid(_manager):
		_create_manager(root)
	if not is_instance_valid(_manager):
		return

	# Evict oldest if at capacity
	_messages = _messages.filter(func(n): return is_instance_valid(n))
	if _messages.size() >= MAX_MESSAGES:
		var oldest = _messages.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	_add_label(bbcode_text, relevant)

static func _create_manager(root: Node) -> void:
	_manager = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd").new()
	_manager.layer = 9

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_END
	_vbox.add_theme_constant_override("separation", 3)
	_vbox.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_vbox.offset_left = 20.0
	_vbox.offset_right = 320.0  # 300px wide
	_vbox.offset_top = 20.0
	_vbox.offset_bottom = -20.0

	_manager.add_child(_vbox)
	root.add_child(_manager)

	# Load the persisted settings page toggles from save meta and apply.
	_chat_visible = Globals.save_file.get_meta(META_CHAT_VISIBLE, _chat_visible)
	_relevant_only = Globals.save_file.get_meta(META_CHAT_RELEVANT_ONLY, _relevant_only)
	_vbox.visible = _chat_visible

static func _add_label(bbcode_text: String, relevant := true) -> void:
	var label := RichTextLabel.new()
	label.set_meta("ap_relevant", relevant)
	label.bbcode_enabled = true
	label.fit_content = true
	label.custom_minimum_size = Vector2(230, 0)
	label.add_theme_font_override("normal_font", load("res://Fonts/youngserif-regular.ttf"))
	label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1.4)
	label.add_theme_constant_override("shadow_offset_y", 1.4)
	label.add_theme_constant_override("shadow_outline_size", 1)
	label.text = "[font_size=12]%s[/font_size]" % bbcode_text
	label.modulate.a = 0.0
	label.visible = _chat_visible

	_vbox.add_child(label)
	_messages.append(label)

	var tween := _vbox.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(MESSAGE_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		_messages.erase(label)
		if is_instance_valid(label):
			label.queue_free()
	)


# AP PrintJSON messages

const AP_COLORS: Dictionary = {
	"red":       "#EE0000",
	"green":     "#00FF7F",
	"yellow":    "#FAFAD2",
	"blue":      "#6495ED",
	"magenta":   "#EE00EE",
	"cyan":      "#00EEEE",
	"white":     "#DDDDDD",
	"black":     "#222222",
	"slateblue": "#6D8BE8",
	"salmon":    "#FA8072",
	"plum":      "#AF99EF",
}

# Boilerplate server messages shown on connect that we don't want in chat.
const FILTERED_MESSAGE_SUBSTRINGS: Array = [
	"does not support compressed",
	"Now that you are connected",
]

static func show_print_json(command: Dictionary, client) -> void:
	var parts: Array = command.get("data", [])
	if parts.is_empty() or str(command.get("type", "")) == "Tutorial":
		return
	var plain := ""
	for part in parts:
		plain += str(part.get("text", ""))
	for needle in FILTERED_MESSAGE_SUBSTRINGS:
		if plain.contains(needle):
			return
	var bbcode := ""
	for part in parts:
		bbcode += _format_part(part, client)
	if bbcode.strip_edges().is_empty():
		return
	show_message(bbcode, client.get_tree().get_root(), _is_relevant(command, parts, client.slot))

static func _format_part(part: Dictionary, client) -> String:
	var text: String = str(part.get("text", ""))
	if text.is_empty():
		return ""
	var part_type: String = str(part.get("type", "text"))
	var game_name: String = client.get_player_game(int(part.get("player", 0)))
	match part_type:
		"player_id":
			text = client.get_player_name(int(text))
		"item_id":
			if client.data_package:
				var resolved: String = client.data_package.resolve_item(int(text), game_name)
				if resolved != "":
					text = resolved
		"location_id":
			if client.data_package:
				var resolved: String = client.data_package.resolve_location(int(text), game_name)
				if resolved != "":
					text = resolved

	var color: String = str(part.get("color", ""))
	if color.is_empty():
		match part_type:
			"player_id", "player_name":
				color = "slateblue"
			"item_id", "item_name":
				var flags: int = int(part.get("flags", 0))
				if flags & 0b001:
					color = "plum"
				elif flags & 0b010:
					color = "slateblue"
				elif flags & 0b100:
					color = "salmon"
				else:
					color = "cyan"
			"location_id", "location_name":
				color = "green"
	if AP_COLORS.has(color):
		return "[color=%s]%s[/color]" % [AP_COLORS[color], text]
	return text

# For the "your messages only" filter: item/hint messages count when you send or receive
# the item, others when they reference your slot. Server replies and countdowns always count.
static func _is_relevant(command: Dictionary, parts: Array, me: int) -> bool:
	match str(command.get("type", "")):
		"ItemSend", "Hint":
			if int(command.get("receiving", -1)) == me:
				return true
			var item_dict = command.get("item", null)
			return item_dict is Dictionary and int(item_dict.get("player", -1)) == me
		"CommandResult", "AdminCommandResult", "Countdown":
			return true
	if int(command.get("slot", -1)) == me:
		return true
	for part in parts:
		if str(part.get("type", "")) == "player_id" and int(str(part.get("text", "-1"))) == me:
			return true
	return false
