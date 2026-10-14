extends AnimatableBody2D

@export var subida: float = 700.0
@export var distancia_x: float = 2500.0
@export var velocidade: float = 200.0
@export var infinito: bool = false   # true = depois de subir, anda para a direita sem parar

var ativada: bool = false

func _ready() -> void:
	set_physics_process(false)   # fica parada até o gatilho ativar

func ativar() -> void:
	if ativada:
		return
	ativada = true

	var inicio := position

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", inicio.y - subida, subida / velocidade)  # 1º: sobe

	if infinito:
		tween.tween_callback(set_physics_process.bind(true))   # 2º: segue para a direita sem parar
	else:
		tween.tween_property(self, "position:x", inicio.x + distancia_x, distancia_x / velocidade)  # 2º: vai para a direita

func _physics_process(delta: float) -> void:
	position.x += velocidade * delta
