extends CharacterBody2D

@export var max_health: int = 3
@export var speed: float = 65.0
@export var damage_amount: int = 20

var health: int = 3
var direction: int = -1
var is_stunned: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("enemy")
	health = max_health

func _physics_process(delta: float) -> void:
	if not is_stunned:
		velocity.x = direction * speed
		
		# Espelhamento do sprite
		if direction < 0:
			sprite.scale.x = abs(sprite.scale.x)
		elif direction > 0:
			sprite.scale.x = -abs(sprite.scale.x)

		# Inverte ao tocar em paredes
		if is_on_wall():
			direction *= -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	move_and_slide()

func take_damage(amount: int = 1, knockback_source: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	is_stunned = true
	
	if knockback_source != Vector2.ZERO:
		var knockback_dir = (global_position - knockback_source).normalized()
		velocity = Vector2(knockback_dir.x * 200.0, -120.0)
	
	modulate = Color(2.0, 0.3, 0.3, 1.0)
	await get_tree().create_timer(0.15).timeout
	modulate = Color.WHITE
	is_stunned = false
	
	if health <= 0:
		queue_free()

func _on_hitbox_dano_body_entered(body: Node2D) -> void:
	if is_stunned:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage_amount)
