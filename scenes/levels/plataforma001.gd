extends AnimatableBody2D

@export var distancia_x: float = 2500.0
@export var distancia_y: float = 400.0
@export var velocidade: float = 100.0

func _ready() -> void:
	var inicio := position
	var tempo_x := distancia_x / velocidade
	var tempo_y := distancia_y / velocidade

	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:x", inicio.x + distancia_x, tempo_x)  # vai 700 pra frente
	tween.tween_property(self, "position:y", inicio.y + distancia_y, tempo_y)  # desce 100
	tween.tween_property(self, "position:x", inicio.x, tempo_x)                # volta 700
	tween.tween_property(self, "position:y", inicio.y, tempo_y)                # sobe 100
