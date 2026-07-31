extends CharacterBody2D

var health = 3
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- NOVAS VARIÁVEIS DE PATRULHA ---
var speed = 100.0 # Velocidade do inimigo
var direction = -1 # Começa andando para a esquerda (-1)

@onready var sprite = $Sprite2D

func _physics_process(delta):
    # Gravidade
    if not is_on_floor():
        velocity.y += gravity * delta

    # --- LÓGICA DE PATRULHA ---
    
    # 1. Aplica a velocidade baseada na direção atual
    velocity.x = direction * speed
    
    # 2. Vira a imagem do sprite RESPEITANDO o seu tamanho original
    if direction > 0:
        sprite.scale.x = abs(sprite.scale.x) # Mantém o tamanho, força a ficar positivo
    elif direction < 0:
        sprite.scale.x = -abs(sprite.scale.x) # Mantém o tamanho, força a ficar negativo

    # 3. Move o boneco e checa colisões
    move_and_slide()
    
    # 4. A MÁGICA: Bateu na parede? Vira para o outro lado!
    if is_on_wall():
        direction = direction * -1 # Multiplicar por -1 inverte o valor! (de 1 vai pra -1, de -1 vai pra 1)
        

func take_damage():
    health -= 1
    
    modulate = Color.RED
    await get_tree().create_timer(0.1).timeout
    modulate = Color.WHITE
    
    if health <= 0:
        queue_free()