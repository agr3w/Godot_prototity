extends Area2D
# Anexe este script em um Area2D que tenha um CollisionShape2D como filho.
# Funciona com o seu player atual: usa take_damage(), is_hurt, is_dashing, is_dead e velocity.

@export_group("Dano")
@export var dano: int = 20

@export_group("Repulsão")
@export var repulsao_horizontal: float = 420.0
@export var repulsao_vertical: float = -260.0   # negativo = joga o player para cima

@export_group("Movimento")
@export var distancia: float = 200.0   # pixels para a direita
@export var duracao: float = 3.0       # segundos para percorrer a distância


func _ready() -> void:
	# Garante que a área detecta corpos
	monitoring = true

	# Move a parede 200px para a direita, igual ao caminhão
	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + distancia, duracao)


func _physics_process(_delta: float) -> void:
	# Checa todo frame quem está encostando: se o player continuar na parede
	# depois que o estado "hurt" acabar, ele leva dano de novo.
	for body in get_overlapping_bodies():
		_tentar_ferir(body)


func _tentar_ferir(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Respeita os i-frames do dash, o estado de dor e a morte
	if body.is_dead or body.is_hurt or body.is_dashing:
		return

	body.take_damage(dano)

	# Direção horizontal: do centro da parede para o player
	var lado: float = signf(body.global_position.x - global_position.x)
	if lado == 0.0:
		lado = -body.facing_direction

	body.velocity.x = lado * repulsao_horizontal
	body.velocity.y = repulsao_vertical
