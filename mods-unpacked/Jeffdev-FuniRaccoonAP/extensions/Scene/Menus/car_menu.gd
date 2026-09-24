extends "res://Scene/Menus/car_menu.gd"

const TROLLEY_LOGO_UID := "uid://cads36fss47rk"
const TROLLEY_MENU_SCALE := 0.75
const TROLLEY_MENU_LIFT := 0.50

# To be perfectly honest, this is probably somewhat sloppy and I'm lazy, so I'm letting the AI take the reigns
# on this one. Seems to work fine though, no issues as far as I can spot

func _ready() -> void:
	super()
	_ap_add_trolley()

func _ap_add_trolley() -> void:
	var mod_main: Node = ModLoader.get_node("Jeffdev-FuniRaccoonAP")
	var trolley_id: int = mod_main.TROLLEY_VEHICLE_ID
	if vehicles.has(trolley_id):
		return

	var source: Node = (load(mod_main.TROLLEY_VEHICLE_SCENE_UID) as PackedScene).instantiate()
	var model: Node3D = source.get_node_or_null("Vehicle/kei_truck_new/body/trolly")
	if model == null:
		push_warning("Trolley scene has no body/trolly mesh; skipping trolley.")
		source.free()
		return

	var rider: Node = model.get_node_or_null("RaccoonMesh")
	if rider != null:
		model.remove_child(rider)
		rider.free()

	model.get_parent().remove_child(model)
	source.free()

	model.name = "trolly"
	model.transform = Transform3D.IDENTITY
	spin.add_child(model)

	var reference: Node3D = vehicles.get(SaveGame.vehicles.KEI_TRUCK)
	var layers: int = 0
	for vis in _ap_visual_instances(reference):
		layers = vis.layers
		break
	if layers != 0:
		for vis in _ap_visual_instances(model):
			vis.layers = layers
	else:
		push_warning("Could not read the car menu's render layer; trolley may be invisible.")

	if reference != null:
		var want: AABB = _ap_visual_bounds(reference, spin)
		var got: AABB = _ap_visual_bounds(model, spin)
		var want_span: float = maxf(want.size.x, maxf(want.size.y, want.size.z))
		var got_span: float = maxf(got.size.x, maxf(got.size.y, got.size.z))
		if got_span > 0.0 and want_span > 0.0:
			var k: float = (want_span / got_span) * TROLLEY_MENU_SCALE
			var origin: Vector3 = want.get_center() - got.get_center() * k
			origin.y += got.size.y * k * TROLLEY_MENU_LIFT
			model.transform = Transform3D(Basis().scaled(Vector3.ONE * k), origin)

	model.hide()
	vehicles[trolley_id] = model

	var data := car_resource.new()
	data.car_dialogue = "[shake]THE VEHICLE NOT AVAILABLE IN THE BASE GAME\nA FULL BLOWN ARCHIPELAGO EXCLUSIVE!!!![/shake]"
	data.car_logo = load(TROLLEY_LOGO_UID)
	vehicle_data[trolley_id] = data

func _ap_visual_instances(root: Node) -> Array:
	var found: Array = []
	if root == null:
		return found
	var stack: Array = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.push_back(child)
		if current is VisualInstance3D:
			found.append(current)
	return found

# Combined bounds of every mesh under `node`, in `space`'s local frame.
func _ap_visual_bounds(node: Node3D, space: Node3D) -> AABB:
	var to_space: Transform3D = space.global_transform.affine_inverse()
	var bounds: AABB = AABB()
	var found: bool = false
	for vis in _ap_visual_instances(node):
		var box: AABB = (to_space * vis.global_transform) * vis.get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	return bounds
