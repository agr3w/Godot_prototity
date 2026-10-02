extends AnimatableBody2D

@export var distancia: float = 250.0
@export var velocidade: float = 100.0

func _ready() -> void:
	print("pilar_novo rodando")
	var x0 := position.x
	var tempo := distancia / velocidade
	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:x", x0 + distancia, tempo)
	tween.tween_property(self, "position:x", x0 - distancia, tempo * 2.0)
	tween.tween_property(self, "position:x", x0, tempo)
