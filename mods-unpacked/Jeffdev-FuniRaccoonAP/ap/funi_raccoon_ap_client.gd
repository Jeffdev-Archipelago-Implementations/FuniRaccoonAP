## Funi Raccoon Game Archipelago Client
##
## Extends GodotApClient with game-specific integration:
## - Maps each item_tracker.item_id to an Archipelago location ID
## - Provides item_stored() to send a location check when an item is dumpster'd
extends "res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/godot_ap_client.gd"

const _LOG = "Jeffdev-FuniRaccoonAP/FuniRaccoonApClient"

## Base offset for all Funi Raccoon Game location IDs in the AP multiworld.
const LOCATION_ID_BASE = 1000

const PROGRESSIVE_DUMBBELL_AP_ITEM_ID = 400
const PROGRESSIVE_COOLING_ROD_AP_ITEM_ID = 94

const KEI_TRUCK_RADIO_AP_ITEM_ID = 201
const KEI_TRUCK_TOASTER_AP_ITEM_ID = 202
const KEI_TRUCK_BOOST_AP_ITEM_ID = 203

const HAT_AP_ITEM_IDS: Dictionary = {
	501: 1,  # Sun Hat        → hat_enum 1
	502: 6,  # Sombrero       → hat_enum 6
	503: 8,  # Top Hat        → hat_enum 8
	504: 7,  # Jester Hat     → hat_enum 7
	505: 2,  # Raccoon Hat    → hat_enum 2
	506: 4,  # Media Player   → hat_enum 4
	507: 5,  # Fridge Crown   → hat_enum 5
	508: 9,  # Patty Hat      → hat_enum 9
}

const JEWEL_AP_ITEM_IDS: Dictionary = {
	601: "jewel_1_eaten",  # Green
	602: "jewel_2_eaten",  # Blue
	603: "jewel_3_eaten",  # Purple
	604: "jewel_4_eaten",  # Red
}

const EURO_10_AP_ITEM_ID = 300
const EURO_100_AP_ITEM_ID = 301

## [score_threshold, ap_location_id] pairs for kei truck stunt checks.
const TRUCK_SCORE_CHECKS: Array = [
	[1000, 2001],
	[2000, 2002],
	[3000, 2003],
	[4000, 2004],
	[5000, 2005],
]

const DUMBBELL_LOCATION_IDS: Dictionary = {
	"dumbell_1": LOCATION_ID_BASE + 2001,
	"dumbell_2": LOCATION_ID_BASE + 2002,
	"dumbell_3": LOCATION_ID_BASE + 2003,
	"dumbell_4": LOCATION_ID_BASE + 2004,
}

var COOLING_ROD_PROGRESSION: Array = [
	item_tracker.item_id.COOLING_ROD,
	item_tracker.item_id.COOLING_ROD_PLIMBO,
	item_tracker.item_id.COOLING_ROD_FRIDGE_KING,
]

var TRUCK_UPGRADE_ITEM_MAP: Dictionary = {
	KEI_TRUCK_RADIO_AP_ITEM_ID:   truck_flags.radio_purchased,
	KEI_TRUCK_TOASTER_AP_ITEM_ID: truck_flags.jump_purchased,
	KEI_TRUCK_BOOST_AP_ITEM_ID:   truck_flags.boost_purchased,
}

var SHOP_UPGRADE_LOCATION_IDS: Dictionary = {
	truck_flags.radio_purchased: 4001,
	truck_flags.jump_purchased:  4002,
	truck_flags.boost_purchased: 4003,
}

var CAT_LOCATION_IDS: Dictionary = {
	item_tracker.item_id.MICHI_CAT:    5001,
	item_tracker.item_id.CAT:          5002,
	item_tracker.item_id.CONCRETE_CAT: 5003,
	item_tracker.item_id.GIZMO_CAT:    5004,
	item_tracker.item_id.KEKSZ_CAT:    5005,
	item_tracker.item_id.BOINGLER_CAT: 5006,
}

