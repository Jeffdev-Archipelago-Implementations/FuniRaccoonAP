## Funi Raccoon Game Archipelago Client
##
## Extends GodotApClient with game-specific integration:
## - Maps each item_tracker.item_id to an Archipelago location ID
## - Provides item_stored() to send a location check when an item is dumpster'd
extends "res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap/godot_ap_client.gd"

const _LOG = "Jeffdev-FuniRaccoonAP/FuniRaccoonApClient"

## Base offset for all Funi Raccoon Game location IDs in the AP multiworld.
const LOCATION_ID_BASE = 1000

## Valid goal name strings; slot_data["goal"] is an Archipelago OptionSet and arrives as an
## Array of these (one or more may be selected — all selected goals must be completed to win).
const VALID_GOALS: Array = ["orb", "museum", "fellowship", "lugh"]

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

const POLICE_TRAP_AP_ITEM_ID = 701
const PHONE_RATIO_TRAP_AP_ITEM_ID = 702
const BRAZIL_TRAIN_TICKET_AP_ITEM_ID = 800

## Mobile/portrait window size used by the Phone Ratio Trap (matches Scene/Menus/settings/resolution_settings.gd's "Phone" option).
const PHONE_SCREEN_SIZE = Vector2i(240, 480)

const POLICE_CLUSTER_SCENE = preload("res://Scene/characters/police/police_cluster.tscn")
const POLICE_WARNING_SCENE = preload("res://Scene/characters/police/police_warning.tscn")
const POLICE_TRAP_WARNING_DURATION: float = 20.0
const POLICE_TRAP_CAR_DURATION: float = 25.0
const MAX_CONCURRENT_POLICE_CLUSTERS: int = 1

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

const COOLING_ROD_PROGRESSION: Array = [
	item_tracker.item_id.COOLING_ROD,
	item_tracker.item_id.COOLING_ROD_PLIMBO,
	item_tracker.item_id.COOLING_ROD_FRIDGE_KING,
]

const TRUCK_UPGRADE_ITEM_MAP: Dictionary = {
	KEI_TRUCK_RADIO_AP_ITEM_ID:   truck_flags.radio_purchased,
	KEI_TRUCK_TOASTER_AP_ITEM_ID: truck_flags.jump_purchased,
	KEI_TRUCK_BOOST_AP_ITEM_ID:   truck_flags.boost_purchased,
}

const SHOP_UPGRADE_LOCATION_IDS: Dictionary = {
	truck_flags.radio_purchased: 4001,
	truck_flags.jump_purchased:  4002,
	truck_flags.boost_purchased: 4003,
}

