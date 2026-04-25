extends CanvasLayer

const LOG_NAME = "Jeffdev-FuniRaccoonAP/ap_connect_panel"
const CONFIG_PATH = "user://ap_connect.json"

var ap_client
var _visible := false

@onready var panel := $Panel
@onready var server_field := $Panel/VBoxContainer/ServerField
@onready var player_field := $Panel/VBoxContainer/PlayerField
@onready var password_field := $Panel/VBoxContainer/PasswordField
@onready var connect_button := $Panel/VBoxContainer/ConnectButton
@onready var status_label := $Panel/VBoxContainer/StatusLabel

func _ready() -> void:
	
	server_field.process_mode = Node.PROCESS_MODE_ALWAYS
	player_field.process_mode = Node.PROCESS_MODE_ALWAYS
	password_field.process_mode = Node.PROCESS_MODE_ALWAYS
	connect_button.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	
	layer = 128
	ap_client.connection_state_changed.connect(_on_connection_state_changed)

	# Load saved config
	if FileAccess.file_exists(CONFIG_PATH):
		var f = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed:
				server_field.text = parsed.get("ap_server", "")
				player_field.text = parsed.get("ap_player", "")
				password_field.text = parsed.get("ap_password", "")

	connect_button.pressed.connect(_on_connect_pressed)
	_update_status()
	panel.visible = false
	_visible = false
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			if not _visible and Globals.save_file == null:
				return
			_visible = !_visible
			panel.visible = _visible
			if _visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().paused = true
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				get_tree().paused = false

func _on_connect_pressed() -> void:
	var server = server_field.text.strip_edges()
	var player = player_field.text.strip_edges()
	var password = password_field.text.strip_edges()

	if server.is_empty() or player.is_empty():
		status_label.text = "Server and player name are required."
		return

	ap_client.server = server
	ap_client.player = player
	ap_client.password = password

	# Save to config
	var f = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"ap_server": server,
			"ap_player": player,
			"ap_password": password
		}, "\t"))
		f.close()

	status_label.text = "Connecting..."
	connect_button.disabled = true
	ap_client.connect_to_multiworld()

func _on_connection_state_changed(state: int, error: int = 0) -> void:
	_update_status(state, error)
	connect_button.disabled = (state == ap_client.ConnectState.CONNECTING)

func _update_status(state: int = -1, error: int = 0) -> void:
	if state == -1:
		state = ap_client.connect_state
	match state:
		ap_client.ConnectState.DISCONNECTED:
			status_label.text = "Disconnected" if error == 0 else "Error: %s" % ap_client.ConnectResult.keys()[error]
		ap_client.ConnectState.CONNECTING:
			status_label.text = "Connecting..."
		ap_client.ConnectState.CONNECTED_TO_SERVER:
			status_label.text = "Connected to server..."
		ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
			status_label.text = "Connected to multiworld!"
			panel.visible = false
			_visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().paused = false
		ap_client.ConnectState.DISCONNECTING:
			status_label.text = "Disconnecting..."