const HAT_LOCATION_IDS: Dictionary = {
	1: 6001,  # Sun Hat
	6: 6002,  # Sombrero
	8: 6003,  # Top Hat
	7: 6004,  # Jester Hat
	2: 6005,  # Raccoon Hat
	4: 6006,  # Media Player Hat
	5: 6007,  # Fridge Crown
	9: 6008,  # Patty Hat
}

const JEWEL_LOCATION_IDS: Dictionary = {
	"jewel_1_eaten": 7001,
	"jewel_2_eaten": 7002,
	"jewel_3_eaten": 7003,
	"jewel_4_eaten": 7004,
}

## Maps item_tracker.item_id enum values to AP location IDs.
const ITEM_ID_TO_AP_LOCATION: Dictionary = {
	item_tracker.item_id.MOAI:                     LOCATION_ID_BASE + 1,
	item_tracker.item_id.STREET_LIGHT:             LOCATION_ID_BASE + 2,
	item_tracker.item_id.FUN_BELLS:                LOCATION_ID_BASE + 3,
	item_tracker.item_id.LAMA:                     LOCATION_ID_BASE + 4,
	item_tracker.item_id.GYM:                      LOCATION_ID_BASE + 5,
	item_tracker.item_id.KEI_TRUCK:                LOCATION_ID_BASE + 6,
	item_tracker.item_id.VENDING_MACHINE:          LOCATION_ID_BASE + 7,
	item_tracker.item_id.COIN:                     LOCATION_ID_BASE + 8,
	item_tracker.item_id.RADIO:                    LOCATION_ID_BASE + 9,
	item_tracker.item_id.GUN:                      LOCATION_ID_BASE + 11,
	item_tracker.item_id.CONSTRUCTION_SIGN:        LOCATION_ID_BASE + 16,
	item_tracker.item_id.CHICKEN:                  LOCATION_ID_BASE + 17,
	item_tracker.item_id.WASHING_MACHINE:          LOCATION_ID_BASE + 18,
	item_tracker.item_id.CAT:                      LOCATION_ID_BASE + 19,
	item_tracker.item_id.BROB_ENERGY:              LOCATION_ID_BASE + 20,
	item_tracker.item_id.BUISNESS_MAN:             LOCATION_ID_BASE + 21,
	item_tracker.item_id.CONCRETE_CAT:             LOCATION_ID_BASE + 22,
	item_tracker.item_id.GIZMO_CAT:               LOCATION_ID_BASE + 23,
	item_tracker.item_id.KEKSZ_CAT:               LOCATION_ID_BASE + 24,
	item_tracker.item_id.MICHI_CAT:               LOCATION_ID_BASE + 25,
	item_tracker.item_id.BOINGLER_CAT:             LOCATION_ID_BASE + 26,
	item_tracker.item_id.PARACETAMOL:              LOCATION_ID_BASE + 27,
	item_tracker.item_id.TORCH:                    LOCATION_ID_BASE + 28,
	item_tracker.item_id.MONITOR:                  LOCATION_ID_BASE + 31,
	item_tracker.item_id.SIGN:                     LOCATION_ID_BASE + 37,
	item_tracker.item_id.CRACKHEAD:                LOCATION_ID_BASE + 38,
	item_tracker.item_id.CRAYON:                   LOCATION_ID_BASE + 39,
	item_tracker.item_id.CRICKET_BAT:              LOCATION_ID_BASE + 40,
	item_tracker.item_id.PIRATE_1:                 LOCATION_ID_BASE + 42,
	item_tracker.item_id.PIRATE_2:                 LOCATION_ID_BASE + 43,
	item_tracker.item_id.PIRATE_3:                 LOCATION_ID_BASE + 44,
	item_tracker.item_id.CONSTRUCTION_SIGN_SPIN:   LOCATION_ID_BASE + 45,
	item_tracker.item_id.MICROWAVE:                LOCATION_ID_BASE + 48,
	item_tracker.item_id.TOASTER:                  LOCATION_ID_BASE + 49,
	item_tracker.item_id.LOGAN_LEFT:               LOCATION_ID_BASE + 50,
	item_tracker.item_id.LOGAN_RIGHT:              LOCATION_ID_BASE + 51,
	item_tracker.item_id.FISH:                     LOCATION_ID_BASE + 52,
	item_tracker.item_id.FERAL_DOG:               LOCATION_ID_BASE + 53,
	item_tracker.item_id.WINDMILL:                 LOCATION_ID_BASE + 54,
	item_tracker.item_id.BEENIE_BOX:              LOCATION_ID_BASE + 55,
	item_tracker.item_id.GOO:                      LOCATION_ID_BASE + 56,
	item_tracker.item_id.BEENIE:                   LOCATION_ID_BASE + 57,
	item_tracker.item_id.FAN:                      LOCATION_ID_BASE + 59,
	item_tracker.item_id.LETTER_B:                 LOCATION_ID_BASE + 61,
	item_tracker.item_id.BEENIE_STATUE:            LOCATION_ID_BASE + 62,
	item_tracker.item_id.CANDLE:                   LOCATION_ID_BASE + 63,
	item_tracker.item_id.FUNI_MARKETABLE_PLUSHIE:  LOCATION_ID_BASE + 64,
	item_tracker.item_id.PATRICK_OHARA:            LOCATION_ID_BASE + 65,
	item_tracker.item_id.TOASTIE:                  LOCATION_ID_BASE + 66,
	item_tracker.item_id.CRISP:                    LOCATION_ID_BASE + 67,
	item_tracker.item_id.FLOWER:                   LOCATION_ID_BASE + 68,
	item_tracker.item_id.DIVIDER:                  LOCATION_ID_BASE + 69,
	item_tracker.item_id.OFFICE_CHAIR:             LOCATION_ID_BASE + 70,
	item_tracker.item_id.OFFICE_DESK:              LOCATION_ID_BASE + 71,
	item_tracker.item_id.MY_FAVORITE_CHAIR:        LOCATION_ID_BASE + 73,
	item_tracker.item_id.CRICKET:                  LOCATION_ID_BASE + 74,
	item_tracker.item_id.UNDYING_LOVE:             LOCATION_ID_BASE + 75,
	item_tracker.item_id.BLIMBO_SIGN:              LOCATION_ID_BASE + 76,
	item_tracker.item_id.OUGHAM_STONE:             LOCATION_ID_BASE + 77,
	item_tracker.item_id.COW:                      LOCATION_ID_BASE + 78,
	item_tracker.item_id.MINES_KEY:               LOCATION_ID_BASE + 80,
	item_tracker.item_id.PLIMBO:                   LOCATION_ID_BASE + 81,
	item_tracker.item_id.FRIDGE_KEY:              LOCATION_ID_BASE + 82,
	item_tracker.item_id.TYRE:                     LOCATION_ID_BASE + 84,
	item_tracker.item_id.PAPA_TYRE:               LOCATION_ID_BASE + 85,
	item_tracker.item_id.SMOKER:                   LOCATION_ID_BASE + 86,
	item_tracker.item_id.BROKEN_TRUCK:             LOCATION_ID_BASE + 87,
	item_tracker.item_id.CHEESE:                   LOCATION_ID_BASE + 88,
	item_tracker.item_id.GAS_DRUM:                LOCATION_ID_BASE + 89,
	item_tracker.item_id.COFFEE_SHOP:              LOCATION_ID_BASE + 90,
	item_tracker.item_id.TROLLEY:                  LOCATION_ID_BASE + 91,
	item_tracker.item_id.FOLDING_CHAIR:            LOCATION_ID_BASE + 93,
	item_tracker.item_id.COOLING_ROD:              LOCATION_ID_BASE + 94,
	item_tracker.item_id.WARNING_BLIMBO:           LOCATION_ID_BASE + 95,
	item_tracker.item_id.PICKAXE:                  LOCATION_ID_BASE + 96,
	item_tracker.item_id.BROKEN_WALL:              LOCATION_ID_BASE + 97,
	item_tracker.item_id.FONE_BLIMBO:              LOCATION_ID_BASE + 98,
	item_tracker.item_id.COFFEE_CUP:              LOCATION_ID_BASE + 99,
	item_tracker.item_id.KETTLE_BLIMBO:            LOCATION_ID_BASE + 100,
	item_tracker.item_id.RADIATOR_BLIMBO:          LOCATION_ID_BASE + 101,
	item_tracker.item_id.FLOWER_BLIMBO:            LOCATION_ID_BASE + 102,
	item_tracker.item_id.BENCH:                    LOCATION_ID_BASE + 104,
	item_tracker.item_id.EVIL_RACCOON:             LOCATION_ID_BASE + 105,
	item_tracker.item_id.NAKED_FELLA:              LOCATION_ID_BASE + 106,
	item_tracker.item_id.BIN:                      LOCATION_ID_BASE + 107,
	item_tracker.item_id.KNIFE:                    LOCATION_ID_BASE + 109,
	item_tracker.item_id.SUITCASE:                 LOCATION_ID_BASE + 110,
	item_tracker.item_id.PINT:                     LOCATION_ID_BASE + 111,
	item_tracker.item_id.FLOWIAN:                  LOCATION_ID_BASE + 112,
	item_tracker.item_id.BOMB:                     LOCATION_ID_BASE + 113,
	item_tracker.item_id.BELL:                     LOCATION_ID_BASE + 114,
	item_tracker.item_id.DEMON_CORE:              LOCATION_ID_BASE + 115,
	item_tracker.item_id.APPLE:                    LOCATION_ID_BASE + 116,
	item_tracker.item_id.GAS_PUMPO:               LOCATION_ID_BASE + 117,
	item_tracker.item_id.CD_PLAYER:               LOCATION_ID_BASE + 118,
	item_tracker.item_id.RADIO_BLIMBO:             LOCATION_ID_BASE + 119,
	item_tracker.item_id.BINOCULBLO:              LOCATION_ID_BASE + 120,
	item_tracker.item_id.POLICE_CAR:              LOCATION_ID_BASE + 121,
	item_tracker.item_id.HAZELNUT:                LOCATION_ID_BASE + 122,
	item_tracker.item_id.ANTI_SADS:               LOCATION_ID_BASE + 123,
	item_tracker.item_id.TV_REMOTE:               LOCATION_ID_BASE + 124,
	item_tracker.item_id.PIANO:                    LOCATION_ID_BASE + 125,
	item_tracker.item_id.BRICK:                    LOCATION_ID_BASE + 126,
	item_tracker.item_id.LLOYD:                    LOCATION_ID_BASE + 127,
	item_tracker.item_id.MANHOLE_COVER:            LOCATION_ID_BASE + 128,
	item_tracker.item_id.OLD_STATION_SIGN:         LOCATION_ID_BASE + 129,
	item_tracker.item_id.WARNING_SIGN:             LOCATION_ID_BASE + 130,
	item_tracker.item_id.TRAIN_SIGN:              LOCATION_ID_BASE + 131,
	item_tracker.item_id.ORB:                      LOCATION_ID_BASE + 132,
	item_tracker.item_id.MS_HEEL:                 LOCATION_ID_BASE + 134,
	item_tracker.item_id.MR_HEEL:                 LOCATION_ID_BASE + 135,
	item_tracker.item_id.WAFFLE:                   LOCATION_ID_BASE + 136,
	item_tracker.item_id.GREENIE:                  LOCATION_ID_BASE + 137,
	item_tracker.item_id.PRIESTESS:               LOCATION_ID_BASE + 138,
	item_tracker.item_id.BEENIE_SAVES_THE_KIDS:    LOCATION_ID_BASE + 140,
	item_tracker.item_id.HERMIT_CAN:              LOCATION_ID_BASE + 141,
	item_tracker.item_id.BARREL:                   LOCATION_ID_BASE + 142,
	item_tracker.item_id.BOOKBLO:                  LOCATION_ID_BASE + 143,
	item_tracker.item_id.FRIDGE:                   LOCATION_ID_BASE + 144,
	item_tracker.item_id.FRIDGLING:               LOCATION_ID_BASE + 145,
	item_tracker.item_id.SNOWBALL:                 LOCATION_ID_BASE + 146,
	item_tracker.item_id.LEECHES:                  LOCATION_ID_BASE + 147,
	item_tracker.item_id.COOLING_ROD_PLIMBO:       LOCATION_ID_BASE + 148,
	item_tracker.item_id.COOLING_ROD_FRIDGE_KING:  LOCATION_ID_BASE + 149,
	item_tracker.item_id.BEACH_BALL:              LOCATION_ID_BASE + 150,
	item_tracker.item_id.MILK_KLUBNIKA:            LOCATION_ID_BASE + 151,
	item_tracker.item_id.CHAIRAPIST:              LOCATION_ID_BASE + 154,
	item_tracker.item_id.CAMERA:                   LOCATION_ID_BASE + 155,
	item_tracker.item_id.YOLKY:                    LOCATION_ID_BASE + 156,
	item_tracker.item_id.PAWN:                     LOCATION_ID_BASE + 157,
	item_tracker.item_id.ROOK:                     LOCATION_ID_BASE + 158,
	item_tracker.item_id.BISHOP:                   LOCATION_ID_BASE + 159,
	item_tracker.item_id.QUEEN:                    LOCATION_ID_BASE + 160,
	item_tracker.item_id.KING:                     LOCATION_ID_BASE + 161,
	item_tracker.item_id.FAKE_GYM:                LOCATION_ID_BASE + 162,
	item_tracker.item_id.SPOONSWEET:              LOCATION_ID_BASE + 163,
	item_tracker.item_id.WRIKS_CELLAR:             LOCATION_ID_BASE + 164,
	item_tracker.item_id.DOOR:                     LOCATION_ID_BASE + 165,
	item_tracker.item_id.FUNI_RACCOON_GAME_CD:     LOCATION_ID_BASE + 166,
	item_tracker.item_id.GOLDEN_MONKEY:            LOCATION_ID_BASE + 167,
	item_tracker.item_id.GOO_MACHINE:              LOCATION_ID_BASE + 168,
	item_tracker.item_id.BUTTERFLY:               LOCATION_ID_BASE + 169,
	item_tracker.item_id.PATRICK_O_BOBBLE:         LOCATION_ID_BASE + 170,
	item_tracker.item_id.DICEBLO:                  LOCATION_ID_BASE + 171,
	item_tracker.item_id.LUGHLING:                LOCATION_ID_BASE + 172,
	item_tracker.item_id.BOOK_STACK:              LOCATION_ID_BASE + 173,
	item_tracker.item_id.TITO:                     LOCATION_ID_BASE + 174,
	item_tracker.item_id.CHEESE_WOMAN:             LOCATION_ID_BASE + 175,
}

