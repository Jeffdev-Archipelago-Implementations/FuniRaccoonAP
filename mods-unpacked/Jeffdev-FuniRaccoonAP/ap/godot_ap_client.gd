## Godot Archipelago Client
##
## Manages the connection to the server, raises signals when Server-Client packets are
## received, and stores information about the connect multiworld room and slot.
##
## In addition, provides methods for sending Client-Server commands, and high-level API
## for common workflows such as establishing the connection.
extends Node
# Hard-code mod name to avoid cyclical dependency
var LOG_NAME = "Jeffdev-FuniRaccoonAP/GodotApClient"

enum ConnectState {
	DISCONNECTED = 0,
	CONNECTING = 1,
	DISCONNECTING = 2,
	CONNECTED_TO_SERVER = 3,
	CONNECTED_TO_MULTIWORLD = 4
}

enum ConnectResult {
	SUCCESS = 0,
	SERVER_CONNECT_FAILURE = 1,
	PLAYER_NOT_SET = 2,
	GAME_NOT_SET = 3,
	INVALID_SERVER = 4,
	# The following correspond to the errors the AP ConnectionRefused message can send.
	AP_INVALID_SLOT = 5,
	AP_INVALID_GAME = 6,
	AP_INCOMPATIBLE_VERSION = 7,
	AP_INVALID_PASSWORD = 8,
	AP_INVALID_ITEMS_HANDLING = 9,
	# Fallback in case a new error is added that we don't support yet
	AP_CONNECTION_REFUSED_UNKNOWN_REASON = 10,
	ALREADY_CONNECTED = 11
}

const _CACHE_DIR = "user://ap_datapackage_cache"

class ApDataPackage:
	# Per-game ID→name maps, keyed by game name.
	var items_by_game: Dictionary      # { game_name: { id -> name } }
	var locations_by_game: Dictionary  # { game_name: { id -> name } }
	# Own-game flat maps kept for backward-compat (ReceivedItems has no game context).
	var item_id_to_name: Dictionary
	var location_id_to_name: Dictionary
	var item_name_to_id: Dictionary
	var location_name_to_id: Dictionary
	# Stored so merge_game can update own-game flat maps when called after _init.
	var _own_game: String = ""

	func _init(data_package_object: Dictionary, own_game: String = ""):
		_own_game = own_game
		items_by_game = {}
		locations_by_game = {}
		item_id_to_name = {}
		location_id_to_name = {}
		item_name_to_id = {}
		location_name_to_id = {}

		if data_package_object.has("games"):
			var games: Dictionary = data_package_object["games"]
			for game_name in games:
				_index_game(game_name, games[game_name])
			if own_game != "" and games.has(own_game):
				item_id_to_name = items_by_game[own_game]
				location_id_to_name = locations_by_game[own_game]
				item_name_to_id = games[own_game].get("item_name_to_id", {})
				location_name_to_id = games[own_game].get("location_name_to_id", {})
		else:
			_index_game(own_game, data_package_object)
			item_id_to_name = items_by_game.get(own_game, {})
			location_id_to_name = locations_by_game.get(own_game, {})
			item_name_to_id = data_package_object.get("item_name_to_id", {})
			location_name_to_id = data_package_object.get("location_name_to_id", {})

	func merge_game(game_name: String, game_data: Dictionary) -> void:
		_index_game(game_name, game_data)
		if game_name == _own_game:
			item_id_to_name = items_by_game[game_name]
			location_id_to_name = locations_by_game[game_name]
			item_name_to_id = game_data.get("item_name_to_id", {})
			location_name_to_id = game_data.get("location_name_to_id", {})

	func _index_game(game_name: String, game_data: Dictionary) -> void:
		var item_map: Dictionary = {}
		for name in game_data.get("item_name_to_id", {}):
			item_map[game_data["item_name_to_id"][name]] = name
		items_by_game[game_name] = item_map

		var loc_map: Dictionary = {}
		for name in game_data.get("location_name_to_id", {}):
			loc_map[game_data["location_name_to_id"][name]] = name
		locations_by_game[game_name] = loc_map

	func resolve_item(item_id: int, game_name: String) -> String:
		# Try the specific game first, then fall back to all games.
		for gname in ([game_name] + items_by_game.keys()):
			var map: Dictionary = items_by_game.get(gname, {})
			var val = map.get(item_id, map.get(float(item_id), null))
			if val != null:
				return str(val)
		return ""

	func resolve_location(loc_id: int, game_name: String) -> String:
		# Try the specific game first, then fall back to all games.
		for gname in ([game_name] + locations_by_game.keys()):
			var map: Dictionary = locations_by_game.get(gname, {})
			var val = map.get(loc_id, map.get(float(loc_id), null))
			if val != null:
				return str(val)
		return ""

