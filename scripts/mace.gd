extends Node3D

@export var target_group: String = "enemy"
@export var player_controlled: bool = true
@export var damage_multiplier: float = 3.0

var targets_in_range: Array[Node3D] = []
var facing_direction: float = 1.0
var attack_direction: float = 1.0
var is_attacking: bool = false


func _ready() -> void:
	var hitbox: Area3D = $Hitbox
	hitbox.top_level = true  # Ignore parent transform so it never rotates with the mace swing
	hitbox.body_entered.connect(_on_body_entered)
	hitbox.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_controlled and not is_attacking:
		var input_dir: float = Input.get_axis("walk_left", "walk_right")
		if input_dir != 0.0:
			facing_direction = sign(input_dir)

	position.x = facing_direction
	scale.x = facing_direction

	# Keep hitbox fixed in world space centered on the player, not the mace
	var owner_node: Node = get_parent()
	if owner_node:
		$Hitbox.global_position = owner_node.global_position + Vector3(facing_direction * 0.5, -0.8, 0)


func _input(event: InputEvent) -> void:
	if not player_controlled:
		return
	var owner_node: Node = get_parent()
	if owner_node and owner_node.get("is_dead"):
		return
	if has_meta("attacks_disabled") and get_meta("attacks_disabled"):
		return

	if event.is_action_pressed("attack") and not is_attacking:
		_try_strike()


func set_facing(direction: float) -> void:
	if direction != 0.0:
		facing_direction = sign(direction)


func _try_strike() -> void:
	var owner_node: Node = get_parent()
	if not owner_node:
		return

	is_attacking = true
	attack_direction = facing_direction

	var vel_y: float = owner_node.velocity.y
	var fall_speed: float = abs(vel_y)
	var damage: int = _calculate_damage(fall_speed)

	# Sword-style swing animation without the lunge forward
	var stab_angle: float = -attack_direction * PI / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation:z", stab_angle, 0.18)
	# Deal damage at the swing peak
	tween.tween_callback(func():
		var scoreboard: Node = get_tree().get_first_node_in_group("scoreboard")
		if scoreboard and scoreboard.round_over:
			return
		for target in targets_in_range:
			if is_instance_valid(target) and target.has_method("take_damage"):
				if owner_node.get("is_dead"):
					break
				if scoreboard and scoreboard.round_over:
					break
				var target_hp: Variant = target.get("current_hp")
				if target_hp != null and target_hp <= damage:
					_add_kill()
				target.take_damage(damage)
				break  # Single hit per swing
	)
	tween.tween_interval(0.2)
	tween.tween_property(self, "rotation:z", 0.0, 0.22)
	tween.tween_interval(0.7)
	tween.tween_callback(func(): is_attacking = false)


func _calculate_damage(fall_speed: float) -> int:
	# Base 10 damage, scales up with fall speed
	return min(max(10, int(fall_speed * damage_multiplier)), 100)


func _add_kill() -> void:
	var scoreboard: Node = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard:
		if player_controlled:
			scoreboard.add_player_kill()
		else:
			scoreboard.add_ai_kill()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(target_group):
		targets_in_range.append(body)


func _on_body_exited(body: Node3D) -> void:
	targets_in_range.erase(body)
