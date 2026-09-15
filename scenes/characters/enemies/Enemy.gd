extends CharacterBody2D

@export var max_health: int = 3
@export var speed: float = 65.0
@export var damage_amount: int = 20

var health: int = 3
var direction: int = -1
var is_stunned: bool = false
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
# Removida a tipagem rígida (aceita AudioStreamPlayer ou AudioStreamPlayer2D)
@onready var dead_sound = $Terrain if has_node("Terrain") else null

# ============================================================
# INÍCIO
# ============================================================

func _ready() -> void:
	add_to_group("enemy")
	health = max_health

# ============================================================
# MOVIMENTO
# ============================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_stunned:
		# Movimento do inimigo
		velocity.x = direction * speed

		# Espelhamento do sprite
		if direction < 0:
			sprite.scale.x = abs(sprite.scale.x)
		elif direction > 0:
			sprite.scale.x = -abs(sprite.scale.x)

		# Inverte quando bate na parede
		if is_on_wall():
			direction *= -1
	else:
		# Para o inimigo enquanto está atordoado
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	move_and_slide()

# ============================================================
# RECEBER DANO
# ============================================================

func take_damage(amount: int = 1, knockback_source: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	health -= amount
	is_stunned = true

	# VERIFICA SE MORREU
	if health <= 0:
		die()
		return

	# KNOCKBACK
	if knockback_source != Vector2.ZERO:
		var knockback_dir = (global_position - knockback_source).normalized()
		velocity = Vector2(knockback_dir.x * 200.0, -120.0)

	# EFEITO VISUAL DE DANO
	modulate = Color(2.0, 0.3, 0.3, 1.0)
	await get_tree().create_timer(0.15).timeout
	modulate = Color.WHITE
	is_stunned = false
	dead_sound.play()
# ============================================================
# MORTE
# ============================================================

func die() -> void:
	is_dead = true

	# TOCA O SOM SEM TRAVAR O JOGO
	if is_instance_valid(dead_sound) and dead_sound.stream:
		var audio_length = dead_sound.stream.get_length()
		
		# Move o som para a cena principal antes de deletar o inimigo
		dead_sound.reparent(get_tree().current_scene)
		dead_sound.play()
		
		# Agenda a destruição do nó de som após a execução do áudio
		get_tree().create_timer(audio_length).timeout.connect(dead_sound.queue_free)

	# REMOVE O INIMIGO DA TELA E MEMÓRIA
	queue_free()

# ============================================================
# HITBOX DO INIMIGO
# ============================================================

func _on_hitbox_dano_body_entered(body: Node2D) -> void:
	if is_stunned or is_dead or not body:
		return

	# Verifica se o corpo é o jogador
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage_amount)
