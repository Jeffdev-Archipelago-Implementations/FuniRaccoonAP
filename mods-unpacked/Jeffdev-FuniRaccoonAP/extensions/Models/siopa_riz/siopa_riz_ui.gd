extends "res://Models/siopa_riz/siopa_riz_ui.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")
const AP_SIGN_TEXTURE := "res://mods-unpacked/Jeffdev-FuniRaccoonAP/images/siopa_ris_ap.png"

var _ap_client: ApClient
var _ap_signs: Dictionary = {}

func _ready() -> void:
	super()
	_ap_client = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	_ap_signs = {
		4001: radio_sign,
		4002: jump_sign,
		4003: boost_sign,
	}
	var ap_sign_tex: Texture2D = load(AP_SIGN_TEXTURE)
	for upgrade_sign in _ap_signs.values():
		_ap_apply_sign_texture(upgrade_sign, ap_sign_tex)
		if upgrade_sign.title_rect and upgrade_sign.title_rect.get_child_count() > 0:
			var title_label = upgrade_sign.title_rect.get_child(0)
			if title_label.has_method("add_theme_font_size_override"):
				title_label.add_theme_font_size_override("normal_font_size", 14)
			if title_label.has_method("set_bbcode_enabled"):
				title_label.set_bbcode_enabled(true)
			if title_label.has_method("set_autowrap"):
				title_label.set_autowrap(true)
			title_label.fit_content = false
	_ap_client.location_info_received.connect(_ap_on_location_info)
	animation_player.animation_finished.connect(_ap_on_animation_finished)

func _exit_tree() -> void:
	if _ap_client != null and _ap_client.location_info_received.is_connected(_ap_on_location_info):
		_ap_client.location_info_received.disconnect(_ap_on_location_info)

func _ap_on_location_info(location_id: int, _item_id: int, item_name: String, _game_name: String, _player_slot: int, player_name: String) -> void:
	var upgrade_sign = _ap_signs.get(location_id, null)
	if upgrade_sign == null or not is_instance_valid(upgrade_sign):
		return
	var label_text: String = item_name
	if player_name != "":
		label_text = "%s\nfor %s" % [item_name, player_name]
	upgrade_sign.title_rect.get_child(0).text = label_text

func _ap_on_animation_finished(anim_name: String) -> void:
	if anim_name != "enter_shop" or not shop_showing:
		return
	var shop_hint_sent: bool = Globals.save_file.get_meta("ap_shop_upgrade_hint_sent", false)
	_ap_client.send_location_scouts([4001, 4002, 4003], 0 if shop_hint_sent else 1)
	if not shop_hint_sent:
		Globals.save_file.set_meta("ap_shop_upgrade_hint_sent", true)

	var shop_items = [
		[radio_sign, truck_flags.radio_purchased],
		[boost_sign, truck_flags.boost_purchased],
		[jump_sign, truck_flags.jump_purchased],
	]
	for entry in shop_items:
		var upgrade_sign = entry[0]
		var flag: String = entry[1]
		for conn in upgrade_sign.button.pressed.get_connections():
			upgrade_sign.button.pressed.disconnect(conn["callable"])
		var check_location_id: int = _ap_client.Ids.SHOP_UPGRADE_LOCATIONS.get(flag, 0)
		var already_checked: bool = Globals.save_file.get_meta("ap_checked_shop_upgrades", []).has(check_location_id)
		if already_checked:
			upgrade_sign.cur_state = truck_upgrade_sign.sign_states.PURCHASED
			upgrade_sign.updated_state()
			continue
		upgrade_sign.cur_state = truck_upgrade_sign.sign_states.UNLOCKED
		upgrade_sign.updated_state()
		upgrade_sign.button.disabled = false
		upgrade_sign.check.hide()
		upgrade_sign.button.pressed.connect(func():
			if Globals.save_file.get_meta("ap_checked_shop_upgrades", []).has(check_location_id):
				return
			if not Globals.remove_euro(upgrade_sign.true_price):
				upgrade_sign.poor()
				return
			cash_sound.play()
			hide_shop(Globals.get_player())
			_ap_client.shop_upgrade_purchased(flag)
		)

# A little hack so I don't have to make a spritesheet for the Archipelago logo sign
func _ap_apply_sign_texture(upgrade_sign, ap_tex: Texture2D) -> void:
	if ap_tex == null or not is_instance_valid(upgrade_sign) or not is_instance_valid(upgrade_sign.item_sprite):
		return
	var sprite: AnimatedSprite2D = upgrade_sign.item_sprite
	var spin_frames: SpriteFrames = sprite.sprite_frames
	var spin_scale: Vector2 = sprite.scale
	var ap_frames := SpriteFrames.new()
	ap_frames.add_frame("default", ap_tex)
	var ap_scale: Vector2 = spin_scale * (250.0 / float(ap_tex.get_height()))
	sprite.sprite_frames = ap_frames
	sprite.scale = ap_scale

	# Swap when focus is entered/exited, when focus is entered the logo is hidden from view anyways!
	upgrade_sign.button.focus_entered.connect(func():
		sprite.sprite_frames = spin_frames
		sprite.scale = spin_scale
		sprite.play("default")
	)
	upgrade_sign.button.focus_exited.connect(func():
		sprite.stop()
		sprite.sprite_frames = ap_frames
		sprite.scale = ap_scale
	)