# Guard flag to distinguish AP-granted items from player throws.
var _receiving_from_ap: bool = false
# Suppresses popups during the initial ReceivedItems sync on connect.
var _ready_for_popups: bool = false

func _ready() -> void:
	super._ready()
	connection_state_changed.connect(_on_connection_state_changed)

func _maybe_show_popup(item_name: String, fallback: String, item_dict: Dictionary, show: bool) -> void:
	if not show:
		return
	var popup_script = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_item_popup.gd")
	popup_script.show_popup(
		item_name if item_name != "" else fallback,
		_get_player_name(int(item_dict.get("player", 0))),
		get_tree().get_root()
	)

func _send_check(meta_key: String, location_id: int) -> void:
	var checked: Array = Globals.save_file.get_meta(meta_key, [])
	if checked.has(location_id):
		return
	checked.append(location_id)
	Globals.save_file.set_meta(meta_key, checked)
	Globals.save_game()
	if connect_state == ConnectState.CONNECTED_TO_MULTIWORLD:
		check_location(location_id)

func _sync_checks(meta_key: String) -> void:
	for location_id in Globals.save_file.get_meta(meta_key, []):
		check_location(location_id)

func _on_received_items(command: Dictionary) -> void:
	var cmd_index: int = int(command.get("index", 0))
	var items: Array = command.get("items", [])
	var stored_index: int = Globals.save_file.get_meta("ap_received_item_index", 0)
	var changed := false
	var show_popups := _ready_for_popups
	_ready_for_popups = true

	for i in range(items.size()):
		var absolute_index := cmd_index + i
		if absolute_index < stored_index:
			continue  # Already processed this item in a previous session.

		var ap_item_id: int = int(items[i]["item"])
		var item_name: String = ""
		if data_package:
			var name_val = data_package.item_id_to_name.get(ap_item_id, null)
			if name_val == null:
				# JSON may have stored the key as float
				name_val = data_package.item_id_to_name.get(float(ap_item_id), null)
			if name_val != null:
				item_name = str(name_val)
		ModLoaderLog.info("AP received item [%d] id=%d '%s'" % [absolute_index, ap_item_id, item_name], _LOG)

		if ap_item_id == PROGRESSIVE_DUMBBELL_AP_ITEM_ID:
			ModLoaderLog.info("AP granted Progressive Mystical Dumbbell — increasing strength.", _LOG)
			LevelUpSystem.level_up_system()
			LevelUpSystem.Level_Up.emit()
			if Globals.save_file.strength >= 5.0:
				Globals.get_achievement("ACH_FULL_BELLY")
			changed = true
			_maybe_show_popup(item_name, "Progressive Mystical Dumbbell", items[i], show_popups)
		elif ap_item_id == PROGRESSIVE_COOLING_ROD_AP_ITEM_ID:
			var next_rod := -1
			for rod_id in COOLING_ROD_PROGRESSION:
				if not Globals.save_file.items_stored.has(rod_id):
					next_rod = rod_id
					break
			if next_rod != -1:
				ModLoaderLog.info("AP granted Progressive Cooling Rod (id=%d)." % next_rod, _LOG)
				_receiving_from_ap = true
				Globals.save_file.items_stored.append(next_rod)
				Globals.dumpster_added_item.emit()
				_receiving_from_ap = false
				if next_rod == item_tracker.item_id.COOLING_ROD_PLIMBO and not Globals.save_file.cooling_rods.has("plimbo"):
					Globals.save_file.cooling_rods.append("plimbo")
				elif next_rod == item_tracker.item_id.COOLING_ROD_FRIDGE_KING and not Globals.save_file.cooling_rods.has("fridge_king"):
					Globals.save_file.cooling_rods.append("fridge_king")
				changed = true
				_maybe_show_popup(item_name, "Progressive Cooling Rod", items[i], show_popups)
			else:
				ModLoaderLog.warning("AP granted Progressive Cooling Rod but all three are already collected.", _LOG)
		elif TRUCK_UPGRADE_ITEM_MAP.has(ap_item_id):
			var flag: String = TRUCK_UPGRADE_ITEM_MAP[ap_item_id]
			if not Globals.save_file.truck_upgrades.has(flag):
				Globals.save_file.truck_upgrades.append(flag)
				changed = true
				ModLoaderLog.info("AP granted truck upgrade '%s'." % flag, _LOG)
				_maybe_show_popup(item_name, flag, items[i], show_popups)
		elif HAT_AP_ITEM_IDS.has(ap_item_id):
			var hat_enum_id: int = HAT_AP_ITEM_IDS[ap_item_id]
			if not Globals.save_file.unlocked_hats.has(hat_enum_id):
				Globals.save_file.unlocked_hats.append(hat_enum_id)
				changed = true
				ModLoaderLog.info("AP granted hat enum_id=%d." % hat_enum_id, _LOG)
				_maybe_show_popup(item_name, "Hat", items[i], show_popups)
		elif JEWEL_AP_ITEM_IDS.has(ap_item_id):
			var jewel_flag: String = JEWEL_AP_ITEM_IDS[ap_item_id]
			if not Globals.save_file.states_occurred.has(jewel_flag):
				Globals.save_file.states_occurred.append(jewel_flag)
				changed = true
				ModLoaderLog.info("AP granted jewel flag='%s'." % jewel_flag, _LOG)
				_maybe_show_popup(item_name, "Mystical Jewel", items[i], show_popups)
		elif ap_item_id == EURO_10_AP_ITEM_ID:
			Globals.add_euro(10.0)
			changed = true
			ModLoaderLog.info("AP granted 10 Euro.", _LOG)
			_maybe_show_popup(item_name, "10 Euro", items[i], show_popups)
		elif ap_item_id == EURO_100_AP_ITEM_ID:
			Globals.add_euro(100.0)
			changed = true
			ModLoaderLog.info("AP granted 100 Euro.", _LOG)
			_maybe_show_popup(item_name, "100 Euro", items[i], show_popups)
		elif ITEM_ID_TO_AP_LOCATION.has(ap_item_id):
			if not Globals.save_file.items_stored.has(ap_item_id):
				_receiving_from_ap = true
				Globals.save_file.items_stored.append(ap_item_id)
				Globals.dumpster_added_item.emit()
				_receiving_from_ap = false
				changed = true
				_maybe_show_popup(item_name, str(ap_item_id), items[i], show_popups)
		else:
			ModLoaderLog.info("AP item id=%d ('%s') has no handler, skipping." % [ap_item_id, item_name], _LOG)

		stored_index = absolute_index + 1
		Globals.save_file.set_meta("ap_received_item_index", stored_index)

	if changed:
		Globals.save_game()


