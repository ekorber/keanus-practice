extends CharacterBody3D

## AI States for decision making
enum State {
	IDLE,            # Brief assessment/waiting
	CHASE,           # Pursuing the player
	ATTACK,          # In range, actively attacking
	RETREAT,         # Backing off (low HP or tactical)
	NAVIGATE,        # Finding path around obstacles
	STRAFE,          # Dodging/circling during combat
	JUMP_TO_PLATFORM # Moving to jump point and jumping to reach platform
}

## Movement speed in units per second
@export var speed: float = 4.0
## Sprint speed when chasing
@export var sprint_speed: float = 6.0
## Jump velocity
@export var jump_velocity: float = 10.0
## Gravity multiplier
@export var gravity_multiplier: float = 2.0
## Minimum distance to keep from player
@export var stop_distance: float = 1.5
## How much the enemy can be pushed
@export var push_resistance: float = 0.5
## Time before considering stuck
@export var stuck_threshold: float = 1.5
## Time to try navigating before reassessing
@export var navigate_duration: float = 2.0
## Map bounds for spawning
@export var spawn_min_x: float = -13.0
@export var spawn_max_x: float = 13.0
@export var spawn_max_y: float = 10.0
## Distance at which enemy will attack
@export var attack_distance: float = 2.0
## Distance to start engaging
@export var engage_distance: float = 8.0
## HP threshold to consider retreating (percentage)
@export var retreat_hp_threshold: float = 0.25
## How long to retreat before re-engaging
@export var retreat_duration: float = 1.5
## How long to strafe during combat
@export var strafe_duration: float = 0.8

const MAX_HP: int = 100
const PLATFORM_SCAN_DISTANCE: float = 12.0
const PLATFORM_SCAN_STEPS: int = 8
const MAX_JUMP_HEIGHT: float = 4.5
const MIN_PLATFORM_HEIGHT: float = 0.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var knife: Node3D = null  # Keep name for compatibility
var weapon: Node3D = null
var player: Node3D = null
var selected_weapon_id: String = "knife"
var push_velocity: float = 0.0
var was_blocked: bool = false
var was_blocked_above: bool = false
var move_direction: float = 0.0
var spawn_position: Vector3
var is_dead: bool = false
var is_frozen: bool = false
var current_hp: int = MAX_HP
var health_bar: Node3D = null

# State machine variables
var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var state_timer: float = 0.0

# Progress tracking
var last_distance_to_player: float = 0.0
var no_progress_timer: float = 0.0
var navigate_timer: float = 0.0
var navigate_direction: float = 1.0
var last_y_position: float = 0.0
var attempts_in_direction: int = 0

# Combat tracking
var last_hp: int = MAX_HP
var damage_react_timer: float = 0.0
var strafe_direction: float = 1.0
var attack_cooldown: float = 0.0
var attacks_landed: int = 0

# Retreat tracking
var retreat_blocked_timer: float = 0.0
var retreat_cooldown: float = 0.0
var is_cornered: bool = false
const CORNERED_THRESHOLD: float = 0.4
const RETREAT_COOLDOWN_DURATION: float = 3.0

# Strafe tracking
var strafe_accumulated: float = 0.0
var strafe_cooldown: float = 0.0
const MAX_STRAFE_TIME: float = 3.0
const STRAFE_COOLDOWN_DURATION: float = 2.0

# Spear charge
var ai_spear_charging: bool = false

# Dash
const DASH_DISTANCE: float = 2.1
const DASH_DURATION: float = 0.05
const DASH_COOLDOWN: float = 3.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 1.0

# Rampage
const RAMPAGE_DURATION: float = 3.0
const RAMPAGE_HIT_REQUIREMENT: int = 10
var rampage_multiplier: float = 1.0
var rampage_active: bool = false
var rampage_timer: float = 0.0
var rampage_hit_count: int = 0

# Parry
const PARRY_DURATION: float = 1.0
const PARRY_COOLDOWN: float = 2.0
var parry_active: bool = false
var parry_timer: float = 0.0
var parry_cooldown_timer: float = 0.0

# Platform jumping
var target_platform_pos: Vector3 = Vector3.ZERO
var jump_point: Vector3 = Vector3.ZERO
var has_jumped: bool = false
var jump_timeout: float = 0.0
var failed_jump_cooldown: float = 0.0
var consecutive_jump_failures: int = 0

