extends RefCounted

# Archipelago id constants

const STORE_LOCATION_OFFSET := 1000

const STORE_ITEMS: Array = [
	item_tracker.item_id.MOAI,
	item_tracker.item_id.STREET_LIGHT,
	item_tracker.item_id.FUN_BELLS,
	item_tracker.item_id.LAMA,
	item_tracker.item_id.GYM,
	item_tracker.item_id.VENDING_MACHINE,
	item_tracker.item_id.COIN,
	item_tracker.item_id.RADIO,
	item_tracker.item_id.GUN,
	item_tracker.item_id.CONSTRUCTION_SIGN,
	item_tracker.item_id.CHICKEN,
	item_tracker.item_id.WASHING_MACHINE,
	item_tracker.item_id.CAT,
	item_tracker.item_id.BROB_ENERGY,
	item_tracker.item_id.BUISNESS_MAN,
	item_tracker.item_id.CONCRETE_CAT,
	item_tracker.item_id.GIZMO_CAT,
	item_tracker.item_id.KEKSZ_CAT,
	item_tracker.item_id.MICHI_CAT,
	item_tracker.item_id.BOINGLER_CAT,
	item_tracker.item_id.PARACETAMOL,
	item_tracker.item_id.TORCH,
	item_tracker.item_id.MONITOR,
	item_tracker.item_id.SIGN,
	item_tracker.item_id.CRACKHEAD,
	item_tracker.item_id.CRAYON,
	item_tracker.item_id.CRICKET_BAT,
	item_tracker.item_id.PIRATE_1,
	item_tracker.item_id.PIRATE_2,
	item_tracker.item_id.PIRATE_3,
	item_tracker.item_id.CONSTRUCTION_SIGN_SPIN,
	item_tracker.item_id.MICROWAVE,
	item_tracker.item_id.TOASTER,
	item_tracker.item_id.LOGAN_LEFT,
	item_tracker.item_id.LOGAN_RIGHT,
	item_tracker.item_id.FISH,
	item_tracker.item_id.FERAL_DOG,
	item_tracker.item_id.WINDMILL,
	item_tracker.item_id.BEENIE_BOX,
	item_tracker.item_id.GOO,
	item_tracker.item_id.BEENIE,
	item_tracker.item_id.FAN,
	item_tracker.item_id.BEENIE_FACTORY_SIGN,
	item_tracker.item_id.LETTER_B,
	item_tracker.item_id.BEENIE_STATUE,
	item_tracker.item_id.CANDLE,
	item_tracker.item_id.FUNI_MARKETABLE_PLUSHIE,
	item_tracker.item_id.PATRICK_OHARA,
	item_tracker.item_id.TOASTIE,
	item_tracker.item_id.CRISP,
	item_tracker.item_id.FLOWER,
	item_tracker.item_id.DIVIDER,
	item_tracker.item_id.OFFICE_CHAIR,
	item_tracker.item_id.OFFICE_DESK,
	item_tracker.item_id.MY_FAVORITE_CHAIR,
	item_tracker.item_id.CRICKET,
	item_tracker.item_id.UNDYING_LOVE,
	item_tracker.item_id.BLIMBO_SIGN,
	item_tracker.item_id.OUGHAM_STONE,
	item_tracker.item_id.COW,
	item_tracker.item_id.MINES_KEY,
	item_tracker.item_id.PLIMBO,
	item_tracker.item_id.FRIDGE_KEY,
	item_tracker.item_id.TYRE,
	item_tracker.item_id.PAPA_TYRE,
	item_tracker.item_id.SMOKER,
	item_tracker.item_id.BROKEN_TRUCK,
	item_tracker.item_id.CHEESE,
	item_tracker.item_id.GAS_DRUM,
	item_tracker.item_id.COFFEE_SHOP,
	item_tracker.item_id.TROLLEY,
	item_tracker.item_id.TRASCO_SIGN,
	item_tracker.item_id.FOLDING_CHAIR,
	item_tracker.item_id.COOLING_ROD,
	item_tracker.item_id.WARNING_BLIMBO,
	item_tracker.item_id.PICKAXE,
	item_tracker.item_id.BROKEN_WALL,
	item_tracker.item_id.FONE_BLIMBO,
	item_tracker.item_id.COFFEE_CUP,
	item_tracker.item_id.KETTLE_BLIMBO,
	item_tracker.item_id.RADIATOR_BLIMBO,
	item_tracker.item_id.FLOWER_BLIMBO,
	item_tracker.item_id.BLIMBO_CITY_SIGN,
	item_tracker.item_id.BENCH,
	item_tracker.item_id.EVIL_RACCOON,
	item_tracker.item_id.NAKED_FELLA,
	item_tracker.item_id.BIN,
	item_tracker.item_id.FRIEND_MARTIN,
	item_tracker.item_id.KNIFE,
	item_tracker.item_id.SUITCASE,
	item_tracker.item_id.PINT,
	item_tracker.item_id.FLOWIAN,
	item_tracker.item_id.BOMB,
	item_tracker.item_id.BELL,
	item_tracker.item_id.DEMON_CORE,
	item_tracker.item_id.APPLE,
	item_tracker.item_id.GAS_PUMPO,
	item_tracker.item_id.CD_PLAYER,
	item_tracker.item_id.RADIO_BLIMBO,
	item_tracker.item_id.BINOCULBLO,
	item_tracker.item_id.POLICE_CAR,
	item_tracker.item_id.HAZELNUT,
	item_tracker.item_id.ANTI_SADS,
	item_tracker.item_id.TV_REMOTE,
	item_tracker.item_id.PIANO,
	item_tracker.item_id.BRICK,
	item_tracker.item_id.LLOYD,
	item_tracker.item_id.MANHOLE_COVER,
	item_tracker.item_id.OLD_STATION_SIGN,
	item_tracker.item_id.WARNING_SIGN,
	item_tracker.item_id.TRAIN_SIGN,
	item_tracker.item_id.ORB,
	item_tracker.item_id.MS_HEEL,
	item_tracker.item_id.MR_HEEL,
	item_tracker.item_id.WAFFLE,
	item_tracker.item_id.GREENIE,
	item_tracker.item_id.PRIESTESS,
	item_tracker.item_id.BEENIE_SAVES_THE_KIDS,
	item_tracker.item_id.HERMIT_CAN,
	item_tracker.item_id.BARREL,
	item_tracker.item_id.BOOKBLO,
	item_tracker.item_id.FRIDGE,
	item_tracker.item_id.FRIDGLING,
	item_tracker.item_id.SNOWBALL,
	item_tracker.item_id.LEECHES,
	item_tracker.item_id.COOLING_ROD_PLIMBO,
	item_tracker.item_id.COOLING_ROD_FRIDGE_KING,
	item_tracker.item_id.BEACH_BALL,
	item_tracker.item_id.MILK_KLUBNIKA,
	item_tracker.item_id.MIKK_MASSIVE,
	item_tracker.item_id.CHAIRAPIST,
	item_tracker.item_id.CAMERA,
	item_tracker.item_id.YOLKY,
	item_tracker.item_id.PAWN,
	item_tracker.item_id.ROOK,
	item_tracker.item_id.BISHOP,
	item_tracker.item_id.QUEEN,
	item_tracker.item_id.KING,
	item_tracker.item_id.FAKE_GYM,
	item_tracker.item_id.SPOONSWEET,
	item_tracker.item_id.WRIKS_CELLAR,
	item_tracker.item_id.DOOR,
	item_tracker.item_id.FUNI_RACCOON_GAME_CD,
	item_tracker.item_id.GOLDEN_MONKEY,
	item_tracker.item_id.GOO_MACHINE,
	item_tracker.item_id.BUTTERFLY,
	item_tracker.item_id.PATRICK_O_BOBBLE,
	item_tracker.item_id.DICEBLO,
	item_tracker.item_id.LUGHLING,
	item_tracker.item_id.BOOK_STACK,
	item_tracker.item_id.TITO,
	item_tracker.item_id.CHEESE_WOMAN,
	item_tracker.item_id.BRAZIL_KNIGHT,
	item_tracker.item_id.HINTBLO,
	item_tracker.item_id.REAL_FOOTBALL,
	item_tracker.item_id.DOGGY,
	item_tracker.item_id.FUNI_RACCOON,
	item_tracker.item_id.TONY_ENGINE,
	item_tracker.item_id.OUTDOOR_CHAIR,
	item_tracker.item_id.LIGHTNING_ROD,
	item_tracker.item_id.ROBIN,
	185, # Gacha Machine, this doesn't have an item id in the item tracker so we just force add it here
]

