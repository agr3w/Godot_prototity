extends AnimatedSprite2D

@export var distancia: float = 400.0   # pixels para a direita
@export var duracao: float = 4.0       # segundos para percorrer a distância


func _ready() -> void:
	# Se o AnimatedSprite2D tiver animação (rodas girando), ela toca enquanto anda
	if sprite_frames and sprite_frames.has_animation("default"):
		play("default")

	var tween := create_tween()
	tween.tween_property(self, "position:x", position.x + distancia, duracao)
	tween.finished.connect(_on_chegou)


func _on_chegou() -> void:
	# Para a animação quando o caminhão termina de andar
	stop()