const CAT_LOCATION_IDS: Dictionary = {
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

const VEHICLE_LOCATION_IDS: Dictionary = {
	2: 9002, # Fork Vehicle
	3: 9002, # Tony Vehicle
	4: 9003, # Horse
}

## AP item id -> SaveGame.vehicles value. 5 is the trolley, which the mod adds
## to the selector itself (SaveGame.vehicles stops at HORSE = 4).
const VEHICLE_AP_ITEM_IDS: Dictionary = {
	900: 1, # Scooter
	901: 2, # Tony
	902: 3, # Fork
	903: 4, # Horse
	904: 5, # Trolly
}

## Maps money.gd money_id strings (str(get_path()) + str(value)) to AP location IDs.
const EURO_LOCATION_IDS: Dictionary = {
	# Norwich (scene root: GymDay)
	"/root/GymDay/money/money5":                      8001, # Norwich: Euro at train station
	"/root/GymDay/moneys/money/money25":              8002, # Norwich: Euro at chicken farm island
	# Chicken Farm (scene root: Level_Container)
	"/root/Level_Container/money/money5":             8003, # Chicken Farm: Euro on pillar
	# Gym (scene root: gym)
	"/root/gym/money/money5":                         8004, # Gym: Euro on roof with vending machine
	"/root/gym/money3/money20":                       8005, # Gym: Euro behind building
	"/root/gym/money2/money50":                       8006, # Gym: Euro at the end of train tracks
	"/root/gym/money4/money100":                      8007, # Gym: Euro on bee sign under clouds
	# Tyre Shop (scene root: Node3D)
	"/root/Node3D/money/money1":       				  8008, # Tyre Shop: Euro on roof of entrance
	# Water Zone (scene root: Level)
	"/root/Level/money2/money50":                     8009, # Water Zone: Euro under stairs underwater
	# Beenie Death (scene root: beenieDiesOnTheCross)
	"/root/beenieDiesOnTheCross/money/money20":       8010, # Beenie Death: Euro behind cross
	# Canyon (scene root: Canyon)
	"/root/Canyon/money/money1":                      8011, # Canyon: Euro on the edge of canyon
	# Parking Lot / Trasco (scene root: TrascoCarpark)
	"/root/TrascoCarpark/money/money150":             8012, # Trasco: Euro on edge wall 1
	"/root/TrascoCarpark/money2/money150":            8013, # Trasco: Euro on edge wall 2
	"/root/TrascoCarpark/money3/money150":            8014, # Trasco: Euro on edge wall 3
	# Blimbo City (scene root: City)
	"/root/City/MoneyHolder/money/money100":          8015, # City: Euro on watertower
	"/root/City/MoneyHolder/money2/money20":          8016, # City: Euro near boat on edge of city
	"/root/City/Bellboyevent/money2/money5":          8017, # City: Euro near Robin P. Bobin Store
	"/root/City/Bellboyevent/money3/money5":          8018, # City: Euro net to Robin P. Bobin Store
	"/root/City/Bellboyevent/money4/money5":          8019, # City: Euro near Guns stands
	"/root/City/Bellboyevent/money5/money5":          8020, # City: Euro under city on girders 1
	"/root/City/Bellboyevent/money6/money5":          8021, # City: Euro under city on girders 2
	"/root/City/Bellboyevent/money7/money5":          8022, # City: Euro under city on girders 3
	"/root/City/Bellboyevent/money8/money5":          8023, # City: Euro under city on girders 4
	"/root/City/Bellboyevent/money9/money5":          8024, # City: Euro near cheese wheel
	# Blimbo Village (scene root: Blimbo)
	"/root/Blimbo/money2/money25":                    8025, # Village: Euro on castle
	# Desert Connections / Wastes (scene root: MeshInstance3D)
	"/root/MeshInstance3D/moneys/money/money1":       8027, # Wastes: Euro on top of breakfast building
	"/root/MeshInstance3D/moneys/money2/money1":      8028, # Wastes: Euro on top of chinese building
	"/root/MeshInstance3D/moneys/money7/money1":      8029, # Wastes: Euro on lower end of chinese building
	"/root/MeshInstance3D/moneys/money3/money1":      8030, # Wastes: Euro on sad therapy sign building
	"/root/MeshInstance3D/moneys/money4/money1":      8031, # Wastes: Euro nearby mystical dumbbell in flowers
	"/root/MeshInstance3D/moneys/money5/money1":      8032, # Wastes: Euro on road edge
	"/root/MeshInstance3D/moneys/money6/money1":      8033, # Wastes: Euro on dead blimbos building
	# Desert Level (scene root: Desert_Level)
	"/root/Desert_Level/money/money1":                8034, # Desert: Euro on tilted building
	"/root/Desert_Level/money2/money1":               8035, # Desert: Euro in moai head pool 1
	"/root/Desert_Level/money3/money1":               8036, # Desert: Euro in moai head pool 2
	"/root/Desert_Level/money4/money1":               8037, # Desert: Euro in moai head pool 3
	"/root/Desert_Level/money5/money1":               8038, # Desert: Euro in moai head pool 4
	"/root/Desert_Level/money6/money1":               8039, # Desert: Euro in moai head pool 5
	"/root/Desert_Level/money7/money1":               8040, # Desert: Euro in moai head pool 6
	"/root/Desert_Level/money8/money1":               8041, # Desert: Euro on pillar near MFC
	"/root/Desert_Level/money10/money1":              8042, # Desert: Euro on yellow house roof in fridge land
	"/root/Desert_Level/money9/money1":               8043, # Desert: Euro in New Buisness HQ
	"/root/Desert_Level/money11/money1":              8044, # Desert: Euro on top of fridge land skull
	"/root/Desert_Level/money12/money1":              8045, # Desert: Euro on on blue house roof in fridge land
	"/root/Desert_Level/money13/money1":              8046, # Desert: Euro in BLMB nuclear reactor
	# Brazil
	"/root/Level_Container/money/money100":           8047, # Brazil: Euro on top of train
	# Hat Store
	"/root/Node3D/money/money30":                     8048, # Hat Store: Euro from saving toastie
}

## Maps item_tracker.item_id enum values to AP location IDs.
const ITEM_ID_TO_AP_LOCATION: Dictionary = {
	item_tracker.item_id.MOAI:                     LOCATION_ID_BASE + 1,
	item_tracker.item_id.STREET_LIGHT:             LOCATION_ID_BASE + 2,
	item_tracker.item_id.FUN_BELLS:                LOCATION_ID_BASE + 3,
	item_tracker.item_id.LAMA:                     LOCATION_ID_BASE + 4,
	item_tracker.item_id.GYM:                      LOCATION_ID_BASE + 5,
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
	item_tracker.item_id.BEENIE_FACTORY_SIGN:      LOCATION_ID_BASE + 60,
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
	item_tracker.item_id.TRASCO_SIGN:              LOCATION_ID_BASE + 92,
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
	item_tracker.item_id.BLIMBO_CITY_SIGN:         LOCATION_ID_BASE + 103,
	item_tracker.item_id.BENCH:                    LOCATION_ID_BASE + 104,
	item_tracker.item_id.EVIL_RACCOON:             LOCATION_ID_BASE + 105,
	item_tracker.item_id.NAKED_FELLA:              LOCATION_ID_BASE + 106,
	item_tracker.item_id.BIN:                      LOCATION_ID_BASE + 107,
	item_tracker.item_id.FRIEND_MARTIN:            LOCATION_ID_BASE + 108,
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
	item_tracker.item_id.MIKK_MASSIVE:             LOCATION_ID_BASE + 152,
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
	item_tracker.item_id.BRAZIL_KNIGHT:			  LOCATION_ID_BASE + 176,
	item_tracker.item_id.REAL_FOOTBALL:           LOCATION_ID_BASE + 177,
	item_tracker.item_id.DOGGY:                    LOCATION_ID_BASE + 178,
	item_tracker.item_id.HINTBLO:            	  LOCATION_ID_BASE + 179,
	item_tracker.item_id.FUNI_RACCOON:            LOCATION_ID_BASE + 180,
	item_tracker.item_id.TONY_ENGINE: 			  LOCATION_ID_BASE + 181,
	item_tracker.item_id.OUTDOOR_CHAIR: 		  LOCATION_ID_BASE + 182,
	item_tracker.item_id.LIGHTNING_ROD:           LOCATION_ID_BASE + 183,
	item_tracker.item_id.ROBIN:                   LOCATION_ID_BASE + 184,
	185:                                          LOCATION_ID_BASE + 185, # Gacha, this item id is forced in manually

}

# Guard flag to distinguish AP-granted items from player throws.
var _receiving_from_ap: bool = false
# Item index at connect time; popups only fire for items at or above this index.
var _baseline_item_index: int = -1
# ItemTacker.thresholds as shipped by the game, captured before overwriting with
# the slot's threshold options so it can be restored on disconnect.
var _vanilla_thresholds: Array = []

# True once we've fully joined the multiworld this session. Used so a *failed* connect
# attempt (which also ends in DISCONNECTED) doesn't kick the player back to the menu.
var _was_connected: bool = false

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

func _ready() -> void:
	super._ready()
	connection_state_changed.connect(_on_connection_state_changed)
	websocket_client.on_print_json.connect(_on_print_json)

# Boilerplate server/boot messages shown on connect that we don't want in chat.
const FILTERED_MESSAGE_SUBSTRINGS: Array = [
	"does not support compressed",
	"Now that you are connected",
]

func _on_print_json(command: Dictionary) -> void:
	var parts: Array = command.get("data", [])
	if parts.is_empty():
		return
	if str(command.get("type", "")) == "Tutorial":
		return
	var plain := ""
	for part in parts:
		plain += str(part.get("text", ""))
	for needle in FILTERED_MESSAGE_SUBSTRINGS:
		if plain.find(needle) != -1:
			return
	var bbcode := ""
	for part in parts:
		var text: String = str(part.get("text", ""))
		if text.is_empty():
			continue
		var color: String = str(part.get("color", ""))
		var part_type: String = str(part.get("type", "text"))

		# Resolve numeric IDs to human-readable names
		match part_type:
			"player_id":
				text = _get_player_name(int(text))
			"item_id":
				if data_package:
					var game_name := _get_player_game(int(part.get("player", 0)))
					var resolved := data_package.resolve_item(int(text), game_name)
					if resolved != "":
						text = resolved
			"location_id":
				if data_package:
					var game_name := _get_player_game(int(part.get("player", 0)))
					var resolved := data_package.resolve_location(int(text), game_name)
					if resolved != "":
						text = resolved

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
			bbcode += "[color=%s]%s[/color]" % [AP_COLORS[color], text]
		else:
			bbcode += text
	if bbcode.strip_edges().is_empty():
		return
	var popup_script = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
	popup_script.show_message(bbcode, get_tree().get_root(), _print_json_is_relevant(command, parts))

# Whether a PrintJSON message involves the local player, for the "your messages only"
# chat filter (F4). Item/hint messages count when you are the sender or receiver;
# other messages count when they reference your slot. Server replies and global
# countdowns always count.
func _print_json_is_relevant(command: Dictionary, parts: Array) -> bool:
	var me: int = slot
	match str(command.get("type", "")):
		"ItemSend", "Hint":
			if int(command.get("receiving", -1)) == me:
				return true
			var item_dict = command.get("item", null)
			if item_dict is Dictionary and int(item_dict.get("player", -1)) == me:
				return true
			return false
		"CommandResult", "AdminCommandResult", "Countdown":
			return true
		_:
			if int(command.get("slot", -1)) == me:
				return true
			for part in parts:
				if str(part.get("type", "")) == "player_id" and int(str(part.get("text", "-1"))) == me:
					return true
			return false

func _show_popup(item_name: String, fallback: String, item_dict: Dictionary, show: bool) -> void:
	if not show:
		return
	var popup_script = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_item_popup.gd")
	popup_script.show_popup(
		item_name if item_name != "" else fallback,
		_get_player_name(int(item_dict.get("player", 0))),
		get_tree().get_root()
	)

var _active_police_clusters: Array = []
var _active_police_warning: Node2D = null

func clear_police_warning() -> void:
	if is_instance_valid(_active_police_warning):
		_active_police_warning.queue_free()
	_active_police_warning = null

func _trigger_police_trap() -> void:
	var raccoon_player := Globals.get_player()
	if not is_instance_valid(raccoon_player) or not is_instance_valid(LevelChanger.current_level):
		ModLoaderLog.warning("Police Trap: no valid player/level to spawn into, skipping.", _LOG)
		return
	# Cap concurrent clusters so a burst of Police Trap items (e.g. several granted at once on
	# connect) can't spawn dozens of pathfinding cars simultaneously - that hung the game before.
	_active_police_clusters = _active_police_clusters.filter(func(c): return is_instance_valid(c))
	if _active_police_clusters.size() >= MAX_CONCURRENT_POLICE_CLUSTERS:
		ModLoaderLog.info("Police Trap: a cluster is already active, skipping this one.", _LOG)
		return

	var police_inst: Node3D = POLICE_CLUSTER_SCENE.instantiate()
	LevelChanger.current_level.add_child(police_inst)
	# Offset slightly: police_cluster.tscn's first car has zero local transform, so spawning
	# exactly on the player made its look_at() fail every frame (origin == target position).
	police_inst.global_position = raccoon_player.global_position + Vector3(2.0, 0.0, 2.0)
	_active_police_clusters.append(police_inst)
	get_tree().create_timer(POLICE_TRAP_CAR_DURATION).timeout.connect(func():
		if is_instance_valid(police_inst):
			police_inst.queue_free()
	)

	clear_police_warning()
	var warning_inst: Node2D = POLICE_WARNING_SCENE.instantiate()
	_active_police_warning = warning_inst
	warning_inst.tree_exited.connect(func():
		if _active_police_warning == warning_inst:
			_active_police_warning = null
	)
	var message_label: RichTextLabel = warning_inst.get_node("CanvasLayer/CenterContainer/RichTextLabel")
	if is_instance_valid(message_label):
		message_label.text = "[center]THEY GOT A POLICE TRAP LMAOOOO[/center]\n\n\n[center][shake][color=#FF0000]GET THEY/THEM ASS[/color][/shake][/center]"
	var warning_timer: Timer = warning_inst.get_node("Timer")
	if is_instance_valid(warning_timer):
		warning_timer.wait_time = POLICE_TRAP_WARNING_DURATION
	get_tree().get_root().add_child(warning_inst)

	ModLoaderLog.info("Police Trap triggered at %s." % str(raccoon_player.global_position), _LOG)

var _phone_trap_original_size: Vector2i = Vector2i(854, 480)
var _phone_trap_active: bool = false
var _phone_trap_generation: int = 0

const PHONE_RATIO_TRAP_DURATION: float = 30.0

func _trigger_phone_ratio_trap() -> void:
	if not _phone_trap_active:
		_phone_trap_original_size = Globals.save_file.screen_size
		_phone_trap_active = true
	_phone_trap_generation += 1
	var this_generation: int = _phone_trap_generation
	Globals.save_file.screen_size = PHONE_SCREEN_SIZE
	Globals.updated_res.emit()
	ModLoaderLog.info("Phone Ratio Trap triggered; reverting in %.0fs." % PHONE_RATIO_TRAP_DURATION, _LOG)
	get_tree().create_timer(PHONE_RATIO_TRAP_DURATION).timeout.connect(func():
		if this_generation != _phone_trap_generation:
			return
		Globals.save_file.screen_size = _phone_trap_original_size
		Globals.updated_res.emit()
		_phone_trap_active = false
		ModLoaderLog.info("Phone Ratio Trap expired; screen size reverted.", _LOG)
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

	for i in range(items.size()):
		var absolute_index := cmd_index + i
		if absolute_index < stored_index:
			continue  # Already processed this item in a previous session.
		var show_popup := (_baseline_item_index >= 0 and absolute_index >= _baseline_item_index)

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
			_show_popup(item_name, "Progressive Mystical Dumbbell", items[i], show_popup)
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
				_show_popup(item_name, "Progressive Cooling Rod", items[i], show_popup)
			else:
				ModLoaderLog.warning("AP granted Progressive Cooling Rod but all three are already collected.", _LOG)
		elif ap_item_id == item_tracker.item_id.KEI_TRUCK:
			if not Globals.save_file.items_stored.has(item_tracker.item_id.KEI_TRUCK):
				_receiving_from_ap = true
				Globals.save_file.items_stored.append(item_tracker.item_id.KEI_TRUCK)
				Globals.dumpster_added_item.emit()
				_receiving_from_ap = false
				changed = true
				ModLoaderLog.info("AP granted Kei Truck.", _LOG)
				_show_popup(item_name, "Kei Truck", items[i], show_popup)
		elif TRUCK_UPGRADE_ITEM_MAP.has(ap_item_id):
			var flag: String = TRUCK_UPGRADE_ITEM_MAP[ap_item_id]
			if not Globals.save_file.truck_upgrades.has(flag):
				Globals.save_file.truck_upgrades.append(flag)
				changed = true
				ModLoaderLog.info("AP granted truck upgrade '%s'." % flag, _LOG)
				_show_popup(item_name, flag, items[i], show_popup)
		elif HAT_AP_ITEM_IDS.has(ap_item_id):
			var hat_enum_id: int = HAT_AP_ITEM_IDS[ap_item_id]
			if not Globals.save_file.unlocked_hats.has(hat_enum_id):
				Globals.save_file.unlocked_hats.append(hat_enum_id)
				changed = true
				ModLoaderLog.info("AP granted hat enum_id=%d." % hat_enum_id, _LOG)
				_show_popup(item_name, "Hat", items[i], show_popup)
		elif JEWEL_AP_ITEM_IDS.has(ap_item_id):
			var jewel_flag: String = JEWEL_AP_ITEM_IDS[ap_item_id]
			if not Globals.save_file.states_occurred.has(jewel_flag):
				Globals.save_file.states_occurred.append(jewel_flag)
				changed = true
				ModLoaderLog.info("AP granted jewel flag='%s'." % jewel_flag, _LOG)
				_show_popup(item_name, "Mystical Jewel", items[i], show_popup)
			var received_jewels: Array = Globals.save_file.get_meta("ap_received_jewels", [])
			if not received_jewels.has(ap_item_id):
				received_jewels.append(ap_item_id)
				Globals.save_file.set_meta("ap_received_jewels", received_jewels)
		elif VEHICLE_AP_ITEM_IDS.has(ap_item_id):
			var vehicle_id: int = VEHICLE_AP_ITEM_IDS[ap_item_id]
			if not Globals.save_file.unlocked_vehicles.has(vehicle_id):
				Globals.save_file.unlocked_vehicles.append(vehicle_id)
				changed = true
				ModLoaderLog.info("AP granted vehicle=%d." % vehicle_id, _LOG)
				_show_popup(item_name, "Vehicle", items[i], show_popup)
			var received_vehicles: Array = Globals.save_file.get_meta("ap_received_vehicles", [])
			if not received_vehicles.has(vehicle_id):
				received_vehicles.append(vehicle_id)
				Globals.save_file.set_meta("ap_received_vehicles", received_vehicles)
		elif ap_item_id == EURO_10_AP_ITEM_ID:
			Globals.add_euro(10.0)
			changed = true
			ModLoaderLog.info("AP granted 10 Euro.", _LOG)
			_show_popup(item_name, "10 Euro", items[i], show_popup)
		elif ap_item_id == EURO_100_AP_ITEM_ID:
			Globals.add_euro(100.0)
			changed = true
			ModLoaderLog.info("AP granted 100 Euro.", _LOG)
			_show_popup(item_name, "100 Euro", items[i], show_popup)
		elif ap_item_id == POLICE_TRAP_AP_ITEM_ID:
			_trigger_police_trap()
		elif ap_item_id == PHONE_RATIO_TRAP_AP_ITEM_ID:
			_trigger_phone_ratio_trap()
			changed = true
			_show_popup(item_name, "Phone Ratio Trap", items[i], show_popup)
		elif ap_item_id == BRAZIL_TRAIN_TICKET_AP_ITEM_ID:
			if not Globals.save_file.get_meta("ap_brazil_train_ticket", false):
				Globals.save_file.set_meta("ap_brazil_train_ticket", true)
				changed = true
				ModLoaderLog.info("AP granted Brazil Train Ticket.", _LOG)
				_show_popup(item_name, "Brazil Train Ticket", items[i], show_popup)
		elif ITEM_ID_TO_AP_LOCATION.has(ap_item_id):
			if not Globals.save_file.items_stored.has(ap_item_id):
				_receiving_from_ap = true
				Globals.save_file.items_stored.append(ap_item_id)
				Globals.dumpster_added_item.emit()
				_receiving_from_ap = false
				changed = true
				_show_popup(item_name, str(ap_item_id), items[i], show_popup)
		else:
			ModLoaderLog.info("AP item id=%d ('%s') has no handler, skipping." % [ap_item_id, item_name], _LOG)

		# The base class emits this per item; keep that contract since this override
		# replaces its handler entirely (UI refreshes listen for it).
		item_received.emit(item_name, items[i])

		stored_index = absolute_index + 1
		Globals.save_file.set_meta("ap_received_item_index", stored_index)

	if changed:
		Globals.save_game()

func _get_player_name(player_slot: int) -> String:
	for p in players:
		if int(p.get("slot", -1)) == player_slot:
			return str(p.get("alias", p.get("name", "Unknown")))
	return "Unknown"

func _get_player_game(player_slot: int) -> String:
	var info = slot_info.get(str(player_slot), slot_info.get(player_slot, null))
	if info is Dictionary:
		return str(info.get("game", ""))
	return ""

const ACT_CLUSTER_NAMES: Dictionary = {
	1: "ACT_1_CLUSTER",     # act1
	2: "ACT_2_CLUSTER",    	# act2
	5: "ACT_3_CLUSTER", 	# act3
}

func _map_location_key() -> String:
	return "map_location_%s" % player

func update_map_location(level_id: int) -> void:
	if connect_state != ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	set_value(_map_location_key(), "replace", level_changer.LEVEL_ID.keys()[level_id])

func update_map_location_for_cluster(cluster_id: int) -> void:
	if connect_state != ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	var act_name: String = ACT_CLUSTER_NAMES.get(cluster_id, "")
	if act_name == "":
		return
	set_value(_map_location_key(), "replace", act_name)

## Refuses to join a room whose seed doesn't match the one this save file was first connected
## to (stored as the "ap_seed" save meta by ap_connect_panel.gd on successful connect), so a
## save can't be accidentally corrupted by playing it against a different multiworld.
func _validate_room_info(room_info_to_validate: Dictionary) -> int:
	var stored_seed: String = str(Globals.save_file.get_meta("ap_seed", ""))
	var room_seed: String = str(room_info_to_validate.get("seed_name", ""))
	if stored_seed != "" and room_seed != "" and stored_seed != room_seed:
		ModLoaderLog.warning(
			"Seed mismatch: save was started on seed '%s' but the room is seed '%s'. Refusing to connect." % [stored_seed, room_seed],
			_LOG
		)
		return ConnectResult.SEED_MISMATCH
	return ConnectResult.SUCCESS

func _on_connection_state_changed(new_state: int, _error: int = 0) -> void:
	if new_state == ConnectState.CONNECTING:
		_baseline_item_index = -1
	elif new_state == ConnectState.CONNECTED_TO_MULTIWORLD:
		_was_connected = true
		_baseline_item_index = Globals.save_file.get_meta("ap_received_item_index", 0)
		# Swap the dumpster progress thresholds (ItemTacker.thresholds) for the slot's
		# options so vanilla consumers like dumpster_text.gd display AP values.
		if _vanilla_thresholds.is_empty():
			_vanilla_thresholds = ItemTacker.thresholds.duplicate()
		ItemTacker.thresholds = [
			int(slot_data.get("options", {}).get("museum_threshold", 15)),
			int(slot_data.get("options", {}).get("act2_threshold", 25)),
			int(slot_data.get("options", {}).get("act3_threshold", 35)),
			int(slot_data.get("options", {}).get("act4_threshold", 50)),
		]
		if LevelChanger.current_level != null:
			update_map_location(LevelChanger.current_level.level_id)
		sync_stored_items()
		Globals.save_file.streamer_mode = true
		var rackheath = LevelChanger.all_levels.get(level_changer.LEVEL_ID.DEFAULT)
		if rackheath != null:
			rackheath.level_found = false
		if Globals.save_file.found_levels.has(level_changer.LEVEL_ID.DEFAULT):
			Globals.save_file.found_levels.erase(level_changer.LEVEL_ID.DEFAULT)
			Globals.save_game()
		var on_rackheath = LevelChanger.current_level != null and LevelChanger.current_level.level_id == level_changer.LEVEL_ID.DEFAULT
		if not on_rackheath:
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
		var popup_script = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
		popup_script.show_message(popup_script.HELP_MESSAGE, get_tree().get_root())
	elif new_state == ConnectState.DISCONNECTED:
		if not _vanilla_thresholds.is_empty():
			ItemTacker.thresholds.assign(_vanilla_thresholds)
		if _was_connected:
			# We lost an established multiworld connection: clean up and return to menu.
			_was_connected = false
			var popup_script = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_chat_popup.gd")
			popup_script.clear_all()
			var item_popup_script = load("res://mods-unpacked/Jeffdev-FuniRaccoonAP/ap_item_popup.gd")
			item_popup_script.clear_all()
			popup_script.show_message("[color=#EE0000]Disconnected from Archipelago[/color]", get_tree().get_root())
			Globals.QUIT_TO_MEUN()

const _DEFAULT_GATE_THRESHOLDS := [15, 25, 35, 50]

## Remaps a vanilla dumpster gate value (a hub door/floor/meter's hardcoded 15/25/35/50)
## to this slot's configured threshold. Values that aren't gate defaults (0, 3, etc.) are
## returned unchanged, as is everything while disconnected (thresholds not yet swapped).
func slot_threshold_for(vanilla_value: int) -> int:
	if _vanilla_thresholds.is_empty():
		return vanilla_value
	var idx: int = _DEFAULT_GATE_THRESHOLDS.find(vanilla_value)
	if idx == -1 or idx >= ItemTacker.thresholds.size():
		return vanilla_value
	return int(ItemTacker.thresholds[idx])

func sync_stored_items() -> void:
	var thrown: Array = Globals.save_file.get_meta("ap_stored_items", [])
	ModLoaderLog.info("Syncing %d dumpster'd items to AP" % thrown.size(), _LOG)
	var found_changed := false
	for id in thrown:
		if ITEM_ID_TO_AP_LOCATION.has(id):
			check_location(ITEM_ID_TO_AP_LOCATION[id])
		if not Globals.save_file.items_found.has(id):
			Globals.save_file.items_found.append(id)
			found_changed = true
	if found_changed:
		Globals.save_game()

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
	_sync_checks("ap_checked_euros")
	_sync_checks("ap_checked_vehicles")
	_sync_checks("ap_checked_speedway")

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

func vehicle_unlocked(vehicle: int) -> void:
	var location_id: int = VEHICLE_LOCATION_IDS.get(vehicle, 0)
	if location_id == 0:
		ModLoaderLog.warning("vehicle_unlocked: no AP location for vehicle=%d" % vehicle, _LOG)
		return
	ModLoaderLog.info("Vehicle unlocked: vehicle=%d location_id=%d" % [vehicle, location_id], _LOG)
	_send_check("ap_checked_vehicles", location_id)

func euro_collected(money_id: String) -> void:
	var location_id: int = EURO_LOCATION_IDS.get(money_id, 0)
	if location_id == 0:
		ModLoaderLog.warning("euro_collected: no AP location for money_id='%s'" % money_id, _LOG)
		return
	ModLoaderLog.info("Euro collected: money_id='%s' location_id=%d" % [money_id, location_id], _LOG)
	_send_check("ap_checked_euros", location_id)

## Reads slot_data["goal"] (an Archipelago OptionSet) as the list of goal names that must ALL be completed to goal.
func get_required_goals() -> Array:
	var goal_raw = slot_data.get("goal", [])
	var goals: Array = []
	if goal_raw is Array:
		goals = goal_raw
	elif goal_raw is Dictionary:
		goals = goal_raw.keys()
	elif goal_raw != null and str(goal_raw) != "":
		goals = [str(goal_raw)]
	var valid: Array = []
	for goal in goals:
		if VALID_GOALS.has(str(goal)):
			valid.append(str(goal))
		else:
			ModLoaderLog.warning("get_required_goals: ignoring unrecognized goal '%s' in slot_data." % str(goal), _LOG)
	return valid

func is_goal_completed(goal: String) -> bool:
	var completed: Array = Globals.save_file.get_meta("ap_goals_completed", [])
	return completed.has(goal)

## Whether the item/dumpster-count prerequisites for a single goal are currently satisfied.
func _goal_requirements_met(goal: String) -> bool:
	var stored: Array = Globals.save_file.items_stored
	var dumpster_count: int = stored.size()
	var act4_threshold: int = slot_threshold_for(50)
	match goal:
		"orb":
			return (dumpster_count >= act4_threshold
				and stored.has(item_tracker.item_id.ORB)
				and stored.has(item_tracker.item_id.COOLING_ROD)
				and stored.has(item_tracker.item_id.COOLING_ROD_PLIMBO)
				and stored.has(item_tracker.item_id.COOLING_ROD_FRIDGE_KING))
		"museum":
			return (dumpster_count >= 100
				and stored.has(item_tracker.item_id.WAFFLE)
				and stored.has(item_tracker.item_id.COOLING_ROD)
				and stored.has(item_tracker.item_id.COOLING_ROD_PLIMBO)
				and stored.has(item_tracker.item_id.COOLING_ROD_FRIDGE_KING))
		"fellowship":
			return (dumpster_count >= act4_threshold
				and stored.has(item_tracker.item_id.PRIESTESS)
				and stored.has(item_tracker.item_id.GREENIE)
				and stored.has(item_tracker.item_id.COOLING_ROD)
				and stored.has(item_tracker.item_id.COOLING_ROD_PLIMBO)
				and stored.has(item_tracker.item_id.COOLING_ROD_FRIDGE_KING))
		"lugh":
			return dumpster_count >= act4_threshold
		_:
			ModLoaderLog.warning("check_goal: unknown goal '%s'." % goal, _LOG)
			return false

func check_goal(triggered_goal: String = "") -> void:
	if connect_state != ConnectState.CONNECTED_TO_MULTIWORLD:
		ModLoaderLog.info("check_goal: not connected, skipping.", _LOG)
		return
	var required_goals: Array = get_required_goals()
	if required_goals.is_empty():
		ModLoaderLog.warning("check_goal: slot_data has no goals configured, skipping.", _LOG)
		return
	if triggered_goal != "":
		if not required_goals.has(triggered_goal):
			ModLoaderLog.info("check_goal: '%s' triggered but not among selected goals %s, skipping." % [triggered_goal, str(required_goals)], _LOG)
			return
		if not is_goal_completed(triggered_goal):
			if not _goal_requirements_met(triggered_goal):
				ModLoaderLog.info("check_goal: '%s' triggered but requirements not yet met, skipping." % triggered_goal, _LOG)
				return
			var completed: Array = Globals.save_file.get_meta("ap_goals_completed", [])
			completed.append(triggered_goal)
			Globals.save_file.set_meta("ap_goals_completed", completed)
			Globals.save_game()
			ModLoaderLog.info("Goal '%s' complete (%d/%d selected goals done)." % [triggered_goal, completed.size(), required_goals.size()], _LOG)

	if Globals.save_file.get_meta("ap_goal_complete", false):
		return
	for goal in required_goals:
		if not is_goal_completed(goal):
			return
	ModLoaderLog.info("All selected goals complete %s - sending CLIENT_GOAL." % str(required_goals), _LOG)
	Globals.save_file.set_meta("ap_goal_complete", true)
	Globals.save_game()
	set_status(ApTypes.ClientStatus.CLIENT_GOAL)

func speedway_completed() -> void:
	ModLoaderLog.info("Behrman Speedway completed in time — sending check.", _LOG)
	_send_check("ap_checked_speedway", LOCATION_ID_BASE + 8001)

func item_stored(id: item_tracker.item_id) -> void:
	if not ITEM_ID_TO_AP_LOCATION.has(id):
		ModLoaderLog.warning(
			"item_stored: no AP location mapped for item_id %d (%s)" % [id, item_tracker.item_id.keys()[id]],
			_LOG
		)
		return
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	var changed := false
	if not ap_stored.has(id):
		ap_stored.append(id)
		Globals.save_file.set_meta("ap_stored_items", ap_stored)
		changed = true
	# A stored (dumpster'd) item also counts as found.
	if not Globals.save_file.items_found.has(id):
		Globals.save_file.items_found.append(id)
		changed = true
	if changed:
		Globals.save_game()
	if connect_state != ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	var location_id: int = ITEM_ID_TO_AP_LOCATION[id]
	ModLoaderLog.info(
		"Sending location check for %s (location_id=%d)" % [item_tracker.item_id.keys()[id], location_id],
		_LOG
	)
	check_location(location_id)
