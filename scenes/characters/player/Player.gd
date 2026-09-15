extends CharacterBody2D  #player

# --- CONFIGURAÇÕES DE FÍSICA ---
@export_group("Física de Movimento")
@export var speed: float = 240.0
@export var acceleration: float = 1200.0
@export var friction: float = 1600.0
@export var air_friction: float = 400.0
@export var jump_velocity: float = -460.0
@export var gravity: float = 980.0
@export var fall_gravity_multiplier: float = 1.5

# --- DASH ---
@export_group("Dash & I-Frames")
@export var dash_speed: float = 650.0
@export var dash_duration: float = 0.18
var is_dashing: bool = false
var can_dash: bool = true

# --- COMBATE ---
@export_group("Combate")
@export var attack_duration: float = 0.22
@export var air_attack_duration: float = 0.20
@export var forward_step_speed: float = 130.0
@export var hit_duration: float = 0.35
@export var hitstop_duration: float = 0.06

# --- ASSISTENTES DE PULO ---
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
const COYOTE_TIME_MAX: float = 0.12
const JUMP_BUFFER_MAX: float = 0.10

# --- NÓS ---
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D
@onready var dust: GPUParticles2D = $GPUParticles2D
@onready var run_sound: AudioStreamPlayer = $Run
@onready var jump_sound: AudioStreamPlayer = $Jump
@onready var sword_sound: AudioStreamPlayer = $Atack
@onready var sword_hitbox: CollisionShape2D = get_node_or_null("SwordHitbox/CollisionShape2D")
@onready var ground_hitbox: CollisionShape2D = get_node_or_null("SwordHitbox/GroundCollision")
@onready var air_hitbox: CollisionShape2D = get_node_or_null("SwordHitbox/AirCollision")

const LOOK_AHEAD_AMOUNT: float = 120.0
const CAMERA_SMOOTH_SPEED: float = 4.0

# --- SISTEMA DE VIDA ---
@export_group("Vida")
@export var max_health: int = 100
var current_health: int = 100
@onready var health_bar: TextureProgressBar = get_node_or_null("../CanvasLayer/BarraVida")

# --- ESTADOS ---
var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false
var landing_timer: float = 0.0
var was_on_floor_last_frame: bool = false
var facing_direction: float = 1.0

# --- SCREEN SHAKE ---
var shake_intensity: float = 0.0
var shake_decay: float = 10.0

func _ready() -> void:
	current_health = max_health
	if is_instance_valid(sword_hitbox):
		sword_hitbox.disabled = true
	if is_instance_valid(ground_hitbox):
		ground_hitbox.disabled = true
	if is_instance_valid(air_hitbox):
		air_hitbox.disabled = true
	
	if not health_bar:
		health_bar = get_node_or_null("../CanvasLayer/BarraVida")
		if not health_bar:
			health_bar = get_node_or_null("../../CanvasLayer/BarraVida")
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	var sword_area = get_node_or_null("SwordHitbox")
	if sword_area and not sword_area.body_entered.is_connected(_on_sword_hitbox_body_entered):
		sword_area.body_entered.connect(_on_sword_hitbox_body_entered)
	if sword_area and not sword_area.area_entered.is_connected(_on_sword_hitbox_area_entered):
		sword_area.area_entered.connect(_on_sword_hitbox_area_entered)
	
	was_on_floor_last_frame = is_on_floor()

func _physics_process(delta: float) -> void:
	if is_dead:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		was_on_floor_last_frame = is_on_floor()
		return

	if is_hurt:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		was_on_floor_last_frame = is_on_floor()
		return

	# 1. GRAVIDADE E COYOTE TIME
	if not is_on_floor():
		coyote_timer -= delta
		if velocity.y > 0.0:
			velocity.y += (gravity * fall_gravity_multiplier) * delta
		else:
			if Input.is_action_just_released("ui_accept"):
				velocity.y *= 0.55
			velocity.y += gravity * delta
	else:
		coyote_timer = COYOTE_TIME_MAX
		can_dash = true

	# 2. INPUT DE PULO COM BUFFER
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_MAX
		jump_sound.play()
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and not is_dashing:
		velocity.y = jump_velocity
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		if is_instance_valid(dust):
			dust.emitting = true

	# 3. DASH (Burst reto com I-Frames)
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing and not is_attacking:
		start_dash()
		return

	if is_dashing:
		velocity.y = 0.0
		velocity.x = facing_direction * dash_speed
		move_and_slide()
		was_on_floor_last_frame = is_on_floor()
		return

	# 4. ATAQUE COM FORWARD STEP
	if Input.is_action_just_pressed("attack") and not is_attacking:
		sword_sound.play()
		
		start_attack()
	
		return

	# 5. MOVIMENTAÇÃO HORIZONTAL PRECISA (SEM PISTA DE GELO)
	var direction = Input.get_axis("ui_left", "ui_right")
	var current_friction = friction if is_on_floor() else air_friction

	if direction != 0.0:
		
		facing_direction = signf(direction)
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		
		# Atualiza orientação dos sprites e hitboxes
		if direction > 0.0:
			sprite.scale.x = 1.0
			update_hitbox_facing(1.0)
		elif direction < 0.0:
			sprite.scale.x = -1.0
			update_hitbox_facing(-1.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_friction * delta)


	# 6. EFEITO DA CÂMERA (LOOK AHEAD & SHAKE)
	var target_offset_x = facing_direction * LOOK_AHEAD_AMOUNT
	camera.offset.x = lerp(camera.offset.x, target_offset_x, CAMERA_SMOOTH_SPEED * delta)
	camera.offset.y = lerp(camera.offset.y, -85.0, CAMERA_SMOOTH_SPEED * delta)

	if shake_intensity > 0.0:
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
		camera.offset.x += randf_range(-shake_intensity, shake_intensity)
		camera.offset.y += randf_range(-shake_intensity, shake_intensity)

	move_and_slide()

	# 7. CONTROLE DE ANIMAÇÕES
	if is_on_floor() and not was_on_floor_last_frame:
		landing_timer = 0.08

	if landing_timer > 0.0:
		landing_timer = maxf(landing_timer - delta, 0.0)

	if not is_attacking:
		if is_on_floor():
			if landing_timer > 0.0:
				dust.emitting = false
				if anim.has_animation("jump"):
					anim.play_backwards("jump")
				if is_instance_valid(run_sound) and run_sound.playing:
					run_sound.stop()
			elif direction != 0.0:
				anim.play("run")
				dust.emitting = true
				print("DEBUG: direction=", direction, " run_sound=", run_sound, " playing=", run_sound.playing if is_instance_valid(run_sound) else "N/A")
				if is_instance_valid(run_sound) and not run_sound.playing:
					run_sound.play()
					print("DEBUG: run_sound.play() chamado")
			else:
				anim.play("idle")
				dust.emitting = false
				if is_instance_valid(run_sound) and run_sound.playing:
					run_sound.stop()
		else:
			dust.emitting = false
			if is_instance_valid(run_sound) and run_sound.playing:
				run_sound.stop()
			if velocity.y < 0.0:
				anim.play("jump")
			else:
				anim.play_backwards("jump")
	else:
		if is_instance_valid(run_sound) and run_sound.playing:
			run_sound.stop()

	was_on_floor_last_frame = is_on_floor()

