extends CharacterBody2D  #sewerMutant

@export var max_health: int = 1
@export var patrol_speed: float = 90.0     # antes: 65
@export var chase_speed: float = 170.0     # velocidade perseguindo
@export var gravity: float = 900.0
@export var damage_amount: int = 15

@export_group("Spawn")
@export var spawn_delay: float = 12.0       # segundos parado antes de a gravidade começar

@export_group("Agressividade")
@export var detection_range: float = 450.0  # começa a perseguir
@export var lose_range: float = 700.0       # só desiste além disso
@export var attack_range: float = 110.0     # distância para dar o bote
@export var lunge_speed: float = 420.0
@export var lunge_jump: float = -220.0
@export var windup_time: float = 0.12       # "preparo" antes do bote
@export var lunge_time: float = 0.28
@export var attack_cooldown: float = 0.7
@export var hit_cooldown: float = 0.4       # intervalo entre danos no jogador
@export var wall_jump_velocity: float = -380.0
@export var stun_time: float = 0.15         # antes: 0.2

var current_health: int
var direction: int = -1
var is_waiting: bool = true
var is_stunned: bool = false
var is_dead: bool = false
var is_chasing: bool = false
var is_attacking: bool = false
var attack_token: int = 0
var attack_cd_left: float = 0.0
var hit_cd_left: float = 0.0
var base_scale: Vector2 = Vector2(0.48, 0.48)
var player: Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var ledge_detector: RayCast2D = get_node_or_null("LedgeDetector")
@onready var wall_detector: RayCast2D = get_node_or_null("WallDetector")
@onready var hitbox: Area2D = get_node_or_null("HitboxDano")

@onready var mutant_sound = $mutant001

func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	update_facing()

	# Espera antes de a gravidade/IA começarem
	await get_tree().create_timer(spawn_delay).timeout
	is_waiting = false

func _physics_process(delta: float) -> void:
	if is_dead or is_waiting:
		return

	# 1. Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	attack_cd_left = max(attack_cd_left - delta, 0.0)
	hit_cd_left = max(hit_cd_left - delta, 0.0)

	# 2. IA
	if is_stunned:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	elif is_attacking:
		pass # durante o bote, a velocidade é controlada por start_attack()
	else:
		run_ai()
		animate_crawl()

	move_and_slide()

	# 3. Dano de contato contínuo
	check_contact_damage()

func run_ai() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var at_wall = (wall_detector and wall_detector.is_colliding()) or is_on_wall()
	var at_ledge = is_on_floor() and ledge_detector and not ledge_detector.is_colliding()

	# Decide se está perseguindo (com histerese: persegue de longe, desiste só bem longe)
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		is_chasing = dist <= detection_range or (is_chasing and dist <= lose_range)
	else:
		is_chasing = false

	if is_chasing:
		var dx = player.global_position.x - global_position.x
		var dy = player.global_position.y - global_position.y

		# Vira na direção do jogador
		var new_dir = 1 if dx > 0 else -1
		if absf(dx) > 8.0 and new_dir != direction:
			direction = new_dir
			update_facing()

		# Bote quando está perto, na mesma altura e sem cooldown
		if absf(dx) <= attack_range and absf(dy) < 70.0 and attack_cd_left <= 0.0 and is_on_floor():
			start_attack()
			return

		if at_ledge:
			velocity.x = 0.0 # não cai atrás do jogador, espera na borda
		else:
			velocity.x = direction * chase_speed
			# Parede no caminho: pula em vez de desistir
			if at_wall and is_on_floor():
				velocity.y = wall_jump_velocity
	else:
		# Patrulha (como antes, só mais rápida)
		if at_ledge or at_wall:
			direction *= -1
			update_facing()
		velocity.x = direction * patrol_speed

func start_attack() -> void:
	is_attacking = true
	attack_token += 1
	var token = attack_token
	velocity.x = 0.0

	# Preparo: fica avermelhado por um instante
	sprite.modulate = Color(1.6, 0.7, 0.7, 1.0)
	await get_tree().create_timer(windup_time).timeout
	if is_dead or token != attack_token:
		return

	# Bote
	sprite.modulate = Color.WHITE
	velocity = Vector2(direction * lunge_speed, lunge_jump)
	await get_tree().create_timer(lunge_time).timeout
	if is_dead or token != attack_token:
		return

	velocity.x = 0.0
	is_attacking = false
	attack_cd_left = attack_cooldown

func animate_crawl() -> void:
	# Respiração/passo asqueroso, mais frenético quando persegue
	var freq = 0.016 if is_chasing else 0.008
	var crawl_factor = sin(Time.get_ticks_msec() * freq) * 0.06
	sprite.scale.y = base_scale.y + crawl_factor
	var dir_sign = -1.0 if direction > 0 else 1.0
	sprite.scale.x = (base_scale.x - crawl_factor * 0.5) * dir_sign

func update_facing() -> void:
	if sprite:
		sprite.scale.x = -abs(base_scale.x) if direction > 0 else abs(base_scale.x)
	if ledge_detector:
		ledge_detector.position.x = 22 * direction
	if wall_detector:
		wall_detector.target_position.x = 22 * direction

func take_damage(amount: int = 1, knockback_source: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health -= amount
	is_stunned = true
	is_attacking = false   # cancela o bote em andamento
	attack_token += 1
	attack_cd_left = 0.3

	# Aplica Knockback (recuo)
	if knockback_source != Vector2.ZERO:
		var knockback_dir = (global_position - knockback_source).normalized()
		velocity = Vector2(knockback_dir.x * 220.0, -150.0)
	else:
		velocity = Vector2(-direction * 180.0, -120.0)

	# Flash vermelho de impacto
	sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	mutant_sound.play()
	if current_health <= 0:
		die()
	else:
		is_chasing = true  # levou dano: passa a perseguir
		await get_tree().create_timer(stun_time).timeout
		is_stunned = false

func die() -> void:
	is_dead = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	if hitbox:
		hitbox.set_deferred("monitoring", false)

	var death_tween = create_tween().set_parallel(true)
	death_tween.tween_property(sprite, "scale:y", 0.05, 0.2)
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await death_tween.finished
	queue_free()

func check_contact_damage() -> void:
	if not hitbox or is_stunned or hit_cd_left > 0.0:
		return
	for body in hitbox.get_overlapping_bodies():
		if try_damage(body):
			break

func try_damage(body: Node2D) -> bool:
	if is_dead or is_stunned or hit_cd_left > 0.0:
		return false
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage_amount)
		hit_cd_left = hit_cooldown
		return true
	return false

func _on_hitbox_body_entered(body: Node2D) -> void:
	try_damage(body)
