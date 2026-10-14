extends CharacterBody2D

@export var max_health: int = 4
@export var patrol_speed: float = 100.0
@export var chase_speed: float = 190.0
@export var gravity: float = 900.0
@export var damage_amount: int = 15

@export_group("Agressividade")
@export var detection_range: float = 500.0   # começa a perseguir
@export var lose_range: float = 800.0        # só desiste além disso
@export var attack_range: float = 120.0      # distância para dar o bote
@export var lunge_speed: float = 450.0
@export var lunge_jump: float = -220.0
@export var windup_time: float = 0.12        # preparo antes do bote
@export var lunge_time: float = 0.28
@export var attack_cooldown: float = 0.6
@export var hit_cooldown: float = 0.4        # intervalo entre danos no player
@export var wall_jump_velocity: float = -380.0
@export var stun_time: float = 0.15

@export_group("Animações")
@export var sprite_olha_para_direita: bool = true   # false se o desenho original olha para a esquerda
@export var anim_idle: String = "idle"
@export var anim_move: String = "run"
@export var anim_attack: String = "attack"
@export var anim_hurt: String = "hurt"
@export var anim_death: String = "death"

var current_health: int
var direction: int = -1
var is_stunned: bool = false
var is_dead: bool = false
var is_chasing: bool = false
var is_attacking: bool = false
var attack_token: int = 0
var attack_cd_left: float = 0.0
var hit_cd_left: float = 0.0
var player: Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
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

	attack_cd_left = max(attack_cd_left - delta, 0.0)
	hit_cd_left = max(hit_cd_left - delta, 0.0)

	# 2. IA
	if is_stunned:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	elif is_attacking:
		pass  # a velocidade é controlada por start_attack()
	else:
		run_ai()

	move_and_slide()
	check_contact_damage()

func run_ai() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var at_wall = (wall_detector and wall_detector.is_colliding()) or is_on_wall()
	var at_ledge = is_on_floor() and ledge_detector and not ledge_detector.is_colliding()

	# Persegue de longe, só desiste bem longe (histerese)
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		is_chasing = dist <= detection_range or (is_chasing and dist <= lose_range)
	else:
		is_chasing = false

	if is_chasing:
		var dx = player.global_position.x - global_position.x
		var dy = player.global_position.y - global_position.y

		var new_dir = 1 if dx > 0 else -1
		if absf(dx) > 8.0 and new_dir != direction:
			direction = new_dir
			update_facing()

		# Bote quando está perto, na mesma altura e sem cooldown
		if absf(dx) <= attack_range and absf(dy) < 80.0 and attack_cd_left <= 0.0 and is_on_floor():
			start_attack()
			return

		if at_ledge:
			velocity.x = 0.0
			play_anim(anim_idle)
		else:
			velocity.x = direction * chase_speed
			play_anim(anim_move)
			if at_wall and is_on_floor():
				velocity.y = wall_jump_velocity
	else:
		# Patrulha
		if at_ledge or at_wall:
			direction *= -1
			update_facing()
		velocity.x = direction * patrol_speed
		play_anim(anim_move)

func start_attack() -> void:
	is_attacking = true
	attack_token += 1
	var token = attack_token
	velocity.x = 0.0

	# Preparo
	play_anim(anim_attack, true)
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

func play_anim(anim_name: String, restart: bool = false) -> void:
	if not sprite.sprite_frames or not sprite.sprite_frames.has_animation(anim_name):
		return
	if restart or sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)

func update_facing() -> void:
	if sprite:
		sprite.flip_h = (direction < 0) if sprite_olha_para_direita else (direction > 0)
	if ledge_detector:
		ledge_detector.position.x = absf(ledge_detector.position.x) * direction
	if wall_detector:
		wall_detector.target_position.x = absf(wall_detector.target_position.x) * direction

func take_damage(amount: int = 1, knockback_source: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health -= amount
	is_stunned = true
	is_attacking = false   # cancela o bote
	attack_token += 1
	attack_cd_left = 0.3

	if knockback_source != Vector2.ZERO:
		var knockback_dir = (global_position - knockback_source).normalized()
		velocity = Vector2(knockback_dir.x * 220.0, -150.0)
	else:
		velocity = Vector2(-direction * 180.0, -120.0)

	sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if current_health <= 0:
		die()
	else:
		is_chasing = true  # levou dano: passa a perseguir
		play_anim(anim_hurt, true)
		await get_tree().create_timer(stun_time).timeout
		is_stunned = false

func die() -> void:
	is_dead = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	if hitbox:
		hitbox.set_deferred("monitoring", false)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_death):
		sprite.play(anim_death)
		if not sprite.sprite_frames.get_animation_loop(anim_death):
			await sprite.animation_finished

	var fade = create_tween()
	fade.tween_property(sprite, "modulate:a", 0.0, 0.3)
	await fade.finished
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
