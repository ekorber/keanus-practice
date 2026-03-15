extends Node3D

## Group of targets this knife can hit
@export var target_group: String = "enemy"
## Whether this knife is controlled by player input
@export var player_controlled: bool = true
## Damage dealt per hit
@export var weapon_damage: int = 10
## Cooldown multiplier (1.0 = base knife speed)
@export var cooldown_multiplier: float = 1.0

@onready var _swing_sound: AudioStreamPlayer3D = $SwingSound
@onready var _hit_sound: AudioStreamPlayer3D = $HitSound


func _play(snd: Node) -> void:
	if snd and snd.get("stream") != null and snd.stream:
		snd.play()

## Reference to targets in the hitbox
var targets_in_range: Array[Node3D] = []
## Targets already hit during current attack
var targets_hit: Array[Node3D] = []
## Current facing direction (1 = right, -1 = left)
var facing_direction: float = 1.0
## Is attack animation playing
var is_attacking: bool = false
## Is the hitbox actively dealing damage
var hitbox_active: bool = false
## Lunge offset for stab animation
var lunge_offset: float = 0.0
## Locked direction during attack
var attack_direction: float = 1.0

func _ready() -> void:
	# Connect Area3D signals
	var hitbox: Area3D = $Hitbox
	hitbox.body_entered.connect(_on_body_entered)
	hitbox.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_controlled and not is_attacking:
		# Get player's horizontal input
		var input_dir: float = Input.get_axis("walk_left", "walk_right")

		# Update facing direction when moving
		if input_dir != 0.0:
			facing_direction = sign(input_dir)

	# Use attack_direction during attack, otherwise use facing_direction
	var current_dir: float = attack_direction if is_attacking else facing_direction

	# Apply position (knife on opposite side of movement + lunge offset)
	position.x = current_dir + (lunge_offset * current_dir)

	# Mirror the knife when on the left side
	scale.x = current_dir

	# Check for hits while hitbox is active
	if hitbox_active:
		_check_hits()


func _input(event: InputEvent) -> void:
	if player_controlled and event.is_action_pressed("attack") and not is_attacking:
		var owner_node: Node = get_parent()
		if owner_node and owner_node.get("is_dead"):
			return
		attack()


## Set the facing direction externally (for AI control)
func set_facing(direction: float) -> void:
	if direction != 0.0:
		facing_direction = sign(direction)


## Check and hit any valid targets in range
func _check_hits() -> void:
	# Don't register hits if owner is dead
	var owner_node: Node = get_parent()
	if owner_node and owner_node.get("is_dead"):
		return

	# Don't register hits if round is over
	var scoreboard: Node = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard and scoreboard.round_over:
		return

	for target in targets_in_range:
		if target in targets_hit:
			continue
		if is_instance_valid(target) and target.has_method("take_damage"):
			# Check again before each hit in case owner died or round ended
			if owner_node and owner_node.get("is_dead"):
				return
			if scoreboard and scoreboard.round_over:
				return
			targets_hit.append(target)
			_play(_hit_sound)

			var _mult = owner_node.get("rampage_multiplier") if owner_node else null
			var multiplier: float = _mult if _mult != null else 1.0
			var final_damage: int = int(weapon_damage * multiplier)

			# Check if this hit will kill the target
			var target_hp: Variant = target.get("current_hp")
			if target_hp != null and target_hp <= final_damage:
				_add_kill()  # Update score first so round result displays correctly

			target.take_damage(final_damage)
			if owner_node and owner_node.has_method("on_hit_landed"):
				owner_node.on_hit_landed()


func _add_kill() -> void:
	var scoreboard: Node = get_tree().get_first_node_in_group("scoreboard")
	if scoreboard:
		if player_controlled:
			scoreboard.add_player_kill()
		else:
			scoreboard.add_ai_kill()


## Trigger an attack (can be called externally by AI)
func attack() -> void:
	if is_attacking:
		return

	# Don't attack if owner is dead
	var owner_node: Node = get_parent()
	if owner_node and owner_node.get("is_dead"):
		return

	# Don't attack if attacks are disabled (round end)
	if has_meta("attacks_disabled") and get_meta("attacks_disabled"):
		return

	is_attacking = true
	hitbox_active = true
	attack_direction = facing_direction
	targets_hit.clear()
	_play(_swing_sound)

	# Play stab animation (times scaled by cooldown_multiplier)
	var tween: Tween = create_tween()
	var stab_angle: float = -attack_direction * PI / 2.0  # 90 degrees toward attack direction

	# Rotate down and lunge forward
	tween.tween_property(self, "rotation:z", stab_angle, 0.04 * cooldown_multiplier)
	tween.parallel().tween_property(self, "lunge_offset", 0.5, 0.04 * cooldown_multiplier)

	# Hold position
	tween.tween_interval(0.075 * cooldown_multiplier)

	# Rotate back up and return
	tween.tween_property(self, "rotation:z", 0.0, 0.06 * cooldown_multiplier)
	tween.parallel().tween_property(self, "lunge_offset", 0.0, 0.06 * cooldown_multiplier)

	# Deactivate hitbox after animation
	tween.tween_callback(func(): hitbox_active = false)

	# Cooldown
	tween.tween_interval(0.075 * cooldown_multiplier)

	tween.tween_callback(func(): is_attacking = false)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(target_group):
		targets_in_range.append(body)


func _on_body_exited(body: Node3D) -> void:
	targets_in_range.erase(body)
