extends Control

const WEAPONS: Dictionary = {
	"bat": {"name": "Bat", "cost": 500, "description": "A sturdy wooden bat"},
	"sword": {"name": "Sword", "cost": 1000, "description": "A sharp metal sword"}
}

@onready var coin_label: Label = $CoinDisplay/CoinLabel
@onready var items_container: VBoxContainer = $ItemsContainer

var item_buttons: Dictionary = {}


func _ready() -> void:
	_update_coin_display()
	_create_shop_items()
	$BackButton.pressed.connect(_on_back_pressed)


func _update_coin_display() -> void:
	coin_label.text = str(SaveData.load_coins())


func _create_shop_items() -> void:
	for weapon_id in WEAPONS:
		var weapon: Dictionary = WEAPONS[weapon_id]
		var item_panel: PanelContainer = _create_item_panel(weapon_id, weapon)
		items_container.add_child(item_panel)


func _create_item_panel(weapon_id: String, weapon: Dictionary) -> PanelContainer:
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

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

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
			button.pressed.connect(_on_buy_pressed.bind(weapon_id))
		else:
			button.text = str(weapon["cost"]) + " C"
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


func _on_buy_pressed(weapon_id: String) -> void:
	var weapon: Dictionary = WEAPONS[weapon_id]
	if SaveData.purchase_weapon(weapon_id, weapon["cost"]):
		_update_coin_display()
		_refresh_item(weapon_id)


func _refresh_item(weapon_id: String) -> void:
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

	# Update other items that might now be unaffordable
	var coins: int = SaveData.load_coins()
	for other_id in WEAPONS:
		if other_id == weapon_id:
			continue
		if SaveData.owns_weapon(other_id):
			continue
		var other_button: Button = item_buttons[other_id]
		var other_weapon: Dictionary = WEAPONS[other_id]
		if coins < other_weapon["cost"]:
			other_button.disabled = true
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
			other_button.add_theme_stylebox_override("normal", disabled_style)
			other_button.add_theme_stylebox_override("disabled", disabled_style)
			other_button.add_theme_color_override("font_disabled_color", Color(0.6, 0.4, 0.4, 1))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