# Unreachable player tracking
var unreachable_timer: float = 0.0
const UNREACHABLE_THRESHOLD: float = 4.0  # After 4s of no vertical progress, consider player unreachable

var _footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.42

@onready var ray_up: RayCast3D = $RayUp
@onready var _footstep_sound: AudioStreamPlayer3D = $FootstepSound
@onready var _rampage_activate_sound: AudioStreamPlayer3D = $RampageActivateSound


func _play(snd: Node) -> void:
	if snd and snd.get("stream") != null and snd.stream:
		snd.play()


func _ready() -> void:
	spawn_position = Vector3(8, 3.5, 0)
	add_to_group("enemy")

	# Create health bar
	var health_bar_scene: PackedScene = preload("res://scenes/health_bar.tscn")
	health_bar = health_bar_scene.instantiate()
	health_bar.position = Vector3(0, 1.5, 0)
	add_child(health_bar)

	# Find the player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_parent().get_node_or_null("Player")

	if player:
		last_distance_to_player = global_position.distance_to(player.global_position)
	last_y_position = global_position.y


func set_weapon(weapon_id: String) -> void:
	selected_weapon_id = weapon_id

	# Remove existing weapon if any (knife and weapon alias the same node — free only once)
	if weapon:
		weapon.queue_free()
		weapon = null
		knife = null

	# Load and instantiate the new weapon
	var weapon_scene_path: String = _get_weapon_scene_path(weapon_id)
	var weapon_scene: PackedScene = load(weapon_scene_path)
	weapon = weapon_scene.instantiate()
	weapon.player_controlled = false
	weapon.target_group = "player"
	weapon.name = "Weapon"
	add_child(weapon)

	# Keep knife reference for compatibility
	knife = weapon

	# Sync hitbox visuals with current debug toggle state
	if HitboxDebug.hitboxes_visible:
		get_tree().call_group("hitbox_debug", "set_visible", true)


func set_random_weapon() -> void:
	var weapons: Array[String] = ["knife", "bat", "sword", "spear", "mace"]
	set_weapon(weapons[randi() % weapons.size()])


func set_weapon_to_match(player_weapon_id: String) -> void:
	var weapon_id: String
	match player_weapon_id:
		"sword", "bat":
			weapon_id = (["sword", "bat"] as Array)[randi() % 2]
		"spear", "mace":
			weapon_id = (["spear", "mace"] as Array)[randi() % 2]
		_:
			weapon_id = "knife"
	set_weapon(weapon_id)


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

# Apply push velocity decay
	push_velocity = move_toward(push_velocity, 0, delta * 8.0)

	# Check if blocked above
	was_blocked_above = ray_up.is_colliding() if ray_up else false

	# Update timers
	state_timer += delta
	attack_cooldown = max(0.0, attack_cooldown - delta)
	damage_react_timer = max(0.0, damage_react_timer - delta)
	jump_timeout = max(0.0, jump_timeout - delta)
	failed_jump_cooldown = max(0.0, failed_jump_cooldown - delta)
	retreat_cooldown = max(0.0, retreat_cooldown - delta)
	strafe_cooldown = max(0.0, strafe_cooldown - delta)
	dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)

	# Handle rampage duration
	if rampage_active:
		rampage_timer -= delta
		if rampage_timer <= 0.0:
			rampage_active = false
			rampage_multiplier = 1.0
			_clear_body_tint()

	# Handle parry timers
	if parry_active:
		parry_timer -= delta
		if parry_timer <= 0.0:
			parry_active = false
			parry_cooldown_timer = PARRY_COOLDOWN
			_clear_body_tint()
	elif parry_cooldown_timer > 0.0:
		parry_cooldown_timer -= delta

	# Handle dash — override movement entirely while dashing
	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_direction * (DASH_DISTANCE / DASH_DURATION)
		velocity.z = 0
		position.z = 0
		if dash_timer <= 0.0:
			is_dashing = false
		move_and_slide()
		_check_collisions()
		return

	# Track cumulative strafe time
	if current_state == State.STRAFE:
		strafe_accumulated += delta
	else:
		strafe_accumulated = 0.0

	# Run state machine
	if player:
		_update_state_machine(delta)
		_execute_current_state(delta)
	else:
		velocity.x = push_velocity

	# Lock Z movement for 2.5D
	velocity.z = 0
	position.z = 0

	move_and_slide()
	_check_collisions()

	# Footstep sounds
	if is_on_floor() and abs(move_direction) > 0:
		_footstep_timer -= delta
		if _footstep_timer <= 0:
			_play(_footstep_sound)
			_footstep_timer = FOOTSTEP_INTERVAL
	else:
		_footstep_timer = 0.0


