extends Control

const WEAPONS: Dictionary = {
	"bat": {"name": "Bat", "cost": 500, "description": "A sturdy wooden bat"},
	"sword": {"name": "Sword", "cost": 1000, "description": "A sharp metal sword"},
	"spear": {"name": "Spear", "cost": 2500, "description": "Hold RMB to charge - faster = more damage"},
	"mace": {"name": "Mace", "cost": 5000, "description": "LMB while falling - faster fall = more damage"}
}

const UTILITIES: Dictionary = {
	"speed_boost": {"name": "Speed Boost", "cost": 100, "description": "1.5x movement speed for one game", "color": Color(0.3, 0.5, 0.9, 1)},
	"jump_boost": {"name": "Jump Boost", "cost": 100, "description": "1.5x jump height for one game", "color": Color(0.9, 0.9, 0.95, 1)},
	"health_boost": {"name": "Health Boost", "cost": 100, "description": "+50 max health for one game", "color": Color(0.9, 0.15, 0.15, 1)}
}

@onready var coin_label: Label = $CoinDisplay/CoinLabel
@onready var items_container: VBoxContainer = $ScrollContainer/ItemsContainer

var item_buttons: Dictionary = {}


func _ready() -> void:
	_update_coin_display()
	_create_shop_items()
	$BackButton.pressed.connect(_on_back_pressed)


func _update_coin_display() -> void:
	coin_label.text = str(SaveData.load_coins())


func _create_shop_items() -> void:
	# Weapons category
	var weapons_label: Label = Label.new()
	weapons_label.text = "— Weapons —"
	weapons_label.add_theme_font_size_override("font_size", 20)
	weapons_label.add_theme_color_override("font_color", Color(1, 0.8, 0.5, 1))
	weapons_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_container.add_child(weapons_label)

	for weapon_id in WEAPONS:
		var weapon: Dictionary = WEAPONS[weapon_id]
		var item_panel: PanelContainer = _create_weapon_panel(weapon_id, weapon)
		items_container.add_child(item_panel)

	# Utilities category
	var utilities_label: Label = Label.new()
	utilities_label.text = "— Utilities —"
	utilities_label.add_theme_font_size_override("font_size", 20)
	utilities_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1, 1))
	utilities_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_container.add_child(utilities_label)

	for utility_id in UTILITIES:
		var utility: Dictionary = UTILITIES[utility_id]
		var item_panel: PanelContainer = _create_utility_panel(utility_id, utility)
		items_container.add_child(item_panel)


func _create_weapon_panel(weapon_id: String, weapon: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 80)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.5, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)

	var inner_hbox: HBoxContainer = HBoxContainer.new()
	inner_hbox.add_theme_constant_override("separation", 20)
	margin.add_child(inner_hbox)

	# Weapon info (left side)
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_hbox.add_child(info_vbox)

	var name_label: Label = Label.new()
	name_label.text = weapon["name"]
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1))
	info_vbox.add_child(name_label)

	var desc_label: Label = Label.new()
	desc_label.text = weapon["description"]
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	info_vbox.add_child(desc_label)

	# Price and button (right side)
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_hbox.add_child(right_vbox)

	var is_owned: bool = SaveData.owns_weapon(weapon_id)
	var coins: int = SaveData.load_coins()
	var can_afford: bool = coins >= weapon["cost"]

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(120, 40)

	var button_style: StyleBoxFlat = StyleBoxFlat.new()
	button_style.corner_radius_top_left = 4
	button_style.corner_radius_top_right = 4
	button_style.corner_radius_bottom_right = 4
	button_style.corner_radius_bottom_left = 4
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2

	if is_owned:
		button.text = "OWNED"
		button.disabled = true
		button_style.bg_color = Color(0.2, 0.4, 0.2, 1)
		button_style.border_color = Color(0.3, 0.6, 0.3, 1)
		button.add_theme_color_override("font_disabled_color", Color(0.5, 0.8, 0.5, 1))
	else:
		button.text = str(weapon["cost"]) + " C"
		if can_afford:
			button_style.bg_color = Color(0.3, 0.25, 0.2, 1)
			button_style.border_color = Color(0.6, 0.5, 0.4, 1)
			button.add_theme_color_override("font_color", Color(1, 0.84, 0, 1))
			button.pressed.connect(_on_buy_weapon_pressed.bind(weapon_id))
		else:
			button.disabled = true
			button_style.bg_color = Color(0.25, 0.2, 0.2, 1)
			button_style.border_color = Color(0.5, 0.3, 0.3, 1)
			button.add_theme_color_override("font_disabled_color", Color(0.6, 0.4, 0.4, 1))

	var button_hover: StyleBoxFlat = button_style.duplicate()
	button_hover.bg_color = button_style.bg_color.lightened(0.15)
	button_hover.border_color = button_style.border_color.lightened(0.2)

	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_hover)
	button.add_theme_stylebox_override("pressed", button_hover)
	button.add_theme_stylebox_override("disabled", button_style)
	button.add_theme_font_size_override("font_size", 16)

	right_vbox.add_child(button)
	item_buttons[weapon_id] = button

	return panel