func _get_player_name(player_slot: int) -> String:
	for p in players:
		if int(p.get("slot", -1)) == player_slot:
			return str(p.get("alias", p.get("name", "Unknown")))
	return "Unknown"

func _on_connection_state_changed(new_state: int, _error: int = 0) -> void:
	if new_state == ConnectState.CONNECTING:
		_ready_for_popups = false
	elif new_state == ConnectState.CONNECTED_TO_MULTIWORLD:
		sync_stored_items()
		if Globals.save_file.is_the_future:
			LevelChanger.LOAD_FROM_LEVEL_WITH_SHORT_ID(
				level_changer.LEVEL_ID.CANYON,
				Globals.player_inst,
				"THE_DUMPSTER"
			)
		else:
			LevelChanger.LOAD_FROM_LEVEL_WITH_SHORT_ID(
				level_changer.LEVEL_ID.MAIN_MENU,
				Globals.player_inst,
				"START_SPAWN"
			)
	elif new_state == ConnectState.DISCONNECTED:
		Globals.QUIT_TO_MEUN()

func sync_stored_items() -> void:
	var thrown: Array = Globals.save_file.get_meta("ap_stored_items", [])
	ModLoaderLog.info("Syncing %d dumpster'd items to AP" % thrown.size(), _LOG)
	for id in thrown:
		if ITEM_ID_TO_AP_LOCATION.has(id):
			check_location(ITEM_ID_TO_AP_LOCATION[id])

	var eaten_dumbbells: Array = Globals.save_file.get_meta("ap_eaten_dumbbells", [])
	ModLoaderLog.info("Syncing %d eaten dumbbells to AP" % eaten_dumbbells.size(), _LOG)
	for collectable_id in eaten_dumbbells:
		if DUMBBELL_LOCATION_IDS.has(collectable_id):
			check_location(DUMBBELL_LOCATION_IDS[collectable_id])

	_sync_checks("ap_checked_truck_scores")
	_sync_checks("ap_checked_shop_upgrades")
	_sync_checks("ap_checked_cats")
	_sync_checks("ap_checked_hats")
	_sync_checks("ap_checked_jewels")