func _update_state_machine(delta: float) -> void:
	var distance_to_player: float = global_position.distance_to(player.global_position)
	var direction_to_player: float = player.global_position.x - global_position.x
	var hp_ratio: float = float(current_hp) / float(MAX_HP)
	var player_hp_ratio: float = float(player.current_hp) / float(player.MAX_HP) if player.has_method("take_damage") else 1.0

	# Check for damage reaction (got hit recently)
	if current_hp < last_hp:
		damage_react_timer = 0.5
		last_hp = current_hp

		# Decide reaction based on HP
		if hp_ratio <= retreat_hp_threshold and retreat_cooldown <= 0:
			_change_state(State.RETREAT)
			return
		elif randf() < 0.4 and strafe_cooldown <= 0:
			_change_state(State.STRAFE)
			return

	# State-specific transitions
	match current_state:
		State.IDLE:
			_evaluate_idle_transitions(distance_to_player, hp_ratio)
		State.CHASE:
			_evaluate_chase_transitions(distance_to_player, hp_ratio, delta)
		State.ATTACK:
			_evaluate_attack_transitions(distance_to_player, hp_ratio)
		State.RETREAT:
			_evaluate_retreat_transitions(distance_to_player, hp_ratio)
		State.NAVIGATE:
			_evaluate_navigate_transitions(distance_to_player)
		State.STRAFE:
			_evaluate_strafe_transitions(distance_to_player, hp_ratio)
		State.JUMP_TO_PLATFORM:
			_evaluate_jump_to_platform_transitions()


func _evaluate_idle_transitions(distance: float, hp_ratio: float) -> void:
	if state_timer > 0.3:
		if hp_ratio <= retreat_hp_threshold and retreat_cooldown <= 0:
			_change_state(State.RETREAT)
		elif distance <= attack_distance:
			_change_state(State.ATTACK)
		elif distance <= engage_distance:
			_change_state(State.CHASE)
		else:
			_change_state(State.CHASE)


func _evaluate_chase_transitions(distance: float, hp_ratio: float, delta: float) -> void:
	if distance <= attack_distance:
		_change_state(State.ATTACK)
		return

	if hp_ratio <= retreat_hp_threshold and retreat_cooldown <= 0:
		_change_state(State.RETREAT)
		return

	var height_diff: float = player.global_position.y - global_position.y
	if height_diff > MIN_PLATFORM_HEIGHT and is_on_floor() and failed_jump_cooldown <= 0:
		var platform_info: Dictionary = _find_reachable_platform_to_player()
		if platform_info.found:
			target_platform_pos = platform_info.platform_pos
			jump_point = platform_info.jump_from
			_change_state(State.JUMP_TO_PLATFORM)
			return

	if is_on_floor():
		var progress: float = last_distance_to_player - distance
		if progress < 0.05:
			no_progress_timer += delta
		else:
			no_progress_timer = 0.0
			attempts_in_direction = 0
		last_distance_to_player = distance

		if no_progress_timer > stuck_threshold:
			if failed_jump_cooldown <= 0:
				var platform_info: Dictionary = _find_reachable_platform_to_player()
				if platform_info.found:
					target_platform_pos = platform_info.platform_pos
					jump_point = platform_info.jump_from
					_change_state(State.JUMP_TO_PLATFORM)
				else:
					# No platform found - set a brief cooldown to avoid rapid retries
					failed_jump_cooldown = 1.0
					_change_state(State.NAVIGATE)
			else:
				_change_state(State.NAVIGATE)


func _evaluate_attack_transitions(distance: float, hp_ratio: float) -> void:
	# Successfully reached the player - reset unreachable tracking
	unreachable_timer = 0.0

	if distance > attack_distance * 1.5:
		_change_state(State.CHASE)
		return

	if hp_ratio <= retreat_hp_threshold and retreat_cooldown <= 0:
		_change_state(State.RETREAT)
		return

	if state_timer > 1.5 and randf() < 0.02 and strafe_cooldown <= 0:
		_change_state(State.STRAFE)


