extends AnimatableBody2D

@export var subida: float = 700.0
@export var distancia_x: float = 2500.0
@export var velocidade: float = 200.0
@export var infinito: bool = false        # true = depois de subir, anda para a direita sem parar
@export var tempo_para_sumir: float = 15.0   # segundos depois de ativada até desaparecer (0 = nunca some)

var ativada: bool = false
var tween: Tween

func _ready() -> void:
	set_physics_process(false)   # fica parada até o gatilho ativar

func ativar() -> void:
	if ativada:
		return
	ativada = true

	var inicio := position

	tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "position:y", inicio.y - subida, subida / velocidade)  # 1º: sobe

	if infinito:
		tween.tween_callback(set_physics_process.bind(true))   # 2º: segue para a direita sem parar
	else:
		tween.tween_property(self, "position:x", inicio.x + distancia_x, distancia_x / velocidade)  # 2º: vai para a direita

	# Depois de X segundos some e perde a colisão
	if tempo_para_sumir > 0.0:
		await get_tree().create_timer(tempo_para_sumir).timeout
		sumir()

func sumir() -> void:
	# para de se mover
	if tween:
		tween.kill()
	set_physics_process(false)

	# esconde a plataforma (e tudo que é filho dela)
	hide()

	# remove as colisões para o personagem não se esconder nela
	collision_layer = 0
	collision_mask = 0
	for forma in find_children("*", "CollisionShape2D", true, false):
		forma.set_deferred("disabled", true)
	for forma in find_children("*", "CollisionPolygon2D", true, false):
		forma.set_deferred("disabled", true)

func _physics_process(delta: float) -> void:
	position.x += velocidade * delta
