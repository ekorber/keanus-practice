extends Control


func _ready() -> void:
	$VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$VBoxContainer/QuitToMenuButton.pressed.connect(_on_quit_to_menu_pressed)
	hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


func toggle_pause() -> void:
	if visible:
		resume()
	else:
		if get_tree().get_first_node_in_group("selection_menu"):
			return
		var scoreboard = get_tree().get_first_node_in_group("scoreboard")
		if scoreboard and scoreboard.round_over:
			return
		pause()


func pause() -> void:
	var scoreboard = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard:
		scoreboard.visible = false
	get_tree().paused = true
	show()


func resume() -> void:
	var scoreboard = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard:
		scoreboard.visible = true
	get_tree().paused = false
	hide()


func _on_resume_pressed() -> void:
	resume()


func _on_quit_to_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