func _create_utility_panel(utility_id: String, utility: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 80)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.2, 0.25, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.45, 0.6, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)

	var inner_hbox: HBoxContainer = HBoxContainer.new()
	inner_hbox.add_theme_constant_override("separation", 20)
	margin.add_child(inner_hbox)

	# Ball icon (left side)
	var ball_container: CenterContainer = CenterContainer.new()
	ball_container.custom_minimum_size = Vector2(40, 40)
	inner_hbox.add_child(ball_container)

	var ball_label: Label = Label.new()
	ball_label.text = "●"
	ball_label.add_theme_font_size_override("font_size", 30)
	ball_label.add_theme_color_override("font_color", utility["color"])
	ball_container.add_child(ball_label)

	# Info
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_hbox.add_child(info_vbox)

	var name_hbox: HBoxContainer = HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 10)
	info_vbox.add_child(name_hbox)

	var name_label: Label = Label.new()
	name_label.text = utility["name"]
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1))
	name_hbox.add_child(name_label)

	var count: int = SaveData.get_utility_count(utility_id)
	var count_label: Label = Label.new()
	count_label.text = "x" + str(count)
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
	name_hbox.add_child(count_label)

	var desc_label: Label = Label.new()
	desc_label.text = utility["description"]
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	info_vbox.add_child(desc_label)

	# Buy button (right side)
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_hbox.add_child(right_vbox)

	var coins: int = SaveData.load_coins()
	var can_afford: bool = coins >= utility["cost"]

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(120, 40)
	button.text = str(utility["cost"]) + " C"

	var button_style: StyleBoxFlat = StyleBoxFlat.new()
	button_style.corner_radius_top_left = 4
	button_style.corner_radius_top_right = 4
	button_style.corner_radius_bottom_right = 4
	button_style.corner_radius_bottom_left = 4
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2

	if can_afford:
		button_style.bg_color = Color(0.2, 0.25, 0.35, 1)
		button_style.border_color = Color(0.4, 0.5, 0.7, 1)
		button.add_theme_color_override("font_color", Color(0.6, 0.85, 1, 1))
		button.pressed.connect(_on_buy_utility_pressed.bind(utility_id, count_label))
	else:
		button.disabled = true
		button_style.bg_color = Color(0.25, 0.2, 0.2, 1)
		button_style.border_color = Color(0.5, 0.3, 0.3, 1)
		button.add_theme_color_override("font_disabled_color", Color(0.6, 0.4, 0.4, 1))

	var button_hover: StyleBoxFlat = button_style.duplicate()
	button_hover.bg_color = button_style.bg_color.lightened(0.15)
	button_hover.border_color = button_style.border_color.lightened(0.2)

	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_hover)
	button.add_theme_stylebox_override("pressed", button_hover)
	button.add_theme_stylebox_override("disabled", button_style)
	button.add_theme_font_size_override("font_size", 16)

	right_vbox.add_child(button)
	item_buttons[utility_id] = button

	return panel


func _on_buy_weapon_pressed(weapon_id: String) -> void:
	var weapon: Dictionary = WEAPONS[weapon_id]
	if SaveData.purchase_weapon(weapon_id, weapon["cost"]):
		_update_coin_display()
		_refresh_weapon_item(weapon_id)
		_refresh_affordability()


