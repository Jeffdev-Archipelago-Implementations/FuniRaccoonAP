extends CheckBox

const ApChatPopup = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
const ApItemPopup = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_item_popup.gd")

enum Setting { FILTER_MESSAGES, HIDE_MESSAGES, SHOW_ITEM_POPUPS }

@export var setting: Setting

func _ready() -> void:
	set_pressed_no_signal(_saved_value())
	toggled.connect(_on_toggled)

# Read straight from the save, since the chat popup only loads these once its first message appears.
func _saved_value() -> bool:
	match setting:
		Setting.FILTER_MESSAGES:
			return Globals.save_file.get_meta(ApChatPopup.META_CHAT_RELEVANT_ONLY, false)
		Setting.HIDE_MESSAGES:
			return not Globals.save_file.get_meta(ApChatPopup.META_CHAT_VISIBLE, true)
		Setting.SHOW_ITEM_POPUPS:
			return Globals.save_file.get_meta(ApItemPopup.META_ITEM_POPUPS_ENABLED, true)
	return false

func _on_toggled(on: bool) -> void:
	match setting:
		Setting.FILTER_MESSAGES:
			ApChatPopup.set_relevant_only(on)
		Setting.HIDE_MESSAGES:
			ApChatPopup.set_chat_visible(not on)
		Setting.SHOW_ITEM_POPUPS:
			ApItemPopup.set_item_popups_enabled(on)
