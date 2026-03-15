extends Node3D

@export var target_group: String = "enemy"
@export var player_controlled: bool = true
@export var stab_damage: int = 10
@export var cooldown_multiplier: float = 2.4

@onready var _swing_sound: AudioStreamPlayer3D = $SwingSound
@onready var _charge_sound: AudioStreamPlayer3D = $ChargeSound
@onready var _hit_sound: AudioStreamPlayer3D = $HitSound

var targets_in_range: Array[Node3D] = []
var targets_hit: Array[Node3D] = []
var facing_direction: float = 1.0
var is_attacking: bool = false
var hitbox_active: bool = false
var lunge_offset: float = 0.0
var attack_direction: float = 1.0

var is_charging: bool = false
var charge_targets_hit: Array[Node3D] = []


func _ready() -> void:
	var hitbox: Area3D = $Hitbox
	hitbox.body_entered.connect(_on_body_entered)
	hitbox.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_controlled and not is_attacking:
		var input_dir: float = Input.get_axis("walk_left", "walk_right")
		if input_dir != 0.0:
			facing_direction = sign(input_dir)
			if is_charging:
				attack_direction = facing_direction

	var current_dir: float = attack_direction if (is_attacking or is_charging) else facing_direction

	position.x = current_dir + (lunge_offset * current_dir)
	scale.x = current_dir

	if hitbox_active:
		if is_charging:
			_check_charge_hits()
		else:
			_check_stab_hits()


func _input(event: InputEvent) -> void:
	if not player_controlled:
		return
	var owner_node: Node = get_parent()
	if owner_node and owner_node.get("is_dead"):
		return
	if has_meta("attacks_disabled") and get_meta("attacks_disabled"):
		return

	# LMB - normal stab
	if event.is_action_pressed("attack") and not is_attacking and not is_charging:
		attack()

	# RMB - charge attack
	if event.is_action_pressed("charge_attack") and not is_attacking and not is_charging:
		_start_charge()
	if event.is_action_released("charge_attack") and is_charging:
		_end_charge()


func set_facing(direction: float) -> void:
	if direction != 0.0:
		facing_direction = sign(direction)


func attack() -> void:
	if is_attacking or is_charging:
		return

	var owner_node: Node = get_parent()
	if owner_node and owner_node.get("is_dead"):
		return
	if has_meta("attacks_disabled") and get_meta("attacks_disabled"):
		return

	is_attacking = true
	hitbox_active = true
	attack_direction = facing_direction
	targets_hit.clear()
	_play(_swing_sound)

	var tween: Tween = create_tween()

	# Forward thrust (no rotation, just lunge)
	tween.tween_property(self, "lunge_offset", 0.5, 0.04 * cooldown_multiplier)

	# Hold
	tween.tween_interval(0.075 * cooldown_multiplier)

	# Retract
	tween.tween_property(self, "lunge_offset", 0.0, 0.06 * cooldown_multiplier)

	# Deactivate hitbox
	tween.tween_callback(func(): hitbox_active = false)

	# Cooldown
	tween.tween_interval(0.075 * cooldown_multiplier)

	tween.tween_callback(func(): is_attacking = false)


func _start_charge() -> void:
	is_charging = true
	hitbox_active = true
	attack_direction = facing_direction
	charge_targets_hit.clear()
	_play(_charge_sound)

	# Extend spear forward
	var tween: Tween = create_tween()
	tween.tween_property(self, "lunge_offset", 0.5, 0.05)


func _end_charge() -> void:
	is_charging = false
	hitbox_active = false
	is_attacking = true  # Brief cooldown

	# Retract spear
	var tween: Tween = create_tween()
	tween.tween_property(self, "lunge_offset", 0.0, 0.3)
	tween.tween_interval(0.45)
	tween.tween_callback(func(): is_attacking = false)


func _check_stab_hits() -> void:
	var owner_node: Node = get_parent()
	if owner_node and owner_node.get("is_dead"):
		return

	var scoreboard: Node = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard and scoreboard.round_over:
		return

	for target in targets_in_range:
		if target in targets_hit:
			continue
		if is_instance_valid(target) and target.has_method("take_damage"):
			if owner_node and owner_node.get("is_dead"):
				return
			if scoreboard and scoreboard.round_over:
				return
			targets_hit.append(target)
			_play(_hit_sound)

			var _mult = owner_node.get("rampage_multiplier") if owner_node else null
			var multiplier: float = _mult if _mult != null else 1.0
			var final_damage: int = int(stab_damage * multiplier)

			var target_hp: Variant = target.get("current_hp")
			if target_hp != null and target_hp <= final_damage:
				_add_kill()

			target.take_damage(final_damage)
			if owner_node and owner_node.has_method("on_hit_landed"):
				owner_node.on_hit_landed()


func _check_charge_hits() -> void:
	var owner_node: Node = get_parent()
	if owner_node and owner_node.get("is_dead"):
		return

	var scoreboard: Node = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard and scoreboard.round_over:
		return

	var player_speed: float = abs(owner_node.velocity.x) if owner_node else 0.0

	for target in targets_in_range:
		if target in charge_targets_hit:
			continue
		if is_instance_valid(target) and target.has_method("take_damage"):
			if owner_node and owner_node.get("is_dead"):
				return
			if scoreboard and scoreboard.round_over:
				return
			charge_targets_hit.append(target)
			_play(_hit_sound)

			var _mult = owner_node.get("rampage_multiplier") if owner_node else null
			var multiplier: float = _mult if _mult != null else 1.0
			var damage: int = int(_calculate_charge_damage(player_speed) * multiplier)

			var target_hp: Variant = target.get("current_hp")
			if target_hp != null and target_hp <= damage:
				_add_kill()

			target.take_damage(damage)
			if owner_node and owner_node.has_method("on_hit_landed"):
				owner_node.on_hit_landed()

			# Auto-retract on hit
			_end_charge()
			return


func _calculate_charge_damage(spd: float) -> int:
	# 20 damage at normal walk speed (8.0), scales linearly, min 10, max 100
	return clamp(int(spd * 2.5), 10, 100)


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


func _play(snd: Node) -> void:
	if snd and snd.get("stream") != null and snd.stream:
		snd.play()
