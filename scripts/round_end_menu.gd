extends CanvasLayer

var player_won: bool = true
var coins_earned: int = 0

@onready var result_label: Label = $Panel/VBoxContainer/ResultLabel
@onready var coins_earned_label: Label = $Panel/VBoxContainer/CoinsEarnedContainer/CoinsEarnedLabel
@onready var play_again_button: Button = $Panel/VBoxContainer/PlayAgainButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton


func _ready() -> void:
	# Set up result text
	if player_won:
		result_label.text = "GAME WON"
		result_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	else:
		result_label.text = "GAME LOST"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

	# Show coins earned
	coins_earned_label.text = "+" + str(coins_earned)

	# Connect buttons
	play_again_button.pressed.connect(_on_play_again)
	main_menu_button.pressed.connect(_on_main_menu)

	# Pause the game
	get_tree().paused = true


func _on_play_again() -> void:
	get_tree().paused = false

	# Get scoreboard and restart the round
	var scoreboard = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard:
		scoreboard.restart_round()

	# Remove this menu
	queue_free()


func _on_main_menu() -> void:
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
