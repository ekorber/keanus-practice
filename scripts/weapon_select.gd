extends CanvasLayer

signal weapon_selected(weapon_id: String)

const WEAPONS: Dictionary = {
	"knife": {"name": "Knife", "damage": 15, "scene": "res://scenes/knife.tscn"},
	"bat": {"name": "Bat", "damage": 20, "scene": "res://scenes/bat.tscn"},
	"sword": {"name": "Sword", "damage": 30, "scene": "res://scenes/sword.tscn"},
	"spear": {"name": "Spear", "damage": 10, "scene": "res://scenes/spear.tscn"}
}

@onready var weapons_container: HBoxContainer = $Panel/VBoxContainer/WeaponsContainer


func _ready() -> void:
	_create_weapon_buttons()


func _create_weapon_buttons() -> void:
	var owned_weapons: Array = SaveData.get_owned_weapons()

	for weapon_id in WEAPONS:
		var weapon: Dictionary = WEAPONS[weapon_id]
		var is_owned: bool = weapon_id in owned_weapons

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(140, 120)

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3

		if is_owned:
			style.bg_color = Color(0.25, 0.3, 0.25, 1)
			style.border_color = Color(0.4, 0.6, 0.4, 1)
			button.pressed.connect(_on_weapon_selected.bind(weapon_id))
		else:
			style.bg_color = Color(0.2, 0.2, 0.2, 1)
			style.border_color = Color(0.4, 0.3, 0.3, 1)
			button.disabled = true

		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.15)
		hover_style.border_color = style.border_color.lightened(0.2)

		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)
		button.add_theme_stylebox_override("disabled", style)

		# Create button content
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 5)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_label: Label = Label.new()
		name_label.text = weapon["name"]
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_owned:
			name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1))
		else:
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		vbox.add_child(name_label)

		var damage_label: Label = Label.new()
		damage_label.text = "DMG: " + str(weapon["damage"])
		damage_label.add_theme_font_size_override("font_size", 14)
		damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_owned:
			damage_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.6, 1))
		else:
			damage_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		vbox.add_child(damage_label)

		if not is_owned:
			var locked_label: Label = Label.new()
			locked_label.text = "LOCKED"
			locked_label.add_theme_font_size_override("font_size", 12)
			locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			locked_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3, 1))
			locked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(locked_label)

		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(vbox)
		weapons_container.add_child(button)


func _on_weapon_selected(weapon_id: String) -> void:
	weapon_selected.emit(weapon_id)
	queue_free()


static func get_weapon_scene(weapon_id: String) -> String:
	if WEAPONS.has(weapon_id):
		return WEAPONS[weapon_id]["scene"]
	return WEAPONS["knife"]["scene"]


static func get_random_weapon() -> String:
	var weapons: Array[String] = ["knife", "bat", "sword"]
	return weapons[randi() % weapons.size()]
