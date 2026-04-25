extends Node
class_name ApWebSocketConnection

enum State {
	CONNECTING = 0,
	OPEN = 1,
	CLOSING = 2,
	CLOSED = 3,
}

# Hard-code mod name to avoid cyclical dependency
const LOG_NAME = "Jeffdev-FuniRaccoonAP/ap_websocket_connection"
const _DEFAULT_PORT = 38281
const _CONNECT_TIMEOUT_SECONDS = 5

var _peer: WebSocketPeer
var _url: String
var _waiting_to_connect_to_server = null
var _last_ws_state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED

var connection_state = State.CLOSED

signal connection_state_changed(state)
signal on_connected(connection_data)
signal on_connection_refused(refused_reason)
signal on_room_info(room_info)
signal on_received_items(command)
signal on_location_info(command)
signal on_room_update(command)
signal on_print_json(command)
signal on_data_package(command)
signal on_bounced(command)
signal on_invalid_packet(command)
signal on_retrieved(command)
signal on_set_reply(command)

signal _stop_waiting_to_connect(success)

func _ready():
	# Always process so we don't disconnect if the game is paused for too long.
	process_mode = Node.PROCESS_MODE_ALWAYS

# Public API
func connect_to_server(server: String) -> bool:
	if connection_state == State.OPEN:
		return true
	_set_connection_state(State.CONNECTING)

	# Use the default Archipelago port if not included in the URL
	var port_check_pattern = RegEx.new()
	port_check_pattern.compile(":(\\d+)$")
	var server_has_port = port_check_pattern.search(server)
	if not server_has_port:
		server = "%s:%d" % [server, _DEFAULT_PORT]

	# Try to connect with SSL first
	var wss_url = "wss://%s" % [server]

	_init_client()
	_waiting_to_connect_to_server = wss_url
	_make_connection_timeout(wss_url)
	_peer.connect_to_url(wss_url)

	var wss_success = await _stop_waiting_to_connect
	_waiting_to_connect_to_server = null

	var ws_success = false
	if not wss_success:
		# We don't have any info on why the connection failed (thanks Godot), so we
		# assume it was because the server doesn't support SSL. So, try connecting using
		# "ws://" instead.
		ModLoaderLog.info("Connecting with WSS failed, trying WS.", LOG_NAME)
		var ws_url = "ws://%s" % [server]
		_init_client()
		_waiting_to_connect_to_server = ws_url
		_make_connection_timeout(ws_url)
		_peer.connect_to_url(ws_url)

		ws_success = await _stop_waiting_to_connect
		_waiting_to_connect_to_server = null
		if ws_success:
			_url = ws_url
	else:
		_url = wss_url

	if wss_success or ws_success:
		_set_connection_state(State.OPEN)
		ModLoaderLog.info("Connected to multiworld %s." % _url, LOG_NAME)

	return wss_success or ws_success

func connected_to_server() -> bool:
	return connection_state == State.OPEN

func disconnect_from_server():
	if connection_state == State.CLOSED:
		return
	_set_connection_state(State.CLOSING)
	# The _process handler will detect the CLOSED state and call _on_connection_closed
	_peer.close()

func send_connect(game: String, user: String, password: String = "", slot_data: bool = true, tags: Array = []):
	_send_command({
		"cmd": "Connect",
		"game": game,
		"name": user,
		"password": password,
		"uuid": "Godot %s: %s" % [game, user],
		"version": {"major": 0, "minor": 6, "build": 7, "class": "Version"},
		"items_handling": 0b111,
		"tags": tags,
		"slot_data": slot_data
	})

func send_connect_update(items_handling: int = -1, tags = null):
	var args = {"cmd": "ConnectUpdate"}
	if items_handling >= 0:
		args["items_handling"] = items_handling
	if tags != null:
		args["tags"] = tags
	_send_command(args)

func send_sync():
	_send_command({"cmd": "Sync"})

func send_location_checks(locations: Array):
	_send_command(
		{
			"cmd": "LocationChecks",
			"locations": locations,
		}
	)

# TODO: create_as_hint Enum
func send_location_scouts(locations: Array, create_as_int: int):
	_send_command({
		"cmd": "LocationScouts",
		"locations": locations,
		"create_as_int": create_as_int
	})

func status_update(status: int):
	_send_command({
		"cmd": "StatusUpdate",
		"status": status,
	})

func say(text: String):
	_send_command({
		"cmd": "Say",
		"text": text,
	})

func get_data_package(games: Array):
	_send_command({
		"cmd": "GetDataPackage",
		"games": games,
	})

