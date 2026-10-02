extends AnimatableBody2D

@export var distancia: float = 50.0
@export var velocidade: float = 60.0

var origem_x: float
var direcao: int = 1

func _ready() -> void:
	origem_x = position.x

func _physics_process(delta: float) -> void:
	position.x += direcao * velocidade * delta

	if position.x >= origem_x + distancia:
		position.x = origem_x + distancia
		direcao = -1
	elif position.x <= origem_x - distancia:
		position.x = origem_x - distancia
