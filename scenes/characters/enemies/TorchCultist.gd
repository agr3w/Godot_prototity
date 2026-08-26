extends CharacterBody2D

@export var max_health: int = 4
@export var speed: float = 55.0
@export var gravity: float = 900.0
@export var damage_amount: int = 20

var current_health: int
var direction: int = -1
var is_stunned: bool = false
var is_dead: bool = false
var base_scale_x: float = 0.55

@onready var sprite: Sprite2D = $Sprite2D
@onready var torch_light: PointLight2D = get_node_or_null("TorchLight")
@onready var torch_sparks: GPUParticles2D = get_node_or_null("TorchSparks")
@onready var ledge_detector: RayCast2D = get_node_or_null("LedgeDetector")
@onready var wall_detector: RayCast2D = get_node_or_null("WallDetector")
@onready var hitbox: Area2D = get_node_or_null("HitboxDano")

func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	update_facing()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 1. Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. Movimentação & IA
	if not is_stunned:
		var at_ledge = is_on_floor() and ledge_detector and not ledge_detector.is_colliding()
		var at_wall = (wall_detector and wall_detector.is_colliding()) or is_on_wall()

		if at_ledge or at_wall:
			direction *= -1
			update_facing()

		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	# 3. Tremulação realista da chama da tocha
	if torch_light and not is_dead:
		torch_light.energy = 1.3 + sin(Time.get_ticks_msec() * 0.015) * 0.2 + randf_range(-0.08, 0.08)

	move_and_slide()

func update_facing() -> void:
	if sprite:
		sprite.scale.x = -abs(base_scale_x) if direction > 0 else abs(base_scale_x)
	if torch_light:
		torch_light.position.x = 14.0 if direction > 0 else -14.0
	if torch_sparks:
		torch_sparks.position.x = 14.0 if direction > 0 else -14.0
	if ledge_detector:
		ledge_detector.position.x = 18.0 * direction
	if wall_detector:
		wall_detector.target_position.x = 18.0 * direction

func take_damage(amount: int = 1, knockback_source: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health -= amount
	is_stunned = true
	
	# Aplica Knockback (recuo)
	if knockback_source != Vector2.ZERO:
		var knockback_dir = (global_position - knockback_source).normalized()
		velocity = Vector2(knockback_dir.x * 220.0, -150.0)
	else:
		velocity = Vector2(-direction * 180.0, -120.0)
	
	# Flash visual de impacto
	sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	if current_health <= 0:
		die()
	else:
		await get_tree().create_timer(0.2).timeout
		is_stunned = false

func die() -> void:
	is_dead = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	
	var death_tween = create_tween().set_parallel(true)
	if torch_light:
		death_tween.tween_property(torch_light, "energy", 0.0, 0.3)
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	death_tween.tween_property(sprite, "scale:y", 0.1, 0.35)
	await death_tween.finished
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead or is_stunned:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage_amount)