func send_bounce(data: Dictionary, games: Array = [], slots: Array = [], tags: Array = []):
	var args = {"cmd": "Bounce", "data": data}
	if games.size() > 0:
		args["games"] = games
	if slots.size() > 0:
		args["slots"] = slots
	if tags.size() > 0:
		args["tags"] = tags

	_send_command(args)

# TODO: Extra custom arguments
func get_value(keys: Array):
	# This is Archipelago's "Get" command, we change the name
	# since "get" is already taken by "Object.get".
	_send_command({
		"cmd": "Get",
		"keys": keys,
	})

# TODO: DataStorageOperation data type
func set_value(key: String, default, want_reply: bool, operations: Array):
	_send_command({
		"cmd": "Set",
		"key": key,
		"default": default,
		"want_reply": want_reply,
		"operations": operations,
	})

func set_notify(keys: Array):
	_send_command({
		"cmd": "SetNotify",
		"keys": keys,
	})

# Internal connection state callbacks (called from _process based on peer state changes)
func _on_connection_established():
	ModLoaderLog.info("Successfully connected.", LOG_NAME)
	_stop_waiting_to_connect.emit(true)

func _on_connection_error():
	ModLoaderLog.info("Connection error.", LOG_NAME)
	_stop_waiting_to_connect.emit(false)

func _on_connection_closed():
	ModLoaderLog.info("AP connection closed.", LOG_NAME)
	_set_connection_state(State.CLOSED)

func _on_data_received():
	var received_data_str = _peer.get_packet().get_string_from_utf8()
	var received_data = JSON.parse_string(received_data_str)
	if received_data == null:
		ModLoaderLog.error("Failed to parse JSON for %s" % received_data_str, LOG_NAME)
		return
	for command in received_data:
		_handle_command(command)

# Internal plumbing
func _send_command(args: Dictionary):
	var command_str = JSON.stringify([args])
	if _peer != null:
		var result = _peer.send_text(command_str)
		if result != OK:
			ModLoaderLog.warning("Failed to send command, error code: %d" % result, LOG_NAME)
	else:
		ModLoaderLog.warning("Peer is null!", LOG_NAME)

func _init_client():
	if _peer != null:
		_peer.close()
	_peer = WebSocketPeer.new()

	# Increase max inbound buffer size to accommodate AP's larger payloads.
	# Some messages we receive are too large for the default 65KB buffer.
	# NOTE: Godot will silently drop packets that do not fit in the buffer!
	_peer.inbound_buffer_size = 1024 * 1024 * 20  # 20 MB

	# Set _last_ws_state to CONNECTING so _process detects transitions correctly
	_last_ws_state = WebSocketPeer.STATE_CONNECTING

func _make_connection_timeout(for_url: String):
	await get_tree().create_timer(_CONNECT_TIMEOUT_SECONDS).timeout
	if _waiting_to_connect_to_server == for_url:
		# We took too long, stop waiting and tell the caller we failed.
		_waiting_to_connect_to_server = false
		ModLoaderLog.info("Timed out trying to connect.", LOG_NAME)
		_stop_waiting_to_connect.emit(false)

func _set_connection_state(state):
	var state_name = State.keys()[state]
	ModLoaderLog.info("AP connection state changed to: %s." % state_name, LOG_NAME)
	connection_state = state
	connection_state_changed.emit(connection_state)

func _handle_command(command: Dictionary):
	ModLoaderLog.info("Received %s command" % command["cmd"], LOG_NAME)
	match command["cmd"]:
		"RoomInfo":
			on_room_info.emit(command)
		"ConnectionRefused":
			on_connection_refused.emit(command)
		"Connected":
			on_connected.emit(command)
		"ReceivedItems":
			on_received_items.emit(command)
		"LocationInfo":
			on_location_info.emit(command)
		"RoomUpdate":
			on_room_update.emit(command)
		"PrintJSON":
			on_print_json.emit(command)
		"DataPackage":
			on_data_package.emit(command)
		"Bounced":
			on_bounced.emit(command)
		"InvalidPacket":
			on_invalid_packet.emit(command)
		"Retrieved":
			on_retrieved.emit(command)
		"SetReply":
			on_set_reply.emit(command)
		_:
			ModLoaderLog.warning("Received Unknown Command %s" % command["cmd"], LOG_NAME)

func _process(_delta):
	if _peer == null:
		return
	_peer.poll()
	var state = _peer.get_ready_state()
	if state != _last_ws_state:
		match state:
			WebSocketPeer.STATE_OPEN:
				_on_connection_established()
			WebSocketPeer.STATE_CLOSED:
				if _last_ws_state == WebSocketPeer.STATE_CONNECTING:
					_on_connection_error()
				else:
					_on_connection_closed()
		_last_ws_state = state
	if state == WebSocketPeer.STATE_OPEN:
		while _peer.get_available_packet_count() > 0:
			_on_data_received()
