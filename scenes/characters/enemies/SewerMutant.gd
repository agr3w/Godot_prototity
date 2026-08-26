extends CharacterBody2D

@export var max_health: int = 3
@export var speed: float = 65.0
@export var damage_amount: int = 15

var current_health: int
var direction: float = -1.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var base_scale: Vector2 = Vector2(0.48, 0.48)
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var floor_detector: RayCast2D = get_node_or_null("FloorDetector")
@onready var hitbox: Area2D = get_node_or_null("HitboxDano")

func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 1. Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	# 2. Movimento de rastejamento
	velocity.x = direction * speed

	# 3. Animação de deformação/respiração asquerosa (Squash & Stretch)
	var crawl_factor = sin(Time.get_ticks_msec() * 0.008) * 0.06
	sprite.scale.y = base_scale.y + crawl_factor
	var dir_sign = -1.0 if direction > 0 else 1.0
	sprite.scale.x = (base_scale.x - crawl_factor * 0.5) * dir_sign

	# 4. Detector de abismo / borda da plataforma
	if floor_detector and is_on_floor():
		floor_detector.position.x = direction * 24.0
		if not floor_detector.is_colliding():
			direction *= -1.0

	move_and_slide()

	# 5. Inverte direção ao bater em paredes
	if is_on_wall():
		direction *= -1.0

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return

	current_health -= amount
	
	# Feedback visual de impacto
	sprite.modulate = Color(1.5, 0.2, 0.2, 1.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	if current_health <= 0:
		die()

func die() -> void:
	is_dead = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	
	# Efeito de esmagamento ao morrer
	var death_tween = create_tween()
	death_tween.tween_property(sprite, "scale:y", 0.05, 0.2)
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await death_tween.finished
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage_amount)