var websocket_client
var config
var connect_state = ConnectState.DISCONNECTED
var server: String = "localhost:38281"
var player: String = "Jeff-FRG"
var password: String = ""
var game: String = "Funi Raccoon Game"

var team: int
var slot: int
var players: Array
var missing_locations: Array
var checked_locations: Array
var slot_data: Dictionary
var slot_info: Dictionary
var hint_points: int
var player_tags: Array = []

var room_info: Dictionary
var data_package: ApDataPackage

signal _received_connect_response(message)
## Sent when the connection status to the server changes.
##
## Includes the new server state (one of `GodotApClient.ConnectResult`), and an error
## code if the connection encountered an error.
signal connection_state_changed(state, error)
signal item_received(item_name, item)
## Sent when a `SetReply` packet is received. Contains the key and new and old values.
signal data_storage_updated(key, new_value, original_value)
## Emitted when a `RoomUpdate` packet is received. Contains the new room information.
signal room_updated(updated_room_info)
## Emitted when a `Bounced` packet is received. Contains the packet's data.
signal bounced_received(bounced_data)

func _init(websocket_client_, config_):
	websocket_client = websocket_client_
	config = config_
	server = "localhost:38281"
	player = "Jeff-FRG"
	password = ""
	game = "Funi Raccoon Game"

func _ready():
	websocket_client.on_received_items.connect(_on_received_items)
	websocket_client.on_set_reply.connect(_on_set_reply)
	websocket_client.on_retrieved.connect(_on_retrieved)
	websocket_client.on_room_update.connect(_on_room_update)
	websocket_client.on_bounced.connect(_on_bounced_received)

func _connected_or_connection_refused_received(message: Dictionary):
	_received_connect_response.emit(message)

