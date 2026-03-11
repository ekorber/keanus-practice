extends Node

var hitboxes_visible: bool = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hitboxes"):
		hitboxes_visible = not hitboxes_visible
		get_tree().call_group("hitbox_debug", "set_visible", hitboxes_visible)