func _evaluate_retreat_transitions(distance: float, hp_ratio: float) -> void:
	# If cornered (stuck against a wall), stop retreating and fight
	if is_cornered:
		is_cornered = false
		retreat_cooldown = RETREAT_COOLDOWN_DURATION
		if distance <= attack_distance:
			_change_state(State.ATTACK)
		elif strafe_cooldown <= 0:
			_change_state(State.STRAFE)
		else:
			_change_state(State.CHASE)
		return

	if state_timer > retreat_duration:
		if distance > engage_distance:
			_change_state(State.IDLE)
		elif strafe_cooldown <= 0:
			_change_state(State.STRAFE)
		else:
			_change_state(State.CHASE)


func _evaluate_navigate_transitions(distance: float) -> void:
	var direction: float = player.global_position.x - global_position.x
	var height_diff: float = player.global_position.y - global_position.y

	var made_vertical_progress: bool = abs(global_position.y - last_y_position) > 0.5
	var reached_player_height: bool = abs(height_diff) < 1.0
	var getting_closer: bool = distance < last_distance_to_player - 0.5
	var player_is_above: bool = height_diff > MIN_PLATFORM_HEIGHT

	# Require minimum time in navigate state to prevent rapid state switching
	if state_timer < 0.5:
		return

	# If player is above us, only transition out if we made vertical progress or reached their height
	if player_is_above:
		if made_vertical_progress or reached_player_height:
			unreachable_timer = 0.0  # Reset since we made progress
			_change_state(State.CHASE)
			no_progress_timer = 0.0
			last_distance_to_player = distance
	else:
		# Player is at same level or below - horizontal progress counts
		unreachable_timer = 0.0  # Player not above, reset timer
		if made_vertical_progress or reached_player_height or getting_closer:
			_change_state(State.CHASE)
			no_progress_timer = 0.0
			last_distance_to_player = distance


func _evaluate_strafe_transitions(distance: float, hp_ratio: float) -> void:
	# Hard cap: force out of strafe after MAX_STRAFE_TIME and set cooldown
	if strafe_accumulated >= MAX_STRAFE_TIME:
		strafe_cooldown = STRAFE_COOLDOWN_DURATION
		if distance <= attack_distance:
			_change_state(State.ATTACK)
		else:
			_change_state(State.CHASE)
		return

	if state_timer > strafe_duration:
		if distance <= attack_distance:
			_change_state(State.ATTACK)
		elif hp_ratio <= retreat_hp_threshold and retreat_cooldown <= 0:
			_change_state(State.RETREAT)
		else:
			_change_state(State.CHASE)


func _evaluate_jump_to_platform_transitions() -> void:
	if has_jumped and is_on_floor():
		var height_reached: bool = global_position.y >= target_platform_pos.y - 0.5
		if height_reached:
			# Success! Reset failure tracking
			consecutive_jump_failures = 0
			failed_jump_cooldown = 0.0
			_change_state(State.CHASE)
			return
		else:
			# Failed to reach platform
			consecutive_jump_failures += 1
			# Increase cooldown with each failure (2s, 4s, 6s, max 8s)
			failed_jump_cooldown = min(consecutive_jump_failures * 2.0, 8.0)
			_change_state(State.NAVIGATE)
			return

	if jump_timeout <= 0:
		# Timeout - whether we jumped or never reached the jump point
		consecutive_jump_failures += 1
		failed_jump_cooldown = min(consecutive_jump_failures * 2.0, 8.0)
		_change_state(State.NAVIGATE)


func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return

	# Cancel spear charge when leaving attack state
	if current_state == State.ATTACK and ai_spear_charging and knife:
		knife._end_charge()
		ai_spear_charging = false

	previous_state = current_state
	current_state = new_state
	state_timer = 0.0

	print("Enemy: ", State.keys()[previous_state], " -> ", State.keys()[new_state])

	match new_state:
		State.NAVIGATE:
			var direction: float = player.global_position.x - global_position.x
			navigate_direction = sign(direction)
			navigate_timer = navigate_duration
			last_y_position = global_position.y
			no_progress_timer = 0.0
		State.STRAFE:
			var direction: float = player.global_position.x - global_position.x
			strafe_direction = -sign(direction) if randf() < 0.7 else sign(direction)
		State.RETREAT:
			attacks_landed = 0
			retreat_blocked_timer = 0.0
			is_cornered = false
		State.JUMP_TO_PLATFORM:
			has_jumped = false
			jump_timeout = 1.0


func _execute_current_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.RETREAT:
			_state_retreat(delta)
		State.NAVIGATE:
			_state_navigate(delta)
		State.STRAFE:
			_state_strafe(delta)
		State.JUMP_TO_PLATFORM:
			_state_jump_to_platform(delta)