func dumbbell_eaten(collectable_id: String) -> void:
	if not DUMBBELL_LOCATION_IDS.has(collectable_id):
		ModLoaderLog.warning("dumbbell_eaten: no AP location mapped for '%s'" % collectable_id, _LOG)
		return

	var eaten: Array = Globals.save_file.get_meta("ap_eaten_dumbbells", [])
	if not eaten.has(collectable_id):
		eaten.append(collectable_id)
		Globals.save_file.set_meta("ap_eaten_dumbbells", eaten)
		Globals.save_game()

	if connect_state != ConnectState.CONNECTED_TO_MULTIWORLD:
		return

	var location_id: int = DUMBBELL_LOCATION_IDS[collectable_id]
	ModLoaderLog.info("Sending dumbbell check for '%s' (location_id=%d)" % [collectable_id, location_id], _LOG)
	check_location(location_id)

func truck_score_achieved(score: int) -> void:
	if score <= 0:
		return
	var checked: Array = Globals.save_file.get_meta("ap_checked_truck_scores", [])
	var newly_checked := false
	for entry in TRUCK_SCORE_CHECKS:
		var threshold: int = entry[0]
		var location_id: int = entry[1]
		if score >= threshold and not checked.has(location_id):
			checked.append(location_id)
			newly_checked = true
			ModLoaderLog.info("Truck score check unlocked: location_id=%d (score=%d)" % [location_id, score], _LOG)
			if connect_state == ConnectState.CONNECTED_TO_MULTIWORLD:
				check_location(location_id)
	if newly_checked:
		Globals.save_file.set_meta("ap_checked_truck_scores", checked)
		Globals.save_game()

