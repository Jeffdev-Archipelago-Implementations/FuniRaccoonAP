extends "res://Scene/photobooth/photobooth.gd"

# Hat picker added to the photobooth menu in scenes/photobooth.tscn
@onready var left_hat: Button = get_node_or_null("Node2D/CanvasLayer/menuracoon/Control/LeftHat")
@onready var right_hat: Button = get_node_or_null("Node2D/CanvasLayer/menuracoon/Control/RightHat")
@onready var hat_preview: TextureRect = get_node_or_null("Node2D/CanvasLayer/menuracoon/Control/HatPreview")
@onready var choose_hat_label: Label = get_node_or_null("Node2D/CanvasLayer/menuracoon/Control/ChooseHat")

func _ready() -> void:
	super()
	if left_hat == null or right_hat == null:
		return
	left_hat.pressed.connect(_cycle_hat.bind(-1))
	right_hat.pressed.connect(_cycle_hat.bind(1))
	_refresh_hat_picker()

func _on_area_3d_interacted(raccoon_player: PlayerScript) -> void:
	_refresh_hat_picker()
	super(raccoon_player)

# Hide the picker when the only option is no hat, since there's nothing to swap to.
func _refresh_hat_picker() -> void:
	var has_hats: bool = _wearable_hats().size() > 1
	for node in [left_hat, right_hat, hat_preview, choose_hat_label]:
		if node != null:
			node.visible = has_hats
	if has_hats:
		_update_hat_preview(Globals.save_file.current_hat)

# Only hats sent to us can be worn
func _wearable_hats() -> Array:
	var wearable: Array = []
	for hat_id in Globals.save_file.unlocked_hats:
		if Globals.hats_data.has(hat_id) and not wearable.has(hat_id):
			wearable.append(hat_id)
	if not wearable.has(hats_logic.hat_enum.NONE):
		wearable.push_front(hats_logic.hat_enum.NONE)
	return wearable

func _cycle_hat(direction: int) -> void:
	if player == null:
		return
	var wearable: Array = _wearable_hats()
	if wearable.size() <= 1:
		return
	var index: int = wearable.find(Globals.save_file.current_hat)
	var new_hat: hats_logic.hat_enum = wearable[posmod(index + direction, wearable.size())]
	player.set_hat(new_hat)
	_update_hat_preview(new_hat)

func _update_hat_preview(hat_id: hats_logic.hat_enum) -> void:
	if hat_preview == null:
		return
	hat_preview.texture = Globals.hats_data[hat_id].hat_texture if Globals.hats_data.has(hat_id) else null
