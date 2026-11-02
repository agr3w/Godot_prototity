extends GPUParticles2D

@export var distancia: float = 200.0   # pixels para cada lado
@export var duracao: float = 1.5       # segundos para ir de um lado ao outro

var _x_inicial: float


func _ready() -> void:
	_x_inicial = position.x

	var tween := create_tween().set_loops()   # repete para sempre
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)         # acelera e desacelera nas pontas = movimento suave

	tween.tween_property(self, "position:x", _x_inicial + distancia, duracao)
	tween.tween_property(self, "position:x", _x_inicial - distancia, duracao)