func connect_to_multiworld(get_data_package: bool = true) -> int:
	## Connect to the multiworld using the host/port/player/password provided.
	##
	## NOTE: The game, server, and player fields for the class MUST be set before
	## calling this. Otherwise, this will not attempt to connect will return an error
	## code.
	if websocket_client.connected_to_server() and self.connect_state == ConnectState.CONNECTED_TO_MULTIWORLD:
		return ConnectResult.ALREADY_CONNECTED
	elif player.strip_edges().is_empty():
		return ConnectResult.PLAYER_NOT_SET
	elif server.strip_edges().is_empty():
		return ConnectResult.INVALID_SERVER

	_set_connection_state(ConnectState.CONNECTING)

	if not websocket_client.connected_to_server():
		var server_connect_result = await websocket_client.connect_to_server(server)

		if server_connect_result == false:
			_set_connection_state(ConnectState.DISCONNECTED, ConnectResult.SERVER_CONNECT_FAILURE)
			return ConnectResult.SERVER_CONNECT_FAILURE
		else:
			_set_connection_state(ConnectState.CONNECTED_TO_SERVER)
			connect_state = ConnectState.CONNECTED_TO_SERVER

		room_info = await websocket_client.on_room_info

		if get_data_package:
			data_package = ApDataPackage.new({}, self.game)
			var checksums: Dictionary = room_info.get("datapackage_checksums", {})
			var games_in_room: Array = room_info.get("games", [])

			# Load cached games and collect those that are missing or stale.
			var games_to_fetch: Array = []
			for game_name in games_in_room:
				var cached = _load_cached_game(game_name, checksums.get(game_name, ""))
				if cached != null:
					data_package.merge_game(game_name, cached)
				else:
					games_to_fetch.append(game_name)

			if not games_to_fetch.is_empty():
				ModLoaderLog.info(
					"Fetching DataPackage for %d/%d games in batches (rest cached)." % [games_to_fetch.size(), games_in_room.size()],
					LOG_NAME
				)
				# Fetch in batches to keep each response payload small.
				const BATCH_SIZE = 30
				var batch_num = 0
				while batch_num * BATCH_SIZE < games_to_fetch.size():
					var batch = games_to_fetch.slice(batch_num * BATCH_SIZE, (batch_num + 1) * BATCH_SIZE)
					ModLoaderLog.info("Fetching DataPackage batch %d (%d games)..." % [batch_num + 1, batch.size()], LOG_NAME)
					websocket_client.get_data_package(batch)
					var data_package_message = await websocket_client.on_data_package
					var fetched_games: Dictionary = data_package_message["data"].get("games", {})
					for game_name in fetched_games:
						data_package.merge_game(game_name, fetched_games[game_name])
						_save_cached_game(game_name, checksums.get(game_name, ""), fetched_games[game_name])
					batch_num += 1
			else:
				ModLoaderLog.info("All %d games loaded from DataPackage cache." % games_in_room.size(), LOG_NAME)

			ModLoaderLog.info("DataPackage ready. item_ids=%d location_ids=%d" % [data_package.item_id_to_name.size(), data_package.location_id_to_name.size()], LOG_NAME)

	# Wait for the first response the server sends back
	if not websocket_client.on_connected.is_connected(_connected_or_connection_refused_received):
		websocket_client.on_connected.connect(_connected_or_connection_refused_received)
	if not websocket_client.on_connection_refused.is_connected(_connected_or_connection_refused_received):
		websocket_client.on_connection_refused.connect(_connected_or_connection_refused_received)

	ModLoaderLog.info("Sending Connect: game='%s' player='%s'" % [game, player], LOG_NAME)
	if room_info.get("password", false):
		websocket_client.send_connect(game, player, password, true, self.player_tags)
	else:
		websocket_client.send_connect(game, player, "", true, self.player_tags)
	var connect_response = await _received_connect_response

	if connect_response["cmd"] == "ConnectionRefused":
		ModLoaderLog.warning("ConnectionRefused errors: %s" % JSON.stringify(connect_response.get("errors", [])), LOG_NAME)
		# There may be multiple errors, but there isn't a clean way in Godot to return
		# them all. Just return the first error the multiworld server sent us.
		var ap_error: int
		match connect_response["errors"][0]:
			"InvalidSlot":
				ap_error = ConnectResult.AP_INVALID_SLOT
			"InvalidGame":
				ap_error = ConnectResult.AP_INVALID_GAME
			"IncompatibleVersion":
				ap_error = ConnectResult.AP_INCOMPATIBLE_VERSION
			"InvalidPassword":
				ap_error = ConnectResult.AP_INVALID_PASSWORD
			"InvalidItemsHandling":
				ap_error = ConnectResult.AP_INVALID_ITEMS_HANDLING
			_:
				ap_error = ConnectResult.AP_CONNECTION_REFUSED_UNKNOWN_REASON
		self._set_connection_state(self.connect_state, ap_error)
		return ap_error

	self.team = connect_response["team"]
	self.slot = connect_response["slot"]
	self.players = connect_response["players"]
	self.missing_locations = connect_response["missing_locations"].duplicate()
	self.checked_locations = connect_response["checked_locations"].duplicate()
	self.slot_data = connect_response["slot_data"]
	self.slot_info = connect_response["slot_info"]
	self.hint_points = connect_response["hint_points"]

	# The last two steps are handled by signal handlers and other classes.
	# 7. Server may send ReceivedItems to the client, in the case that the client is
	#    missing items that are queued up for it.
	# 8. Server sends PrintJSON to all players to notify them of the new client
	#    connection.

	_set_connection_state(ConnectState.CONNECTED_TO_MULTIWORLD)

	ModLoaderLog.info(
		(
			"Connected to Archipelago\n" + \
			"\tServer: %s, Player: %s, Game: %s, Slot: %d, Team: %d\n" % [self.server, self.player, self.game, self.slot, self.team] + \
			"\tChecked locations: %d, Missing locations: %d\n" % [self.checked_locations.size(), self.missing_locations.size()] + \
			"\tHint points: %d\n" % self.hint_points + \
			"\tSlot info: %s\n" % self.slot_info + \
			"\tSlot data:\n\t\t%s" % JSON.stringify(self.slot_data, "\t\t")
		),
		LOG_NAME
	)

	# Mod-specific: Save the connection parameters in the configuration file so
	# the user doesn't need to enter them twice.
	config["ap_server"] = server
	config["ap_player"] = player
	config["ap_password"] = password
	var f = FileAccess.open("user://ap_connect.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(config, "\t"))
		f.close()

	return ConnectResult.SUCCESS

func disconnect_from_multiworld():
	## Disconnect from the server. Can be called even when not connected.
	_set_connection_state(ConnectState.DISCONNECTING)
	self.websocket_client.disconnect_from_server()
	_set_connection_state(ConnectState.DISCONNECTED)
	self.player_tags = []

func _cache_path(game_name: String) -> String:
	# Replace characters that are invalid in filenames.
	var safe_name = game_name.replace("/", "_").replace("\\", "_").replace(":", "_")
	return "%s/%s.json" % [_CACHE_DIR, safe_name]

func _load_cached_game(game_name: String, expected_checksum: String) -> Variant:
	var path = _cache_path(game_name)
	if not FileAccess.file_exists(path):
		return null
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not parsed.has("checksum") or not parsed.has("data"):
		return null
	if parsed["checksum"] != expected_checksum:
		return null
	return parsed["data"]

func _save_cached_game(game_name: String, checksum: String, game_data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_CACHE_DIR)
	var path = _cache_path(game_name)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		ModLoaderLog.warning("Could not write DataPackage cache for '%s'" % game_name, LOG_NAME)
		return
	f.store_string(JSON.stringify({"checksum": checksum, "data": game_data}))
	f.close()

func _set_connection_state(state: int, error: int = 0):
	ModLoaderLog.debug("Setting connection state to %s." % ConnectState.keys()[state], LOG_NAME)
	self.connect_state = state
	connection_state_changed.emit(self.connect_state, error)

func set_status(status: int):
	## Send a `StatusUpdate` packet with the new client status.
	websocket_client.status_update(status)

func check_location(location_id: int):
	## Send a `LocationChecks` packet with the provided location ID(s).
	websocket_client.send_location_checks([location_id])

func get_value(keys: Array):
	## Send a `Get` packet to query the server's data storage.
	websocket_client.get_value(keys)

func set_notify(keys: Array):
	## Send a `SetNotify` packet to the server with the provided keys.
	websocket_client.set_notify(keys)

func set_value(key: String, operations, values, default = null, want_reply: bool = false):
	## Send a `Set` packet to the server to update the server's data storage.
	var ap_ops = Array()
	# Shorthand to allow more concise single operation argument
	if not (operations is Array):
		operations = [operations]
		values = [values]
	for i in range(operations.size()):
		var operation_obj = {"operation": operations[i], "value": values[i]}
		ap_ops.append(operation_obj)
	websocket_client.set_value(key, default, want_reply, ap_ops)

func add_player_tag(tag: String):
	# Add a tag to the player slot and send a ConnectUpdate if connected.
	if not self.player_tags.has(tag):
		self.player_tags.append(tag)
	if self.connect_state == ConnectState.CONNECTED_TO_MULTIWORLD:
		websocket_client.send_connect_update(-1, self.player_tags)

func enable_deathlink():
	# Convenience method to set the "DeathLink" tag for the slot
	add_player_tag("DeathLink")

func send_deathlink(source: String = "", cause: String = ""):
	# Convenience method for sending a DeathLink bounce packet
	var deathlink_args = {
		"time": Time.get_unix_time_from_system(),
	}
	if source == "":
		deathlink_args["source"] = player
	else:
		deathlink_args["source"] = source
	if cause:
		deathlink_args["cause"] = cause
	websocket_client.send_bounce(deathlink_args, [], [], ["DeathLink"])

func _on_received_items(command):
	# TODO: update missing and checked locations?
	var items = command["items"]
	for item in items:
		var item_name = null
		if self.data_package:
			item_name = data_package.item_id_to_name[item["item"]]
		else:
			ModLoaderLog.warning("Received item when data package was not loaded", LOG_NAME)
		ModLoaderLog.info("Received item '%s'" % item_name, LOG_NAME)
		item_received.emit(item_name, item)

func _on_retrieved(command):
	# TODO: Custom additional args
	for key in command["keys"]:
		data_storage_updated.emit(
			key,
			command["keys"][key],
			null
		)

func _on_room_update(command: Dictionary):
	if command.has("checked_locations"):
		for location in command["checked_locations"]:
			checked_locations.append(location)
			var missing_idx = missing_locations.find(location)
			missing_locations.remove_at(missing_idx)
	room_updated.emit(command)

func _on_set_reply(command):
	data_storage_updated.emit(
		command["key"],
		command["value"],
		command["original_value"]
	)

func _on_bounced_received(bounced_data: Dictionary):
	bounced_received.emit(bounced_data)