func _state_idle(delta: float) -> void:
	velocity.x = push_velocity
	move_direction = 0.0

	var direction: float = player.global_position.x - global_position.x
	if knife and direction != 0.0:
		knife.set_facing(sign(direction))


func _state_chase(delta: float) -> void:
	var direction: float = player.global_position.x - global_position.x
	var distance: float = abs(direction)
	var height_diff: float = player.global_position.y - global_position.y

	if knife and direction != 0.0:
		knife.set_facing(sign(direction))

	# Dash toward player at medium range
	if dash_cooldown_timer <= 0 and is_on_floor() and distance > 2.5 and distance < 6.0 and randf() < 0.012:
		_start_dash(sign(direction))
		return

	if distance > stop_distance:
		move_direction = sign(direction)
		var current_speed: float = sprint_speed if distance > engage_distance * 0.5 else speed
		velocity.x = move_direction * current_speed + push_velocity
	else:
		move_direction = 0.0
		velocity.x = push_velocity

	if is_on_floor():
		_handle_jump(height_diff, distance)


func _state_attack(delta: float) -> void:
	var direction: float = player.global_position.x - global_position.x
	var distance: float = abs(direction)
	var total_distance: float = global_position.distance_to(player.global_position)

	if knife and direction != 0.0:
		knife.set_facing(sign(direction))

	match selected_weapon_id:
		"spear":
			_attack_spear(direction, distance, total_distance)
		"mace":
			_attack_mace(direction, distance, total_distance)
		_:
			_attack_default(direction, distance, total_distance)


func _attack_default(direction: float, distance: float, total_distance: float) -> void:
	# Sword parry — occasionally deflect when player is close
	if selected_weapon_id == "sword" and not parry_active and parry_cooldown_timer <= 0 and total_distance <= attack_distance * 1.5 and randf() < 0.008:
		parry_active = true
		parry_timer = PARRY_DURATION
		_set_body_tint(Color(0.30, 0.30, 0.33, 1.0))

	if total_distance <= attack_distance and knife and not knife.is_attacking and attack_cooldown <= 0:
		knife.attack()
		attack_cooldown = 0.3 + randf() * 0.2
		attacks_landed += 1

	if distance > attack_distance * 0.8:
		move_direction = sign(direction)
		velocity.x = move_direction * speed * 0.5 + push_velocity
	elif distance < stop_distance * 0.5:
		move_direction = -sign(direction)
		velocity.x = move_direction * speed * 0.3 + push_velocity
	else:
		move_direction = 0.0
		velocity.x = push_velocity


func _attack_spear(direction: float, distance: float, total_distance: float) -> void:
	if not knife:
		return

	if distance <= attack_distance:
		# In range: release charge if charging, or normal stab
		if ai_spear_charging:
			knife._end_charge()
			ai_spear_charging = false
		elif not knife.is_attacking and attack_cooldown <= 0:
			knife.attack()
			attack_cooldown = 0.5 + randf() * 0.3
			attacks_landed += 1
	elif distance <= 5.0 and not ai_spear_charging and not knife.is_attacking and attack_cooldown <= 0:
		# Medium range: start charge and rush in
		knife._start_charge()
		ai_spear_charging = true

	if ai_spear_charging:
		move_direction = sign(direction)
		velocity.x = move_direction * sprint_speed + push_velocity
	elif distance > attack_distance * 0.8:
		move_direction = sign(direction)
		velocity.x = move_direction * speed * 0.5 + push_velocity
	elif distance < stop_distance * 0.5:
		move_direction = -sign(direction)
		velocity.x = move_direction * speed * 0.3 + push_velocity
	else:
		move_direction = 0.0
		velocity.x = push_velocity


func _attack_mace(direction: float, distance: float, total_distance: float) -> void:
	if not knife:
		return

	# Jump when close and on the floor to set up a falling slam
	if is_on_floor() and total_distance <= attack_distance * 2.0 and not knife.is_attacking:
		velocity.y = jump_velocity

	# Swing on the way down
	if not is_on_floor() and velocity.y < -1.5 and not knife.is_attacking and attack_cooldown <= 0:
		knife.attack()
		attack_cooldown = 1.2
		attacks_landed += 1

	if distance > stop_distance:
		move_direction = sign(direction)
		velocity.x = move_direction * speed * 0.7 + push_velocity
	else:
		move_direction = 0.0
		velocity.x = push_velocity


