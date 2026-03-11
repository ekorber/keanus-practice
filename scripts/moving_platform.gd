extends AnimatableBody3D

@export var move_distance: float = 5.0
@export var move_speed: float = 0.8

var _start_x: float
var _time: float = 0.0


func _ready() -> void:
	_start_x = position.x


func _physics_process(delta: float) -> void:
	_time += delta
	position.x = _start_x + sin(_time * move_speed) * move_distance
