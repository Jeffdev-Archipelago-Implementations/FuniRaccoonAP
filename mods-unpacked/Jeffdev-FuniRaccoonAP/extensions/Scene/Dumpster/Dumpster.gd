extends "res://Scene/Dumpster/Dumpster.gd"

func _on_object_area_detect_body_entered(body: InteractData) -> void:
	ModLoader.get_node("Jeffdev-FuniRaccoonAP").dumpster_handling(self, body)