func _state_retreat(delta: float) -> void:
	var direction: float = player.global_position.x - global_position.x

	if knife and direction != 0.0:
		knife.set_facing(sign(direction))

	# Dash away from player while retreating
	if dash_cooldown_timer <= 0 and is_on_floor() and randf() < 0.02:
		_start_dash(-sign(direction))
		return

	move_direction = -sign(direction)
	velocity.x = move_direction * sprint_speed + push_velocity

	# Track how long we've been blocked against a wall while retreating
	if is_on_floor() and was_blocked:
		retreat_blocked_timer += delta
		if retreat_blocked_timer >= CORNERED_THRESHOLD:
			is_cornered = true
	else:
		retreat_blocked_timer = 0.0


func _state_navigate(delta: float) -> void:
	navigate_timer -= delta

	var direction: float = player.global_position.x - global_position.x
	var height_diff: float = player.global_position.y - global_position.y
	var player_is_above: bool = height_diff > MIN_PLATFORM_HEIGHT

	# Track time spent trying to reach elevated player
	if player_is_above:
		var made_progress: bool = abs(global_position.y - last_y_position) > 0.3
		if made_progress:
			unreachable_timer = 0.0
			last_y_position = global_position.y
		else:
			unreachable_timer += delta

		# If player seems unreachable, just wait below them
		if unreachable_timer > UNREACHABLE_THRESHOLD:
			var dist_to_player_x: float = abs(direction)
			if dist_to_player_x > 2.0:
				# Move toward being under the player
				move_direction = sign(direction)
				velocity.x = move_direction * speed * 0.5 + push_velocity
			else:
				# Already under player, just wait
				move_direction = 0.0
				velocity.x = push_velocity

			if knife:
				knife.set_facing(sign(direction))
			return
	else:
		unreachable_timer = 0.0

	if navigate_timer <= 0:
		attempts_in_direction += 1

		if attempts_in_direction >= 3:
			# Tried both directions multiple times, try moving toward player
			navigate_direction = sign(direction)
			attempts_in_direction = 0
		else:
			navigate_direction = -navigate_direction

		navigate_timer = navigate_duration
		last_y_position = global_position.y

	move_direction = navigate_direction
	velocity.x = move_direction * speed + push_velocity

	if knife:
		knife.set_facing(sign(direction))  # Always face the player

	if is_on_floor():
		# When blocked by a wall and nothing above, jump
		if was_blocked and not was_blocked_above:
			velocity.y = jump_velocity
		# When player is above and we're not blocked above, try jumping periodically
		elif player_is_above and not was_blocked_above:
			# Jump more frequently when navigating and player is above
			if state_timer > 0.3 and fmod(state_timer, 0.8) < delta * 2:
				velocity.y = jump_velocity


func _state_strafe(delta: float) -> void:
	var direction: float = player.global_position.x - global_position.x
	var total_distance: float = global_position.distance_to(player.global_position)

	if knife and direction != 0.0:
		knife.set_facing(sign(direction))

	move_direction = strafe_direction
	velocity.x = move_direction * speed + push_velocity

	if total_distance <= attack_distance and knife and not knife.is_attacking and attack_cooldown <= 0:
		knife.attack()
		attack_cooldown = 0.4

	if was_blocked:
		strafe_direction = -strafe_direction

	if is_on_floor() and was_blocked and not was_blocked_above:
		velocity.y = jump_velocity


func _state_jump_to_platform(delta: float) -> void:
	var direction_to_jump: float = jump_point.x - global_position.x
	var direction_to_player: float = player.global_position.x - global_position.x

	if knife and direction_to_player != 0.0:
		knife.set_facing(sign(direction_to_player))

	if not has_jumped:
		var distance_to_jump: float = abs(direction_to_jump)

		if distance_to_jump > 0.3:
			move_direction = sign(direction_to_jump)
			velocity.x = move_direction * speed + push_velocity
		else:
			if is_on_floor() and not was_blocked_above:
				velocity.y = jump_velocity
				var dir_to_platform: float = sign(target_platform_pos.x - global_position.x)
				velocity.x = dir_to_platform * speed * 1.2
				has_jumped = true
	else:
		var dir_to_platform: float = sign(target_platform_pos.x - global_position.x)
		if not is_on_floor():
			velocity.x = dir_to_platform * speed * 0.8 + push_velocity


