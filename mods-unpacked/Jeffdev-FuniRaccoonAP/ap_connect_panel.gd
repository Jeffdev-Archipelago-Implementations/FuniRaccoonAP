extends CanvasLayer

const LOG_NAME = "Jeffdev-FuniRaccoonAP/ap_connect_panel"
const CONFIG_PATH = "user://ap_connect.json"

var ap_client
var _visible := false
var _force_open := false
var _going_to_menu := false

@onready var panel := $Panel
@onready var server_field := $Panel/VBoxContainer/ServerField
@onready var player_field := $Panel/VBoxContainer/PlayerField
@onready var password_field := $Panel/VBoxContainer/PasswordField
@onready var connect_button := $Panel/VBoxContainer/ConnectButton
@onready var main_menu_button := $Panel/VBoxContainer/MainMenuButton
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
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	main_menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_update_status()
	panel.visible = false
	_visible = false
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if _visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Globals.save_file.id_name.is_empty():
		_going_to_menu = false
		return
	if _force_open or _going_to_menu:
		return
	if ap_client.connect_state == ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
		return
	if not is_instance_valid(LevelChanger.current_level):
		return
	show_forced()

func show_overlay() -> void:
	if _visible:
		return
	_visible = true
	panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_apply_slot_lock()
	if not ap_client.connect_state == ap_client.ConnectState.CONNECTING:
		status_label.text = "Enter your Archipelago connection details."

func show_forced() -> void:
	_force_open = true
	_visible = true
	panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().set_deferred("paused", true)
	_apply_slot_lock()
	if not ap_client.connect_state == ap_client.ConnectState.CONNECTING:
		status_label.text = "Archipelago connection required. Please connect to continue."

func _apply_slot_lock() -> void:
	if Globals.save_file.id_name.is_empty():
		return
	var saved_slot: String = Globals.save_file.get_meta("ap_slot_name", "")
	if saved_slot != "":
		player_field.text = saved_slot
		player_field.editable = false
	else:
		player_field.editable = true

func _on_main_menu_pressed() -> void:
	_going_to_menu = true
	_force_open = false
	_visible = false
	panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not _visible:
		return
	if event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()

func _on_connect_pressed() -> void:
	var server = server_field.text.strip_edges()
	var player = player_field.text.strip_edges()
	var password = password_field.text.strip_edges()

	if server.is_empty() or player.is_empty():
		status_label.text = "Server and player name are required."
		return

	if Globals.save_file != null:
		var saved_slot: String = Globals.save_file.get_meta("ap_slot_name", "")
		if saved_slot != "" and saved_slot != player:
			status_label.text = "This save requires slot name: %s" % saved_slot
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
			status_label.text = "Connected to server, processing datapackages..."
		ap_client.ConnectState.CONNECTED_TO_MULTIWORLD:
			if Globals.save_file != null:
				var player: String = player_field.text.strip_edges()
				if player != "":
					Globals.save_file.set_meta("ap_slot_name", player)
					Globals.save_game()
			_force_open = false
			status_label.text = "Connected to multiworld!"
			panel.visible = false
			_visible = false
			if is_instance_valid(LevelChanger.current_level):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().paused = false
		ap_client.ConnectState.DISCONNECTING:
			status_label.text = "Disconnecting..."
