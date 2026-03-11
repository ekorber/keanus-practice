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


func _ready() -> void:
	# Spawn on left platform
	spawn_position = Vector3(-8, 3.5, 0)

	# Create health bar
	var health_bar_scene := preload("res://scenes/health_bar.tscn")
	health_bar = health_bar_scene.instantiate()
	health_bar.position = Vector3(0, 1.3, 0)  # Above the character
	add_child(health_bar)


func set_weapon(weapon_id: String) -> void:
	selected_weapon_id = weapon_id

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

	# Set X velocity based on input (2.5D movement - only X axis)
	velocity.x = input_dir * speed

	# Lock Z movement for 2.5D
	velocity.z = 0
	position.z = 0

	move_and_slide()

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


func unfreeze() -> void:
	is_frozen = false
