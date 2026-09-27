extends "res://Scene/Objects/GachaMachine/gachaMAchine.gd"

func shoot():
	var ap_stored: Array = Globals.save_file.get_meta("ap_stored_items", [])
	if ap_stored.is_empty():
		return
	var proj_inst: InteractData = ModLoader.get_node("Jeffdev-FuniRaccoonAP").instantiate_item(ap_stored.pick_random())
	if proj_inst == null:
		return
	proj_inst.position = pivotlaunch.global_position

	if proj_inst is RigidBody3D:
		proj_inst.apply_central_impulse(pivotlaunch.get_global_transform().basis.x * speed)
		proj_inst.freeze = false
	Globals.get_current_world().add_child(proj_inst)
