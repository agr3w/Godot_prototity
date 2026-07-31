extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 800.0 
const DASH_DURATION = 0.2 
const ATTACK_DURATION = 0.4 # Tempo que a animação de ataque dura!

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var anim = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var dust = $GPUParticles2D 
# Referência da hitbox que acabamos de criar
@onready var sword_hitbox = $SwordHitbox/CollisionShape2D

var is_dashing = false
var is_attacking = false # Novo estado!
var facing_direction = 1 

func _ready():
	# Desliga a hitbox assim que o jogo começa
	sword_hitbox.disabled = true
	# Garante conexão do sinal mesmo sem bind no editor
	if not $SwordHitbox.body_entered.is_connected(_on_sword_hitbox_body_entered):
		$SwordHitbox.body_entered.connect(_on_sword_hitbox_body_entered)

func _physics_process(delta):
	if is_dashing:
		velocity.y = 0 
		velocity.x = facing_direction * DASH_SPEED
		move_and_slide()
		return 

	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		facing_direction = sign(direction) 
		velocity.x = direction * SPEED
		
		# Espelhamento. Como a Hitbox é filha do CharacterBody, 
		# teríamos que virar ela também. Para facilitar, vamos virar apenas a posição X dela!
		if direction > 0:
			sprite.scale.x = 1
			sword_hitbox.position.x = abs(sword_hitbox.position.x) # Fica na direita
		elif direction < 0:
			sprite.scale.x = -1
			sword_hitbox.position.x = -abs(sword_hitbox.position.x) # Fica na esquerda
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Gatilhos
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking:
		start_dash()
		return 
		
	if Input.is_action_just_pressed("attack") and is_on_floor() and not is_attacking:
		start_attack()

	move_and_slide()

	# Gerenciador de Animações
	if not is_attacking:
		if is_on_floor():
			if direction != 0:
				anim.play("run")
				dust.emitting = true
			else:
				anim.play("idle")
				dust.emitting = false
		else:
			dust.emitting = false

func start_dash():
	is_dashing = true
	anim.play("dash")
	dust.emitting = true 
	await get_tree().create_timer(DASH_DURATION).timeout 
	is_dashing = false

# --- FUNÇÃO DE ATAQUE ---
func start_attack():
	is_attacking = true
	anim.play("attack") # Você precisa criar essa animação lá no AnimationPlayer!
	
	# Liga a hitbox para dar dano
	sword_hitbox.disabled = false 
	
	await get_tree().create_timer(ATTACK_DURATION).timeout 
	
	# Desliga a hitbox quando o ataque acaba
	sword_hitbox.disabled = true
	is_attacking = false


func _on_sword_hitbox_body_entered(body: Node):
	# Checa se em quem batemos tem a função "take_damage" (ou seja, é um inimigo)
	if body.has_method("take_damage"):
		body.take_damage()