func update_hitbox_facing(dir_sign: float) -> void:
	if is_instance_valid(sword_hitbox):
		sword_hitbox.position.x = abs(sword_hitbox.position.x) * dir_sign
	if ground_hitbox:
		ground_hitbox.position.x = abs(ground_hitbox.position.x) * dir_sign
	if air_hitbox:
		air_hitbox.position.x = abs(air_hitbox.position.x) * dir_sign

func start_dash() -> void:
	is_dashing = true
	can_dash = false
	anim.play("dash")
	if is_instance_valid(dust):
		dust.emitting = true
	if is_instance_valid(run_sound) and run_sound.playing:
		run_sound.stop()
	
	# I-Frames: Desativa colisão com inimigos (Layer 2)
	set_collision_mask_value(2, false)
	
	await get_tree().create_timer(dash_duration).timeout
	
	set_collision_mask_value(2, true)
	is_dashing = false

func start_attack() -> void:
	is_attacking = true
	var is_air = not is_on_floor()
	var active_hitbox = get_attack_hitbox(is_air)
	
	if is_instance_valid(run_sound) and run_sound.playing:
		run_sound.stop()
	
	# Forward Step: Pequeno avanço para frente ao golpear
	if not is_air:
		velocity.x = facing_direction * forward_step_speed
	
	var anim_name = "air_attack" if is_air else "attack"
	var duration = air_attack_duration if is_air else attack_duration

	if is_air:
		velocity.y = 0.0
		if anim.current_animation == "jump":
			anim.stop()

	anim.play(anim_name if anim.has_animation(anim_name) else "attack")
	
	if is_instance_valid(active_hitbox):
		active_hitbox.disabled = false

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

func _on_sword_hitbox_body_entered(body: Node) -> void:
	if body == self:
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(1, global_position)
		apply_hitstop(hitstop_duration)
		add_camera_shake(4.0, 12.0)

func _on_sword_hitbox_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	if enemy and enemy != self and enemy.is_in_group("enemy") and enemy.has_method("take_damage"):
		enemy.take_damage(1, global_position)
		apply_hitstop(hitstop_duration)
		add_camera_shake(4.0, 12.0)

func apply_hitstop(duration: float = 0.06) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func take_damage(amount: int = 10) -> void:
	if is_dead or is_hurt or is_dashing:
		return

	is_attacking = false
	if is_instance_valid(sword_hitbox):
		sword_hitbox.set_deferred("disabled", true)
	if is_instance_valid(ground_hitbox):
		ground_hitbox.set_deferred("disabled", true)
	if is_instance_valid(air_hitbox):
		air_hitbox.set_deferred("disabled", true)

	current_health -= amount
	if health_bar:
		health_bar.value = current_health
	
	add_camera_shake(8.0, 8.0)

	if is_instance_valid(run_sound) and run_sound.playing:
		run_sound.stop()

	if current_health <= 0:
		die()
	else:
		is_hurt = true
		anim.play("hit")

		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

		await get_tree().create_timer(hit_duration - 0.1).timeout
		is_hurt = false

func die() -> void:
	is_dead = true
	if is_instance_valid(dust):
		dust.emitting = false
	if is_instance_valid(run_sound) and run_sound.playing:
		run_sound.stop()
	anim.play("death")
	await anim.animation_finished
	get_tree().reload_current_scene()

func add_camera_shake(intensity: float = 6.0, decay: float = 10.0) -> void:
	shake_intensity = max(shake_intensity, intensity)
	shake_decay = decay

func play_fall_animation() -> void:
	if is_instance_valid(dust):
		dust.emitting = false
	if anim.has_animation("jump"):
		anim.play("jump")