func _handle_jump(height_diff: float, distance: float) -> void:
	var should_jump: bool = false

	if height_diff > 1.0 and not was_blocked_above:
		should_jump = true

	if was_blocked and move_direction != 0.0 and not was_blocked_above:
		should_jump = true

	if should_jump:
		velocity.y = jump_velocity


func _find_reachable_platform_to_player() -> Dictionary:
	var result: Dictionary = {"found": false, "platform_pos": Vector3.ZERO, "jump_from": Vector3.ZERO}
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var direction_to_player: float = sign(player.global_position.x - global_position.x)
	var player_height: float = player.global_position.y
	var my_height: float = global_position.y

	var effective_gravity: float = gravity * gravity_multiplier
	var max_reachable_height: float = my_height + (jump_velocity * jump_velocity) / (2.0 * effective_gravity)

	var best_platform: Dictionary = {"found": false, "platform_pos": Vector3.ZERO, "jump_from": Vector3.ZERO, "score": -999.0}

	for i: int in range(PLATFORM_SCAN_STEPS):
		var scan_distance: float = (float(i + 1) / PLATFORM_SCAN_STEPS) * PLATFORM_SCAN_DISTANCE
		var scan_x: float = global_position.x + direction_to_player * scan_distance

		for dir: float in [direction_to_player, -direction_to_player]:
			var check_x: float = global_position.x + dir * scan_distance

			var platform_pos: Vector3 = _find_platform_at_x(check_x, my_height, max_reachable_height, space_state)

			if platform_pos != Vector3.ZERO:
				var platform_height: float = platform_pos.y

				if platform_height > my_height + MIN_PLATFORM_HEIGHT and platform_height <= max_reachable_height:
					var height_score: float = 0.0

					if platform_height >= player_height - 0.5:
						height_score = 10.0
					else:
						height_score = (platform_height - my_height) / (player_height - my_height) * 5.0

					var direction_bonus: float = 2.0 if dir == direction_to_player else 0.0
					var distance_penalty: float = scan_distance * 0.1
					var total_score: float = height_score + direction_bonus - distance_penalty

					if total_score > best_platform.score:
						var jump_from: Vector3 = _calculate_jump_point(platform_pos, dir, space_state)

						best_platform = {
							"found": true,
							"platform_pos": platform_pos,
							"jump_from": jump_from,
							"score": total_score
						}

	if best_platform.found:
		result = best_platform

	return result


