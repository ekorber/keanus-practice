extends CanvasLayer

const WIN_SCORE: int = 5

var player_score: int = 0
var ai_score: int = 0
var is_resetting: bool = false
var round_over: bool = false
var player_won_last_round: bool = false
var player_weapon_id: String = "knife"

@onready var player_score_label: Label = $HBoxContainer/PlayerPanel/PlayerScore
@onready var ai_score_label: Label = $HBoxContainer/AIPanel/AIScore
@onready var countdown_label: Label = $CountdownLabel
@onready var result_label: Label = $ResultLabel
@onready var round_result_label: Label = $RoundResultLabel


func _ready() -> void:
	add_to_group("scoreboard")
	countdown_label.visible = false
	result_label.visible = false
	round_result_label.visible = false
	_update_display()
	_show_weapon_selection()


func _show_weapon_selection() -> void:
	# Freeze both characters at start
	var player: Node = get_tree().get_first_node_in_group("player")
	var enemy: Node = get_tree().get_first_node_in_group("enemy")

	if player:
		player.is_frozen = true
	if enemy:
		enemy.is_frozen = true

	# Show weapon selection UI
	var weapon_select_scene: PackedScene = preload("res://scenes/weapon_select.tscn")
	var weapon_select: CanvasLayer = weapon_select_scene.instantiate()
	get_tree().root.add_child(weapon_select)

	# Wait for player to select a weapon
	var selected_weapon: String = await weapon_select.weapon_selected

	# Set player weapon
	player_weapon_id = selected_weapon
	if player:
		player.set_weapon(selected_weapon)

	# Set random weapon for enemy
	if enemy:
		enemy.set_random_weapon()

	# Start the countdown
	_start_initial_countdown()


func _start_initial_countdown() -> void:
	# Freeze both characters at start
	var player: Node = get_tree().get_first_node_in_group("player")
	var enemy: Node = get_tree().get_first_node_in_group("enemy")

	if player:
		player.is_frozen = true
	if enemy:
		enemy.is_frozen = true

	# Run countdown
	await _run_countdown()

	# Unfreeze both
	if player:
		player.unfreeze()
	if enemy:
		enemy.unfreeze()


func add_player_kill() -> void:
	if round_over:
		return
	player_score += 1
	player_won_last_round = true
	_update_display()
	_check_win()


func add_ai_kill() -> void:
	if round_over:
		return
	ai_score += 1
	player_won_last_round = false
	_update_display()
	_check_win()


func _check_win() -> void:
	if player_score >= WIN_SCORE:
		_trigger_round_end(true)
	elif ai_score >= WIN_SCORE:
		_trigger_round_end(false)


func _trigger_round_end(player_won: bool) -> void:
	if round_over:
		return
	round_over = true

	# Show result text
	if player_won:
		result_label.text = "GAME WON"
		result_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	else:
		result_label.text = "GAME LOST"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	result_label.visible = true

	# Disable attacks
	_set_attacks_enabled(false)

	# Get player and enemy
	var player: Node = get_tree().get_first_node_in_group("player")
	var enemy: Node = get_tree().get_first_node_in_group("enemy")

	# Only make the winner visible and able to move, loser stays dead
	if player_won:
		if player:
			player.visible = true
			if player.weapon:
				player.weapon.visible = true
			player.get_node("CollisionShape3D").set_deferred("disabled", false)
			player.is_dead = false
			player.is_frozen = false
	else:
		if enemy:
			enemy.visible = true
			if enemy.knife:
				enemy.knife.visible = true
			enemy.get_node("CollisionShape3D").set_deferred("disabled", false)
			enemy.is_dead = false
			enemy.is_frozen = false

	# Wait 3 seconds
	await get_tree().create_timer(3.0, false).timeout

	# Calculate and award coins
	var coins: int = player_score * 10
	if player_won:
		coins += 50
	SaveData.add_coins(coins)

	# Show round end menu
	result_label.visible = false
	var round_end_menu: CanvasLayer = preload("res://scenes/round_end_menu.tscn").instantiate()
	round_end_menu.player_won = player_won
	round_end_menu.coins_earned = coins
	get_tree().root.add_child(round_end_menu)


func _set_attacks_enabled(enabled: bool) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	var enemy: Node = get_tree().get_first_node_in_group("enemy")

	if player:
		var weapon: Node3D = player.weapon
		if weapon:
			weapon.set_process_input(enabled)
	if enemy and enemy.knife:
		enemy.knife.set_meta("attacks_disabled", not enabled)


func start_round_reset() -> void:
	if is_resetting or round_over:
		return
	is_resetting = true

	# Show round result text
	if player_won_last_round:
		round_result_label.text = "ROUND WON"
		round_result_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	else:
		round_result_label.text = "ROUND LOST"
		round_result_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	round_result_label.visible = true

	# Wait 3 seconds before resetting (survivor can still move)
	await get_tree().create_timer(3.0, false).timeout

	# Hide round result text
	round_result_label.visible = false

	if round_over:
		is_resetting = false
		return

	# Get player and enemy
	var player: Node = get_tree().get_first_node_in_group("player")
	var enemy: Node = get_tree().get_first_node_in_group("enemy")

	# Reset both to spawn positions and freeze them
	if player:
		player.reset_to_spawn()
	if enemy:
		enemy.reset_to_spawn()

	# Start countdown
	await _run_countdown()

	# Unfreeze both
	if player:
		player.unfreeze()
	if enemy:
		enemy.unfreeze()

	is_resetting = false


func _run_countdown() -> void:
	countdown_label.visible = true

	for i in range(3, 0, -1):
		countdown_label.text = str(i)
		await get_tree().create_timer(1.0, false).timeout

	countdown_label.visible = false


func reset_scores() -> void:
	player_score = 0
	ai_score = 0
	round_over = false
	is_resetting = false
	round_result_label.visible = false
	_update_display()
	_set_attacks_enabled(true)


func restart_round() -> void:
	reset_scores()

	# Reset both characters to spawn
	var player: Node = get_tree().get_first_node_in_group("player")
	var enemy: Node = get_tree().get_first_node_in_group("enemy")

	if player:
		player.reset_to_spawn()
	if enemy:
		enemy.reset_to_spawn()

	# Show weapon selection again
	var weapon_select_scene: PackedScene = preload("res://scenes/weapon_select.tscn")
	var weapon_select: CanvasLayer = weapon_select_scene.instantiate()
	get_tree().root.add_child(weapon_select)

	# Wait for player to select a weapon
	var selected_weapon: String = await weapon_select.weapon_selected

	# Set player weapon
	player_weapon_id = selected_weapon
	if player:
		player.set_weapon(selected_weapon)

	# Set random weapon for enemy
	if enemy:
		enemy.set_random_weapon()

	# Run countdown then unfreeze
	await _run_countdown()

	if player:
		player.unfreeze()
	if enemy:
		enemy.unfreeze()


func _update_display() -> void:
	player_score_label.text = str(player_score)
	ai_score_label.text = str(ai_score)
