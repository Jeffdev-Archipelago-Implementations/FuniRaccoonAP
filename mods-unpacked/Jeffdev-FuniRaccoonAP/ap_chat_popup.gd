## Chat popup manager for AP PrintJSON messages.
## Shows up to MAX_MESSAGES stacked in the bottom-left corner, newest on bottom.
## When a 5th message arrives the oldest (top) is evicted immediately.
## Press F6 to toggle visibility.
extends CanvasLayer

const MAX_MESSAGES = 4
const MESSAGE_DURATION = 5.0
const TOGGLE_KEY = KEY_F6

static var _manager: CanvasLayer = null
static var _vbox: VBoxContainer = null
static var _messages: Array = []  # Active RichTextLabel nodes
static var _chat_visible: bool = true
static var _hiding: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == TOGGLE_KEY:
			_chat_visible = not _chat_visible
			var notice := "Showing AP Messages" if _chat_visible else "Hiding AP Messages"
			_vbox.visible = true
			_hiding = false
			show_message(notice, get_tree().get_root())
			if not _messages.is_empty() and is_instance_valid(_messages.back()):
				_messages.back().visible = true
			if not _chat_visible:
				_hiding = true
				get_tree().create_timer(MESSAGE_DURATION + 0.7).timeout.connect(func():
					_hiding = false
					if not _chat_visible and is_instance_valid(_vbox):
						_vbox.visible = false
				)

static func show_message(bbcode_text: String, root: Node) -> void:
	if _hiding:
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

	_add_label(bbcode_text)

static func _create_manager(root: Node) -> void:
	_manager = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd").new()
	_manager.layer = 9

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_END
	_vbox.add_theme_constant_override("separation", 3)
	_vbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_vbox.offset_left = 20.0
	_vbox.offset_right = 395.0  # 375px wide
	_vbox.offset_top = -295.0   # tall enough for 4 rows
	_vbox.offset_bottom = -20.0

	_manager.add_child(_vbox)
	root.add_child(_manager)

static func _add_label(bbcode_text: String) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.custom_minimum_size = Vector2(280, 0)
	label.add_theme_font_override("normal_font", load("res://Fonts/youngserif-regular.ttf"))
	label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1.4)
	label.add_theme_constant_override("shadow_offset_y", 1.4)
	label.add_theme_constant_override("shadow_outline_size", 1)
	label.text = "[font_size=14]%s[/font_size]" % bbcode_text
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
