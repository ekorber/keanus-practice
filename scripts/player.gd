extends CharacterBody3D

## Movement speed in units per second
@export var speed: float = 8.0
## Jump velocity
@export var jump_velocity: float = 10.0
## Gravity multiplier
@export var gravity_multiplier: float = 2.0
## Push force for rigid bodies
@export var push_force: float = 8.0

const MAX_HP: int = 100

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3
var is_dead: bool = false
var is_frozen: bool = false
var current_hp: int = MAX_HP
var health_bar: Node3D = null
var weapon: Node3D = null
var selected_weapon_id: String = "knife"
var base_speed: float = 8.0
var base_jump_velocity: float = 10.0
var active_utilities: Array = []
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: float = 1.0
const DASH_DISTANCE: float = 2.1
const DASH_DURATION: float = 0.05
const DASH_COOLDOWN: float = 3.0
var dash_cooldown_timer: float = 0.0
var facing_direction: float = 1.0

var rampage_multiplier: float = 1.0
var rampage_active: bool = false
const RAMPAGE_DURATION: float = 3.0
var rampage_timer: float = 0.0
var rampage_hit_count: int = 0
const RAMPAGE_HIT_REQUIREMENT: int = 10
var _rampage_vignette: Control = null
var _ability_hud_row: Control = null
var _parry_hud_row: Control = null
var _dash_fill: ColorRect = null
var _rampage_fill: ColorRect = null
var _parry_fill: ColorRect = null

const PARRY_DURATION: float = 1.0
const PARRY_COOLDOWN: float = 2.0
var parry_active: bool = false
var parry_timer: float = 0.0
var parry_cooldown_timer: float = 0.0

var _footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.38

@onready var _footstep_sound: AudioStreamPlayer3D = $FootstepSound
@onready var _dash_sound: AudioStreamPlayer = $DashSound
@onready var _rampage_activate_sound: AudioStreamPlayer = $RampageActivateSound
@onready var _parry_activate_sound: AudioStreamPlayer = $ParryActivateSound
@onready var _parry_deflect_sound: AudioStreamPlayer = $ParryDeflectSound


func _play(snd: Node) -> void:
	if snd and snd.get("stream") != null and snd.stream:
		snd.play()


func _ready() -> void:
	# Spawn on left platform
	spawn_position = Vector3(-8, 3.5, 0)

	# Create health bar
	var health_bar_scene := preload("res://scenes/health_bar.tscn")
	health_bar = health_bar_scene.instantiate()
	health_bar.position = Vector3(0, 1.3, 0)  # Above the character
	add_child(health_bar)

	# Rampage vignette overlay (layer 10)
	var vignette_canvas: CanvasLayer = CanvasLayer.new()
	vignette_canvas.layer = 10
	add_child(vignette_canvas)
	var vignette: ColorRect = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://shaders/rampage_vignette.gdshader")
	vignette.material = mat
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.visible = false
	vignette_canvas.add_child(vignette)
	_rampage_vignette = vignette

	# Keybind HUD (layer 11 — above vignette)
	var hud_canvas: CanvasLayer = CanvasLayer.new()
	hud_canvas.layer = 11
	add_child(hud_canvas)
	var hud: VBoxContainer = VBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hud.offset_left = 14.0
	hud.offset_bottom = -14.0
	hud.offset_right = 180.0
	hud.offset_top = -94.0
	hud.add_theme_constant_override("separation", 4)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_canvas.add_child(hud)
	var dash_bar: Dictionary = _add_keybind_row(hud, "Shift", "Dash", Color(0.18, 0.18, 0.20, 0.9), Color(0.88, 0.88, 0.90, 1))
	_dash_fill = dash_bar["fill"]
	var rampage_bar: Dictionary = _add_keybind_row(hud, "R", "Rampage", Color(0.28, 0.10, 0.01, 0.9), Color(0.75, 0.35, 0.05, 1))
	_rampage_fill = rampage_bar["fill"]
	_ability_hud_row = rampage_bar["container"]
	_ability_hud_row.visible = false
	var parry_bar: Dictionary = _add_keybind_row(hud, "RMB", "Parry", Color(0.14, 0.14, 0.16, 0.9), Color(0.45, 0.45, 0.48, 1))
	_parry_fill = parry_bar["fill"]
	_parry_hud_row = parry_bar["container"]
	_parry_hud_row.visible = false


