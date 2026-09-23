extends RefCounted

const ApClient = preload("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/funi_raccoon_ap_client.gd")

# Minimum dumpsterable AP items received (items_stored.size()) required per cluster.
const CLUSTER_REQUIREMENTS: Dictionary = {
	level_info.level_cluster_id.act2: 25,
	level_info.level_cluster_id.act3: 35,
	level_info.level_cluster_id.act4: 50,
}

# Per-level overrides that take precedence over the cluster requirement.
const LEVEL_REQUIREMENTS: Dictionary = {
	level_changer.LEVEL_ID.MUSEUM:  15,
	level_changer.LEVEL_ID.RBMK:   	50,
}

static func item_requirement_met(level_id: level_changer.LEVEL_ID) -> bool:
	if level_id == level_changer.LEVEL_ID.RBMK:
		var stored: Array = Globals.save_file.items_stored
		return (stored.has(item_tracker.item_id.COOLING_ROD)
			or stored.has(item_tracker.item_id.COOLING_ROD_PLIMBO)
			or stored.has(item_tracker.item_id.COOLING_ROD_FRIDGE_KING))
	if level_id == level_changer.LEVEL_ID.INSIDE_BRAZIL_TRAIN:
		return Globals.save_file.get_meta("ap_brazil_train_ticket", false)
	return true

static func get_required_for_level(level_id: level_changer.LEVEL_ID) -> int:
	var ap_client: ApClient = ModLoader.get_node("Jeffdev-FuniRaccoonAP").ap_client
	var required: int = _raw_required_for_level(level_id)
	return ap_client.slot_threshold_for(required)

static func _raw_required_for_level(level_id: level_changer.LEVEL_ID) -> int:
	if LEVEL_REQUIREMENTS.has(level_id):
		return LEVEL_REQUIREMENTS[level_id]
	if not LevelChanger.all_levels.has(level_id):
		return 0
	var cluster = LevelChanger.all_levels[level_id].level_cluster
	return CLUSTER_REQUIREMENTS.get(cluster, 0)

# Human-readable name of the specific item a level needs (beyond the item count).
static func _missing_item_text(level_id: level_changer.LEVEL_ID) -> String:
	if level_id == level_changer.LEVEL_ID.RBMK:
		return "a Cooling Rod"
	if level_id == level_changer.LEVEL_ID.INSIDE_BRAZIL_TRAIN:
		return "the Brazil Train Ticket"
	return ""

# Builds the "area locked" chat message describing why the level can't be entered yet.
static func locked_message(level_id: level_changer.LEVEL_ID, connected: bool, have: int) -> String:
	var header := "[color=#EE0000]This area is currently locked![/color]"
	if not connected:
		return header + " Connect to Archipelago first."
	var needs: Array = []
	var required: int = get_required_for_level(level_id)
	if have < required:
		var diff: int = required - have
		needs.append("%d more dumpstered item%s (%d/%d)" % [diff, ("s" if diff != 1 else ""), have, required])
	if not item_requirement_met(level_id):
		var item_txt: String = _missing_item_text(level_id)
		if item_txt != "":
			needs.append(item_txt)
	if needs.is_empty():
		return header
	return header + " You need: " + ", ".join(needs) + "."
