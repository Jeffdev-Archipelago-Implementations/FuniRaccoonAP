extends "res://Scene/Levels/ending_hypercube/dumpster_special_ending.gd"

func _on_object_area_detect_body_entered(body: InteractData) -> void:
	ModLoader.get_node("Jeffdev-FuniRaccoonAP").dumpster_handling(self, body)