func set_weapon(weapon_id: String) -> void:
	if weapon_id != selected_weapon_id:
		rampage_hit_count = rampage_hit_count / 2
	selected_weapon_id = weapon_id
	var _active_ability: String = SaveData.selected_abilities.get(weapon_id, "")
	if _ability_hud_row:
		_ability_hud_row.visible = _active_ability == "rampage"
	if _parry_hud_row:
		_parry_hud_row.visible = _active_ability == "parry"

	# Remove existing weapon if any
	if weapon:
		weapon.queue_free()
		weapon = null

	# Also remove the default Knife node if it exists
	var old_knife: Node = get_node_or_null("Knife")
	if old_knife:
		old_knife.queue_free()

	# Load and instantiate the new weapon
	var weapon_scene_path: String = _get_weapon_scene_path(weapon_id)
	var weapon_scene: PackedScene = load(weapon_scene_path)
	weapon = weapon_scene.instantiate()
	weapon.player_controlled = true
	weapon.target_group = "enemy"
	weapon.name = "Weapon"
	add_child(weapon)

	# Sync hitbox visuals with current debug toggle state
	if HitboxDebug.hitboxes_visible:
		get_tree().call_group("hitbox_debug", "set_visible", true)


func _get_weapon_scene_path(weapon_id: String) -> String:
	match weapon_id:
		"bat":
			return "res://scenes/bat.tscn"
		"sword":
			return "res://scenes/sword.tscn"
		"spear":
			return "res://scenes/spear.tscn"
		"mace":
			return "res://scenes/mace.tscn"
		_:
			return "res://scenes/knife.tscn"


func _physics_process(delta: float) -> void:
	if is_dead or is_frozen:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * gravity_multiplier * delta

	# Handle dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Handle parry timers
	if parry_active:
		parry_timer -= delta
		if parry_timer <= 0:
			parry_active = false
			parry_cooldown_timer = PARRY_COOLDOWN
			_clear_body_tint()
	elif parry_cooldown_timer > 0:
		parry_cooldown_timer -= delta

	# Update HUD fill bars
	if _dash_fill and _dash_fill.get_parent():
		_dash_fill.size.x = _dash_fill.get_parent().size.x * clamp(dash_cooldown_timer / DASH_COOLDOWN, 0.0, 1.0)
	if _rampage_fill and _rampage_fill.get_parent():
		_rampage_fill.size.x = _rampage_fill.get_parent().size.x * clamp(float(rampage_hit_count) / RAMPAGE_HIT_REQUIREMENT, 0.0, 1.0)
	if _parry_fill and _parry_fill.get_parent():
		var bar_width: float = _parry_fill.get_parent().size.x
		if parry_active:
			_parry_fill.size.x = bar_width
			_parry_fill.color = Color(0.75, 0.78, 0.82, 1)
		elif parry_cooldown_timer > 0:
			_parry_fill.size.x = bar_width * (parry_cooldown_timer / PARRY_COOLDOWN)
			_parry_fill.color = Color(0.45, 0.45, 0.48, 1)
		else:
			_parry_fill.size.x = 0.0

	# Handle rampage timer
	if rampage_active:
		rampage_timer -= delta
		if rampage_timer <= 0:
			rampage_active = false
			rampage_multiplier = 1.0
			if _rampage_vignette:
				_rampage_vignette.visible = false
			_clear_body_tint()

	# Activate rampage
	var _scoreboard: Node = get_tree().get_first_node_in_group("scoreboard")
	var _in_countdown: bool = false
	if _scoreboard:
		var _val = _scoreboard.get("is_in_countdown")
		if _val != null:
			_in_countdown = _val
	if Input.is_action_just_pressed("rampage") and not rampage_active and rampage_hit_count >= RAMPAGE_HIT_REQUIREMENT and not _in_countdown:
		var active_ability: String = SaveData.selected_abilities.get(selected_weapon_id, "")
		if active_ability == "rampage":
			rampage_active = true
			rampage_timer = RAMPAGE_DURATION
			rampage_multiplier = 1.5
			rampage_hit_count = 0
			if _rampage_vignette:
				_rampage_vignette.visible = true
			_set_body_tint(Color(1.0, 0.40, 0.05, 1.0), true)
			_play(_rampage_activate_sound)

	# Activate parry
	if Input.is_action_just_pressed("charge_attack") and not parry_active and parry_cooldown_timer <= 0 and not _in_countdown:
		if SaveData.selected_abilities.get(selected_weapon_id, "") == "parry":
			parry_active = true
			parry_timer = PARRY_DURATION
			_set_body_tint(Color(0.30, 0.30, 0.33, 1.0))
			var _ws: Node = weapon.get_node_or_null("ParryActivateSound") if weapon else null
			_play(_ws if _ws else _parry_activate_sound)

	# Handle dash
	if is_dashing:
		dash_timer -= delta
		var dash_speed: float = DASH_DISTANCE / DASH_DURATION
		if "speed_boost" in active_utilities:
			dash_speed *= 1.5
		velocity.x = dash_direction * dash_speed
		velocity.z = 0
		position.z = 0
		if dash_timer <= 0:
			is_dashing = false
		move_and_slide()
		return

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get horizontal input for 2.5D
	var input_dir := Input.get_axis("walk_left", "walk_right")

	# Track facing direction
	if input_dir != 0:
		facing_direction = input_dir

	# Start dash
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		dash_direction = input_dir if input_dir != 0 else facing_direction
		_play(_dash_sound)

	# Set X velocity based on input (2.5D movement - only X axis)
	velocity.x = input_dir * speed

	# Lock Z movement for 2.5D
	velocity.z = 0
	position.z = 0

	move_and_slide()

	# Footstep sounds
	if is_on_floor() and abs(input_dir) > 0:
		_footstep_timer -= delta
		if _footstep_timer <= 0:
			_play(_footstep_sound)
			_footstep_timer = FOOTSTEP_INTERVAL
	else:
		_footstep_timer = 0.0

	# Push objects
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()

		# Calculate push direction
		var push_dir := Vector3.ZERO
		if input_dir != 0:
			push_dir.x = input_dir
		else:
			push_dir = -collision.get_normal()
		push_dir.y = 0
		push_dir.z = 0

		if push_dir.length() > 0:
			push_dir = push_dir.normalized()

			# Push rigid bodies (crates)
			if collider is RigidBody3D:
				collider.apply_central_force(push_dir * push_force * 50.0)

			# Push enemies
			elif collider.has_method("apply_push"):
				collider.apply_push(push_dir.x * push_force)