static func store_location(item_id: int) -> int:
	return STORE_LOCATION_OFFSET + item_id

# Items

const PROGRESSIVE_COOLING_ROD := 94
const COOLING_ROD_ORDER: Array = [
	item_tracker.item_id.COOLING_ROD,
	item_tracker.item_id.COOLING_ROD_PLIMBO,
	item_tracker.item_id.COOLING_ROD_FRIDGE_KING,
]
const KEI_TRUCK_UPGRADES: Dictionary = {
	201: truck_flags.radio_purchased,
	202: truck_flags.jump_purchased,  # Toaster
	203: truck_flags.boost_purchased,
}
const EURO_10 := 300
const EURO_100 := 301
const PROGRESSIVE_DUMBBELL := 400
const HATS: Dictionary = {
	501: hats_logic.hat_enum.SunHat,      # Sun Hat
	502: hats_logic.hat_enum.sombrero,    # Sombrero
	503: hats_logic.hat_enum.Tophat,      # Top Hat
	504: hats_logic.hat_enum.Jester,      # Jester Hat
	505: hats_logic.hat_enum.RaccoonHat,  # Raccoon Hat
	506: hats_logic.hat_enum.ConeHat,     # Media Player Hat
	507: hats_logic.hat_enum.CrownHat,    # Fridge Crown
	508: hats_logic.hat_enum.PaddyHat,    # Patty Hat
}
const JEWELS: Dictionary = {
	601: "jewel_1_eaten",  # Green
	602: "jewel_2_eaten",  # Blue
	603: "jewel_3_eaten",  # Purple
	604: "jewel_4_eaten",  # Red
}
const POLICE_TRAP := 701
const PHONE_RATIO_TRAP := 702
const BRAZIL_TRAIN_TICKET := 800
const VEHICLES: Dictionary = {
	900: SaveGame.vehicles.SCOOTER,
	901: SaveGame.vehicles.TONY,
	902: SaveGame.vehicles.FORKLIFT,
	903: SaveGame.vehicles.HORSE,
	904: 5, # Trolley, unused vehicle in vanilla that we add
}