func _find_platform_at_x(x: float, min_height: float, max_height: float, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var ray_origin: Vector3 = Vector3(x, max_height + 1.0, 0)
	var ray_end: Vector3 = Vector3(x, min_height - 1.0, 0)

	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	ray_query.exclude = [self]
	ray_query.collision_mask = 1

	var ray_result: Dictionary = space_state.intersect_ray(ray_query)

	if not ray_result.is_empty():
		var hit_pos: Vector3 = ray_result.position
		if hit_pos.y > min_height + MIN_PLATFORM_HEIGHT and hit_pos.y <= max_height:
			return hit_pos

	return Vector3.ZERO


func _calculate_jump_point(platform_pos: Vector3, direction: float, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var my_pos: Vector3 = global_position

	var height_diff: float = platform_pos.y - my_pos.y
	var effective_gravity: float = gravity * gravity_multiplier

	var t_peak: float = jump_velocity / effective_gravity
	var h_peak: float = (jump_velocity * jump_velocity) / (2.0 * effective_gravity)

	var t_to_height: float
	if height_diff <= h_peak:
		var discriminant: float = jump_velocity * jump_velocity - 2.0 * effective_gravity * height_diff
		if discriminant >= 0:
			t_to_height = (jump_velocity - sqrt(discriminant)) / effective_gravity
		else:
			t_to_height = t_peak
	else:
		t_to_height = t_peak

	var horizontal_speed: float = speed * 1.2
	var max_horizontal: float = horizontal_speed * t_to_height * 1.5

	var platform_distance: float = abs(platform_pos.x - my_pos.x)
	var jump_distance: float = min(platform_distance, max_horizontal)

	var jump_x: float = platform_pos.x - direction * (platform_distance - jump_distance * 0.3)

	var ground_pos: Vector3 = _find_ground_at_x(jump_x, space_state)
	if ground_pos != Vector3.ZERO:
		return ground_pos

	return my_pos


func _find_ground_at_x(x: float, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var ray_origin: Vector3 = Vector3(x, global_position.y + 5.0, 0)
	var ray_end: Vector3 = Vector3(x, global_position.y - 10.0, 0)

	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	ray_query.exclude = [self]
	ray_query.collision_mask = 1

	var ray_result: Dictionary = space_state.intersect_ray(ray_query)

	if not ray_result.is_empty():
		var hit_pos: Vector3 = ray_result.position
		return Vector3(x, hit_pos.y + 1.0, 0)

	return Vector3.ZERO


func _check_collisions() -> void:
	was_blocked = false
	for i: int in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		var normal: Vector3 = collision.get_normal()

		if abs(normal.x) > 0.7 and is_on_floor():
			was_blocked = true

		if collider.is_in_group("player"):
			var push_dir: float = sign(global_position.x - collider.global_position.x)
			push_velocity = push_dir * collider.velocity.length() * push_resistance


func apply_push(force: float) -> void:
	push_velocity += force * 0.08
	push_velocity = clamp(push_velocity, -3.0, 3.0)


func take_damage(amount: int) -> void:
	if is_dead:
		return

	if parry_active:
		parry_active = false
		parry_cooldown_timer = PARRY_COOLDOWN
		_clear_body_tint()
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
	if knife:
		knife.visible = false
		for child in knife.get_children():
			if child is Node3D and child.top_level:
				child.visible = false
	$CollisionShape3D.set_deferred("disabled", true)

	var scoreboard: Node = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard:
		scoreboard.start_round_reset()


func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	push_velocity = 0.0
	current_state = State.IDLE
	previous_state = State.IDLE
	state_timer = 0.0
	no_progress_timer = 0.0
	is_frozen = true
	is_dead = false
	attacks_landed = 0
	attack_cooldown = 0.0
	damage_react_timer = 0.0
	has_jumped = false
	jump_timeout = 0.0

	current_hp = MAX_HP
	last_hp = MAX_HP
	if health_bar:
		health_bar.reset()

	# Reset jump failure tracking
	failed_jump_cooldown = 0.0
	consecutive_jump_failures = 0
	unreachable_timer = 0.0

	# Reset retreat tracking
	retreat_blocked_timer = 0.0
	retreat_cooldown = 0.0
	is_cornered = false

	# Reset strafe tracking
	strafe_accumulated = 0.0
	strafe_cooldown = 0.0

	# Reset spear, dash, rampage and parry
	ai_spear_charging = false
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	if rampage_active or parry_active:
		_clear_body_tint()
	rampage_active = false
	rampage_timer = 0.0
	rampage_multiplier = 1.0
	parry_active = false
	parry_timer = 0.0
	parry_cooldown_timer = 0.0

	if player:
		last_distance_to_player = global_position.distance_to(player.global_position)

	$CollisionShape3D.set_deferred("disabled", false)
	visible = true
	if knife:
		knife.visible = true
		for child in knife.get_children():
			if child is Node3D and child.top_level:
				child.visible = true


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


func _start_dash(direction: float) -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	dash_direction = direction


func reset_rampage_charge() -> void:
	rampage_hit_count = 0


func on_hit_landed() -> void:
	if rampage_active:
		return
	rampage_hit_count += 1
	if rampage_hit_count >= RAMPAGE_HIT_REQUIREMENT:
		rampage_active = true
		rampage_timer = RAMPAGE_DURATION
		rampage_multiplier = 1.5
		rampage_hit_count = 0
		_set_body_tint(Color(1.0, 0.40, 0.05, 1.0), true)
		_play(_rampage_activate_sound)


func _find_spawn_position() -> Vector3:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var max_attempts: int = 20

	for i: int in max_attempts:
		var random_x: float = randf_range(spawn_min_x, spawn_max_x)
		var ray_origin: Vector3 = Vector3(random_x, spawn_max_y, 0)
		var ray_end: Vector3 = Vector3(random_x, -5, 0)

		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		ray_query.exclude = [self]
		var ray_result: Dictionary = space_state.intersect_ray(ray_query)

		if ray_result.is_empty():
			continue

		var ground_y: float = ray_result.position.y
		var test_position: Vector3 = Vector3(random_x, ground_y + 1.5, 0)

		var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		shape_query.shape = capsule
		shape_query.transform = Transform3D(Basis.IDENTITY, test_position)
		shape_query.exclude = [self]

		var shape_result: Array[Dictionary] = space_state.intersect_shape(shape_query, 1)

		if shape_result.is_empty():
			return test_position

	return spawn_position
