extends Sprite2D

@export var min_speed: float = 80.0
@export var max_speed: float = 215.0
@export var acceleration: float = 100.0   # quanto a velocidade aumenta por segundo
@export var limit_x: float = 8000.0        # posição X onde a nave reinicia

var current_speed: float = 80.0
var start_x: float

func _ready() -> void:
	start_x = position.x
	current_speed = min_speed

func _process(delta: float) -> void:
	if position.x < limit_x:
		current_speed = min(current_speed + acceleration * delta, max_speed)
		position.x += current_speed * delta
	else:
		position.x = start_x
		current_speed = min_speed
