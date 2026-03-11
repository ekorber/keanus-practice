extends CanvasLayer

signal utilities_chosen(active_utilities: Array)

const UTILITIES: Dictionary = {
	"speed_boost": {"name": "Speed Boost", "description": "1.5x Speed", "color": Color(0.3, 0.5, 0.9, 1)},
	"jump_boost": {"name": "Jump Boost", "description": "1.5x Jump", "color": Color(0.9, 0.9, 0.95, 1)},
	"health_boost": {"name": "Health Boost", "description": "+50 HP", "color": Color(0.9, 0.15, 0.15, 1)}
}

var selected_utilities: Array = []
var utility_buttons: Dictionary = {}
var excluded_utilities: Array = []

@onready var utilities_container: GridContainer = $Panel/VBoxContainer/UtilitiesContainer
@onready var ready_button: Button = $Panel/VBoxContainer/ReadyButton


func _ready() -> void:
	add_to_group("selection_menu")
	_create_utility_buttons()
	ready_button.pressed.connect(_on_ready_pressed)

	# Style the ready button
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.35, 0.25, 1)
	style.border_color = Color(0.4, 0.6, 0.4, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.15)
	ready_button.add_theme_stylebox_override("normal", style)
	ready_button.add_theme_stylebox_override("hover", hover)
	ready_button.add_theme_stylebox_override("pressed", hover)
	ready_button.add_theme_color_override("font_color", Color(0.8, 1, 0.8, 1))
	ready_button.add_theme_font_size_override("font_size", 18)


func _create_utility_buttons() -> void:
	var has_any: bool = false

	for utility_id in UTILITIES:
		if utility_id in excluded_utilities:
			continue
		var count: int = SaveData.get_utility_count(utility_id)
		if count <= 0:
			continue
		has_any = true

		var utility: Dictionary = UTILITIES[utility_id]

		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(140, 100)

		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.bg_color = Color(0.2, 0.25, 0.3, 1)
		style.border_color = Color(0.3, 0.45, 0.6, 1)

		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.15)
		hover_style.border_color = style.border_color.lightened(0.2)

		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)

		button.pressed.connect(_on_utility_toggled.bind(utility_id, button))

		# Button content
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Ball icon
		var ball_label: Label = Label.new()
		ball_label.text = "●"
		ball_label.add_theme_font_size_override("font_size", 24)
		ball_label.add_theme_color_override("font_color", utility["color"])
		ball_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ball_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(ball_label)

		var name_label: Label = Label.new()
		name_label.text = utility["name"]
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_label)

		var count_label: Label = Label.new()
		count_label.text = "x" + str(count)
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(count_label)

		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(vbox)
		utilities_container.add_child(button)
		utility_buttons[utility_id] = button

	if not has_any:
		var no_items_label: Label = Label.new()
		no_items_label.text = "No utilities owned"
		no_items_label.add_theme_font_size_override("font_size", 16)
		no_items_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		no_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		utilities_container.add_child(no_items_label)


func _on_utility_toggled(utility_id: String, button: Button) -> void:
	if utility_id in selected_utilities:
		selected_utilities.erase(utility_id)
		# Deselect style
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.bg_color = Color(0.2, 0.25, 0.3, 1)
		style.border_color = Color(0.3, 0.45, 0.6, 1)
		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.15)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)
	else:
		selected_utilities.append(utility_id)
		# Selected style (bright border)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.bg_color = Color(0.25, 0.35, 0.3, 1)
		style.border_color = Color(0.4, 0.9, 0.5, 1)
		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.15)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)


func _on_ready_pressed() -> void:
	# Consume selected utilities from inventory
	for utility_id in selected_utilities:
		SaveData.consume_utility(utility_id)
	utilities_chosen.emit(selected_utilities)
	queue_free()
