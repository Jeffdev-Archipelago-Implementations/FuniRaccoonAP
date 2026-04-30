extends CanvasLayer

var _item_name: String = ""
var _sender_name: String = ""

static var _queue: Array = []
static var _showing: bool = false

static func show_popup(item_name: String, sender_name: String, root: Node) -> void:
	_queue.append({"item_name": item_name, "sender_name": sender_name, "root": root})
	if not _showing:
		_show_next()

static func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var next: Dictionary = _queue.pop_front()
	var root: Node = next["root"]
	if not is_instance_valid(root):
		_show_next()
		return
	var popup = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_item_popup.gd").new()
	popup._item_name = next["item_name"]
	popup._sender_name = next["sender_name"]
	popup.tree_exited.connect(_show_next)
	root.add_child(popup)

func _ready() -> void:
	layer = 10

	var sfx := AudioStreamPlayer.new()
	sfx.stream = load("res://Audio/SoundEffects/Objectives/yippee_%d.ogg" % (randi() % 6 + 1))
	sfx.bus = "Effects"
	add_child(sfx)
	sfx.play()

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.add_theme_font_override("normal_font", load("res://Fonts/PixaDoodle.ttf"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.text = "[center][rainbow][wave amp=25 freq=4][font_size=36]Received: %s![/font_size][/wave][/rainbow][/center]" % _item_name

	var sender_label := RichTextLabel.new()
	sender_label.bbcode_enabled = true
	sender_label.fit_content = true
	sender_label.add_theme_font_override("normal_font", load("res://Fonts/PixaDoodle.ttf"))
	sender_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	sender_label.add_theme_constant_override("shadow_offset_x", 3)
	sender_label.add_theme_constant_override("shadow_offset_y", 3)
	sender_label.text = "[center][rainbow][wave amp=25 freq=4][font_size=24]from %s[/font_size][/wave][/rainbow][/center]" % _sender_name
	sender_label.set_anchors_preset(Control.PRESET_CENTER)
	sender_label.offset_left = -400.0
	sender_label.offset_right = 400.0
	sender_label.offset_top = 10.0
	sender_label.offset_bottom = 50.0
	sender_label.modulate.a = 0.0
	add_child(sender_label)

	get_tree().create_timer(1.0).timeout.connect(func():
		var t := create_tween()
		t.tween_property(sender_label, "modulate:a", 1.0, 0.3)
	)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -400.0
	label.offset_right = 400.0
	label.offset_top = -30.0
	label.offset_bottom = 70.0
	label.custom_minimum_size = Vector2(800, 140)
	add_child(label)

	label.modulate.a = 0.0
	label.position.y -= 20.0

	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(label, "modulate:a", 1.0, 0.25)
	tween.tween_property(label, "position:y", label.position.y + 20.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_interval(4)
	tween.tween_callback(func():
		var t2 := create_tween()
		t2.tween_property(label, "modulate:a", 0.0, 0.4)
		t2.parallel().tween_property(sender_label, "modulate:a", 0.0, 0.4)
		t2.tween_callback(queue_free)
	)
