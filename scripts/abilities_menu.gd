extends Control

const WEAPONS: Dictionary = {
	"knife": {"name": "Knife", "description": "A basic knife"},
	"bat": {"name": "Bat", "description": "A sturdy wooden bat"},
	"sword": {"name": "Sword", "description": "A sharp metal sword"},
	"spear": {"name": "Spear", "description": "Hold RMB to charge - faster = more damage"},
	"mace": {"name": "Mace", "description": "LMB while falling - faster fall = more damage"}
}

const RAMPAGE_2X: Dictionary = {
	"id": "rampage", "name": "Rampage",
	"description": "Activate 2x Damage for 3 seconds - 6 second cooldown\nR to activate",
	"bg_color": Color(0.28, 0.06, 0.04, 1),
	"border_color": Color(0.9, 0.45, 0.1, 1),
	"font_color": Color(1.0, 0.55, 0.1, 1)
}

const RAMPAGE_15X: Dictionary = {
	"id": "rampage", "name": "Rampage",
	"description": "Activate 1.5x Damage for 3 seconds - 6 second cooldown\nR to activate",
	"bg_color": Color(0.28, 0.06, 0.04, 1),
	"border_color": Color(0.9, 0.45, 0.1, 1),
	"font_color": Color(1.0, 0.55, 0.1, 1)
}

const PARRY: Dictionary = {
	"id": "parry", "name": "Parry",
	"description": "Deflects enemy hit once when active - 2 second cooldown",
	"bg_color": Color(0.22, 0.22, 0.22, 1),
	"border_color": Color(0.5, 0.5, 0.5, 1),
	"font_color": Color(0.78, 0.78, 0.78, 1)
}

const WEAPON_ABILITIES: Dictionary = {
	"bat":   [RAMPAGE_2X],
	"sword": [RAMPAGE_2X, PARRY],
	"spear": [RAMPAGE_15X],
	"mace":  [RAMPAGE_15X]
}

var _weapon: Dictionary = {}
var _selected_ability: String = ""
var _ability_buttons: Dictionary = {}

@onready var _name_label: Label = $WeaponDisplay/MarginContainer/VBox/NameLabel
@onready var _desc_label: Label = $WeaponDisplay/MarginContainer/VBox/DescLabel
@onready var _status_label: Label = $WeaponDisplay/MarginContainer/VBox/StatusLabel
@onready var _slots_container: HBoxContainer = $AbilityBar/MarginContainer/VBox/SlotsContainer


func _ready() -> void:
	var weapon_id: String = SaveData.selected_weapon
	_weapon = WEAPONS.get(weapon_id, {"name": weapon_id.capitalize(), "description": ""})
	_selected_ability = SaveData.selected_abilities.get(weapon_id, "")

	$Title.text = _weapon["name"] + " — Abilities"
	_populate_slots(weapon_id)
	_refresh_display()
	_refresh_button_styles()
	$BackButton.pressed.connect(_on_back_pressed)


func _populate_slots(weapon_id: String) -> void:
	var abilities: Array = WEAPON_ABILITIES.get(weapon_id, [])
	for ability in abilities:
		var btn: Button = Button.new()
		btn.text = ability["name"]
		btn.custom_minimum_size = Vector2(110, 54)
		btn.add_theme_font_size_override("font_size", 15)

		_apply_button_style(btn, ability, false)

		btn.pressed.connect(_on_ability_pressed.bind(ability["id"]))
		_slots_container.add_child(btn)
		_ability_buttons[ability["id"]] = btn


func _on_ability_pressed(ability_id: String) -> void:
	if _selected_ability == ability_id:
		_selected_ability = ""
	else:
		_selected_ability = ability_id
	var weapon_id: String = SaveData.selected_weapon
	if _selected_ability == "":
		SaveData.selected_abilities.erase(weapon_id)
	else:
		SaveData.selected_abilities[weapon_id] = _selected_ability
	SaveData.save_selected_abilities()
	_refresh_display()
	_refresh_button_styles()


func _refresh_display() -> void:
	if _selected_ability == "":
		_name_label.text = _weapon["name"]
		_desc_label.text = _weapon["description"]
		_status_label.text = "No Ability"
		_status_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65, 1))
		_name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1))
		_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		_set_panel_style(Color(0.15, 0.15, 0.2, 1), Color(0.4, 0.4, 0.6, 1))
	else:
		var weapon_id: String = SaveData.selected_weapon
		var abilities: Array = WEAPON_ABILITIES.get(weapon_id, [])
		for ability in abilities:
			if ability["id"] == _selected_ability:
				_name_label.text = ability["name"]
				_name_label.add_theme_color_override("font_color", ability["font_color"])
				_desc_label.text = ability["description"]
				_desc_label.add_theme_color_override("font_color", ability["font_color"].darkened(0.2))
				_status_label.text = ""
				_set_panel_style(ability["bg_color"], ability["border_color"])
				break


func _set_panel_style(bg: Color, border: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	$WeaponDisplay.add_theme_stylebox_override("panel", style)


func _refresh_button_styles() -> void:
	var weapon_id: String = SaveData.selected_weapon
	var abilities: Array = WEAPON_ABILITIES.get(weapon_id, [])
	for ability in abilities:
		var btn: Button = _ability_buttons[ability["id"]]
		var is_selected: bool = ability["id"] == _selected_ability
		_apply_button_style(btn, ability, is_selected)


func _apply_button_style(btn: Button, ability: Dictionary, selected: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.bg_color = ability["bg_color"] if not selected else ability["bg_color"].lightened(0.12)
	style.border_color = ability["border_color"] if not selected else ability["border_color"].lightened(0.15)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.1)
	hover_style.border_color = style.border_color.lightened(0.1)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_color_override("font_color", ability["font_color"])


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shop_menu.tscn")
