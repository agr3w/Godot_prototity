extends CharacterBody2D

var health = 3
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
    # Gravidade para ele ficar no chão
    if not is_on_floor():
        velocity.y += gravity * delta
    move_and_slide()

# Função que a espada do jogador vai chamar!
func take_damage():
    health -= 1
    
    # Efeito visual de tomar dano (Fica vermelho)
    modulate = Color.RED
    await get_tree().create_timer(0.1).timeout
    modulate = Color.WHITE
    
    # Morre se a vida zerar
    if health <= 0:
        queue_free() # Destrói o nó da cena