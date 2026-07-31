extends CharacterBody2D

const SPEED = 350.0
const JUMP_VELOCITY = -500.0
const FALL_GRAVITY_MULTIPLIER = 1.6
const DASH_SPEED = 1000.0
const DASH_DURATION = 0.15
const ATTACK_DURATION = 0.3
const AIR_ATTACK_DURATION = 0.25
const HIT_DURATION = 0.4 # Tempo que ele fica atordoado ao tomar dano

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var anim = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var dust = $GPUParticles2D 
@onready var sword_hitbox = get_node_or_null("SwordHitbox/CollisionShape2D")
@onready var ground_hitbox = get_node_or_null("SwordHitbox/GroundCollision")
@onready var air_hitbox = get_node_or_null("SwordHitbox/AirCollision")

# --- SISTEMA DE VIDA ---
var max_health = 100
var current_health = max_health
@onready var health_bar = $"../CanvasLayer/ProgressBar"

# --- ESTADOS DO JOGADOR ---
var is_dashing = false
var is_attacking = false
var is_hurt = false
var is_dead = false
var facing_direction = 1 

func _ready():
	if is_instance_valid(sword_hitbox):
		sword_hitbox.disabled = true
	if is_instance_valid(ground_hitbox):
		ground_hitbox.disabled = true
	if is_instance_valid(air_hitbox):
		air_hitbox.disabled = true
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if not $SwordHitbox.body_entered.is_connected(_on_sword_hitbox_body_entered):
		$SwordHitbox.body_entered.connect(_on_sword_hitbox_body_entered)

func _physics_process(delta):
	if is_dead:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	if is_hurt:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	if is_dashing:
		velocity.y = 0 
		velocity.x = facing_direction * DASH_SPEED
		move_and_slide()
		return 

	if is_attacking and is_on_floor():
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y += gravity * delta
		move_and_slide()
		return

	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += (gravity * FALL_GRAVITY_MULTIPLIER) * delta
		else:
			if Input.is_action_just_released("ui_accept"):
				velocity.y *= 0.5
			velocity.y += gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		dust.emitting = true

	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		facing_direction = sign(direction) 
		var current_speed = SPEED if is_on_floor() else SPEED * 0.8
		velocity.x = direction * current_speed
		
		if direction > 0:
			sprite.scale.x = 1
			if is_instance_valid(sword_hitbox):
				sword_hitbox.position.x = abs(sword_hitbox.position.x)
			if ground_hitbox:
				ground_hitbox.position.x = abs(ground_hitbox.position.x)
			if air_hitbox:
				air_hitbox.position.x = abs(air_hitbox.position.x)
		elif direction < 0:
			sprite.scale.x = -1
			if is_instance_valid(sword_hitbox):
				sword_hitbox.position.x = -abs(sword_hitbox.position.x)
			if ground_hitbox:
				ground_hitbox.position.x = -abs(ground_hitbox.position.x)
			if air_hitbox:
				air_hitbox.position.x = -abs(air_hitbox.position.x)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking:
		start_dash()
		return 
		
	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack()
		return

	move_and_slide()

	if not is_attacking:
		if is_on_floor():
			if direction != 0:
				anim.play("run")
				dust.emitting = true
			else:
				anim.play("idle")
				dust.emitting = false
		elif anim.has_animation("jump"):
			dust.emitting = false
			if velocity.y < 0:
				if anim.current_animation != "jump" or not anim.is_playing():
					anim.play("jump")
			elif anim.current_animation != "jump" or anim.current_animation_position <= 0.0:
				anim.play_backwards("jump")
		else:
			dust.emitting = false

func start_dash():
	is_dashing = true
	anim.play("dash")
	dust.emitting = true 
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false

func start_attack():
	is_attacking = true
	var active_hitbox = get_attack_hitbox(is_on_floor())
	if not is_instance_valid(active_hitbox):
		is_attacking = false
		return

	var anim_name = "attack"
	var duration = ATTACK_DURATION

	if not is_on_floor():
		anim_name = "air_attack"
		duration = AIR_ATTACK_DURATION
		if anim.current_animation == "jump":
			anim.stop()

	anim.play(anim_name if anim.has_animation(anim_name) else "attack")
	active_hitbox.disabled = false

	if anim_name == "air_attack":
		velocity.y = 0

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(active_hitbox):
		active_hitbox.disabled = true
	is_attacking = false

func get_attack_hitbox(is_air_attack: bool) -> CollisionShape2D:
	if is_air_attack:
		if is_instance_valid(air_hitbox):
			return air_hitbox
		if is_instance_valid(ground_hitbox):
			return ground_hitbox
		return sword_hitbox

	if is_instance_valid(ground_hitbox):
		return ground_hitbox
	return sword_hitbox

func _on_sword_hitbox_body_entered(body: Node):
	if body == self:
		return

	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(1)

func take_damage(amount: int = 10):
	if is_dead or is_hurt:
		return

	is_attacking = false
	is_dashing = false
	if is_instance_valid(sword_hitbox):
		sword_hitbox.disabled = true
	if is_instance_valid(ground_hitbox):
		ground_hitbox.disabled = true
	if is_instance_valid(air_hitbox):
		air_hitbox.disabled = true

	current_health -= amount
	if health_bar:
		health_bar.value = current_health
	
	if current_health <= 0:
		die()
	else:
		is_hurt = true
		anim.play("hit")

		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

		await get_tree().create_timer(HIT_DURATION - 0.1).timeout
		is_hurt = false

func die():
	is_dead = true
	dust.emitting = false
	anim.play("death")
	await anim.animation_finished
	get_tree().reload_current_scene()
