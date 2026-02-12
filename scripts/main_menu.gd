extends Control

@onready var coin_label: Label = $CoinDisplay/CoinLabel


func _ready() -> void:
	coin_label.text = str(SaveData.load_coins())
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/ShopButton.pressed.connect(_on_shop_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shop_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
