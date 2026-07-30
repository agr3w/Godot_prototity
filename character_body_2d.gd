extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 800.0 
const DASH_DURATION = 0.2 

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var anim = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var dust = $GPUParticles2D 

var is_dashing = false
var facing_direction = 1 

func _physics_process(delta):
    # 1. ESTADO DE DASH (Se estiver no dash, move e sai da função)
    if is_dashing:
        velocity.y = 0 
        velocity.x = facing_direction * DASH_SPEED
        move_and_slide()
        return 

    # 2. GRAVIDADE E PULO
    if not is_on_floor():
        velocity.y += gravity * delta

    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    # 3. MOVIMENTO HORIZONTAL E ESPELHAMENTO
    var direction = Input.get_axis("ui_left", "ui_right")
    
    if direction != 0:
        facing_direction = sign(direction) 
        velocity.x = direction * SPEED
        
        if direction > 0:
            sprite.scale.x = 1
        elif direction < 0:
            sprite.scale.x = -1
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    # 4. GATILHO DO DASH
    if Input.is_action_just_pressed("dash") and not is_dashing:
        start_dash()
        return # Importante: sai da função na hora para a animação do dash não ser sobrescrita!

    # 5. APLICA A FÍSICA NO MUNDO
    move_and_slide()

    # 6. GERENCIADOR DE ANIMAÇÕES (A Mágica blindada contra bugs)
    # Aqui a gente testa qual é o estado atual e obriga a Godot a tocar a animação certa
    if is_on_floor():
        if direction != 0:
            anim.play("run")
            dust.emitting = true
        else:
            anim.play("idle")
            dust.emitting = false
    else:
        dust.emitting = false
        # anim.play("jump") # Descomentaremos isso quando fizer o pulo!

func start_dash():
    is_dashing = true
    anim.play("dash")
    dust.emitting = true # Levantar poeira no dash fica muito dinâmico!
    
    # O script pausa aqui dentro esperando o tempo acabar
    await get_tree().create_timer(DASH_DURATION).timeout 
    
    is_dashing = false