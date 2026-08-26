extends CharacterBody2D

@export var max_health: int = 4
@export var speed: float = 55.0
@export var damage_amount: int = 20

var current_health: int
var direction: float = -1.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_dead: bool = false
var base_scale_x: float = 0.55

@onready var sprite: Sprite2D = $Sprite2D
@onready var torch_light: PointLight2D = get_node_or_null("TorchLight")
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

	# 2. Movimento de patrulha
	velocity.x = direction * speed

	# 3. Espelhamento do sentinela
	if direction > 0:
		sprite.scale.x = -abs(base_scale_x)
		if torch_light:
			torch_light.position.x = 14.0
	else:
		sprite.scale.x = abs(base_scale_x)
		if torch_light:
			torch_light.position.x = -14.0

	# 4. Tremulação realista da chama da tocha
	if torch_light:
		torch_light.energy = 1.3 + sin(Time.get_ticks_msec() * 0.015) * 0.2 + randf_range(-0.08, 0.08)

	# 5. Detector de borda da plataforma
	if floor_detector and is_on_floor():
		floor_detector.position.x = direction * 20.0
		if not floor_detector.is_colliding():
			direction *= -1.0

	move_and_slide()

	# 6. Inverte ao colidir em paredes
	if is_on_wall():
		direction *= -1.0

func take_damage(amount: int = 1) -> void:
	if is_dead:
		return

	current_health -= amount
	
	# Feedback visual de dano
	sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
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
	
	# Apaga a tocha e faz fade out do cultista
	var death_tween = create_tween().set_parallel(true)
	if torch_light:
		death_tween.tween_property(torch_light, "energy", 0.0, 0.3)
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	death_tween.tween_property(sprite, "scale:y", 0.1, 0.35)
	await death_tween.finished
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage_amount)
