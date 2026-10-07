extends AnimatableBody2D

@export var distancia: float = 450.0
@export var velocidade: float = 90.0

func _ready() -> void:
	print("pilar_novo rodando")
	var y0 := position.y
	var tempo := distancia / velocidade
	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", y0 + distancia, tempo)
	tween.tween_property(self, "position:y", y0 - distancia, tempo * 2.0)
	tween.tween_property(self, "position:y", y0, tempo)
