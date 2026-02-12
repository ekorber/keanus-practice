extends Node3D

@export var max_hp: int = 100
var current_hp: int = 100

@onready var fill_panel: Panel = $SubViewport/Fill
@onready var hp_label: Label = $SubViewport/HPLabel

const FILL_MAX_WIDTH: float = 234.0  # Full width of the fill area (240 - 3px padding on each side)
const FILL_LEFT_OFFSET: float = 3.0  # Left padding

var fill_style: StyleBoxFlat = null


func _ready() -> void:
	current_hp = max_hp

	# Create a unique stylebox for this instance so colors don't affect other health bars
	if fill_panel:
		var original_style = fill_panel.get_theme_stylebox("panel")
		if original_style:
			fill_style = original_style.duplicate()
			fill_panel.add_theme_stylebox_override("panel", fill_style)

	_update_display()


func set_hp(value: int) -> void:
	current_hp = clampi(value, 0, max_hp)
	_update_display()


func take_damage(amount: int) -> void:
	set_hp(current_hp - amount)


func heal(amount: int) -> void:
	set_hp(current_hp + amount)


func reset() -> void:
	current_hp = max_hp
	_update_display()


func _update_display() -> void:
	if not fill_panel or not hp_label:
		return

	var hp_ratio: float = float(current_hp) / float(max_hp)

	# Scale the fill panel width
	var new_width: float = FILL_MAX_WIDTH * hp_ratio
	fill_panel.offset_right = FILL_LEFT_OFFSET + new_width

	# Update label
	hp_label.text = str(current_hp)

	# Change color based on HP (green -> yellow -> orange -> red)
	var color: Color
	if hp_ratio > 0.75:
		color = Color(0.2, 0.8, 0.2)  # Green
	elif hp_ratio > 0.5:
		color = Color(0.7, 0.9, 0.1)  # Yellow-green
	elif hp_ratio > 0.25:
		color = Color(1.0, 0.6, 0.1)  # Orange
	else:
		color = Color(0.9, 0.2, 0.2)  # Red

	# Update stylebox color
	if fill_style:
		fill_style.bg_color = color
