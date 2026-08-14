extends CharacterBody2D

var health = 3
var speed = 70.0
var direction = -1
var time_passed = 0.0

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("enemy")

func _physics_process(delta):
	time_passed += delta

	# Movimento horizontal de patrulha
	velocity.x = direction * speed

	# Efeito de flutuação suave para cima e para baixo
	velocity.y = sin(time_passed * 4.0) * 20.0
	
	# Espelhamento do sprite
	if direction > 0:
		sprite.scale.x = abs(sprite.scale.x)
	elif direction < 0:
		sprite.scale.x = -abs(sprite.scale.x)

	move_and_slide()
	
	# Inverte ao tocar em paredes
	if is_on_wall():
		direction *= -1
		

func take_damage(amount: int = 1):
	health -= amount
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if health <= 0:
		queue_free()

func _on_hitbox_dano_body_entered(body: Node2D) -> void:
	# Pergunta se o corpo tem a etiqueta "player" e se tem a função de tomar dano
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(20) # Causa 20 de dano no player!