func shop_upgrade_purchased(flag: String) -> void:
	var location_id: int = SHOP_UPGRADE_LOCATION_IDS.get(flag, 0)
	if location_id == 0:
		ModLoaderLog.warning("shop_upgrade_purchased: unknown flag '%s'" % flag, _LOG)
		return
	ModLoaderLog.info("Shop upgrade purchased: flag='%s' location_id=%d" % [flag, location_id], _LOG)
	_send_check("ap_checked_shop_upgrades", location_id)

func cat_found(cat_id: item_tracker.item_id) -> void:
	var location_id: int = CAT_LOCATION_IDS.get(cat_id, 0)
	if location_id == 0:
		return
	ModLoaderLog.info("Cat found: id=%d location_id=%d" % [cat_id, location_id], _LOG)
	_send_check("ap_checked_cats", location_id)

func hat_collected(hat_id: int) -> void:
	var location_id: int = HAT_LOCATION_IDS.get(hat_id, 0)
	if location_id == 0:
		ModLoaderLog.warning("hat_collected: no AP location for hat_id=%d" % hat_id, _LOG)
		return
	ModLoaderLog.info("Hat collected: hat_id=%d location_id=%d" % [hat_id, location_id], _LOG)
	_send_check("ap_checked_hats", location_id)

func jewel_collected(jewel_flag: String) -> void:
	var location_id: int = JEWEL_LOCATION_IDS.get(jewel_flag, 0)
	if location_id == 0:
		ModLoaderLog.warning("jewel_collected: no AP location for jewel_flag='%s'" % jewel_flag, _LOG)
		return
	ModLoaderLog.info("Jewel collected: flag='%s' location_id=%d" % [jewel_flag, location_id], _LOG)
	_send_check("ap_checked_jewels", location_id)

func item_stored(id: item_tracker.item_id) -> void:
	if not ITEM_ID_TO_AP_LOCATION.has(id):
		ModLoaderLog.warning(
			"item_stored: no AP location mapped for item_id %d (%s)" % [id, item_tracker.item_id.keys()[id]],
			_LOG
		)
		return
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	if not ap_stored.has(id):
		ap_stored.append(id)
		Globals.save_file.set_meta("ap_stored_items", ap_stored)
		Globals.save_game()
	if connect_state != ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	var location_id: int = ITEM_ID_TO_AP_LOCATION[id]
	ModLoaderLog.info(
		"Sending location check for %s (location_id=%d)" % [item_tracker.item_id.keys()[id], location_id],
		_LOG
	)
	check_location(location_id)