func take_damage(amount: int) -> void:
	if is_dead:
		return

	if parry_active:
		parry_active = false
		parry_cooldown_timer = PARRY_COOLDOWN
		_clear_body_tint()
		var _wd: Node = weapon.get_node_or_null("ParryDeflectSound") if weapon else null
		_play(_wd if _wd else _parry_deflect_sound)
		return

	if parry_cooldown_timer > 0 and SaveData.selected_abilities.get(selected_weapon_id, "") == "parry":
		parry_cooldown_timer = 0.0

	current_hp -= amount
	if health_bar:
		health_bar.set_hp(current_hp)

	if current_hp <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	visible = false
	if weapon:
		weapon.visible = false
	$CollisionShape3D.set_deferred("disabled", true)

	# Notify scoreboard to start round reset
	var scoreboard = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard:
		scoreboard.start_round_reset()


func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	is_frozen = true
	is_dead = false
	rampage_active = false
	rampage_multiplier = 1.0
	rampage_timer = 0.0
	if _rampage_vignette:
		_rampage_vignette.visible = false
	parry_active = false
	parry_timer = 0.0
	parry_cooldown_timer = 0.0
	_clear_body_tint()
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	visible = true
	if weapon:
		weapon.visible = true
	$CollisionShape3D.set_deferred("disabled", false)

	# Reset HP
	if "health_boost" in active_utilities:
		current_hp = MAX_HP + 50
		if health_bar:
			health_bar.max_hp = MAX_HP + 50
			health_bar.set_hp(current_hp)
	else:
		current_hp = MAX_HP
		if health_bar:
			health_bar.reset()


func apply_utilities(utilities: Array) -> void:
	active_utilities = utilities
	speed = base_speed
	jump_velocity = base_jump_velocity

	if "speed_boost" in utilities:
		speed = base_speed * 1.5
	if "jump_boost" in utilities:
		jump_velocity = base_jump_velocity * 1.5
	if "health_boost" in utilities:
		current_hp = MAX_HP + 50
		if health_bar:
			health_bar.max_hp = MAX_HP + 50
			health_bar.set_hp(current_hp)


func clear_utilities() -> void:
	active_utilities = []
	speed = base_speed
	jump_velocity = base_jump_velocity
	if health_bar:
		health_bar.max_hp = MAX_HP


func reset_rampage() -> void:
	rampage_active = false
	rampage_multiplier = 1.0
	rampage_timer = 0.0
	if _rampage_vignette:
		_rampage_vignette.visible = false
	_clear_body_tint()


func on_hit_landed() -> void:
	if rampage_hit_count < RAMPAGE_HIT_REQUIREMENT:
		rampage_hit_count += 1


func reset_rampage_charge() -> void:
	rampage_hit_count = 0


func unfreeze() -> void:
	is_frozen = false


func _set_body_tint(color: Color, with_emission: bool = false) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	if with_emission:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
	$HitboxVisual.material_override = mat
	if HitboxDebug.hitboxes_visible:
		$HitboxVisual.visible = true


func _clear_body_tint() -> void:
	$HitboxVisual.material_override = null
	$HitboxVisual.visible = HitboxDebug.hitboxes_visible


func _add_keybind_row(parent: VBoxContainer, key: String, action: String, bg_color: Color, fill_color: Color) -> Dictionary:
	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(150, 24)
	container.size_flags_horizontal = Control.SIZE_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = bg_color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fill: ColorRect = ColorRect.new()
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.size.x = 0.0
	fill.color = fill_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -8.0
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var key_label: Label = Label.new()
	key_label.text = "[" + key + "]"
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82, 1))
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var action_label: Label = Label.new()
	action_label.text = action
	action_label.add_theme_font_size_override("font_size", 13)
	action_label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.76, 1))
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	row.add_child(key_label)
	row.add_child(action_label)
	container.add_child(bg)
	container.add_child(fill)
	container.add_child(row)
	parent.add_child(container)
	return {"container": container, "fill": fill}
