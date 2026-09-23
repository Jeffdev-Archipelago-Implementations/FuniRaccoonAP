extends "res://Scene/SunGod/sun_god_cliff.gd"

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

func check_what_is_in_hand(body) -> void:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	var lugh_quest_locking: bool = ap_client.slot_data.get("options", {}).get("lugh_quest_locking", false)
	if lugh_quest_locking and not Globals.save_file.items_stored.has(item_id):
		var offering_quest_item: bool = false
		if body is InteractData:
			offering_quest_item = (body.obj_id == item_id)
		elif body is PlayerScript:
			offering_quest_item = body.pickup_pivot.get_objects_in_hand_id().has(item_id)
		if offering_quest_item:
			DialogueManager.Dialogue_Start(
				sun_gawd_dialogue.profile,
				sun_gawd_dialogue.char_name,
				"[color=#FF0000]NO!!!!![/color] This item does not contain any power!! Its power must be found in a [rainbow][wave]mysterious Archipelago location.....[/wave][/rainbow]",
				sun_gawd_dialogue.voice_sound,
				sun_gawd_dialogue.id
			)
		return
	super(body)