# Locations

# [score threshold, location]
const TRUCK_SCORE_LOCATIONS: Array = [
	[1000, 2001],
	[2000, 2002],
	[3000, 2003],
	[4000, 2004],
	[5000, 2005],
]
const DUMBBELL_LOCATIONS: Dictionary = {
	"dumbell_1": 3001,
	"dumbell_2": 3002,
	"dumbell_3": 3003,
	"dumbell_4": 3004,
}
const SHOP_UPGRADE_LOCATIONS: Dictionary = {
	truck_flags.radio_purchased: 4001,
	truck_flags.jump_purchased: 4002,
	truck_flags.boost_purchased: 4003,
}
const CAT_LOCATIONS: Dictionary = {
	item_tracker.item_id.MICHI_CAT: 5001,
	item_tracker.item_id.CAT: 5002,
	item_tracker.item_id.CONCRETE_CAT: 5003,
	item_tracker.item_id.GIZMO_CAT: 5004,
	item_tracker.item_id.KEKSZ_CAT: 5005,
	item_tracker.item_id.BOINGLER_CAT: 5006,
}
const HAT_LOCATIONS: Dictionary = {
	hats_logic.hat_enum.SunHat: 6001,
	hats_logic.hat_enum.sombrero: 6002,
	hats_logic.hat_enum.Tophat: 6003,
	hats_logic.hat_enum.Jester: 6004,
	hats_logic.hat_enum.RaccoonHat: 6005,
	hats_logic.hat_enum.ConeHat: 6006,
	hats_logic.hat_enum.CrownHat: 6007,
	hats_logic.hat_enum.PaddyHat: 6008,
}
const JEWEL_LOCATIONS: Dictionary = {
	"jewel_1_eaten": 7001,
	"jewel_2_eaten": 7002,
	"jewel_3_eaten": 7003,
	"jewel_4_eaten": 7004,
}
# money.gd money_id (str(get_path()) + str(value)) -> location
const EURO_LOCATIONS: Dictionary = {
	"/root/GymDay/money/money5":                 8001,  # Norwich: Euro at train station
	"/root/GymDay/moneys/money/money25":         8002,  # Norwich: Euro at chicken farm island
	"/root/Level_Container/money/money5":        8003,  # Chicken Farm: Euro on pillar
	"/root/gym/money/money5":                    8004,  # Gym: Euro on roof with vending machine
	"/root/gym/money3/money20":                  8005,  # Gym: Euro behind building
	"/root/gym/money2/money50":                  8006,  # Gym: Euro at end of train tracks
	"/root/gym/money4/money100":                 8007,  # Gym: Euro on bee sign under clouds
	"/root/Node3D/money/money1":                 8008,  # Tyre: Euro on roof of entrance
	"/root/Level/money2/money50":                8009,  # Water Zone: Euro under stairs underwater
	"/root/beenieDiesOnTheCross/money/money20":  8010,  # Beenie Death: Euro behind cross
	"/root/Canyon/money/money1":                 8011,  # Canyon: Euro on edge of canyon
	"/root/TrascoCarpark/money/money150":        8012,  # Trasco: Euro on edge wall 1
	"/root/TrascoCarpark/money2/money150":       8013,  # Trasco: Euro on edge wall 2
	"/root/TrascoCarpark/money3/money150":       8014,  # Trasco: Euro on edge wall 3
	"/root/City/MoneyHolder/money/money100":     8015,  # City: Euro on watertower
	"/root/City/MoneyHolder/money2/money20":     8016,  # City: Euro near boat on edge of city
	"/root/City/Bellboyevent/money2/money5":     8017,  # City: Euro at Robin P. Bobin Store
	"/root/City/Bellboyevent/money3/money5":     8018,  # City: Euro next to Robin P. Bobin Store
	"/root/City/Bellboyevent/money4/money5":     8019,  # City: Euro near Guns stands
	"/root/City/Bellboyevent/money5/money5":     8020,  # City: Euro under city on girders 1
	"/root/City/Bellboyevent/money6/money5":     8021,  # City: Euro under city on girders 2
	"/root/City/Bellboyevent/money7/money5":     8022,  # City: Euro under city on girders 3
	"/root/City/Bellboyevent/money8/money5":     8023,  # City: Euro under city on girders 4
	"/root/City/Bellboyevent/money9/money5":     8024,  # City: Euro near cheese wheel
	"/root/Blimbo/money2/money25":               8025,  # Village: Euro on castle
	"/root/MeshInstance3D/moneys/money/money1":  8027,  # Wastes: Euro on top of breakfast building
	"/root/MeshInstance3D/moneys/money2/money1": 8028,  # Wastes: Euro on top of chinese building
	"/root/MeshInstance3D/moneys/money7/money1": 8029,  # Wastes: Euro on lower end of chinese building
	"/root/MeshInstance3D/moneys/money3/money1": 8030,  # Wastes: Euro on sad therapy sign building
	"/root/MeshInstance3D/moneys/money4/money1": 8031,  # Wastes: Euro nearby mystical dumbbell in flowers
	"/root/MeshInstance3D/moneys/money5/money1": 8032,  # Wastes: Euro on road edge
	"/root/MeshInstance3D/moneys/money6/money1": 8033,  # Wastes: Euro on dead blimbos building
	"/root/Desert_Level/money/money1":           8034,  # Desert: Euro on tilted building
	"/root/Desert_Level/money2/money1":          8035,  # Desert: Euro in moai head pool 1
	"/root/Desert_Level/money3/money1":          8036,  # Desert: Euro in moai head pool 2
	"/root/Desert_Level/money4/money1":          8037,  # Desert: Euro in moai head pool 3
	"/root/Desert_Level/money5/money1":          8038,  # Desert: Euro in moai head pool 4
	"/root/Desert_Level/money6/money1":          8039,  # Desert: Euro in moai head pool 5
	"/root/Desert_Level/money7/money1":          8040,  # Desert: Euro in moai head pool 6
	"/root/Desert_Level/money8/money1":          8041,  # Desert: Euro on pillar near MFC
	"/root/Desert_Level/money10/money1":         8042,  # Desert: Euro on yellow house roof in fridge land
	"/root/Desert_Level/money9/money1":          8043,  # Desert: Euro in New Buisness HQ
	"/root/Desert_Level/money11/money1":         8044,  # Desert: Euro on top of fridge land skull
	"/root/Desert_Level/money12/money1":         8045,  # Desert: Euro on blue house roof in fridge land
	"/root/Desert_Level/money13/money1":         8046,  # Desert: Euro in BLMB nuclear reactor
	"/root/Level_Container/money/money100":      8047,  # Brazil: Euro on middle hill
	"/root/Node3D/money/money30":                8048,  # Hat Store: Euro reward after saving Toastie
}
const SPEEDWAY_LOCATION := 9001
const VEHICLE_LOCATIONS: Dictionary = {
	SaveGame.vehicles.TONY: 9002,
	SaveGame.vehicles.FORKLIFT: 9002,
	SaveGame.vehicles.HORSE: 9003,
}
