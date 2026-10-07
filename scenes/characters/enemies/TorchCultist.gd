extends CharacterBody2D

@export var max_health: int = 4
@export var speed: float = 55.0
@export var gravity: float = 900.0
@export var damage_amount: int = 20

@export_group("Empurrão")
@export var push_force: float = 450.0      # força horizontal do empurrão
@export var push_up: float = -180.0        # pulinho que tira o jogador do chão
@export var hit_cooldown: float = 0.8      # intervalo entre empurrões/danos

@export_group("Perseguição")
@export var chase_enabled: bool = true
@export var detection_range: float = 350.0
@export var lose_range: float = 550.0
@export var chase_speed: float = 95.0

var current_health: int
var direction: int = -1
var is_stunned: bool = false
var is_dead: bool = false
var is_chasing: bool = false
var hit_cd_left: float = 0.0
var base_scale_x: float = 0.55
var player: Node2D

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

	hit_cd_left = max(hit_cd_left - delta, 0.0)

	# 2. Movimentação & IA
	if not is_stunned:
		run_ai()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	# 3. Tremulação realista da chama da tocha
	if torch_light and not is_dead:
		torch_light.energy = 1.3 + sin(Time.get_ticks_msec() * 0.015) * 0.2 + randf_range(-0.08, 0.08)

	move_and_slide()

	# 4. Empurrão/dano contínuo enquanto o jogador estiver encostado
	check_contact_push()

func run_ai() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var at_ledge = is_on_floor() and ledge_detector and not ledge_detector.is_colliding()
	var at_wall = (wall_detector and wall_detector.is_colliding()) or is_on_wall()

	# Decide se persegue (persegue de perto, só desiste bem longe)
	if chase_enabled and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		is_chasing = dist <= detection_range or (is_chasing and dist <= lose_range)
	else:
		is_chasing = false

	if is_chasing:
		var dx = player.global_position.x - global_position.x
		var new_dir = 1 if dx > 0 else -1
		if absf(dx) > 8.0 and new_dir != direction:
			direction = new_dir
			update_facing()

		if at_ledge:
			velocity.x = 0.0  # não cai atrás do jogador
		else:
			velocity.x = direction * chase_speed
	else:
		# Patrulha normal
		if at_ledge or at_wall:
			direction *= -1
			update_facing()
		velocity.x = direction * speed

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
		is_chasing = true  # levou dano: passa a perseguir
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

func check_contact_push() -> void:
	if not hitbox or is_stunned or hit_cd_left > 0.0:
		return
	for body in hitbox.get_overlapping_bodies():
		if try_hit_player(body):
			break

func try_hit_player(body: Node2D) -> bool:
	if is_dead or is_stunned or hit_cd_left > 0.0:
		return false
	if not body.is_in_group("player"):
		return false

	if body.has_method("take_damage"):
		body.take_damage(damage_amount)
	push_player(body)
	hit_cd_left = hit_cooldown
	return true

func push_player(body: Node2D) -> void:
	# Empurra para longe do inimigo (na direção em que ele está avançando)
	var dir = signf(body.global_position.x - global_position.x)
	if dir == 0.0:
		dir = float(direction)
	var impulse = Vector2(dir * push_force, push_up)

	if body.has_method("apply_knockback"):
		body.apply_knockback(impulse)
	elif "velocity" in body:
		body.velocity = impulse

func _on_hitbox_body_entered(body: Node2D) -> void:
	try_hit_player(body)