func _on_buy_utility_pressed(utility_id: String, count_label: Label) -> void:
	var utility: Dictionary = UTILITIES[utility_id]
	if SaveData.purchase_utility(utility_id, utility["cost"]):
		_update_coin_display()
		var new_count: int = SaveData.get_utility_count(utility_id)
		count_label.text = "x" + str(new_count)
		_refresh_affordability()


func _refresh_weapon_item(weapon_id: String) -> void:
	var button: Button = item_buttons[weapon_id]
	button.text = "OWNED"
	button.disabled = true

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.2, 1)
	style.border_color = Color(0.3, 0.6, 0.3, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.8, 0.5, 1))


func _refresh_affordability() -> void:
	var coins: int = SaveData.load_coins()

	# Check weapons
	for weapon_id in WEAPONS:
		if SaveData.owns_weapon(weapon_id):
			continue
		var button: Button = item_buttons[weapon_id]
		var weapon: Dictionary = WEAPONS[weapon_id]
		if coins < weapon["cost"]:
			button.disabled = true
			var disabled_style: StyleBoxFlat = StyleBoxFlat.new()
			disabled_style.bg_color = Color(0.25, 0.2, 0.2, 1)
			disabled_style.border_color = Color(0.5, 0.3, 0.3, 1)
			disabled_style.corner_radius_top_left = 4
			disabled_style.corner_radius_top_right = 4
			disabled_style.corner_radius_bottom_right = 4
			disabled_style.corner_radius_bottom_left = 4
			disabled_style.border_width_left = 2
			disabled_style.border_width_top = 2
			disabled_style.border_width_right = 2
			disabled_style.border_width_bottom = 2
			button.add_theme_stylebox_override("normal", disabled_style)
			button.add_theme_stylebox_override("disabled", disabled_style)
			button.add_theme_color_override("font_disabled_color", Color(0.6, 0.4, 0.4, 1))

	# Check utilities
	for utility_id in UTILITIES:
		var button: Button = item_buttons[utility_id]
		var utility: Dictionary = UTILITIES[utility_id]
		if coins < utility["cost"]:
			button.disabled = true
			var disabled_style: StyleBoxFlat = StyleBoxFlat.new()
			disabled_style.bg_color = Color(0.25, 0.2, 0.2, 1)
			disabled_style.border_color = Color(0.5, 0.3, 0.3, 1)
			disabled_style.corner_radius_top_left = 4
			disabled_style.corner_radius_top_right = 4
			disabled_style.corner_radius_bottom_right = 4
			disabled_style.corner_radius_bottom_left = 4
			disabled_style.border_width_left = 2
			disabled_style.border_width_top = 2
			disabled_style.border_width_right = 2
			disabled_style.border_width_bottom = 2
			button.add_theme_stylebox_override("normal", disabled_style)
			button.add_theme_stylebox_override("disabled", disabled_style)
			button.add_theme_color_override("font_disabled_color", Color(0.6, 0.4, 0.4, 1))
		else:
			button.disabled = false
			var enabled_style: StyleBoxFlat = StyleBoxFlat.new()
			enabled_style.bg_color = Color(0.2, 0.25, 0.35, 1)
			enabled_style.border_color = Color(0.4, 0.5, 0.7, 1)
			enabled_style.corner_radius_top_left = 4
			enabled_style.corner_radius_top_right = 4
			enabled_style.corner_radius_bottom_right = 4
			enabled_style.corner_radius_bottom_left = 4
			enabled_style.border_width_left = 2
			enabled_style.border_width_top = 2
			enabled_style.border_width_right = 2
			enabled_style.border_width_bottom = 2
			button.add_theme_stylebox_override("normal", enabled_style)
			var hover_style: StyleBoxFlat = enabled_style.duplicate()
			hover_style.bg_color = enabled_style.bg_color.lightened(0.15)
			hover_style.border_color = enabled_style.border_color.lightened(0.2)
			button.add_theme_stylebox_override("hover", hover_style)
			button.add_theme_stylebox_override("pressed", hover_style)
			button.add_theme_color_override("font_color", Color(0.6, 0.85, 1, 1))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
